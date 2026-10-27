using GameHub.Api.model;
using Microsoft.EntityFrameworkCore;

namespace GameHub.Api.Repositories;

public class CaroRepository(GameHubDbContext db) : ICaroRepository
{
    public Task<CaroSavedGame?> GetSavedGameAsync(int userId, string? gameMode = null, CancellationToken ct = default)
    {
        var q = db.CaroSavedGames.Where(g => g.UserId == userId);
        if (!string.IsNullOrEmpty(gameMode))
        {
            q = q.Where(g => g.GameMode == gameMode);
        }
        return q.OrderByDescending(g => g.UpdatedAt).FirstOrDefaultAsync(ct);
    }

    public async Task UpsertSavedGameAsync(CaroSavedGame savedGame, CancellationToken ct = default)
    {
        var existing = await db.CaroSavedGames
            .FirstOrDefaultAsync(g => g.UserId == savedGame.UserId && g.GameMode == savedGame.GameMode, ct);

        if (existing == null)
        {
            await db.CaroSavedGames.AddAsync(savedGame, ct);
        }
        else
        {
            existing.Difficulty = savedGame.Difficulty;
            existing.PlayerFirst = savedGame.PlayerFirst;
            existing.HistoryData = savedGame.HistoryData;
            existing.Undos = savedGame.Undos;
            existing.ElapsedSeconds = savedGame.ElapsedSeconds;
            existing.HintsRemaining = savedGame.HintsRemaining;
            existing.UpdatedAt = DateTime.UtcNow;
            db.CaroSavedGames.Update(existing);
        }
    }

    public async Task<bool> DeleteSavedGameAsync(int userId, string? gameMode = null, CancellationToken ct = default)
    {
        var q = db.CaroSavedGames.Where(g => g.UserId == userId);
        if (!string.IsNullOrEmpty(gameMode))
        {
            q = q.Where(g => g.GameMode == gameMode);
        }

        var matches = await q.ToListAsync(ct);
        if (matches.Count == 0) return false;

        db.CaroSavedGames.RemoveRange(matches);
        return true;
    }

    public Task<int> SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}
