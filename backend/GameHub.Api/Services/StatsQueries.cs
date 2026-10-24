using GameHub.Api.model;
using Microsoft.EntityFrameworkCore;

namespace GameHub.Api.Services;

public static class StatsQueries
{
    public static readonly string[] GameOrder = ["RUBIK", "SUDOKU", "PUZZLE", "CARO"];
    private static readonly string[] Scoring = ["COMPLETED", "WIN"];

    /// <summary>Thống kê 4 game: số trận (Matches), kỷ lục chơi đơn, rating.</summary>
    public static async Task<List<GameStatsDto>> GameStatsAsync(this GameHubDbContext db, int userId, CancellationToken ct = default)
    {
        var games = await db.Games.AsNoTracking().ToListAsync(ct);
        var matches = await db.Matches.AsNoTracking()
            .Where(m => m.Player1Id == userId || m.Player2Id == userId)
            .GroupBy(m => m.GameId)
            .Select(g => new
            {
                GameId = g.Key,
                Games = g.Count(),
                Wins = g.Count(m => m.WinnerId == userId),
                Draws = g.Count(m => m.WinnerId == null),
            }).ToDictionaryAsync(x => x.GameId, ct);
        var best = await db.History.AsNoTracking()
            .Where(h => h.UserId == userId && Scoring.Contains(h.Result) && h.MatchId == null)
            .GroupBy(h => h.GameId)
            .Select(g => new { GameId = g.Key, Best = g.Max(h => h.Score) })
            .ToDictionaryAsync(x => x.GameId, x => x.Best, ct);
        var ratings = await db.PlayerRatings.AsNoTracking().Where(r => r.UserId == userId).ToDictionaryAsync(r => r.GameId, ct);

        var list = new List<GameStatsDto>();
        foreach (var code in GameOrder)
        {
            var g = games.FirstOrDefault(x => x.GameCode == code);
            if (g is null) continue;
            matches.TryGetValue(g.GameId, out var m);
            ratings.TryGetValue(g.GameId, out var r);
            var rating = r?.Rating ?? Elo.StartRating;
            var t = Tiers.Of(rating);
            var played = m?.Games ?? 0;
            var wins = m?.Wins ?? 0;
            var draws = m?.Draws ?? 0;
            list.Add(new GameStatsDto(code, g.GameName, played, wins, played - wins - draws, draws,
                best.TryGetValue(g.GameId, out var b) ? b : null,
                rating, t.Code, t.Name, r?.PeakRating ?? Elo.StartRating, r?.Games ?? 0));
        }
        return list;
    }

    public static async Task<List<RatingDto>> RatingsAsync(this GameHubDbContext db, int userId, CancellationToken ct = default)
    {
        var games = await db.Games.AsNoTracking().ToListAsync(ct);
        var ratings = await db.PlayerRatings.AsNoTracking().Where(r => r.UserId == userId).ToDictionaryAsync(r => r.GameId, ct);
        var list = new List<RatingDto>();
        foreach (var code in GameOrder)
        {
            var g = games.FirstOrDefault(x => x.GameCode == code);
            if (g is null) continue;
            ratings.TryGetValue(g.GameId, out var r);
            var rating = r?.Rating ?? Elo.StartRating;
            var t = Tiers.Of(rating);
            list.Add(new RatingDto(g.GameCode, g.GameName, rating, t.Code, t.Name,
                r?.Games ?? 0, r?.Wins ?? 0, r?.Losses ?? 0, r?.Draws ?? 0, r?.PeakRating ?? Elo.StartRating));
        }
        return list;
    }
}
