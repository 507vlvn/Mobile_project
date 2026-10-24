using Microsoft.EntityFrameworkCore;
using GameHub.Api.model;

namespace GameHub.Api.Repositories;

public class FriendshipRepository(GameHubDbContext db) : IFriendshipRepository
{
    public IQueryable<Friendship> Friendships() => db.Friendships;

    public Task<bool> AreFriendsAsync(int userId1, int userId2, CancellationToken ct = default)
    {
        var (low, high) = Friendship.Pair(userId1, userId2);
        return db.Friendships.AsNoTracking()
            .AnyAsync(f => f.UserLowId == low && f.UserHighId == high && f.Status == Friendship.Accepted, ct);
    }

    public Task<List<int>> GetFriendIdsAsync(int userId, CancellationToken ct = default) =>
        db.Friendships.AsNoTracking()
            .Where(f => f.Status == Friendship.Accepted && (f.RequesterId == userId || f.AddresseeId == userId))
            .Select(f => f.RequesterId == userId ? f.AddresseeId : f.RequesterId)
            .ToListAsync(ct);

    public Task<Friendship?> FindPairAsync(int userId1, int userId2, CancellationToken ct = default)
    {
        var (low, high) = Friendship.Pair(userId1, userId2);
        return db.Friendships.FirstOrDefaultAsync(f => f.UserLowId == low && f.UserHighId == high, ct);
    }

    public void Add(Friendship friendship) => db.Friendships.Add(friendship);

    public void Remove(Friendship friendship) => db.Friendships.Remove(friendship);

    public Task<bool> SaveAsync(CancellationToken ct = default) => db.TrySaveAsync(ct);

    public Task<int> SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}
