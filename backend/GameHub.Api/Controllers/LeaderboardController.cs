using GameHub.Api.model;
using GameHub.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GameHub.Api.Controllers;

[ApiController]
[Route("api/leaderboard")]
public class LeaderboardController(LeaderboardService svc) : ApiControllerBase
{
    private static readonly string[] Games = ["RUBIK", "SUDOKU", "PUZZLE", "CARO"];

    /// <summary>Tương thích ngược: board thiếu = record; period=week = season.</summary>
    private ActionResult? Parse(string? gameCode, string? board, int? difficulty, string? scope, string? period, out BoardQuery? q)
    {
        q = null;
        if (string.IsNullOrWhiteSpace(gameCode)) return Problem(statusCode: 400, title: "Thiếu mã game");
        if (difficulty is < 1 or > 3) return Problem(statusCode: 400, title: "Độ khó phải từ 1 đến 3");
        board = string.IsNullOrWhiteSpace(board) ? "record" : board.Trim().ToLowerInvariant();
        if (board is not ("ranked" or "record")) return Problem(statusCode: 400, title: "board phải là ranked hoặc record");
        scope = string.IsNullOrWhiteSpace(scope) ? "global" : scope.Trim().ToLowerInvariant();
        if (scope is not ("global" or "friends")) return Problem(statusCode: 400, title: "scope phải là global hoặc friends");
        period = string.IsNullOrWhiteSpace(period) ? "all" : period.Trim().ToLowerInvariant();
        if (period == "week") period = "season";
        if (period is not ("season" or "all")) return Problem(statusCode: 400, title: "period phải là season hoặc all");
        if (scope == "friends" && User.Identity?.IsAuthenticated != true)
            return Problem(statusCode: 401, title: "Cần đăng nhập để xem bảng xếp hạng bạn bè");

        var code = gameCode.Trim().ToUpperInvariant();
        if (!Games.Contains(code)) return Problem(statusCode: 400, title: "Game không tồn tại");
        q = new BoardQuery(code, board, difficulty, scope, period);
        return null;
    }

    private int? AuthUserId() => User.Identity?.IsAuthenticated == true ? CurrentUserId : null;

    [HttpGet]
    public async Task<ActionResult<List<LeaderboardEntryDto>>> Top(
        [FromQuery] string? gameCode, [FromQuery] string? board, [FromQuery] int? difficulty,
        [FromQuery] string? scope, [FromQuery] string? period, [FromQuery] int top = 50, CancellationToken ct = default)
    {
        if (Parse(gameCode, board, difficulty, scope, period, out var q) is { } err) return err;
        return await svc.TopAsync(q!, AuthUserId(), Math.Clamp(top, 1, 100), ct);
    }

    [HttpGet("me")]
    [Authorize]
    public async Task<ActionResult<MyRankDto>> Me(
        [FromQuery] string? gameCode, [FromQuery] string? board, [FromQuery] int? difficulty,
        [FromQuery] string? scope, [FromQuery] string? period, CancellationToken ct = default)
    {
        if (Parse(gameCode, board, difficulty, scope, period, out var q) is { } err) return err;
        return await svc.MyRankAsync(q!, CurrentUserId, ct);
    }

    [HttpGet("season")]
    public SeasonDto CurrentSeason()
    {
        var now = DateTime.UtcNow;
        var s = Season.Of(now);
        return new SeasonDto(s.StartUtc, s.EndUtc, now);
    }
}
