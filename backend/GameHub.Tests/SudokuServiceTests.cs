using GameHub.Api.model;
using GameHub.Api.Repositories;
using GameHub.Api.Services;
using Xunit;

namespace GameHub.Tests;

public class SudokuServiceTests
{
    private class FakeSudokuRepository : ISudokuRepository
    {
        public List<SudokuProgress> Progresses { get; } = [];
        public List<SudokuSavedGame> SavedGames { get; } = [];

        public Task<List<SudokuProgress>> GetProgressListByUserIdAsync(int userId, CancellationToken ct = default)
            => Task.FromResult(Progresses.Where(p => p.UserId == userId).ToList());

        public Task<SudokuProgress?> GetProgressByLevelAsync(int userId, int level, CancellationToken ct = default)
            => Task.FromResult(Progresses.FirstOrDefault(p => p.UserId == userId && p.Level == level));

        public Task AddProgressAsync(SudokuProgress progress, CancellationToken ct = default)
        {
            Progresses.Add(progress);
            return Task.CompletedTask;
        }

        public void UpdateProgress(SudokuProgress progress) { }

        public Task<SudokuSavedGame?> GetSavedGameAsync(int userId, string gameMode, CancellationToken ct = default)
            => Task.FromResult(SavedGames.FirstOrDefault(g => g.UserId == userId && g.GameMode.Equals(gameMode, StringComparison.OrdinalIgnoreCase)));

        public Task UpsertSavedGameAsync(SudokuSavedGame savedGame, CancellationToken ct = default)
        {
            var idx = SavedGames.FindIndex(g => g.UserId == savedGame.UserId && g.GameMode.Equals(savedGame.GameMode, StringComparison.OrdinalIgnoreCase));
            if (idx >= 0)
                SavedGames[idx] = savedGame;
            else
                SavedGames.Add(savedGame);
            return Task.CompletedTask;
        }

        public Task<bool> DeleteSavedGameAsync(int userId, string gameMode, CancellationToken ct = default)
        {
            var item = SavedGames.FirstOrDefault(g => g.UserId == userId && g.GameMode.Equals(gameMode, StringComparison.OrdinalIgnoreCase));
            if (item == null) return Task.FromResult(false);
            SavedGames.Remove(item);
            return Task.FromResult(true);
        }

        public List<SudokuDifficultyStat> Stats { get; } = [];

        public Task<List<SudokuDifficultyStat>> GetDifficultyStatsByUserIdAsync(int userId, CancellationToken ct = default)
            => Task.FromResult(Stats.Where(s => s.UserId == userId).ToList());

        public Task<SudokuDifficultyStat?> GetDifficultyStatAsync(int userId, int difficulty, CancellationToken ct = default)
            => Task.FromResult(Stats.FirstOrDefault(s => s.UserId == userId && s.Difficulty == difficulty));

        public Task UpsertDifficultyStatAsync(SudokuDifficultyStat stat, CancellationToken ct = default)
        {
            var idx = Stats.FindIndex(s => s.UserId == stat.UserId && s.Difficulty == stat.Difficulty);
            if (idx >= 0) Stats[idx] = stat;
            else Stats.Add(stat);
            return Task.CompletedTask;
        }

        public Task<int> SaveChangesAsync(CancellationToken ct = default) => Task.FromResult(1);
    }

    [Fact]
    public void GetCluesForLevel_MatchesExpectedScaling()
    {
        Assert.Equal(50, SudokuService.GetCluesForLevel(1));
        Assert.Equal(18, SudokuService.GetCluesForLevel(30));
        Assert.True(SudokuService.GetCluesForLevel(15) < 50);
        Assert.True(SudokuService.GetCluesForLevel(15) > 18);
    }

    [Fact]
    public async Task GetProgressSummaryAsync_NewUser_HasLevel1UnlockedOnly()
    {
        var repo = new FakeSudokuRepository();
        var service = new SudokuService(repo);

        var summary = await service.GetProgressSummaryAsync(userId: 1);

        Assert.Equal(0, summary.CompletedCount);
        Assert.Equal(1, summary.HighestUnlockedLevel);
        Assert.Equal(30, summary.Levels.Count);
        Assert.True(summary.Levels[0].IsUnlocked);
        Assert.False(summary.Levels[1].IsUnlocked);
    }

    [Fact]
    public async Task RecordWinAsync_UnlocksNextLevel_AndRecordsBestTime()
    {
        var repo = new FakeSudokuRepository();
        var service = new SudokuService(repo);

        var response = await service.RecordWinAsync(1, new UpdateSudokuProgressRequest(
            Level: 1,
            TimeSpentSeconds: 120,
            Mistakes: 1
        ));

        Assert.True(response.Success);
        Assert.True(response.IsNewBest);
        Assert.Equal(120, response.BestTimeSeconds);
        Assert.Equal(2, response.HighestUnlockedLevel);

        // Record a faster time
        var response2 = await service.RecordWinAsync(1, new UpdateSudokuProgressRequest(
            Level: 1,
            TimeSpentSeconds: 95,
            Mistakes: 0
        ));

        Assert.True(response2.Success);
        Assert.True(response2.IsNewBest);
        Assert.Equal(95, response2.BestTimeSeconds);

        // Record a slower time -> not new best
        var response3 = await service.RecordWinAsync(1, new UpdateSudokuProgressRequest(
            Level: 1,
            TimeSpentSeconds: 150,
            Mistakes: 2
        ));

        Assert.True(response3.Success);
        Assert.False(response3.IsNewBest);
        Assert.Equal(95, response3.BestTimeSeconds);
    }

    [Fact]
    public async Task SaveAndGetSavedGameAsync_WorksCorrectly()
    {
        var repo = new FakeSudokuRepository();
        var service = new SudokuService(repo);

        var saved = await service.SaveGameAsync(1, new SaveSudokuGameRequest(
            GameMode: "CLASSIC",
            Level: null,
            Difficulty: 2,
            Seed: 123456,
            BoardCurrent: new string('0', 81),
            NotesData: null,
            Mistakes: 1,
            ElapsedSeconds: 65
        ));

        Assert.NotNull(saved);
        Assert.Equal("CLASSIC", saved.GameMode);
        Assert.Equal(65, saved.ElapsedSeconds);

        var retrieved = await service.GetSavedGameAsync(1, "CLASSIC");
        Assert.NotNull(retrieved);
        Assert.Equal(123456, retrieved.Seed);

        var deleted = await service.DeleteSavedGameAsync(1, "CLASSIC");
        Assert.True(deleted);

        var retrievedAfterDelete = await service.GetSavedGameAsync(1, "CLASSIC");
        Assert.Null(retrievedAfterDelete);
    }

    [Fact]
    public async Task DifficultyStats_RecordAndGet_WorksCorrectly()
    {
        var repo = new FakeSudokuRepository();
        var service = new SudokuService(repo);

        // Initially returns 5 difficulties (Dễ … Ác mộng) with 0s
        var initial = await service.GetDifficultyStatsAsync(userId: 1);
        Assert.Equal(5, initial.Count);
        Assert.Equal(1, initial[0].Difficulty);
        Assert.Equal(5, initial[4].Difficulty);
        Assert.Equal(0, initial[0].GamesStarted);

        // Record game started on difficulty 2 (Medium)
        var s1 = await service.RecordDifficultyStatAsync(1, new RecordSudokuStatRequest(
            Difficulty: 2,
            IsGameStarted: true,
            IsWin: false,
            ElapsedSeconds: 0,
            Mistakes: 0
        ));
        Assert.Equal(1, s1.GamesStarted);
        Assert.Equal(0, s1.GamesWon);

        // Record win without mistakes in 120s
        var s2 = await service.RecordDifficultyStatAsync(1, new RecordSudokuStatRequest(
            Difficulty: 2,
            IsGameStarted: false,
            IsWin: true,
            ElapsedSeconds: 120,
            Mistakes: 0
        ));
        Assert.Equal(1, s2.GamesStarted);
        Assert.Equal(1, s2.GamesWon);
        Assert.Equal(1, s2.WinWithoutMistakes);
        Assert.Equal(120, s2.BestTimeSeconds);
        Assert.Equal(120, s2.TotalWinTimeSeconds);

        // Record another win with 1 mistake in 90s (faster)
        var s3 = await service.RecordDifficultyStatAsync(1, new RecordSudokuStatRequest(
            Difficulty: 2,
            IsGameStarted: false,
            IsWin: true,
            ElapsedSeconds: 90,
            Mistakes: 1
        ));
        Assert.Equal(2, s3.GamesWon);
        Assert.Equal(1, s3.WinWithoutMistakes); // Still 1
        Assert.Equal(90, s3.BestTimeSeconds); // Faster best time
        Assert.Equal(210, s3.TotalWinTimeSeconds);

        // Get all stats
        var allStats = await service.GetDifficultyStatsAsync(1);
        Assert.Equal(5, allStats.Count);
        Assert.Equal(2, allStats[1].GamesWon);
    }
}
