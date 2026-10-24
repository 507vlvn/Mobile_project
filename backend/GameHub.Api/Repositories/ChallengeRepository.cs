using Microsoft.EntityFrameworkCore;
using GameHub.Api.model;

namespace GameHub.Api.Repositories;

public class ChallengeRepository(GameHubDbContext db) : IChallengeRepository
{
    public IQueryable<Challenge> Challenges() => db.Challenges;

    public Task<Challenge?> FindByIdAsync(int challengeId, CancellationToken ct = default) =>
        db.Challenges.FirstOrDefaultAsync(c => c.ChallengeId == challengeId, ct);

    public void Add(Challenge challenge) => db.Challenges.Add(challenge);

    public void Remove(Challenge challenge) => db.Challenges.Remove(challenge);

    public Task<bool> SaveAsync(CancellationToken ct = default) => db.TrySaveAsync(ct);

    public Task<int> SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}
