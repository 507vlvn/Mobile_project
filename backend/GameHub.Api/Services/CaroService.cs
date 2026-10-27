using GameHub.Api.model;
using GameHub.Api.Repositories;

namespace GameHub.Api.Services;

public class CaroService(ICaroRepository repository) : ICaroService
{
    public async Task<CaroSavedGameDto?> GetSavedGameAsync(int userId, string? gameMode = null, CancellationToken ct = default)
    {
        var normalizedMode = gameMode?.Trim().ToLowerInvariant();
        var saved = await repository.GetSavedGameAsync(userId, normalizedMode, ct);
        if (saved == null) return null;

        return new CaroSavedGameDto(
            Id: saved.Id,
            GameMode: saved.GameMode,
            Difficulty: saved.Difficulty,
            PlayerFirst: saved.PlayerFirst,
            HistoryData: saved.HistoryData,
            Undos: saved.Undos,
            ElapsedSeconds: saved.ElapsedSeconds,
            HintsRemaining: saved.HintsRemaining,
            UpdatedAt: saved.UpdatedAt
        );
    }

    public async Task<CaroSavedGameDto> SaveGameAsync(int userId, SaveCaroGameRequest request, CancellationToken ct = default)
    {
        var normalizedMode = request.GameMode.Trim().ToLowerInvariant();
        var entity = new CaroSavedGame
        {
            UserId = userId,
            GameMode = normalizedMode,
            Difficulty = request.Difficulty,
            PlayerFirst = request.PlayerFirst,
            HistoryData = request.HistoryData,
            Undos = request.Undos,
            ElapsedSeconds = request.ElapsedSeconds,
            HintsRemaining = request.HintsRemaining,
            UpdatedAt = DateTime.UtcNow
        };

        await repository.UpsertSavedGameAsync(entity, ct);
        await repository.SaveChangesAsync(ct);

        return new CaroSavedGameDto(
            Id: entity.Id,
            GameMode: entity.GameMode,
            Difficulty: entity.Difficulty,
            PlayerFirst: entity.PlayerFirst,
            HistoryData: entity.HistoryData,
            Undos: entity.Undos,
            ElapsedSeconds: entity.ElapsedSeconds,
            HintsRemaining: entity.HintsRemaining,
            UpdatedAt: entity.UpdatedAt
        );
    }

    public async Task<bool> DeleteSavedGameAsync(int userId, string? gameMode = null, CancellationToken ct = default)
    {
        var normalizedMode = gameMode?.Trim().ToLowerInvariant();
        var result = await repository.DeleteSavedGameAsync(userId, normalizedMode, ct);
        if (result)
        {
            await repository.SaveChangesAsync(ct);
        }
        return result;
    }
}
