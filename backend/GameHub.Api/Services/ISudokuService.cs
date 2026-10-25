using GameHub.Api.model;

namespace GameHub.Api.Services;

public interface ISudokuService
{
    Task<SudokuProgressSummaryDto> GetProgressSummaryAsync(int userId, CancellationToken ct = default);
    Task<UpdateSudokuProgressResponse> RecordWinAsync(int userId, UpdateSudokuProgressRequest request, CancellationToken ct = default);
    Task<SudokuSavedGameDto?> GetSavedGameAsync(int userId, string gameMode, CancellationToken ct = default);
    Task<SudokuSavedGameDto> SaveGameAsync(int userId, SaveSudokuGameRequest request, CancellationToken ct = default);
    Task<bool> DeleteSavedGameAsync(int userId, string gameMode, CancellationToken ct = default);

    Task<List<DifficultyStatsDto>> GetDifficultyStatsAsync(int userId, CancellationToken ct = default);
    Task<DifficultyStatsDto> RecordDifficultyStatAsync(int userId, RecordSudokuStatRequest request, CancellationToken ct = default);
}
