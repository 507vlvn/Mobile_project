using Microsoft.AspNetCore.SignalR;

namespace GameHub.Api.Services;

public interface IClock { DateTime UtcNow { get; } }

public sealed class SystemClock : IClock { public DateTime UtcNow => DateTime.UtcNow; }

/// <summary>Đẩy sự kiện xuống mọi kết nối (đa thiết bị) của một người dùng.</summary>
public interface IRealtimeNotifier
{
    Task SendAsync(int userId, string method, params object?[] args);
}

public sealed class SignalRNotifier(IHubContext<GameHub> hub, ILogger<SignalRNotifier> log) : IRealtimeNotifier
{
    public async Task SendAsync(int userId, string method, params object?[] args)
    {
        try { await hub.Clients.User(userId.ToString()).SendCoreAsync(method, args); }
        catch (Exception ex) { log.LogWarning(ex, "Không đẩy được {Method} tới user {UserId}", method, userId); }
    }
}

/// <summary>User id của SignalR = claim "sub" (MapInboundClaims = false).</summary>
public sealed class SubUserIdProvider : IUserIdProvider
{
    public string? GetUserId(HubConnectionContext connection) => connection.User?.FindFirst("sub")?.Value;
}
