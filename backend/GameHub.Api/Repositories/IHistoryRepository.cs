using GameHub.Api.model;

namespace GameHub.Api.Repositories;

public interface IHistoryRepository
{
    IQueryable<HistoryEntry> History();
    Task<int?> GetPersonalBestScoreAsync(int userId, int gameId, int difficulty, CancellationToken ct = default);
    void Add(HistoryEntry entry);
    void Remove(HistoryEntry entry);
    Task<bool> SaveAsync(CancellationToken ct = default);
    Task<int> SaveChangesAsync(CancellationToken ct = default);
}
