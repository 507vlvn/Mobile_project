using GameHub.Api.model;

namespace GameHub.Api.Repositories;

public interface IChallengeRepository
{
    IQueryable<Challenge> Challenges();
    Task<Challenge?> FindByIdAsync(int challengeId, CancellationToken ct = default);
    void Add(Challenge challenge);
    void Remove(Challenge challenge);
    Task<bool> SaveAsync(CancellationToken ct = default);
    Task<int> SaveChangesAsync(CancellationToken ct = default);
}
