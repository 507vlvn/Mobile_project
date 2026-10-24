using GameHub.Api.model;
using Microsoft.EntityFrameworkCore;

namespace GameHub.Api.Services;

public static class GameQueries
{
    /// <summary>Level mặc định: ưu tiên dòng không có initial_state, rồi level_id nhỏ nhất.</summary>
    public static Task<GameLevel?> DefaultLevelAsync(this GameHubDbContext db, int gameId, int difficulty, CancellationToken ct) =>
        db.GameLevels.AsNoTracking()
            .Where(l => l.GameId == gameId && l.Difficulty == difficulty)
            .OrderBy(l => l.InitialState != null).ThenBy(l => l.LevelId)
            .FirstOrDefaultAsync(ct);
}
