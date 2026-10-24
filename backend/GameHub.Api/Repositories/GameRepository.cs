using Microsoft.EntityFrameworkCore;
using GameHub.Api.model;

namespace GameHub.Api.Repositories;

public class GameRepository(GameHubDbContext db) : IGameRepository
{
    public IQueryable<Game> Games() => db.Games;

    public IQueryable<GameLevel> GameLevels() => db.GameLevels;

    public Task<Game?> FindByCodeAsync(string gameCode, CancellationToken ct = default) =>
        db.Games.AsNoTracking().FirstOrDefaultAsync(g => g.GameCode == gameCode, ct);

    public Task<GameLevel?> FindDefaultLevelAsync(int gameId, int difficulty, CancellationToken ct = default) =>
        db.GameLevels.AsNoTracking()
            .Where(l => l.GameId == gameId && l.Difficulty == difficulty)
            .OrderBy(l => l.InitialState != null).ThenBy(l => l.LevelId)
            .FirstOrDefaultAsync(ct);

    public void AddGame(Game game) => db.Games.Add(game);

    public void AddLevel(GameLevel level) => db.GameLevels.Add(level);

    public Task<bool> SaveAsync(CancellationToken ct = default) => db.TrySaveAsync(ct);

    public Task<int> SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}
