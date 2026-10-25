using GameHub.Api.model;

namespace GameHub.Api.Repositories;

public interface ISudokuRepository
{
    Task<List<SudokuProgress>> GetProgressListByUserIdAsync(int userId, CancellationToken ct = default);
    Task<SudokuProgress?> GetProgressByLevelAsync(int userId, int level, CancellationToken ct = default);
    Task AddProgressAsync(SudokuProgress progress, CancellationToken ct = default);
    void UpdateProgress(SudokuProgress progress);

    Task<SudokuSavedGame?> GetSavedGameAsync(int userId, string gameMode, CancellationToken ct = default);
    Task UpsertSavedGameAsync(SudokuSavedGame savedGame, CancellationToken ct = default);
    Task<bool> DeleteSavedGameAsync(int userId, string gameMode, CancellationToken ct = default);

    Task<int> SaveChangesAsync(CancellationToken ct = default);
}
