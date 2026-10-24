using GameHub.Api.model;

namespace GameHub.Api.Repositories;

public class MatchRepository(GameHubDbContext db) : IMatchRepository
{
    public IQueryable<GameMatch> Matches() => db.Matches;

    public IQueryable<PlayerRating> Ratings() => db.PlayerRatings;

    public void AddMatch(GameMatch match) => db.Matches.Add(match);

    public void AddRating(PlayerRating rating) => db.PlayerRatings.Add(rating);

    public void RemoveRating(PlayerRating rating) => db.PlayerRatings.Remove(rating);

    public Task<bool> SaveAsync(CancellationToken ct = default) => db.TrySaveAsync(ct);

    public Task<int> SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}
