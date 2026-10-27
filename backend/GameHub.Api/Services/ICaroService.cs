using GameHub.Api.model;

namespace GameHub.Api.Services;

public interface ICaroService
{
    Task<CaroSavedGameDto?> GetSavedGameAsync(int userId, string? gameMode = null, CancellationToken ct = default);
    Task<CaroSavedGameDto> SaveGameAsync(int userId, SaveCaroGameRequest request, CancellationToken ct = default);
    Task<bool> DeleteSavedGameAsync(int userId, string? gameMode = null, CancellationToken ct = default);
}
