using Microsoft.EntityFrameworkCore;
using GameHub.Api.model;

namespace GameHub.Api.Repositories;

public class HistoryRepository(GameHubDbContext db) : IHistoryRepository
{
    private static readonly string[] Scoring = ["COMPLETED", "WIN"];

    public IQueryable<HistoryEntry> History() => db.History;

    public Task<int?> GetPersonalBestScoreAsync(int userId, int gameId, int difficulty, CancellationToken ct = default) =>
        db.History.AsNoTracking()
            .Where(h => h.UserId == userId && h.GameId == gameId
                        && h.Level!.Difficulty == difficulty && Scoring.Contains(h.Result))
            .MaxAsync(h => (int?)h.Score, ct);

    public void Add(HistoryEntry entry) => db.History.Add(entry);

    public void Remove(HistoryEntry entry) => db.History.Remove(entry);

    public Task<bool> SaveAsync(CancellationToken ct = default) => db.TrySaveAsync(ct);

    public Task<int> SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}
