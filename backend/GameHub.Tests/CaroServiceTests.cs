using GameHub.Api.model;
using GameHub.Api.Repositories;
using GameHub.Api.Services;
using Xunit;

namespace GameHub.Tests;

public class CaroServiceTests
{
    private class FakeCaroRepository : ICaroRepository
    {
        public List<CaroSavedGame> SavedGames { get; } = [];

        public Task<CaroSavedGame?> GetSavedGameAsync(int userId, string? gameMode = null, CancellationToken ct = default)
        {
            var q = SavedGames.Where(g => g.UserId == userId);
            if (!string.IsNullOrEmpty(gameMode))
            {
                q = q.Where(g => g.GameMode.Equals(gameMode, StringComparison.OrdinalIgnoreCase));
            }
            return Task.FromResult(q.OrderByDescending(g => g.UpdatedAt).FirstOrDefault());
        }

        public Task UpsertSavedGameAsync(CaroSavedGame savedGame, CancellationToken ct = default)
        {
            var idx = SavedGames.FindIndex(g => g.UserId == savedGame.UserId && g.GameMode.Equals(savedGame.GameMode, StringComparison.OrdinalIgnoreCase));
            if (idx >= 0)
            {
                SavedGames[idx] = savedGame;
            }
            else
            {
                SavedGames.Add(savedGame);
            }
            return Task.CompletedTask;
        }

        public Task<bool> DeleteSavedGameAsync(int userId, string? gameMode = null, CancellationToken ct = default)
        {
            var q = SavedGames.Where(g => g.UserId == userId);
            if (!string.IsNullOrEmpty(gameMode))
            {
                q = q.Where(g => g.GameMode.Equals(gameMode, StringComparison.OrdinalIgnoreCase));
            }

            var toRemove = q.ToList();
            if (toRemove.Count == 0) return Task.FromResult(false);

            foreach (var r in toRemove)
            {
                SavedGames.Remove(r);
            }
            return Task.FromResult(true);
        }

        public Task<int> SaveChangesAsync(CancellationToken ct = default) => Task.FromResult(1);
    }

    [Fact]
    public async Task SaveGame_IsIsolatedBetweenAccounts()
    {
        var repo = new FakeCaroRepository();
        var service = new CaroService(repo);

        // User 1 lưu ván đang chơi
        var reqUser1 = new SaveCaroGameRequest(
            GameMode: "pve",
            Difficulty: 2,
            PlayerFirst: true,
            HistoryData: "[112, 113, 120]",
            Undos: 0,
            ElapsedSeconds: 45,
            HintsRemaining: 3
        );
        await service.SaveGameAsync(1, reqUser1);

        // User 2 truy vấn ván cờ -> Không được thấy ván của User 1
        var user2Game = await service.GetSavedGameAsync(2, "pve");
        Assert.Null(user2Game);

        // User 1 truy vấn ván cờ -> Thấy đúng ván của mình
        var user1Game = await service.GetSavedGameAsync(1, "pve");
        Assert.NotNull(user1Game);
        Assert.Equal("[112, 113, 120]", user1Game.HistoryData);
        Assert.Equal(45, user1Game.ElapsedSeconds);

        // User 2 lưu ván cờ riêng
        var reqUser2 = new SaveCaroGameRequest(
            GameMode: "pve",
            Difficulty: 3,
            PlayerFirst: false,
            HistoryData: "[50, 65]",
            Undos: 1,
            ElapsedSeconds: 20,
            HintsRemaining: 2
        );
        await service.SaveGameAsync(2, reqUser2);

        // Cả 2 tài khoản chỉ thấy đúng dữ liệu của mình
        var u1Again = await service.GetSavedGameAsync(1);
        var u2Again = await service.GetSavedGameAsync(2);

        Assert.NotNull(u1Again);
        Assert.Equal("[112, 113, 120]", u1Again.HistoryData);

        Assert.NotNull(u2Again);
        Assert.Equal("[50, 65]", u2Again.HistoryData);
    }

    [Fact]
    public async Task DeleteGame_OnlyDeletesGameOfTargetUser()
    {
        var repo = new FakeCaroRepository();
        var service = new CaroService(repo);

        await service.SaveGameAsync(1, new SaveCaroGameRequest("pve", 1, true, "[10]", 0, 5, 3));
        await service.SaveGameAsync(2, new SaveCaroGameRequest("pve", 2, true, "[20]", 0, 10, 3));

        // User 1 hoàn thành ván và xoá
        var deleted = await service.DeleteSavedGameAsync(1, "pve");
        Assert.True(deleted);

        // User 1 không còn ván lưu
        Assert.Null(await service.GetSavedGameAsync(1, "pve"));

        // User 2 vẫn còn nguyên ván lưu của mình
        var u2Game = await service.GetSavedGameAsync(2, "pve");
        Assert.NotNull(u2Game);
        Assert.Equal("[20]", u2Game.HistoryData);
    }
}
