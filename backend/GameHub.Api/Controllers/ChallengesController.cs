using GameHub.Api.model;
using GameHub.Api.Repositories;
using GameHub.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace GameHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/challenges")]
public class ChallengesController(
    IChallengeRepository challenges,
    IUserRepository users,
    IFriendshipRepository friendships,
    IGameRepository games,
    ChallengeService svc) : ApiControllerBase
{
    private const int PageSize = 100;

    [HttpPost]
    [EnableRateLimiting(RateLimitPolicies.CreateChallenge)]
    public async Task<ActionResult<ChallengeDto>> Create(CreateChallengeRequest req, CancellationToken ct)
    {
        var me = CurrentUserId;
        if (req.OpponentId == me) return Problem(statusCode: 400, title: "Không thể tự thách đấu chính mình");

        var opponentOk = await users.Users().AsNoTracking().AnyAsync(u => u.UserId == req.OpponentId && u.IsActive, ct);
        if (!opponentOk) return Problem(statusCode: 404, title: "Không tìm thấy người chơi");
        if (!await friendships.AreFriendsAsync(me, req.OpponentId, ct))
            return Problem(statusCode: 403, title: "Chỉ nhắn tin / thách đấu với bạn bè");

        var gameCode = req.GameCode.Trim().ToUpperInvariant();
        var game = await games.FindByCodeAsync(gameCode, ct);
        if (game is null) return Problem(statusCode: 400, title: "Game không tồn tại");
        var level = await games.FindDefaultLevelAsync(game.GameId, req.Difficulty, ct);
        if (level is null) return Problem(statusCode: 400, title: "Độ khó không tồn tại cho game này");

        var duplicate = await challenges.Challenges().AsNoTracking().AnyAsync(c =>
            c.GameId == game.GameId && c.LevelId == level.LevelId
            && (c.Status == ChallengeRules.Pending || c.Status == ChallengeRules.Accepted)
            && ((c.ChallengerId == me && c.OpponentId == req.OpponentId)
                || (c.ChallengerId == req.OpponentId && c.OpponentId == me)), ct);
        if (duplicate)
            return Problem(statusCode: 409, title: "Hai bạn đã có thách đấu đang mở cho game và độ khó này");

        var entity = new Challenge
        {
            ChallengerId = me,
            OpponentId = req.OpponentId,
            GameId = game.GameId,
            LevelId = level.LevelId,
            Status = ChallengeRules.Pending,
            CreatedAt = DateTime.UtcNow,
        };
        challenges.Add(entity);
        await challenges.SaveAsync(ct);
        return Ok(await svc.GetDtoAsync(entity.ChallengeId, me, ct));
    }

    [HttpGet]
    public async Task<ActionResult<List<ChallengeDto>>> List([FromQuery] string? box, CancellationToken ct)
    {
        if (!ChallengeRules.TryParseBox(box ?? "active", out var parsed))
            return Problem(statusCode: 400, title: "Hộp thách đấu phải là incoming, outgoing, active, done hoặc all");
        var me = CurrentUserId;
        await svc.ExpireStaleAsync(me, DateTime.UtcNow, ct);

        var q = svc.Full();
        var done = ChallengeRules.DoneStatuses;
        q = parsed switch
        {
            ChallengeBox.Incoming => q.Where(c => c.Status == ChallengeRules.Pending && c.OpponentId == me),
            ChallengeBox.Outgoing => q.Where(c => c.Status == ChallengeRules.Pending && c.ChallengerId == me),
            ChallengeBox.Active => q.Where(c => c.Status == ChallengeRules.Accepted
                                                && (c.ChallengerId == me || c.OpponentId == me)),
            ChallengeBox.Done => q.Where(c => done.Contains(c.Status) && (c.ChallengerId == me || c.OpponentId == me)),
            _ => q.Where(c => c.ChallengerId == me || c.OpponentId == me),
        };
        var list = await q.OrderByDescending(c => c.CreatedAt).ThenByDescending(c => c.ChallengeId)
            .Take(PageSize).ToListAsync(ct);
        return await svc.ToDtosAsync(list, me, ct);
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<ChallengeDto>> Get(int id, CancellationToken ct)
    {
        var me = CurrentUserId;
        await svc.ExpireStaleAsync(me, DateTime.UtcNow, ct);
        var dto = await svc.GetDtoAsync(id, me, ct);
        if (dto is null || (dto.Challenger.UserId != me && dto.Opponent.UserId != me))
            return Problem(statusCode: 404, title: "Không tìm thấy thách đấu");
        return dto;
    }

    [HttpPost("{id:int}/accept")]
    public Task<ActionResult<ChallengeDto>> Accept(int id, CancellationToken ct) =>
        Respond(id, ChallengeRules.Accepted, ct);

    [HttpPost("{id:int}/decline")]
    public Task<ActionResult<ChallengeDto>> Decline(int id, CancellationToken ct) =>
        Respond(id, ChallengeRules.Declined, ct);

    private async Task<ActionResult<ChallengeDto>> Respond(int id, string newStatus, CancellationToken ct)
    {
        var me = CurrentUserId;
        var c = await challenges.FindByIdAsync(id, ct);
        if (c is null || (c.ChallengerId != me && c.OpponentId != me))
            return Problem(statusCode: 404, title: "Không tìm thấy thách đấu");
        if (c.OpponentId != me)
            return Problem(statusCode: 403, title: "Chỉ người được thách mới có thể phản hồi");
        if (c.Status != ChallengeRules.Pending)
            return Problem(statusCode: 409, title: "Thách đấu này không còn chờ phản hồi");
        if (ChallengeRules.IsExpired(c.Status, c.CreatedAt, DateTime.UtcNow))
        {
            c.Status = ChallengeRules.Expired;
            await challenges.SaveAsync(ct);
            return Problem(statusCode: 409, title: "Lời thách đấu đã hết hạn");
        }

        c.Status = newStatus;
        if (newStatus == ChallengeRules.Accepted) c.AcceptedAt = DateTime.UtcNow;
        await challenges.SaveAsync(ct);
        return Ok(await svc.GetDtoAsync(id, me, ct));
    }
}
