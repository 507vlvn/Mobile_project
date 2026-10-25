using GameHub.Api.model;
using GameHub.Api.Repositories;

namespace GameHub.Api.Services;

public class SudokuService(ISudokuRepository repository) : ISudokuService
{
    private const int TotalLevels = 30;

    public static int GetCluesForLevel(int level)
    {
        if (level <= 1) return 50;
        if (level >= TotalLevels) return 18;
        return 50 - ((level - 1) * (50 - 18) / (TotalLevels - 1));
    }

    public async Task<SudokuProgressSummaryDto> GetProgressSummaryAsync(int userId, CancellationToken ct = default)
    {
        var progressList = await repository.GetProgressListByUserIdAsync(userId, ct);
        var progressMap = progressList.ToDictionary(p => p.Level);

        var completedCount = progressList.Count(p => p.BestTimeSeconds.HasValue);
        var highestUnlocked = 1;
        if (completedCount > 0)
        {
            var maxCompleted = progressList.Where(p => p.BestTimeSeconds.HasValue).Max(p => p.Level);
            highestUnlocked = Math.Min(maxCompleted + 1, TotalLevels);
        }

        var levels = new List<SudokuLevelDto>(TotalLevels);
        for (int lvl = 1; lvl <= TotalLevels; lvl++)
        {
            progressMap.TryGetValue(lvl, out var p);
            var isUnlocked = lvl <= highestUnlocked || (p?.IsUnlocked ?? false);
            var bestTime = p?.BestTimeSeconds;
            var completedAt = p?.CompletedAt;

            levels.Add(new SudokuLevelDto(
                Level: lvl,
                Clues: GetCluesForLevel(lvl),
                IsUnlocked: isUnlocked,
                BestTimeSeconds: bestTime,
                IsCompleted: bestTime.HasValue,
                CompletedAt: completedAt
            ));
        }

        return new SudokuProgressSummaryDto(
            CompletedCount: completedCount,
            HighestUnlockedLevel: highestUnlocked,
            Levels: levels
        );
    }

    public async Task<UpdateSudokuProgressResponse> RecordWinAsync(int userId, UpdateSudokuProgressRequest request, CancellationToken ct = default)
    {
        var level = request.Level;
        if (level < 1 || level > TotalLevels)
        {
            return new UpdateSudokuProgressResponse(false, false, null, 1, "Level không hợp lệ.");
        }

        var existing = await repository.GetProgressByLevelAsync(userId, level, ct);
        var isNewBest = false;
        var now = DateTime.UtcNow;

        if (existing == null)
        {
            isNewBest = true;
            existing = new SudokuProgress
            {
                UserId = userId,
                Level = level,
                IsUnlocked = true,
                BestTimeSeconds = request.TimeSpentSeconds,
                Mistakes = request.Mistakes,
                CompletedAt = now
            };
            await repository.AddProgressAsync(existing, ct);
        }
        else
        {
            existing.IsUnlocked = true;
            if (!existing.BestTimeSeconds.HasValue || request.TimeSpentSeconds < existing.BestTimeSeconds.Value)
            {
                isNewBest = true;
                existing.BestTimeSeconds = request.TimeSpentSeconds;
                existing.Mistakes = request.Mistakes;
            }
            if (!existing.CompletedAt.HasValue)
            {
                existing.CompletedAt = now;
            }
            repository.UpdateProgress(existing);
        }

        // Mở khóa level kế tiếp nếu còn trong 30 màn
        var nextLevel = level + 1;
        if (nextLevel <= TotalLevels)
        {
            var nextRecord = await repository.GetProgressByLevelAsync(userId, nextLevel, ct);
            if (nextRecord == null)
            {
                await repository.AddProgressAsync(new SudokuProgress
                {
                    UserId = userId,
                    Level = nextLevel,
                    IsUnlocked = true
                }, ct);
            }
            else if (!nextRecord.IsUnlocked)
            {
                nextRecord.IsUnlocked = true;
                repository.UpdateProgress(nextRecord);
            }
        }

        await repository.SaveChangesAsync(ct);

        // Tính lại level mở khóa cao nhất
        var allProgress = await repository.GetProgressListByUserIdAsync(userId, ct);
        var completedLevels = allProgress.Where(p => p.BestTimeSeconds.HasValue).Select(p => p.Level).ToList();
        var highestUnlocked = completedLevels.Count > 0
            ? Math.Min(completedLevels.Max() + 1, TotalLevels)
            : 1;

        return new UpdateSudokuProgressResponse(
            Success: true,
            IsNewBest: isNewBest,
            BestTimeSeconds: existing.BestTimeSeconds,
            HighestUnlockedLevel: highestUnlocked,
            Message: isNewBest ? "Chúc mừng bạn đạt kỷ lục mới!" : "Hoàn thành màn chơi thành công."
        );
    }

    public async Task<SudokuSavedGameDto?> GetSavedGameAsync(int userId, string gameMode, CancellationToken ct = default)
    {
        var saved = await repository.GetSavedGameAsync(userId, gameMode.ToUpperInvariant(), ct);
        if (saved == null) return null;

        return new SudokuSavedGameDto(
            Id: saved.Id,
            GameMode: saved.GameMode,
            Level: saved.Level,
            Difficulty: saved.Difficulty,
            Seed: saved.Seed,
            BoardCurrent: saved.BoardCurrent,
            NotesData: saved.NotesData,
            Mistakes: saved.Mistakes,
            ElapsedSeconds: saved.ElapsedSeconds,
            UpdatedAt: saved.UpdatedAt
        );
    }

    public async Task<SudokuSavedGameDto> SaveGameAsync(int userId, SaveSudokuGameRequest request, CancellationToken ct = default)
    {
        var entity = new SudokuSavedGame
        {
            UserId = userId,
            GameMode = request.GameMode.ToUpperInvariant(),
            Level = request.Level,
            Difficulty = request.Difficulty,
            Seed = request.Seed,
            BoardCurrent = request.BoardCurrent,
            NotesData = request.NotesData,
            Mistakes = request.Mistakes,
            ElapsedSeconds = request.ElapsedSeconds,
            UpdatedAt = DateTime.UtcNow
        };

        await repository.UpsertSavedGameAsync(entity, ct);
        await repository.SaveChangesAsync(ct);

        return new SudokuSavedGameDto(
            Id: entity.Id,
            GameMode: entity.GameMode,
            Level: entity.Level,
            Difficulty: entity.Difficulty,
            Seed: entity.Seed,
            BoardCurrent: entity.BoardCurrent,
            NotesData: entity.NotesData,
            Mistakes: entity.Mistakes,
            ElapsedSeconds: entity.ElapsedSeconds,
            UpdatedAt: entity.UpdatedAt
        );
    }

    public async Task<bool> DeleteSavedGameAsync(int userId, string gameMode, CancellationToken ct = default)
    {
        var result = await repository.DeleteSavedGameAsync(userId, gameMode.ToUpperInvariant(), ct);
        if (result)
        {
            await repository.SaveChangesAsync(ct);
        }
        return result;
    }
}
