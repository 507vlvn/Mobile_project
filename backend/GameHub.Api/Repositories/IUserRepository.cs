using GameHub.Api.model;

namespace GameHub.Api.Repositories;

public interface IUserRepository
{
    IQueryable<User> Users();
    Task<User?> FindByIdAsync(int id, CancellationToken ct = default);
    Task<User?> FindByUsernameOrEmailAsync(string usernameOrEmail, CancellationToken ct = default);
    void Add(User user);
    void Remove(User user);
    Task<bool> SaveAsync(CancellationToken ct = default);
    Task<int> SaveChangesAsync(CancellationToken ct = default);
}
