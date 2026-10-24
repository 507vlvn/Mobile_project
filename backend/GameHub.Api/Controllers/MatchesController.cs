using GameHub.Api.model;
using GameHub.Api.Repositories;
using GameHub.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GameHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api")]
public class MatchesController(
    IMatchRepository matches,
    IUserRepository users,
    IGameRepository games,
    GameHubDbContext db) : ApiControllerBase
{
    [HttpGet("matches")]
    public async Task<ActionResult<PagedResult<MatchHistoryDto>>> Mine(
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default)
    {
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 50);
        var me = CurrentUserId;
        var q = matches.Matches().AsNoTracking().Where(m => m.Player1Id == me || m.Player2Id == me);
        var total = await q.CountAsync(ct);
        var rows = await q.OrderByDescending(m => m.EndedAt).ThenByDescending(m => m.MatchId)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);

        var otherIds = rows.Select(m => m.Player1Id == me ? m.Player2Id : m.Player1Id).Distinct().ToList();
        var userDict = await users.Users().AsNoTracking().Where(u => otherIds.Contains(u.UserId)).ToDictionaryAsync(u => u.UserId, ct);
        var gameDict = await games.Games().AsNoTracking().ToDictionaryAsync(g => g.GameId, ct);

        var items = rows.Select(m =>
        {
            var first = m.Player1Id == me;
            var oppId = first ? m.Player2Id : m.Player1Id;
            userDict.TryGetValue(oppId, out var o);
            var g = gameDict[m.GameId];
            var before = first ? m.P1RatingBefore : m.P2RatingBefore;
            var after = first ? m.P1RatingAfter : m.P2RatingAfter;
            var result = m.WinnerId == me ? "WIN" : m.WinnerId is null ? "DRAW" : "LOSE";
            return new MatchHistoryDto(m.MatchId, g.GameCode, g.GameName, m.Difficulty, m.Mode, m.Kind,
                new UserSummaryDto(oppId, o?.Username ?? "?", o?.FullName, o?.AvatarUrl),
                result, m.EndReason, before, after, before is int b && after is int a ? a - b : null,
                m.StartedAt, m.EndedAt, (int)(m.EndedAt - m.StartedAt).TotalSeconds);
        }).ToList();
        return new PagedResult<MatchHistoryDto>(items, page, pageSize, total);
    }

    [HttpGet("ratings/me")]
    public async Task<ActionResult<List<RatingDto>>> MyRatings(CancellationToken ct) =>
        await db.RatingsAsync(CurrentUserId, ct);
}
