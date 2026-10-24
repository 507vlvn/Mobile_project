using System.Collections.Concurrent;
using GameHub.Api.model;
using Microsoft.EntityFrameworkCore;

namespace GameHub.Api.Services;

public interface IPresence
{
    bool IsOnline(int userId);
}

/// <summary>Theo dõi kết nối (đa thiết bị) của từng user, trong bộ nhớ.</summary>
public sealed class ConnectionTracker : IPresence
{
    private readonly object _gate = new();
    private readonly Dictionary<int, HashSet<string>> _connections = [];

    public bool IsOnline(int userId)
    {
        lock (_gate) return _connections.TryGetValue(userId, out var set) && set.Count > 0;
    }

    /// <summary>True nếu đây là kết nối đầu tiên của user.</summary>
    public bool Add(int userId, string connectionId)
    {
        lock (_gate)
        {
            if (!_connections.TryGetValue(userId, out var set)) _connections[userId] = set = [];
            var first = set.Count == 0;
            set.Add(connectionId);
            return first;
        }
    }

    /// <summary>True nếu đây là kết nối cuối cùng vừa đóng.</summary>
    public bool Remove(int userId, string connectionId)
    {
        lock (_gate)
        {
            if (!_connections.TryGetValue(userId, out var set)) return false;
            set.Remove(connectionId);
            if (set.Count > 0) return false;
            _connections.Remove(userId);
            return true;
        }
    }
}

/// <summary>
/// Theo dõi kết nối (đa thiết bị) trong bộ nhớ, phát Presence tới bạn bè đã chấp nhận,
/// và ghi Users.last_seen_at tối đa 1 lần/60 giây/người.
/// </summary>
public sealed class PresenceService
{
    public static readonly TimeSpan LastSeenThrottle = TimeSpan.FromSeconds(60);

    private readonly ConcurrentDictionary<int, DateTime> _lastWrite = new();
    private readonly ConcurrentDictionary<int, DateTime> _lastSeen = new();
    private readonly ConnectionTracker _tracker;
    private readonly IServiceScopeFactory _scopes;
    private readonly IRealtimeNotifier _notifier;
    private readonly IClock _clock;
    private readonly MatchService _matches;
    private readonly ILogger<PresenceService> _log;

    public PresenceService(ConnectionTracker tracker, IServiceScopeFactory scopes, IRealtimeNotifier notifier, IClock clock,
        MatchService matches, ILogger<PresenceService> log)
    {
        _tracker = tracker; _scopes = scopes; _notifier = notifier; _clock = clock; _matches = matches; _log = log;
        _matches.InMatchChanged += userId => _ = SafeBroadcastAsync(userId);
    }

    public bool IsOnline(int userId) => _tracker.IsOnline(userId);

    public string StatusOf(int userId) =>
        !IsOnline(userId) ? "offline" : _matches.IsInMatch(userId) ? "in_match" : "online";

    /// <summary>Thời điểm thấy gần nhất trong bộ nhớ (kể từ khi server chạy), nếu có.</summary>
    public DateTime? LastSeenInMemory(int userId) => _lastSeen.TryGetValue(userId, out var t) ? t : null;

    /// <summary>Trả về true nếu đây là kết nối đầu tiên của user.</summary>
    public async Task<bool> ConnectedAsync(int userId, string connectionId)
    {
        var first = _tracker.Add(userId, connectionId);
        _lastSeen[userId] = _clock.UtcNow;
        await TouchLastSeenAsync(userId);
        if (first) await BroadcastAsync(userId);
        return first;
    }

    /// <summary>Trả về true nếu đây là kết nối cuối cùng vừa đóng.</summary>
    public async Task<bool> DisconnectedAsync(int userId, string connectionId)
    {
        var last = _tracker.Remove(userId, connectionId);
        _lastSeen[userId] = _clock.UtcNow;
        if (last)
        {
            await TouchLastSeenAsync(userId);
            await BroadcastAsync(userId);
        }
        return last;
    }

    private async Task TouchLastSeenAsync(int userId)
    {
        var now = _clock.UtcNow;
        if (_lastWrite.TryGetValue(userId, out var prev) && now - prev < LastSeenThrottle) return;
        _lastWrite[userId] = now;
        try
        {
            using var scope = _scopes.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<GameHubDbContext>();
            await db.Users.Where(u => u.UserId == userId)
                .ExecuteUpdateAsync(s => s.SetProperty(u => u.LastSeenAt, now));
        }
        catch (Exception ex) { _log.LogWarning(ex, "Không ghi được last_seen_at của {UserId}", userId); }
    }

    private async Task SafeBroadcastAsync(int userId)
    {
        try { await BroadcastAsync(userId); }
        catch (Exception ex) { _log.LogWarning(ex, "Lỗi phát Presence của {UserId}", userId); }
    }

    /// <summary>Phát Presence(userId, status) tới bạn bè ĐÃ CHẤP NHẬN của user.</summary>
    public async Task BroadcastAsync(int userId)
    {
        List<int> friends;
        using (var scope = _scopes.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<GameHubDbContext>();
            friends = await FriendQueries.FriendIdsAsync(db, userId);
        }
        var status = StatusOf(userId);
        foreach (var f in friends)
            if (IsOnline(f)) await _notifier.SendAsync(f, "Presence", userId, status);
    }
}
