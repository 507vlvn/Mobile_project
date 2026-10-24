using GameHub.Api.model;
using GameHub.Api.Repositories;
using GameHub.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GameHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/friends")]
public class FriendsController(
    IFriendshipRepository friendships,
    IUserRepository users,
    PresenceService presence,
    IRealtimeNotifier notifier) : ApiControllerBase
{
    private FriendDto ToFriend(User u, DateTime? since) => new(
        u.UserId, u.Username, u.FullName, u.AvatarUrl, presence.StatusOf(u.UserId),
        presence.LastSeenInMemory(u.UserId) ?? u.LastSeenAt, since);

    private static object UserPayload(User u) => new { userId = u.UserId, username = u.Username, fullName = u.FullName, avatarUrl = u.AvatarUrl };

    /// <summary>Online trước, rồi đang trong trận, rồi offline (mới thấy gần nhất trước).</summary>
    [HttpGet]
    public async Task<ActionResult<List<FriendDto>>> List(CancellationToken ct)
    {
        var me = CurrentUserId;
        var list = await friendships.Friendships().AsNoTracking().Include(f => f.Requester).Include(f => f.Addressee)
            .Where(f => f.Status == Friendship.Accepted && (f.RequesterId == me || f.AddresseeId == me))
            .ToListAsync(ct);
        var rows = list.Select(f => new { Since = f.RespondedAt ?? f.CreatedAt, Other = f.RequesterId == me ? f.Addressee : f.Requester }).ToList();
        static int Order(string s) => s switch { "online" => 0, "in_match" => 1, _ => 2 };
        return rows.Where(r => r.Other.IsActive).Select(r => ToFriend(r.Other, r.Since))
            .OrderBy(f => Order(f.Status)).ThenByDescending(f => f.LastSeenAt).ThenBy(f => f.Username).ToList();
    }

    [HttpGet("requests")]
    public async Task<ActionResult<FriendRequestsDto>> Requests(CancellationToken ct)
    {
        var me = CurrentUserId;
        var rows = await friendships.Friendships().AsNoTracking().Include(f => f.Requester).Include(f => f.Addressee)
            .Where(f => f.Status == Friendship.Pending && (f.RequesterId == me || f.AddresseeId == me))
            .OrderByDescending(f => f.CreatedAt).Take(100).ToListAsync(ct);
        FriendRequestDto Dto(Friendship f, User u) => new(f.FriendshipId, u.UserId, u.Username, u.FullName, u.AvatarUrl, f.CreatedAt);
        return new FriendRequestsDto(
            rows.Where(f => f.AddresseeId == me && f.Requester.IsActive).Select(f => Dto(f, f.Requester)).ToList(),
            rows.Where(f => f.RequesterId == me && f.Addressee.IsActive).Select(f => Dto(f, f.Addressee)).ToList());
    }

    [HttpPost("requests")]
    public async Task<ActionResult<FriendRequestResultDto>> Send(SendFriendRequest req, CancellationToken ct)
    {
        var me = CurrentUserId;
        if (req.UserId == me) return Problem(statusCode: 400, title: "Không thể kết bạn với chính mình");
        var target = await users.Users().AsNoTracking().FirstOrDefaultAsync(u => u.UserId == req.UserId && u.IsActive, ct);
        if (target is null) return Problem(statusCode: 404, title: "Không tìm thấy người chơi");
        var self = await users.Users().AsNoTracking().FirstAsync(u => u.UserId == me, ct);

        var (low, high) = Friendship.Pair(me, req.UserId);
        var f = await friendships.Friendships().FirstOrDefaultAsync(x => x.UserLowId == low && x.UserHighId == high, ct);
        var now = DateTime.UtcNow;
        try
        {
            if (f is null)
            {
                f = new Friendship { CreatedAt = now };
                f.SetPair(me, req.UserId);
                friendships.Add(f);
            }
            else if (f.Status == Friendship.Accepted) return Problem(statusCode: 409, title: "Hai bạn đã là bạn bè");
            else if (f.Status == Friendship.Pending && f.RequesterId == me) return Problem(statusCode: 409, title: "Bạn đã gửi lời mời cho người này");
            else if (f.Status == Friendship.Pending)
            {
                // Bên kia đã mời mình -> tự thành bạn
                f.Status = Friendship.Accepted;
                f.RespondedAt = now;
                await friendships.SaveChangesAsync(ct);
                await notifier.SendAsync(target.UserId, "FriendAccepted", new { requestId = f.FriendshipId, user = UserPayload(self) });
                return Ok(new FriendRequestResultDto(f.FriendshipId, Friendship.Accepted, ToFriend(target, now)));
            }
            else
            {
                f.SetPair(me, req.UserId); // DECLINED -> mời lại
                f.Status = Friendship.Pending;
                f.CreatedAt = now;
                f.RespondedAt = null;
            }
            await friendships.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            return Problem(statusCode: 409, title: "Lời mời kết bạn đã tồn tại");
        }
        await notifier.SendAsync(target.UserId, "FriendRequest",
            new { requestId = f.FriendshipId, from = UserPayload(self), createdAt = f.CreatedAt });
        return Ok(new FriendRequestResultDto(f.FriendshipId, Friendship.Pending, null));
    }

    [HttpPost("requests/{id:int}/accept")]
    public async Task<ActionResult<FriendRequestResultDto>> Accept(int id, CancellationToken ct)
    {
        var me = CurrentUserId;
        var f = await friendships.Friendships().Include(x => x.Requester).FirstOrDefaultAsync(x => x.FriendshipId == id && x.AddresseeId == me, ct);
        if (f is null) return Problem(statusCode: 404, title: "Không tìm thấy lời mời");
        if (f.Status != Friendship.Pending) return Problem(statusCode: 409, title: "Lời mời này không còn chờ phản hồi");
        f.Status = Friendship.Accepted;
        f.RespondedAt = DateTime.UtcNow;
        await friendships.SaveChangesAsync(ct);
        var self = await users.Users().AsNoTracking().FirstAsync(u => u.UserId == me, ct);
        await notifier.SendAsync(f.RequesterId, "FriendAccepted", new { requestId = f.FriendshipId, user = UserPayload(self) });
        return Ok(new FriendRequestResultDto(f.FriendshipId, Friendship.Accepted, ToFriend(f.Requester, f.RespondedAt)));
    }

    [HttpPost("requests/{id:int}/decline")]
    public async Task<ActionResult<FriendRequestResultDto>> Decline(int id, CancellationToken ct)
    {
        var me = CurrentUserId;
        var f = await friendships.Friendships().FirstOrDefaultAsync(x => x.FriendshipId == id && x.AddresseeId == me, ct);
        if (f is null) return Problem(statusCode: 404, title: "Không tìm thấy lời mời");
        if (f.Status != Friendship.Pending) return Problem(statusCode: 409, title: "Lời mời này không còn chờ phản hồi");
        f.Status = Friendship.Declined;
        f.RespondedAt = DateTime.UtcNow;
        await friendships.SaveChangesAsync(ct);
        return Ok(new FriendRequestResultDto(f.FriendshipId, Friendship.Declined, null));
    }

    /// <summary>Hủy kết bạn (hoặc thu hồi lời mời mình đã gửi). Không có gì để xóa -> 404.</summary>
    [HttpDelete("{userId:int}")]
    public async Task<IActionResult> Remove(int userId, CancellationToken ct)
    {
        var me = CurrentUserId;
        var (low, high) = Friendship.Pair(me, userId);
        var f = await friendships.Friendships().FirstOrDefaultAsync(x => x.UserLowId == low && x.UserHighId == high
            && (x.Status == Friendship.Accepted || (x.Status == Friendship.Pending && x.RequesterId == me)), ct);
        if (f is null) return Problem(statusCode: 404, title: "Hai bạn không phải bạn bè");
        friendships.Remove(f);
        await friendships.SaveChangesAsync(ct);
        return NoContent();
    }
}
