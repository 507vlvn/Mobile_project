using GameHub.Api.model;
using Microsoft.EntityFrameworkCore;

namespace GameHub.Api.Services;

public record PlayerInfo(int UserId, string Username, string? FullName, string? AvatarUrl, int Rating, int RatedGames);

public record PlayerOutcome(
    int UserId, string Result, int Score, int TimeSeconds, int Mistakes, int Moves, int RatingBefore, int RatingAfter);

public record MatchResultRecord(
    string GameCode, int Difficulty, string Mode, string Kind, int Seed, DateTime StartedAt, DateTime EndedAt,
    int? WinnerId, string Reason, PlayerOutcome P1, PlayerOutcome P2)
{
    public bool Ranked => Mode == "RANKED";
}

/// <summary>Truy cập DB của MatchService (tách ra để test không cần DB).</summary>
public interface IMatchData
{
    Task<PlayerInfo?> LoadPlayerAsync(int userId, string gameCode, CancellationToken ct = default);
    Task<bool> AreFriendsAsync(int a, int b, CancellationToken ct = default);
    /// <summary>Ghi MỘT transaction: Matches + 2 History + (xếp hạng) upsert PlayerRatings.</summary>
    Task SaveResultAsync(MatchResultRecord r, CancellationToken ct = default);
}

public sealed class EfMatchData(IServiceScopeFactory scopes) : IMatchData
{
    public async Task<PlayerInfo?> LoadPlayerAsync(int userId, string gameCode, CancellationToken ct = default)
    {
        using var scope = scopes.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<GameHubDbContext>();
        var u = await db.Users.AsNoTracking().FirstOrDefaultAsync(x => x.UserId == userId && x.IsActive, ct);
        if (u is null) return null;
        var pr = await db.PlayerRatings.AsNoTracking()
            .Where(r => r.UserId == userId && db.Games.Any(g => g.GameId == r.GameId && g.GameCode == gameCode))
            .Select(r => new { r.Rating, r.Games }).FirstOrDefaultAsync(ct);
        return new PlayerInfo(u.UserId, u.Username, u.FullName, u.AvatarUrl, pr?.Rating ?? Elo.StartRating, pr?.Games ?? 0);
    }

    public async Task<bool> AreFriendsAsync(int a, int b, CancellationToken ct = default)
    {
        using var scope = scopes.CreateScope();
        return await scope.ServiceProvider.GetRequiredService<GameHubDbContext>().AreFriendsAsync(a, b, ct);
    }

    public async Task SaveResultAsync(MatchResultRecord r, CancellationToken ct = default)
    {
        using var scope = scopes.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<GameHubDbContext>();
        var game = await db.Games.AsNoTracking().FirstAsync(g => g.GameCode == r.GameCode, ct);
        var level = await db.DefaultLevelAsync(game.GameId, r.Difficulty, ct);

        var match = new GameMatch
        {
            GameId = game.GameId, Difficulty = r.Difficulty, Mode = r.Mode, Kind = r.Kind,
            Player1Id = r.P1.UserId, Player2Id = r.P2.UserId, WinnerId = r.WinnerId, EndReason = r.Reason,
            Seed = r.Seed, StartedAt = r.StartedAt, EndedAt = r.EndedAt,
            P1RatingBefore = r.Ranked ? r.P1.RatingBefore : null, P1RatingAfter = r.Ranked ? r.P1.RatingAfter : null,
            P2RatingBefore = r.Ranked ? r.P2.RatingBefore : null, P2RatingAfter = r.Ranked ? r.P2.RatingAfter : null,
        };
        db.Matches.Add(match);

        foreach (var o in new[] { r.P1, r.P2 })
        {
            db.History.Add(new HistoryEntry
            {
                UserId = o.UserId, GameId = game.GameId, LevelId = level?.LevelId, Match = match,
                TimeSpentSeconds = Math.Max(o.TimeSeconds, 0), MistakesCount = Math.Max(o.Mistakes, 0),
                MovesCount = o.Moves, HintsUsed = 0, Result = o.Result, Score = o.Score, PlayedAt = r.EndedAt,
            });
        }

        if (r.Ranked)
        {
            var ids = new[] { r.P1.UserId, r.P2.UserId };
            var existing = await db.PlayerRatings.Where(x => x.GameId == game.GameId && ids.Contains(x.UserId)).ToListAsync(ct);
            foreach (var o in new[] { r.P1, r.P2 })
            {
                var row = existing.FirstOrDefault(x => x.UserId == o.UserId);
                if (row is null)
                {
                    row = new PlayerRating { UserId = o.UserId, GameId = game.GameId };
                    db.PlayerRatings.Add(row);
                }
                row.Rating = o.RatingAfter;
                row.PeakRating = Math.Max(row.PeakRating, o.RatingAfter);
                row.Games++;
                if (o.Result == "WIN") row.Wins++;
                else if (o.Result == "DRAW") row.Draws++;
                else row.Losses++;
                row.UpdatedAt = r.EndedAt;
            }
        }

        await db.SaveChangesAsync(ct); // một lần SaveChanges = một transaction
    }
}
