using GameHub.Api.Infrastructure;
using GameHub.Api.model;
using GameHub.Api.Realtime;
using GameHub.Api.Repositories;
using GameHub.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace GameHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/messages")]
public class MessagesController(
    IMessageRepository messages,
    IUserRepository users,
    IFriendshipRepository friendships,
    IRealtimeNotifier notifier,
    GameHubDbContext db) : ApiControllerBase
{
    private const int MaxConversations = 50;

    private static MessageDto ToDto(Message m) => new(m.MessageId, m.SenderId, m.ReceiverId, m.Content, m.IsRead, m.SentAt);

    [HttpGet("conversations")]
    public async Task<ActionResult<List<ConversationDto>>> Conversations(CancellationToken ct)
    {
        var me = CurrentUserId;
        var groups = await messages.Messages().AsNoTracking()
            .Where(m => m.SenderId == me || m.ReceiverId == me)
            .GroupBy(m => m.SenderId == me ? m.ReceiverId : m.SenderId)
            .Select(g => new
            {
                PartnerId = g.Key,
                LastId = g.Max(m => m.MessageId),
                Unread = g.Sum(m => m.ReceiverId == me && !m.IsRead ? 1 : 0),
            })
            .OrderByDescending(g => g.LastId)
            .Take(MaxConversations)
            .ToListAsync(ct);
        if (groups.Count == 0) return new List<ConversationDto>();

        var lastIds = groups.Select(g => g.LastId).ToList();
        var partnerIds = groups.Select(g => g.PartnerId).ToList();
        var lastMessages = (await messages.Messages().AsNoTracking().Where(m => lastIds.Contains(m.MessageId)).ToListAsync(ct))
            .ToDictionary(m => m.MessageId);
        var userDict = (await users.Users().AsNoTracking().Where(u => partnerIds.Contains(u.UserId)).ToListAsync(ct))
            .ToDictionary(u => u.UserId);

        return groups.Where(g => userDict.ContainsKey(g.PartnerId)).Select(g =>
        {
            var u = userDict[g.PartnerId];
            var m = lastMessages[g.LastId];
            return new ConversationDto(u.UserId, u.Username, u.FullName, u.AvatarUrl,
                m.Content, m.SentAt, m.SenderId == me, g.Unread);
        }).ToList();
    }

    /// <summary>Tăng dần theo message_id. afterId: tin mới hơn (polling); beforeId: tin cũ hơn (tải lịch sử).</summary>
    [HttpGet("with/{userId:int}")]
    public async Task<ActionResult<List<MessageDto>>> With(
        int userId, [FromQuery] int? afterId, [FromQuery] int? beforeId, [FromQuery] int? limit, CancellationToken ct)
    {
        var me = CurrentUserId;
        if (userId == me) return Problem(statusCode: 400, title: "Không thể nhắn tin cho chính mình");
        if (!await users.Users().AsNoTracking().AnyAsync(u => u.UserId == userId, ct))
            return Problem(statusCode: 404, title: "Không tìm thấy người chơi");

        var take = ChallengeRules.ClampLimit(limit);
        var q = messages.Messages().AsNoTracking().Where(m =>
            (m.SenderId == me && m.ReceiverId == userId) || (m.SenderId == userId && m.ReceiverId == me));

        List<Message> rows;
        if (afterId is int after)
        {
            rows = await q.Where(m => m.MessageId > after).OrderBy(m => m.MessageId).Take(take).ToListAsync(ct);
        }
        else
        {
            if (beforeId is int before) q = q.Where(m => m.MessageId < before);
            rows = await q.OrderByDescending(m => m.MessageId).Take(take).ToListAsync(ct);
            rows.Reverse();
        }
        return rows.Select(ToDto).ToList();
    }

    [HttpPost("with/{userId:int}")]
    [EnableRateLimiting(RateLimitPolicies.SendMessage)]
    public async Task<ActionResult<MessageDto>> Send(int userId, SendMessageRequest req, CancellationToken ct)
    {
        var me = CurrentUserId;
        if (userId == me) return Problem(statusCode: 400, title: "Không thể nhắn tin cho chính mình");
        if (!ChallengeRules.TryNormalizeMessage(req.Content, out var content, out var error))
            return Problem(statusCode: 400, title: error);
        if (!await users.Users().AsNoTracking().AnyAsync(u => u.UserId == userId && u.IsActive, ct))
            return Problem(statusCode: 404, title: "Không tìm thấy người chơi");
        if (!await friendships.AreFriendsAsync(me, userId, ct))
            return Problem(statusCode: 403, title: "Chỉ nhắn tin / thách đấu với bạn bè");

        var m = new Message { SenderId = me, ReceiverId = userId, Content = content, IsRead = false, SentAt = DateTime.UtcNow };
        messages.Add(m);
        await messages.SaveChangesAsync(ct);
        await notifier.SendAsync(userId, "MessageReceived", ToDto(m));
        return Ok(ToDto(m));
    }

    [HttpPost("with/{userId:int}/read")]
    public async Task<IActionResult> MarkRead(int userId, CancellationToken ct)
    {
        var me = CurrentUserId;
        await db.Messages.Where(m => m.SenderId == userId && m.ReceiverId == me && !m.IsRead)
            .ExecuteUpdateAsync(s => s.SetProperty(m => m.IsRead, true), ct);
        return NoContent();
    }
}
