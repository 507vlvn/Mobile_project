using GameHub.Api.model;

namespace GameHub.Api.Repositories;

public interface IMatchRepository
{
    IQueryable<GameMatch> Matches();
    IQueryable<PlayerRating> Ratings();
    void AddMatch(GameMatch match);
    void AddRating(PlayerRating rating);
    void RemoveRating(PlayerRating rating);
    Task<bool> SaveAsync(CancellationToken ct = default);
    Task<int> SaveChangesAsync(CancellationToken ct = default);
}
