using System.Text.Json;
using GameHub.Api.Realtime;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace GameHub.Tests;

public sealed class FakeClock : IClock
{
    public DateTime UtcNow { get; set; } = new(2026, 10, 21, 3, 0, 0, DateTimeKind.Utc);
    public void Advance(double seconds) => UtcNow = UtcNow.AddSeconds(seconds);
}

public sealed record Sent(int User, string Method, object?[] Args)
{
    public JsonElement Json(int i = 0) => JsonSerializer.SerializeToElement(Args[i]);
}

public sealed class FakeNotifier : IRealtimeNotifier
{
    public List<Sent> Messages { get; } = [];
    public Task SendAsync(int userId, string method, params object?[] args)
    {
        lock (Messages) Messages.Add(new Sent(userId, method, args));
        return Task.CompletedTask;
    }
    public List<Sent> Of(int user, string method) { lock (Messages) return Messages.Where(m => m.User == user && m.Method == method).ToList(); }
    public Sent Last(int user, string method) => Of(user, method).Last();
    public void Clear() { lock (Messages) Messages.Clear(); }
}

public sealed class FakePresence : IPresence
{
    public HashSet<int> Online { get; } = [];
    public bool IsOnline(int userId) => Online.Contains(userId);
}

public sealed class FakeData : IMatchData
{
    public Dictionary<int, PlayerInfo> Players { get; } = [];
    public HashSet<(int, int)> Friends { get; } = [];
    public List<MatchResultRecord> Saved { get; } = [];

    public Task<PlayerInfo?> LoadPlayerAsync(int userId, string gameCode, CancellationToken ct = default) =>
        Task.FromResult(Players.TryGetValue(userId, out var p) ? p : null);
    public Task<bool> AreFriendsAsync(int a, int b, CancellationToken ct = default) =>
        Task.FromResult(Friends.Contains((Math.Min(a, b), Math.Max(a, b))));
    public Task SaveResultAsync(MatchResultRecord r, CancellationToken ct = default) { Saved.Add(r); return Task.CompletedTask; }
}

public class MatchServiceTests
{
    private readonly FakeClock _clock = new();
    private readonly FakeNotifier _out = new();
    private readonly FakePresence _presence = new();
    private readonly FakeData _data = new();
    private readonly MatchService _svc;

    public MatchServiceTests()
    {
        _svc = new MatchService(_data, _out, _presence, _clock, NullLogger<MatchService>.Instance, new Random(7));
    }

    private void AddPlayer(int id, int rating = 1000, int games = 0)
    {
        _data.Players[id] = new PlayerInfo(id, "u" + id, "User " + id, null, rating, games);
        _presence.Online.Add(id);
    }

    private static string Str(JsonElement e, string name) => e.GetProperty(name).GetString()!;

    /// <summary>Ghép 1 và 2 qua hàng đợi, trả về matchId.</summary>
    private async Task<string> StartRanked(string game = "CARO", int diff = 2, int r1 = 1000, int r2 = 1000, int g1 = 0, int g2 = 0)
    {
        AddPlayer(1, r1, g1); AddPlayer(2, r2, g2);
        await _svc.QueueJoinAsync(1, game, diff);
        await _svc.QueueJoinAsync(2, game, diff);
        return Str(_out.Last(1, "MatchStarted").Json(), "matchId");
    }

    private int FirstTurn(string matchId, int viewer = 1) =>
        _out.Last(viewer, "MatchStarted").Json().GetProperty("caro").GetProperty("currentTurnUserId").GetInt32();

    // ---------- Hàng đợi ----------

    [Theory]
    [InlineData(0, 100)]
    [InlineData(9.9, 100)]
    [InlineData(10, 200)]
    [InlineData(19.9, 200)]
    [InlineData(20, 400)]
    [InlineData(29.9, 400)]
    public void RatingRange_Widens(double waited, int expected) => Assert.Equal(expected, MatchService.RatingRange(waited));

    [Fact]
    public void RatingRange_UnlimitedAfter30s() => Assert.Null(MatchService.RatingRange(30));

    [Fact]
    public async Task Queue_CloseRatings_MatchImmediately_AndPayloadIsComplete()
    {
        var id = await StartRanked(r1: 1000, r2: 1090);
        var m1 = _out.Last(1, "MatchStarted").Json();
        var m2 = _out.Last(2, "MatchStarted").Json();
        Assert.Equal(id, Str(m2, "matchId"));
        Assert.Equal("RANKED", Str(m1, "mode"));
        Assert.Equal("TURN", Str(m1, "kind"));
        Assert.Equal(1, m1.GetProperty("you").GetInt32());
        Assert.Equal(2, m2.GetProperty("you").GetInt32());
        Assert.Equal(2, m1.GetProperty("players").GetArrayLength());
        Assert.Equal("BRONZE", m1.GetProperty("players")[0].GetProperty("tier").GetString());
        Assert.True(m1.GetProperty("seed").GetInt32() > 0);
        Assert.True(_svc.IsInMatch(1) && _svc.IsInMatch(2));
        Assert.False(_svc.IsQueued(1));
    }

    [Fact]
    public async Task Queue_FarRatings_WidenOverTime()
    {
        AddPlayer(1, 1000); AddPlayer(2, 1300);
        await _svc.QueueJoinAsync(1, "CARO", 2);
        await _svc.QueueJoinAsync(2, "CARO", 2);
        Assert.False(_svc.IsInMatch(1));

        _clock.Advance(9); await _svc.TickAsync(); Assert.False(_svc.IsInMatch(1));   // ±100
        _clock.Advance(10); await _svc.TickAsync(); Assert.False(_svc.IsInMatch(1));  // ±200 (19s)
        _clock.Advance(1); await _svc.TickAsync(); Assert.True(_svc.IsInMatch(1));    // ±400 (20s)
    }

    [Fact]
    public async Task Queue_UnlimitedAfter30s()
    {
        AddPlayer(1, 800); AddPlayer(2, 1900);
        await _svc.QueueJoinAsync(1, "SUDOKU", 1);
        await _svc.QueueJoinAsync(2, "SUDOKU", 1);
        _clock.Advance(29); await _svc.TickAsync(); Assert.False(_svc.IsInMatch(1));
        _clock.Advance(1); await _svc.TickAsync(); Assert.True(_svc.IsInMatch(1));
    }

    [Fact]
    public async Task Queue_DifferentGameOrDifficulty_DoNotMatch()
    {
        AddPlayer(1); AddPlayer(2); AddPlayer(3);
        await _svc.QueueJoinAsync(1, "CARO", 1);
        await _svc.QueueJoinAsync(2, "CARO", 2);
        await _svc.QueueJoinAsync(3, "SUDOKU", 1);
        _clock.Advance(100); await _svc.TickAsync();
        Assert.False(_svc.IsInMatch(1)); Assert.False(_svc.IsInMatch(2)); Assert.False(_svc.IsInMatch(3));
    }

    [Fact]
    public async Task Queue_StatusEveryThreeSeconds_AndLeave()
    {
        AddPlayer(1);
        await _svc.QueueJoinAsync(1, "CARO", 1);
        Assert.Single(_out.Of(1, "QueueStatus"));
        _clock.Advance(1); await _svc.TickAsync();
        Assert.Single(_out.Of(1, "QueueStatus"));
        _clock.Advance(2); await _svc.TickAsync();
        Assert.Equal(2, _out.Of(1, "QueueStatus").Count);
        var st = _out.Last(1, "QueueStatus");
        Assert.Equal(true, st.Args[0]); Assert.Equal(3, st.Args[1]); Assert.Equal(100, st.Args[2]);

        await _svc.QueueLeaveAsync(1);
        Assert.Equal(false, _out.Last(1, "QueueStatus").Args[0]);
        Assert.False(_svc.IsQueued(1));
    }

    [Fact]
    public async Task Queue_WhileInMatch_Throws()
    {
        await StartRanked();
        await Assert.ThrowsAsync<HubException>(() => _svc.QueueJoinAsync(1, "CARO", 2));
    }

    [Fact]
    public async Task Queue_InvalidGameOrDifficulty_Throws()
    {
        AddPlayer(1);
        await Assert.ThrowsAsync<HubException>(() => _svc.QueueJoinAsync(1, "CHESS", 1));
        await Assert.ThrowsAsync<HubException>(() => _svc.QueueJoinAsync(1, "CARO", 4));
    }

    // ---------- Lời mời ----------

    [Fact]
    public async Task Invite_NonFriend_Rejected_Offline_Rejected()
    {
        AddPlayer(1); AddPlayer(2);
        await Assert.ThrowsAsync<HubException>(() => _svc.InviteAsync(1, 2, "CARO", 1));
        _data.Friends.Add((1, 2));
        _presence.Online.Remove(2);
        await Assert.ThrowsAsync<HubException>(() => _svc.InviteAsync(1, 2, "CARO", 1));
    }

    [Fact]
    public async Task Invite_Accept_StartsFriendlyMatch_NoRatingChange()
    {
        AddPlayer(1); AddPlayer(2); _data.Friends.Add((1, 2));
        var inviteId = await _svc.InviteAsync(1, 2, "CARO", 1);
        var rec = _out.Last(2, "InviteReceived").Json();
        Assert.Equal(inviteId, Str(rec, "inviteId"));
        Assert.Equal(30, rec.GetProperty("expiresInSec").GetInt32());

        await _svc.RespondInviteAsync(2, inviteId, true);
        Assert.Equal("accepted", Str(_out.Last(1, "InviteResult").Json(), "status"));
        var started = _out.Last(1, "MatchStarted").Json();
        Assert.Equal("FRIENDLY", Str(started, "mode"));
        var matchId = Str(started, "matchId");

        await _svc.ResignAsync(1, matchId);
        var saved = Assert.Single(_data.Saved);
        Assert.False(saved.Ranked);
        Assert.Equal(saved.P1.RatingBefore, saved.P1.RatingAfter);
        Assert.Equal(2, saved.WinnerId);
    }

    [Fact]
    public async Task Invite_Decline_NotifiesInviter()
    {
        AddPlayer(1); AddPlayer(2); _data.Friends.Add((1, 2));
        var id = await _svc.InviteAsync(1, 2, "SUDOKU", 2);
        await _svc.RespondInviteAsync(2, id, false);
        Assert.Equal("declined", Str(_out.Last(1, "InviteResult").Json(), "status"));
        Assert.False(_svc.IsInMatch(1));
    }

    [Fact]
    public async Task Invite_Expires_After30Seconds()
    {
        AddPlayer(1); AddPlayer(2); _data.Friends.Add((1, 2));
        var id = await _svc.InviteAsync(1, 2, "CARO", 1);
        _clock.Advance(29); await _svc.TickAsync();
        Assert.Empty(_out.Of(1, "InviteResult"));
        _clock.Advance(1); await _svc.TickAsync();
        Assert.Equal("expired", Str(_out.Last(1, "InviteResult").Json(), "status"));
        await Assert.ThrowsAsync<HubException>(() => _svc.RespondInviteAsync(2, id, true));
    }

    [Fact]
    public async Task Invite_OnlyInviteeCanRespond()
    {
        AddPlayer(1); AddPlayer(2); AddPlayer(3); _data.Friends.Add((1, 2));
        var id = await _svc.InviteAsync(1, 2, "CARO", 1);
        await Assert.ThrowsAsync<HubException>(() => _svc.RespondInviteAsync(3, id, true));
    }

    // ---------- Caro ----------

    [Fact]
    public async Task Caro_TurnValidation()
    {
        var id = await StartRanked();
        var first = FirstTurn(id);
        var second = first == 1 ? 2 : 1;

        await Assert.ThrowsAsync<HubException>(() => _svc.CaroMoveAsync(second, id, 7, 7)); // sai lượt
        await Assert.ThrowsAsync<HubException>(() => _svc.CaroMoveAsync(first, id, -1, 0));
        await Assert.ThrowsAsync<HubException>(() => _svc.CaroMoveAsync(first, id, 0, 15));
        await _svc.CaroMoveAsync(first, id, 7, 7);
        await Assert.ThrowsAsync<HubException>(() => _svc.CaroMoveAsync(first, id, 8, 8));  // đi hai lần
        await Assert.ThrowsAsync<HubException>(() => _svc.CaroMoveAsync(second, id, 7, 7)); // ô đã có quân

        var state = _out.Last(second, "MatchState").Json().GetProperty("caro");
        Assert.Equal(second, state.GetProperty("currentTurnUserId").GetInt32());
        Assert.Equal(1, state.GetProperty("moves").GetArrayLength());
    }

    [Fact]
    public async Task Caro_Participant_Only()
    {
        var id = await StartRanked();
        AddPlayer(3);
        await Assert.ThrowsAsync<HubException>(() => _svc.CaroMoveAsync(3, id, 0, 0));
        await Assert.ThrowsAsync<HubException>(() => _svc.ResignAsync(3, id));
        await Assert.ThrowsAsync<HubException>(() => _svc.CaroMoveAsync(1, "nope", 0, 0));
    }

    private async Task PlayFiveInRow(string id, int winner)
    {
        var loser = winner == 1 ? 2 : 1;
        // Hàng 0 cho người thắng, hàng 1 cho người thua; người đi trước là FirstTurn.
        var first = FirstTurn(id);
        var seq = new List<(int user, int r, int c)>();
        for (var i = 0; i < 5; i++)
        {
            seq.Add((winner, 0, i));
            if (i < 4) seq.Add((loser, 1, i));
        }
        // nếu người thua đi trước, chèn một nước đệm
        if (first == loser) seq.Insert(0, (loser, 10, 10));
        foreach (var (u, r, c) in seq) await _svc.CaroMoveAsync(u, id, r, c);
    }

    [Fact]
    public async Task Caro_FiveInRow_Wins_EloAndOneSave()
    {
        var id = await StartRanked();
        await PlayFiveInRow(id, 1);

        var ended = _out.Last(2, "MatchEnded").Json();
        Assert.Equal(1, ended.GetProperty("winnerId").GetInt32());
        Assert.Equal("WIN", Str(ended, "reason"));
        var changes = ended.GetProperty("ratingChanges");
        Assert.Equal(2, changes.GetArrayLength());
        var w = changes.EnumerateArray().First(x => x.GetProperty("userId").GetInt32() == 1);
        var l = changes.EnumerateArray().First(x => x.GetProperty("userId").GetInt32() == 2);
        Assert.Equal(1020, w.GetProperty("after").GetInt32());
        Assert.Equal(980, l.GetProperty("after").GetInt32());

        var rec = Assert.Single(_data.Saved);
        Assert.True(rec.Ranked);
        var win = rec.P1.UserId == 1 ? rec.P1 : rec.P2;
        var lose = rec.P1.UserId == 1 ? rec.P2 : rec.P1;
        Assert.Equal("WIN", win.Result); Assert.True(win.Score > 0); Assert.Equal(5, win.Moves);
        Assert.Equal("LOSE", lose.Result); Assert.Equal(0, lose.Score);
        Assert.False(_svc.IsInMatch(1) || _svc.IsInMatch(2));

        // sau khi kết thúc không đi tiếp được
        await Assert.ThrowsAsync<HubException>(() => _svc.CaroMoveAsync(2, id, 5, 5));
    }

    [Fact]
    public async Task Caro_PlacementK40_vs_EstablishedK24()
    {
        var id = await StartRanked(r1: 1000, r2: 1000, g1: 0, g2: 20);
        await PlayFiveInRow(id, 1);
        var rec = Assert.Single(_data.Saved);
        var p1 = rec.P1.UserId == 1 ? rec.P1 : rec.P2;
        var p2 = rec.P1.UserId == 1 ? rec.P2 : rec.P1;
        Assert.Equal(1020, p1.RatingAfter);  // K=40
        Assert.Equal(988, p2.RatingAfter);   // K=24
    }

    [Fact]
    public async Task Caro_Timeout30s_CurrentPlayerLoses()
    {
        var id = await StartRanked();
        var first = FirstTurn(id);
        _clock.Advance(29); await _svc.TickAsync();
        Assert.Empty(_out.Of(1, "MatchEnded"));
        _clock.Advance(1); await _svc.TickAsync();
        var ended = _out.Last(1, "MatchEnded").Json();
        Assert.Equal("TIMEOUT", Str(ended, "reason"));
        Assert.Equal(first == 1 ? 2 : 1, ended.GetProperty("winnerId").GetInt32());
        Assert.Single(_data.Saved);
    }

    [Fact]
    public async Task Caro_MoveResetsTurnClock()
    {
        var id = await StartRanked();
        var first = FirstTurn(id);
        _clock.Advance(20);
        await _svc.CaroMoveAsync(first, id, 7, 7);
        _clock.Advance(20); await _svc.TickAsync();
        Assert.Empty(_out.Of(1, "MatchEnded"));
        _clock.Advance(10); await _svc.TickAsync();
        Assert.Equal("TIMEOUT", Str(_out.Last(1, "MatchEnded").Json(), "reason"));
    }

    [Fact]
    public async Task Caro_DrawByAgreement_And_Decline()
    {
        var id = await StartRanked();
        await _svc.OfferDrawAsync(1, id);
        await Assert.ThrowsAsync<HubException>(() => _svc.OfferDrawAsync(2, id)); // đã có lời xin hòa
        await Assert.ThrowsAsync<HubException>(() => _svc.RespondDrawAsync(1, id, true)); // người xin không tự đồng ý
        await _svc.RespondDrawAsync(2, id, false);
        Assert.False((bool)_out.Last(1, "DrawResponded").Json().GetProperty("accepted").GetBoolean());

        await _svc.OfferDrawAsync(2, id);
        await _svc.RespondDrawAsync(1, id, true);
        var ended = _out.Last(1, "MatchEnded").Json();
        Assert.Equal("DRAW", Str(ended, "reason"));
        Assert.Equal(JsonValueKind.Null, ended.GetProperty("winnerId").ValueKind);
        var rec = Assert.Single(_data.Saved);
        Assert.Equal(1000, rec.P1.RatingAfter); // hòa cân bằng: không đổi
    }

    [Fact]
    public async Task Caro_Resign_And_AbandonedScoreZero()
    {
        var id = await StartRanked();
        await _svc.ResignAsync(2, id);
        var ended = _out.Last(1, "MatchEnded").Json();
        Assert.Equal("RESIGN", Str(ended, "reason"));
        Assert.Equal(1, ended.GetProperty("winnerId").GetInt32());
    }

    [Fact]
    public async Task Caro_FullBoard_IsDraw()
    {
        var id = await StartRanked();
        var first = FirstTurn(id);
        var second = first == 1 ? 2 : 1;
        // Mẫu sọc: không có 5 quân thẳng hàng; người đi trước chiếm 113 ô, người sau 112 ô.
        var a = new List<(int, int)>(); var b = new List<(int, int)>();
        for (var r = 0; r < 15; r++)
            for (var c = 0; c < 15; c++)
                ((c / 2 + r) % 2 == 0 ? a : b).Add((r, c));
        Assert.Equal(113, a.Count); Assert.Equal(112, b.Count);
        for (var i = 0; i < a.Count; i++)
        {
            await _svc.CaroMoveAsync(first, id, a[i].Item1, a[i].Item2);
            if (i < b.Count) await _svc.CaroMoveAsync(second, id, b[i].Item1, b[i].Item2);
        }
        var ended = _out.Last(1, "MatchEnded").Json();
        Assert.Equal("DRAW", Str(ended, "reason"));
        Assert.Single(_data.Saved);
    }

    // ---------- Đua giải ----------

    [Fact]
    public async Task Race_Payload_HasSeedAndRace()
    {
        var id = await StartRanked("SUDOKU", 1);
        var m = _out.Last(1, "MatchStarted").Json();
        Assert.Equal("RACE", Str(m, "kind"));
        Assert.True(m.GetProperty("seed").GetInt32() > 0);
        Assert.Equal(JsonValueKind.Null, m.GetProperty("caro").ValueKind);
        Assert.Equal(2, m.GetProperty("race").GetProperty("progress").GetArrayLength());
        Assert.NotNull(id);
    }

    [Fact]
    public async Task Race_Progress_MonotonicAndRateLimited()
    {
        var id = await StartRanked("SUDOKU", 1);
        await _svc.RaceProgressAsync(1, id, 10);
        Assert.Single(_out.Of(2, "OpponentProgress"));
        await _svc.RaceProgressAsync(1, id, 20);                // < 250ms: bỏ qua
        Assert.Single(_out.Of(2, "OpponentProgress"));
        _clock.Advance(0.3);
        await _svc.RaceProgressAsync(1, id, 5);                 // giảm: bỏ qua
        Assert.Single(_out.Of(2, "OpponentProgress"));
        _clock.Advance(0.3);
        await _svc.RaceProgressAsync(1, id, 30);
        Assert.Equal(2, _out.Of(2, "OpponentProgress").Count);
        Assert.Equal(30, _out.Last(2, "OpponentProgress").Json().GetProperty("percent").GetInt32());
        _clock.Advance(0.3);
        await _svc.RaceProgressAsync(1, id, 150);               // ngoài khoảng: bỏ qua
        Assert.Equal(2, _out.Of(2, "OpponentProgress").Count);
    }

    private async Task Reach(string id, int user, int percent)
    {
        _clock.Advance(0.3);
        await _svc.RaceProgressAsync(user, id, percent);
    }

    [Fact]
    public async Task Race_Finish_RequiresProgress_MinTime_AndNotInFuture()
    {
        var id = await StartRanked("SUDOKU", 1);   // tối thiểu 30 s
        _clock.Advance(60);
        await Assert.ThrowsAsync<HubException>(() => _svc.RaceFinishAsync(1, id, 45_000, 0)); // chưa đủ tiến độ
        await Reach(id, 1, 95);
        await Assert.ThrowsAsync<HubException>(() => _svc.RaceFinishAsync(1, id, 10_000, 0)); // nhanh bất khả thi
        await Assert.ThrowsAsync<HubException>(() => _svc.RaceFinishAsync(1, id, 600_000, 0)); // dài hơn thời gian trận
        Assert.True(_svc.IsInMatch(1));
    }

    [Fact]
    public async Task Race_FirstValidFinishWins_ScoredAndRated()
    {
        var id = await StartRanked("SUDOKU", 1);
        await Reach(id, 1, 100);
        _clock.Advance(359);
        await Reach(id, 2, 95);
        await _svc.RaceFinishAsync(2, id, 360_000, 1);
        var ended = _out.Last(1, "MatchEnded").Json();
        Assert.Equal(2, ended.GetProperty("winnerId").GetInt32());
        Assert.Equal("WIN", Str(ended, "reason"));
        var rec = Assert.Single(_data.Saved);
        var win = rec.P1.UserId == 2 ? rec.P1 : rec.P2;
        Assert.Equal(920, win.Score); // 1000 × 1.0 × 0.92
        Assert.Equal(360, win.TimeSeconds);
        Assert.Equal(1, win.Mistakes);
        await Assert.ThrowsAsync<HubException>(() => _svc.RaceFinishAsync(1, id, 360_000, 0)); // trận đã kết thúc
    }

    [Fact]
    public async Task Race_TimeLimit_HigherProgressWins()
    {
        var id = await StartRanked("PUZZLE", 1);
        await Reach(id, 1, 40);
        await Reach(id, 2, 70);
        _clock.Advance(15 * 60 - 1); await _svc.TickAsync();
        Assert.Empty(_out.Of(1, "MatchEnded"));
        _clock.Advance(2); await _svc.TickAsync();
        var ended = _out.Last(1, "MatchEnded").Json();
        Assert.Equal("TIME_LIMIT", Str(ended, "reason"));
        Assert.Equal(2, ended.GetProperty("winnerId").GetInt32());
    }

    [Fact]
    public async Task Race_TimeLimit_EqualProgress_IsDraw()
    {
        await StartRanked("RUBIK", 1);
        _clock.Advance(15 * 60 + 1); await _svc.TickAsync();
        var ended = _out.Last(1, "MatchEnded").Json();
        Assert.Equal("TIME_LIMIT", Str(ended, "reason"));
        Assert.Equal(JsonValueKind.Null, ended.GetProperty("winnerId").ValueKind);
        var rec = Assert.Single(_data.Saved);
        Assert.Equal("DRAW", rec.P1.Result);
    }

    // ---------- Mất kết nối ----------

    [Fact]
    public async Task Disconnect_GraceExpires_Abandon()
    {
        var id = await StartRanked();
        await _svc.UserDisconnectedAsync(1);
        var oc = _out.Last(2, "OpponentConnection");
        Assert.Equal(false, oc.Args[0]); Assert.Equal(30, oc.Args[1]);

        _clock.Advance(29); await _svc.TickAsync();
        Assert.Empty(_out.Of(2, "MatchEnded"));
        _clock.Advance(1); await _svc.TickAsync();
        var ended = _out.Last(2, "MatchEnded").Json();
        Assert.Equal("ABANDON", Str(ended, "reason"));
        Assert.Equal(2, ended.GetProperty("winnerId").GetInt32());
        var rec = Assert.Single(_data.Saved);
        var leaver = rec.P1.UserId == 1 ? rec.P1 : rec.P2;
        Assert.Equal("ABANDONED", leaver.Result);
        Assert.Equal(0, leaver.Score);
        Assert.True(leaver.RatingAfter < leaver.RatingBefore);
        Assert.NotNull(id);
    }

    [Fact]
    public async Task Disconnect_Rejoin_RestoresState_NoAbandon()
    {
        var id = await StartRanked();
        var first = FirstTurn(id);
        await _svc.CaroMoveAsync(first, id, 7, 7);
        var other = first == 1 ? 2 : 1;

        await _svc.UserDisconnectedAsync(other);
        _clock.Advance(10);
        _out.Clear();
        await _svc.RejoinAsync(other, id);
        Assert.Equal(true, _out.Last(first, "OpponentConnection").Args[0]);
        var st = _out.Last(other, "MatchState").Json();
        Assert.Equal(1, st.GetProperty("caro").GetProperty("moves").GetArrayLength());
        Assert.Equal(other, st.GetProperty("caro").GetProperty("currentTurnUserId").GetInt32());

        _clock.Advance(25); await _svc.TickAsync(); // quá 30s kể từ lúc rớt nhưng đã rejoin; lượt chưa quá 30s kể từ nước đi? (đã 35s)
        // lượt của 'other' đã quá 30s -> TIMEOUT chứ không phải ABANDON
        Assert.Equal("TIMEOUT", Str(_out.Last(first, "MatchEnded").Json(), "reason"));
    }

    [Fact]
    public async Task Disconnect_RaceRejoin_ThenNoAbandon()
    {
        var id = await StartRanked("RUBIK", 1);
        await _svc.UserDisconnectedAsync(2);
        _clock.Advance(20);
        await _svc.RejoinAsync(2, id);
        _clock.Advance(20); await _svc.TickAsync();
        Assert.Empty(_out.Of(1, "MatchEnded"));
        Assert.True(_svc.IsInMatch(2));
    }

    [Fact]
    public async Task Disconnect_InQueue_RemovesFromQueue()
    {
        AddPlayer(1);
        await _svc.QueueJoinAsync(1, "CARO", 1);
        await _svc.UserDisconnectedAsync(1);
        Assert.False(_svc.IsQueued(1));
    }

    // ---------- Chat nhanh & tái đấu ----------

    [Fact]
    public async Task QuickChat_Whitelist_And_Throttle()
    {
        var id = await StartRanked();
        await _svc.QuickChatAsync(1, id, "gg");
        Assert.Equal("gg", Str(_out.Last(2, "QuickChat").Json(), "code"));
        await _svc.QuickChatAsync(1, id, "nice");           // < 2 giây: bỏ qua
        Assert.Single(_out.Of(2, "QuickChat"));
        _clock.Advance(2);
        await _svc.QuickChatAsync(1, id, "nice");
        Assert.Equal(2, _out.Of(2, "QuickChat").Count);
        await Assert.ThrowsAsync<HubException>(() => _svc.QuickChatAsync(1, id, "idiot"));
    }

    [Fact]
    public async Task Rematch_BothWithin30s_StartsNewMatch()
    {
        var id = await StartRanked();
        await _svc.ResignAsync(1, id);
        _clock.Advance(10);
        await _svc.RematchAsync(1, id);
        Assert.Single(_out.Of(2, "RematchRequested"));
        await _svc.RematchAsync(2, id);
        var started = _out.Last(1, "MatchStarted").Json();
        Assert.NotEqual(id, Str(started, "matchId"));
        Assert.Equal("RANKED", Str(started, "mode"));
        Assert.True(_svc.IsInMatch(1) && _svc.IsInMatch(2));
        // rating mang theo từ trận trước (người thắng +20)
        var players = started.GetProperty("players").EnumerateArray().ToDictionary(p => p.GetProperty("userId").GetInt32(), p => p.GetProperty("rating").GetInt32());
        Assert.Equal(1000 - 20, players[1]);
        Assert.Equal(1000 + 20, players[2]);
    }

    [Fact]
    public async Task Rematch_TooLate_Throws()
    {
        var id = await StartRanked();
        await _svc.ResignAsync(1, id);
        _clock.Advance(31);
        await Assert.ThrowsAsync<HubException>(() => _svc.RematchAsync(1, id));
    }

    [Fact]
    public async Task Rematch_NonParticipant_Throws()
    {
        var id = await StartRanked();
        AddPlayer(3);
        await _svc.ResignAsync(1, id);
        await Assert.ThrowsAsync<HubException>(() => _svc.RematchAsync(3, id));
    }

    [Fact]
    public async Task Shutdown_EndsMatchesWithoutSaving()
    {
        await StartRanked();
        await _svc.ShutdownAsync();
        Assert.Equal("SERVER_RESTART", Str(_out.Last(1, "MatchEnded").Json(), "reason"));
        Assert.Empty(_data.Saved);
        Assert.False(_svc.IsInMatch(1));
    }

    [Fact]
    public async Task InMatchChanged_Fires_OnStartAndEnd()
    {
        var changed = new List<int>();
        _svc.InMatchChanged += changed.Add;
        var id = await StartRanked();
        Assert.Contains(1, changed); Assert.Contains(2, changed);
        changed.Clear();
        await _svc.ResignAsync(1, id);
        Assert.Contains(1, changed); Assert.Contains(2, changed);
    }
}
