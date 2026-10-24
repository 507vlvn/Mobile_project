using GameHub.Api.model;

namespace GameHub.Api.Repositories;

public interface IFriendshipRepository
{
    IQueryable<Friendship> Friendships();
    Task<bool> AreFriendsAsync(int userId1, int userId2, CancellationToken ct = default);
    Task<List<int>> GetFriendIdsAsync(int userId, CancellationToken ct = default);
    Task<Friendship?> FindPairAsync(int userId1, int userId2, CancellationToken ct = default);
    void Add(Friendship friendship);
    void Remove(Friendship friendship);
    Task<bool> SaveAsync(CancellationToken ct = default);
    Task<int> SaveChangesAsync(CancellationToken ct = default);
}
