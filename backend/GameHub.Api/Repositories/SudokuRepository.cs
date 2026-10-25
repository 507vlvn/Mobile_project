using GameHub.Api.model;
using Microsoft.EntityFrameworkCore;

namespace GameHub.Api.Repositories;

public class SudokuRepository(GameHubDbContext db) : ISudokuRepository
{
    public Task<List<SudokuProgress>> GetProgressListByUserIdAsync(int userId, CancellationToken ct = default) =>
        db.SudokuProgresses.AsNoTracking()
            .Where(p => p.UserId == userId)
            .OrderBy(p => p.Level)
            .ToListAsync(ct);

    public Task<SudokuProgress?> GetProgressByLevelAsync(int userId, int level, CancellationToken ct = default) =>
        db.SudokuProgresses
            .FirstOrDefaultAsync(p => p.UserId == userId && p.Level == level, ct);

    public async Task AddProgressAsync(SudokuProgress progress, CancellationToken ct = default) =>
        await db.SudokuProgresses.AddAsync(progress, ct);

    public void UpdateProgress(SudokuProgress progress) =>
        db.SudokuProgresses.Update(progress);

    public Task<SudokuSavedGame?> GetSavedGameAsync(int userId, string gameMode, CancellationToken ct = default) =>
        db.SudokuSavedGames
            .FirstOrDefaultAsync(g => g.UserId == userId && g.GameMode == gameMode, ct);

    public async Task UpsertSavedGameAsync(SudokuSavedGame savedGame, CancellationToken ct = default)
    {
        var existing = await db.SudokuSavedGames
            .FirstOrDefaultAsync(g => g.UserId == savedGame.UserId && g.GameMode == savedGame.GameMode, ct);

        if (existing == null)
        {
            await db.SudokuSavedGames.AddAsync(savedGame, ct);
        }
        else
        {
            existing.Level = savedGame.Level;
            existing.Difficulty = savedGame.Difficulty;
            existing.Seed = savedGame.Seed;
            existing.BoardCurrent = savedGame.BoardCurrent;
            existing.NotesData = savedGame.NotesData;
            existing.Mistakes = savedGame.Mistakes;
            existing.ElapsedSeconds = savedGame.ElapsedSeconds;
            existing.UpdatedAt = DateTime.UtcNow;
        }
    }

    public async Task<bool> DeleteSavedGameAsync(int userId, string gameMode, CancellationToken ct = default)
    {
        var existing = await db.SudokuSavedGames
            .FirstOrDefaultAsync(g => g.UserId == userId && g.GameMode == gameMode, ct);

        if (existing == null) return false;

        db.SudokuSavedGames.Remove(existing);
        return true;
    }

    public Task<int> SaveChangesAsync(CancellationToken ct = default) =>
        db.SaveChangesAsync(ct);
}
