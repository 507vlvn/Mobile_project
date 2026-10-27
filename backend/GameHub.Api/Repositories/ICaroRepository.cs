using GameHub.Api.model;

namespace GameHub.Api.Repositories;

public interface ICaroRepository
{
    Task<CaroSavedGame?> GetSavedGameAsync(int userId, string? gameMode = null, CancellationToken ct = default);
    Task UpsertSavedGameAsync(CaroSavedGame savedGame, CancellationToken ct = default);
    Task<bool> DeleteSavedGameAsync(int userId, string? gameMode = null, CancellationToken ct = default);
    Task<int> SaveChangesAsync(CancellationToken ct = default);
}
