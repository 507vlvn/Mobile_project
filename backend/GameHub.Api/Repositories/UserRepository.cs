using Microsoft.EntityFrameworkCore;
using GameHub.Api.model;

namespace GameHub.Api.Repositories;

public class UserRepository(GameHubDbContext db) : IUserRepository
{
    public IQueryable<User> Users() => db.Users;

    public Task<User?> FindByIdAsync(int id, CancellationToken ct = default) =>
        db.Users.FirstOrDefaultAsync(u => u.UserId == id, ct);

    public Task<User?> FindByUsernameOrEmailAsync(string usernameOrEmail, CancellationToken ct = default)
    {
        var key = usernameOrEmail.Trim();
        var lower = key.ToLowerInvariant();
        return db.Users.FirstOrDefaultAsync(u => u.IsActive && (u.Username == key || u.Email == lower), ct);
    }

    public void Add(User user) => db.Users.Add(user);

    public void Remove(User user) => db.Users.Remove(user);

    public Task<bool> SaveAsync(CancellationToken ct = default) => db.TrySaveAsync(ct);

    public Task<int> SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}
