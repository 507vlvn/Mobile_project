using Microsoft.EntityFrameworkCore;
using GameHub.Api.model;

namespace GameHub.Api.Repositories;

public class MessageRepository(GameHubDbContext db) : IMessageRepository
{
    public IQueryable<Message> Messages() => db.Messages;

    public Task<Message?> FindByIdAsync(int messageId, CancellationToken ct = default) =>
        db.Messages.FirstOrDefaultAsync(m => m.MessageId == messageId, ct);

    public void Add(Message message) => db.Messages.Add(message);

    public void Remove(Message message) => db.Messages.Remove(message);

    public Task<bool> SaveAsync(CancellationToken ct = default) => db.TrySaveAsync(ct);

    public Task<int> SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}
