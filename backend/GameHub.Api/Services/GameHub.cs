using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace GameHub.Api.Services;

/// <summary>
/// Hub /hubs/game. Mỗi phương thức chỉ ủy quyền cho <see cref="MatchService"/> (kiểm tra người tham gia ở đó).
/// Lỗi nghiệp vụ là HubException (thông điệp tiếng Việt tới client).
/// </summary>
[Authorize]
public sealed class GameHub(MatchService matches, PresenceService presence) : Hub
{
    private int Me => Context.User!.GetUserId();

    public override async Task OnConnectedAsync()
    {
        await presence.ConnectedAsync(Me, Context.ConnectionId);
        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        var last = await presence.DisconnectedAsync(Me, Context.ConnectionId);
        if (last) await matches.UserDisconnectedAsync(Me);
        await base.OnDisconnectedAsync(exception);
    }

    public Task QueueJoin(string gameCode, int difficulty) => matches.QueueJoinAsync(Me, gameCode, difficulty);
    public Task QueueLeave() => matches.QueueLeaveAsync(Me);
    /// <summary>Trả về inviteId.</summary>
    public Task<string> Invite(int friendId, string gameCode, int difficulty) => matches.InviteAsync(Me, friendId, gameCode, difficulty);
    public Task RespondInvite(string inviteId, bool accept) => matches.RespondInviteAsync(Me, inviteId, accept);
    public Task CaroMove(string matchId, int row, int col) => matches.CaroMoveAsync(Me, matchId, row, col);
    public Task RaceProgress(string matchId, int percent) => matches.RaceProgressAsync(Me, matchId, percent);
    public Task RaceFinish(string matchId, int timeMs, int mistakes) => matches.RaceFinishAsync(Me, matchId, timeMs, mistakes);
    public Task Resign(string matchId) => matches.ResignAsync(Me, matchId);
    public Task OfferDraw(string matchId) => matches.OfferDrawAsync(Me, matchId);
    public Task RespondDraw(string matchId, bool accept) => matches.RespondDrawAsync(Me, matchId, accept);
    public Task Rematch(string matchId) => matches.RematchAsync(Me, matchId);
    public Task QuickChat(string matchId, string code) => matches.QuickChatAsync(Me, matchId, code);
    public Task Rejoin(string matchId) => matches.RejoinAsync(Me, matchId);
}

/// <summary>Chỉ đọc bộ nhớ + đẩy thông báo; không chạm DB. Xử lý hết giờ mỗi giây.</summary>
public sealed class MatchTicker(MatchService matches, ILogger<MatchTicker> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(1));
        try
        {
            while (await timer.WaitForNextTickAsync(stoppingToken))
            {
                try { await matches.TickAsync(); }
                catch (Exception ex) { log.LogError(ex, "MatchService.Tick lỗi"); }
            }
        }
        catch (OperationCanceledException) { }
    }
}
