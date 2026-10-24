using GameHub.Api.model;

namespace GameHub.Api.Repositories;

public interface IMessageRepository
{
    IQueryable<Message> Messages();
    Task<Message?> FindByIdAsync(int messageId, CancellationToken ct = default);
    void Add(Message message);
    void Remove(Message message);
    Task<bool> SaveAsync(CancellationToken ct = default);
    Task<int> SaveChangesAsync(CancellationToken ct = default);
}
