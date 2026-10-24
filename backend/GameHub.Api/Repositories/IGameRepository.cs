using GameHub.Api.model;

namespace GameHub.Api.Repositories;

public interface IGameRepository
{
    IQueryable<Game> Games();
    IQueryable<GameLevel> GameLevels();
    Task<Game?> FindByCodeAsync(string gameCode, CancellationToken ct = default);
    Task<GameLevel?> FindDefaultLevelAsync(int gameId, int difficulty, CancellationToken ct = default);
    void AddGame(Game game);
    void AddLevel(GameLevel level);
    Task<bool> SaveAsync(CancellationToken ct = default);
    Task<int> SaveChangesAsync(CancellationToken ct = default);
}
