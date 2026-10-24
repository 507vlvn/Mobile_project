using GameHub.Api.model;
using Microsoft.EntityFrameworkCore;

namespace GameHub.Api.Services;

public static class FriendQueries
{
    public static async Task<List<int>> FriendIdsAsync(this GameHubDbContext db, int me, CancellationToken ct = default) =>
        await db.Friendships.AsNoTracking()
            .Where(f => f.Status == Friendship.Accepted && (f.RequesterId == me || f.AddresseeId == me))
            .Select(f => f.RequesterId == me ? f.AddresseeId : f.RequesterId)
            .ToListAsync(ct);

    public static Task<bool> AreFriendsAsync(this GameHubDbContext db, int a, int b, CancellationToken ct = default)
    {
        var (low, high) = Friendship.Pair(a, b);
        return db.Friendships.AsNoTracking()
            .AnyAsync(f => f.UserLowId == low && f.UserHighId == high && f.Status == Friendship.Accepted, ct);
    }
}
