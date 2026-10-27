using Microsoft.AspNetCore.SignalR;

namespace GameHub.Api.Services;

/// <summary>
/// Toàn bộ trạng thái trận nằm trong bộ nhớ. Mọi thay đổi trạng thái diễn ra trong MỘT khóa (_gate);
/// thông báo và ghi DB được thực hiện SAU khi nhả khóa. Đồng hồ (hết lượt, kết nối lại, lời mời, hàng đợi)
/// được điều khiển bằng <see cref="TickAsync"/> (MatchTicker gọi mỗi giây; test gọi tay với đồng hồ giả),
/// không có timer riêng và không đụng DB.
/// </summary>
public sealed class MatchService
{
    public const int InviteSeconds = 30, GraceSeconds = 30, TurnSeconds = CaroRules.MoveSeconds;
    public const int RematchSeconds = 30, QueueStatusSeconds = 3, MaxDrawOffers = 3;
    public static readonly TimeSpan RaceProgressInterval = TimeSpan.FromMilliseconds(1000.0 / RaceRules.MaxProgressPerSecond);
    public static readonly TimeSpan QuickChatInterval = TimeSpan.FromSeconds(2);
    public static readonly TimeSpan RaceLimit = TimeSpan.FromMinutes(RaceRules.TimeLimitMinutes);
    public static readonly string[] GameCodes = ["CARO", "SUDOKU", "PUZZLE", "RUBIK"];
    public static readonly string[] QuickChatCodes = ["hello", "nice", "gg", "rematch", "oops", "thanks"];

    /// <summary>Khoảng rating cho phép sau <paramref name="waitedSec"/> giây chờ; null = không giới hạn.</summary>
    public static int? RatingRange(double waitedSec) => waitedSec switch
    {
        < 10 => 100,
        < 20 => 200,
        < 30 => 400,
        _ => null,
    };

    private sealed class Slot(PlayerInfo info)
    {
        public PlayerInfo Info = info;
        public bool Connected = true;
        public DateTime? DisconnectDeadline;
        public int Progress;
        public DateTime LastProgressAt = DateTime.MinValue;
        public DateTime LastChatAt = DateTime.MinValue;
        public int? FinishMs;
        public int Mistakes;
        public int Moves;
        public int DrawOffers;
        public int UserId => Info.UserId;
    }

    private sealed class Live
    {
        public string Id = "";
        public string GameCode = "", Mode = "", Kind = "";
        public int Difficulty, Seed;
        public DateTime StartedAt;
        public Slot[] Slots = [];
        public bool Active = true;
        // Caro
        public int[] Board = new int[CaroRules.Size * CaroRules.Size];
        public List<(int Row, int Col, int UserId)> Moves = [];
        public int CurrentTurn;
        public DateTime TurnDeadline;
        public int? DrawOfferFrom;
        // Race
        public DateTime RaceDeadline;
        // Sudoku Co-op
        public int SharedMistakes;
        public List<(int Row, int Col, int Value, int UserId, bool IsMistake)> SudokuMoves = [];
        // Kết thúc
        public DateTime EndedAt;
        public int? WinnerId;
        public string Reason = "";
        public MatchResultRecord? Record;
        public HashSet<int> Rematch = [];

        public Slot SlotOf(int userId) => Slots[0].UserId == userId ? Slots[0] : Slots[1];
        public Slot OtherOf(int userId) => Slots[0].UserId == userId ? Slots[1] : Slots[0];
        public bool Has(int userId) => Slots[0].UserId == userId || Slots[1].UserId == userId;
    }

    private sealed class QEntry(PlayerInfo info, string game, int diff, DateTime now)
    {
        public PlayerInfo Info = info;
        public string Game = game;
        public int Difficulty = diff;
        public DateTime JoinedAt = now, LastStatusAt = now;
    }

    private sealed class Invite
    {
        public string Id = "";
        public PlayerInfo From = null!;
        public int ToId;
        public string GameCode = "";
        public int Difficulty;
        public DateTime ExpiresAt;
    }

    /// <summary>Gom thông báo / kết thúc trận để xử lý sau khi nhả khóa.</summary>
    private sealed class Ctx
    {
        public readonly List<(int User, string Method, object?[] Args)> Out = [];
        public readonly List<Live> Ended = [];
        public readonly List<int> StatusChanged = [];
        public void Send(int user, string method, params object?[] args) => Out.Add((user, method, args));
    }

    private readonly object _gate = new();
    private readonly Dictionary<string, Live> _matches = [];
    private readonly Dictionary<int, Live> _userMatch = [];
    private readonly Dictionary<string, Live> _endedMatches = [];
    private readonly Dictionary<int, QEntry> _queue = [];
    private readonly Dictionary<string, Invite> _invites = [];
    private readonly IMatchData _data;
    private readonly IRealtimeNotifier _notifier;
    private readonly IPresence _presence;
    private readonly IClock _clock;
    private readonly ILogger<MatchService> _log;
    private readonly Random _rng;

    /// <summary>Phát khi trạng thái "đang trong trận" của một người đổi (để phát Presence).</summary>
    public event Action<int>? InMatchChanged;

    public MatchService(IMatchData data, IRealtimeNotifier notifier, IPresence presence, IClock clock,
        ILogger<MatchService> log, Random? rng = null)
    {
        _data = data; _notifier = notifier; _presence = presence; _clock = clock; _log = log;
        _rng = rng ?? new Random();
    }

    // ---------- Truy vấn ----------

    public bool IsInMatch(int userId) { lock (_gate) return _userMatch.ContainsKey(userId); }
    public bool IsQueued(int userId) { lock (_gate) return _queue.ContainsKey(userId); }
    public string? CurrentMatchId(int userId) { lock (_gate) return _userMatch.TryGetValue(userId, out var m) ? m.Id : null; }
    public int ActiveMatchCount { get { lock (_gate) return _matches.Count; } }

    // ---------- Hàng đợi ----------

    public async Task QueueJoinAsync(int userId, string gameCode, int difficulty)
    {
        gameCode = NormalizeGame(gameCode);
        ValidateDifficulty(difficulty, gameCode);
        var info = await _data.LoadPlayerAsync(userId, gameCode) ?? throw new HubException("Tài khoản không tồn tại");
        var ctx = new Ctx();
        lock (_gate)
        {
            if (_userMatch.ContainsKey(userId)) throw new HubException("Bạn đang trong một trận đấu");
            _queue.Remove(userId);
            var now = _clock.UtcNow;
            _queue[userId] = new QEntry(info, gameCode, difficulty, now);
            CancelInvitesOf(userId, ctx);
            ctx.Send(userId, "QueueStatus", true, 0, RatingRange(0) ?? 0);
            TryMatchLocked(ctx);
        }
        await CompleteAsync(ctx);
    }

    public async Task QueueLeaveAsync(int userId)
    {
        var ctx = new Ctx();
        lock (_gate)
        {
            if (_queue.Remove(userId)) ctx.Send(userId, "QueueStatus", false, 0, 0);
        }
        await CompleteAsync(ctx);
    }

    private void TryMatchLocked(Ctx ctx)
    {
        var now = _clock.UtcNow;
        foreach (var group in _queue.Values.GroupBy(q => (q.Game, q.Difficulty)).ToList())
        {
            var pool = group.OrderBy(q => q.JoinedAt).ToList();
            var used = new HashSet<int>();
            foreach (var a in pool)
            {
                if (used.Contains(a.Info.UserId)) continue;
                QEntry? best = null;
                foreach (var b in pool)
                {
                    if (b == a || used.Contains(b.Info.UserId)) continue;
                    if (!Compatible(a, b, now)) continue;
                    if (best is null || Math.Abs(b.Info.Rating - a.Info.Rating) < Math.Abs(best.Info.Rating - a.Info.Rating)) best = b;
                }
                if (best is null) continue;
                used.Add(a.Info.UserId); used.Add(best.Info.UserId);
                StartLocked(a.Info, best.Info, a.Game, a.Difficulty, "RANKED", ctx);
            }
        }
    }

    private static bool Compatible(QEntry a, QEntry b, DateTime now)
    {
        var ra = RatingRange((now - a.JoinedAt).TotalSeconds);
        var rb = RatingRange((now - b.JoinedAt).TotalSeconds);
        if (ra is null || rb is null) return true; // ai đã chờ đủ lâu thì không giới hạn
        return Math.Abs(a.Info.Rating - b.Info.Rating) <= Math.Max(ra.Value, rb.Value);
    }

    // ---------- Lời mời giao hữu ----------

    public async Task<string> InviteAsync(int userId, int friendId, string gameCode, int difficulty)
    {
        gameCode = NormalizeGame(gameCode);
        ValidateDifficulty(difficulty, gameCode);
        if (friendId == userId) throw new HubException("Không thể tự mời chính mình");
        if (!await _data.AreFriendsAsync(userId, friendId)) throw new HubException("Chỉ mời đấu giao hữu với bạn bè");
        if (!_presence.IsOnline(friendId)) throw new HubException("Bạn bè đang offline");
        var me = await _data.LoadPlayerAsync(userId, gameCode) ?? throw new HubException("Tài khoản không tồn tại");

        var ctx = new Ctx();
        string id;
        lock (_gate)
        {
            if (_userMatch.ContainsKey(userId)) throw new HubException("Bạn đang trong một trận đấu");
            if (_queue.ContainsKey(userId)) throw new HubException("Bạn đang tìm trận, hãy hủy tìm trước");
            if (_userMatch.ContainsKey(friendId)) throw new HubException("Bạn bè đang trong trận đấu");
            if (_invites.Values.Any(i => i.From.UserId == userId)) throw new HubException("Bạn đang có một lời mời chờ phản hồi");
            id = Guid.NewGuid().ToString("N");
            var inv = new Invite
            {
                Id = id, From = me, ToId = friendId, GameCode = gameCode, Difficulty = difficulty,
                ExpiresAt = _clock.UtcNow.AddSeconds(InviteSeconds),
            };
            _invites[id] = inv;
            ctx.Send(friendId, "InviteReceived", new
            {
                inviteId = id,
                from = new { userId = me.UserId, username = me.Username, fullName = me.FullName, avatarUrl = me.AvatarUrl },
                gameCode, difficulty, expiresAtUtc = inv.ExpiresAt, expiresInSec = InviteSeconds,
            });
        }
        await CompleteAsync(ctx);
        return id;
    }

    public async Task RespondInviteAsync(int userId, string inviteId, bool accept)
    {
        var ctx = new Ctx();
        Invite? inv;
        string? error = null;
        var go = false;
        lock (_gate)
        {
            if (!_invites.TryGetValue(inviteId ?? "", out inv)) throw new HubException("Lời mời không còn hiệu lực");
            if (inv.ToId != userId) throw new HubException("Đây không phải lời mời của bạn");
            _invites.Remove(inv.Id);
            if (_clock.UtcNow >= inv.ExpiresAt)
            {
                ctx.Send(inv.From.UserId, "InviteResult", InviteResult(inv, "expired", null));
                error = "Lời mời đã hết hạn";
            }
            else if (!accept)
            {
                ctx.Send(inv.From.UserId, "InviteResult", InviteResult(inv, "declined", null));
            }
            else go = true;
        }
        if (!go)
        {
            await CompleteAsync(ctx);
            if (error is not null) throw new HubException(error);
            return;
        }

        var me = await _data.LoadPlayerAsync(userId, inv.GameCode);
        var from = await _data.LoadPlayerAsync(inv.From.UserId, inv.GameCode);
        lock (_gate)
        {
            if (me is null || from is null) error = "Người chơi không tồn tại";
            else if (_userMatch.ContainsKey(userId) || _queue.ContainsKey(userId)) error = "Bạn đang trong một trận đấu";
            else if (_userMatch.ContainsKey(from.UserId)) error = "Bạn bè đã vào trận khác";
            else if (!_presence.IsOnline(from.UserId)) error = "Bạn bè đã offline";
            if (error is null) StartLocked(from!, me!, inv.GameCode, inv.Difficulty, "FRIENDLY", ctx, inv);
            else ctx.Send(inv.From.UserId, "InviteResult", InviteResult(inv, "expired", null));
        }
        await CompleteAsync(ctx);
        if (error is not null) throw new HubException(error);
    }

    private static object InviteResult(Invite inv, string status, string? matchId) =>
        new { inviteId = inv.Id, status, userId = inv.ToId, gameCode = inv.GameCode, difficulty = inv.Difficulty, matchId };

    /// <summary>Hủy lời mời liên quan tới user (khi vào trận / hàng đợi / mất kết nối).</summary>
    private void CancelInvitesOf(int userId, Ctx ctx, string statusForInviter = "declined")
    {
        foreach (var inv in _invites.Values.Where(i => i.From.UserId == userId || i.ToId == userId).ToList())
        {
            _invites.Remove(inv.Id);
            if (inv.From.UserId == userId) ctx.Send(inv.ToId, "InviteResult", InviteResult(inv, "expired", null));
            else ctx.Send(inv.From.UserId, "InviteResult", InviteResult(inv, statusForInviter, null));
        }
    }

    // ---------- Bắt đầu trận ----------

    private Live StartLocked(PlayerInfo a, PlayerInfo b, string gameCode, int difficulty, string mode, Ctx ctx, Invite? invite = null)
    {
        _queue.Remove(a.UserId); _queue.Remove(b.UserId);
        var now = _clock.UtcNow;
        var turn = gameCode == "CARO";
        var coop = gameCode == "SUDOKU" && mode == "FRIENDLY";
        var kind = turn ? "TURN" : (coop ? "COOP" : "RACE");
        var m = new Live
        {
            Id = Guid.NewGuid().ToString("N"), GameCode = gameCode, Difficulty = difficulty, Mode = mode,
            Kind = kind, Seed = _rng.Next(1, int.MaxValue), StartedAt = now,
            Slots = [new Slot(a), new Slot(b)],
        };
        if (turn)
        {
            m.CurrentTurn = m.Slots[_rng.Next(2)].UserId;
            m.TurnDeadline = now.AddSeconds(TurnSeconds);
        }
        else if (coop)
        {
            m.RaceDeadline = now.AddMinutes(30);
            m.CurrentTurn = a.UserId;
        }
        else m.RaceDeadline = now + RaceLimit;

        _matches[m.Id] = m;
        _userMatch[a.UserId] = m;
        _userMatch[b.UserId] = m;
        foreach (var s in m.Slots) CancelInvitesOf(s.UserId, ctx, "declined");
        if (invite is not null) ctx.Send(invite.From.UserId, "InviteResult", InviteResult(invite, "accepted", m.Id));
        foreach (var s in m.Slots)
        {
            ctx.Send(s.UserId, "QueueStatus", false, 0, 0);
            ctx.Send(s.UserId, "MatchStarted", Payload(m, s.UserId));
            ctx.StatusChanged.Add(s.UserId);
        }
        return m;
    }

    private static object Payload(Live m, int forUser) => new
    {
        matchId = m.Id,
        gameCode = m.GameCode,
        difficulty = m.Difficulty,
        mode = m.Mode,
        kind = m.Kind,
        seed = m.Seed,
        status = m.Active ? "ACTIVE" : "ENDED",
        startedAtUtc = m.StartedAt,
        you = forUser,
        players = m.Slots.Select(s => new
        {
            userId = s.UserId, username = s.Info.Username, fullName = s.Info.FullName, avatarUrl = s.Info.AvatarUrl,
            rating = s.Info.Rating, tier = Tiers.Of(s.Info.Rating).Code, tierName = Tiers.Of(s.Info.Rating).Name,
            connected = s.Connected,
        }).ToList(),
        caro = m.Kind == "TURN"
            ? new
            {
                size = CaroRules.Size,
                moves = m.Moves.Select(x => new { row = x.Row, col = x.Col, userId = x.UserId }).ToList(),
                currentTurnUserId = m.Active ? (int?)m.CurrentTurn : null,
                turnDeadlineUtc = m.Active ? (DateTime?)m.TurnDeadline : null,
                drawOfferedBy = m.DrawOfferFrom,
            }
            : null,
        race = m.Kind == "RACE"
            ? new
            {
                progress = m.Slots.Select(s => new { userId = s.UserId, percent = s.Progress }).ToList(),
                deadlineUtc = m.RaceDeadline,
            }
            : null,
        coop = m.Kind == "COOP"
            ? new
            {
                mistakes = m.SharedMistakes,
                maxMistakes = 3,
                currentTurnUserId = m.CurrentTurn,
                moves = m.SudokuMoves.Select(x => new { row = x.Row, col = x.Col, value = x.Value, userId = x.UserId, isMistake = x.IsMistake }).ToList(),
            }
            : null,
    };

    // ---------- Caro ----------

    public async Task CaroMoveAsync(int userId, string matchId, int row, int col)
    {
        var ctx = new Ctx();
        lock (_gate)
        {
            var m = ActiveFor(userId, matchId);
            if (m.Kind != "TURN") throw new HubException("Đây không phải trận Caro");
            if (m.CurrentTurn != userId) throw new HubException("Chưa đến lượt của bạn");
            if (row is < 0 or >= CaroRules.Size || col is < 0 or >= CaroRules.Size) throw new HubException("Nước đi ngoài bàn cờ");
            var idx = row * CaroRules.Size + col;
            if (m.Board[idx] != 0) throw new HubException("Ô này đã có quân");

            var me = m.SlotOf(userId);
            var opp = m.OtherOf(userId);
            m.Board[idx] = userId;
            m.Moves.Add((row, col, userId));
            me.Moves++;
            if (m.DrawOfferFrom == opp.UserId)
            {
                m.DrawOfferFrom = null; // đi tiếp = từ chối lời xin hòa
                ctx.Send(opp.UserId, "DrawResponded", new { matchId = m.Id, accepted = false, byUserId = userId });
            }

            if (CaroRules.IsWin(m.Board, row, col)) EndLocked(m, userId, "WIN", ctx);
            else if (m.Moves.Count >= m.Board.Length) EndLocked(m, null, "DRAW", ctx);
            else
            {
                m.CurrentTurn = opp.UserId;
                m.TurnDeadline = _clock.UtcNow.AddSeconds(TurnSeconds);
            }
            foreach (var s in m.Slots) ctx.Send(s.UserId, "MatchState", Payload(m, s.UserId));
        }
        await CompleteAsync(ctx);
    }

    public async Task OfferDrawAsync(int userId, string matchId)
    {
        var ctx = new Ctx();
        lock (_gate)
        {
            var m = ActiveFor(userId, matchId);
            if (m.Kind != "TURN") throw new HubException("Chỉ xin hòa được trong trận Caro");
            if (m.DrawOfferFrom is not null) throw new HubException("Đã có lời xin hòa đang chờ");
            var me = m.SlotOf(userId);
            if (me.DrawOffers >= MaxDrawOffers) throw new HubException("Bạn đã xin hòa quá số lần cho phép");
            me.DrawOffers++;
            m.DrawOfferFrom = userId;
            ctx.Send(m.OtherOf(userId).UserId, "DrawOffered", new { matchId = m.Id, fromUserId = userId });
        }
        await CompleteAsync(ctx);
    }

    public async Task RespondDrawAsync(int userId, string matchId, bool accept)
    {
        var ctx = new Ctx();
        lock (_gate)
        {
            var m = ActiveFor(userId, matchId);
            if (m.DrawOfferFrom is not { } from || from == userId) throw new HubException("Không có lời xin hòa nào để phản hồi");
            m.DrawOfferFrom = null;
            if (accept) EndLocked(m, null, "DRAW", ctx);
            else ctx.Send(from, "DrawResponded", new { matchId = m.Id, accepted = false, byUserId = userId });
            foreach (var s in m.Slots) ctx.Send(s.UserId, "MatchState", Payload(m, s.UserId));
        }
        await CompleteAsync(ctx);
    }

    public async Task ResignAsync(int userId, string matchId)
    {
        var ctx = new Ctx();
        lock (_gate)
        {
            var m = ActiveFor(userId, matchId);
            EndLocked(m, m.OtherOf(userId).UserId, "RESIGN", ctx);
        }
        await CompleteAsync(ctx);
    }

    // ---------- Đua giải ----------

    public async Task RaceProgressAsync(int userId, string matchId, int percent)
    {
        var ctx = new Ctx();
        lock (_gate)
        {
            var m = ActiveFor(userId, matchId);
            if (m.Kind != "RACE") throw new HubException("Đây không phải trận đua");
            var me = m.SlotOf(userId);
            var now = _clock.UtcNow;
            if (percent < 0 || percent > 100) return;
            if (now - me.LastProgressAt < RaceProgressInterval) return; // tối đa 4 lần/giây
            me.LastProgressAt = now;
            if (percent <= me.Progress) return; // chỉ tăng
            me.Progress = percent;
            ctx.Send(m.OtherOf(userId).UserId, "OpponentProgress", new { matchId = m.Id, userId, percent });
        }
        await CompleteAsync(ctx);
    }

    public async Task RaceFinishAsync(int userId, string matchId, int timeMs, int mistakes)
    {
        var ctx = new Ctx();
        lock (_gate)
        {
            var m = ActiveFor(userId, matchId);
            if (m.Kind != "RACE") throw new HubException("Đây không phải trận đua");
            var me = m.SlotOf(userId);
            var elapsedMs = (_clock.UtcNow - m.StartedAt).TotalMilliseconds;
            var min = RaceRules.MinTimeMs(m.GameCode, m.Difficulty);
            if (me.Progress < RaceRules.FinishProgressGate) throw new HubException("Kết quả không hợp lệ: tiến độ chưa đủ");
            if (timeMs < min || elapsedMs < min) throw new HubException("Kết quả không hợp lệ: thời gian quá ngắn");
            if (timeMs > elapsedMs + RaceRules.ClockToleranceMs) throw new HubException("Kết quả không hợp lệ: thời gian vượt quá trận");
            me.FinishMs = timeMs;
            me.Mistakes = Math.Clamp(mistakes, 0, 100000);
            me.Progress = 100;
            EndLocked(m, userId, "WIN", ctx);
            foreach (var s in m.Slots) ctx.Send(s.UserId, "MatchState", Payload(m, s.UserId));
        }
        await CompleteAsync(ctx);
    }

    // ---------- Sudoku Co-op ----------

    public async Task SudokuMoveAsync(int userId, string matchId, int row, int col, int val, bool isMistake)
    {
        var ctx = new Ctx();
        lock (_gate)
        {
            var m = ActiveFor(userId, matchId);
            if (m.Kind != "COOP") throw new HubException("Đây không phải trận Sudoku đồng đội");
            if (m.CurrentTurn != 0 && m.CurrentTurn != userId) throw new HubException("Chưa đến lượt của bạn");
            if (row is < 0 or >= 9 || col is < 0 or >= 9) throw new HubException("Tọa độ ngoài ô");

            var me = m.SlotOf(userId);
            me.Moves++;
            if (isMistake)
            {
                me.Mistakes++;
                m.SharedMistakes++;
                m.SudokuMoves.Add((row, col, val, userId, true));
            }
            else
            {
                m.SudokuMoves.Add((row, col, val, userId, false));
            }

            var nextTurn = m.OtherOf(userId).UserId;
            m.CurrentTurn = nextTurn;

            foreach (var s in m.Slots)
            {
                ctx.Send(s.UserId, "SudokuMoveApplied", new
                {
                    matchId = m.Id,
                    row,
                    col,
                    value = val,
                    byUserId = userId,
                    isMistake,
                    mistakes = m.SharedMistakes,
                    movesCount = m.SudokuMoves.Count,
                    nextTurnUserId = nextTurn,
                });
            }

            if (m.SharedMistakes >= 3)
            {
                EndLocked(m, null, "MISTAKES_LIMIT", ctx);
            }
        }
        await CompleteAsync(ctx);
    }

    public async Task SudokuCursorAsync(int userId, string matchId, int row, int col)
    {
        var ctx = new Ctx();
        lock (_gate)
        {
            var m = ActiveFor(userId, matchId);
            if (m.Kind != "COOP") return;
            var opp = m.OtherOf(userId);
            ctx.Send(opp.UserId, "SudokuCursorMoved", new { matchId = m.Id, userId, row, col });
        }
        await CompleteAsync(ctx);
    }

    public async Task SudokuFinishAsync(int userId, string matchId, int timeSeconds)
    {
        var ctx = new Ctx();
        lock (_gate)
        {
            var m = ActiveFor(userId, matchId);
            if (m.Kind != "COOP") throw new HubException("Đây không phải trận Sudoku đồng đội");
            var me = m.SlotOf(userId);
            me.FinishMs = timeSeconds * 1000;
            var opp = m.OtherOf(userId);
            opp.FinishMs = timeSeconds * 1000;
            EndLocked(m, null, "COOP_WIN", ctx);
            foreach (var s in m.Slots) ctx.Send(s.UserId, "MatchState", Payload(m, s.UserId));
        }
        await CompleteAsync(ctx);
    }

    // ---------- Tin nhắn nhanh, tái đấu, kết nối lại ----------

    public async Task QuickChatAsync(int userId, string matchId, string code)
    {
        var ctx = new Ctx();
        lock (_gate)
        {
            var m = FindFor(userId, matchId);
            if (!QuickChatCodes.Contains(code ?? "")) throw new HubException("Tin nhắn nhanh không hợp lệ");
            var me = m.SlotOf(userId);
            var now = _clock.UtcNow;
            if (now - me.LastChatAt < QuickChatInterval) return; // 1 tin/2 giây
            me.LastChatAt = now;
            ctx.Send(m.OtherOf(userId).UserId, "QuickChat", new { matchId = m.Id, fromUserId = userId, code });
        }
        await CompleteAsync(ctx);
    }

    public async Task RematchAsync(int userId, string matchId)
    {
        var ctx = new Ctx();
        lock (_gate)
        {
            if (!_endedMatches.TryGetValue(matchId ?? "", out var old) || !old.Has(userId))
                throw new HubException("Không thể tái đấu trận này");
            if (_clock.UtcNow > old.EndedAt.AddSeconds(RematchSeconds)) throw new HubException("Đã hết thời gian tái đấu");
            var opp = old.OtherOf(userId);
            if (!_presence.IsOnline(opp.UserId)) throw new HubException("Đối thủ đã rời đi");
            if (_userMatch.ContainsKey(userId) || _userMatch.ContainsKey(opp.UserId)) throw new HubException("Một trong hai người đang trong trận khác");
            old.Rematch.Add(userId);
            if (old.Rematch.Count < 2)
            {
                ctx.Send(opp.UserId, "RematchRequested", new { matchId = old.Id, fromUserId = userId });
            }
            else
            {
                _endedMatches.Remove(old.Id);
                // Rating hiện tại = rating sau trận trước (đã tính xong, chưa cần đọc lại DB).
                PlayerInfo Next(Slot s)
                {
                    var o = old.Record is null ? null : old.Record.P1.UserId == s.UserId ? old.Record.P1 : old.Record.P2;
                    return old.Mode == "RANKED" && o is not null
                        ? s.Info with { Rating = o.RatingAfter, RatedGames = s.Info.RatedGames + 1 }
                        : s.Info;
                }
                StartLocked(Next(old.Slots[1]), Next(old.Slots[0]), old.GameCode, old.Difficulty, old.Mode, ctx);
            }
        }
        await CompleteAsync(ctx);
    }

    public async Task RejoinAsync(int userId, string matchId)
    {
        var ctx = new Ctx();
        lock (_gate)
        {
            var m = ActiveFor(userId, matchId);
            var me = m.SlotOf(userId);
            var wasDown = !me.Connected;
            me.Connected = true;
            me.DisconnectDeadline = null;
            if (wasDown) ctx.Send(m.OtherOf(userId).UserId, "OpponentConnection", true, 0);
            ctx.Send(userId, "MatchState", Payload(m, userId));
        }
        await CompleteAsync(ctx);
    }

    // ---------- Kết nối ----------

    /// <summary>Gọi khi kết nối CUỐI CÙNG của user đóng.</summary>
    public async Task UserDisconnectedAsync(int userId)
    {
        var ctx = new Ctx();
        lock (_gate)
        {
            if (_queue.Remove(userId)) { /* rời hàng đợi, không cần báo */ }
            CancelInvitesOf(userId, ctx);
            if (_userMatch.TryGetValue(userId, out var m) && m.Active)
            {
                var me = m.SlotOf(userId);
                me.Connected = false;
                me.DisconnectDeadline = _clock.UtcNow.AddSeconds(GraceSeconds);
                ctx.Send(m.OtherOf(userId).UserId, "OpponentConnection", false, GraceSeconds);
            }
        }
        await CompleteAsync(ctx);
    }

    // ---------- Đồng hồ ----------

    public async Task TickAsync()
    {
        var ctx = new Ctx();
        lock (_gate)
        {
            var now = _clock.UtcNow;

            foreach (var inv in _invites.Values.Where(i => now >= i.ExpiresAt).ToList())
            {
                _invites.Remove(inv.Id);
                ctx.Send(inv.From.UserId, "InviteResult", InviteResult(inv, "expired", null));
                ctx.Send(inv.ToId, "InviteResult", InviteResult(inv, "expired", null));
            }

            TryMatchLocked(ctx);
            foreach (var q in _queue.Values)
            {
                if ((now - q.LastStatusAt).TotalSeconds < QueueStatusSeconds) continue;
                q.LastStatusAt = now;
                var waited = (now - q.JoinedAt).TotalSeconds;
                ctx.Send(q.Info.UserId, "QueueStatus", true, (int)waited, RatingRange(waited) ?? 0);
            }

            foreach (var m in _matches.Values.Where(x => x.Active).ToList())
            {
                var gone = m.Slots.FirstOrDefault(s => s.DisconnectDeadline is { } d && now >= d);
                if (gone is not null)
                {
                    EndLocked(m, m.OtherOf(gone.UserId).UserId, "ABANDON", ctx);
                }
                else if (m.Kind == "TURN" && now >= m.TurnDeadline)
                {
                    EndLocked(m, m.OtherOf(m.CurrentTurn).UserId, "TIMEOUT", ctx);
                }
                else if (m.Kind == "RACE" && now >= m.RaceDeadline)
                {
                    var (a, b) = (m.Slots[0], m.Slots[1]);
                    EndLocked(m, a.Progress == b.Progress ? null : a.Progress > b.Progress ? a.UserId : b.UserId, "TIME_LIMIT", ctx);
                }
                else if (m.Kind == "COOP" && now >= m.RaceDeadline)
                {
                    EndLocked(m, null, "TIME_LIMIT", ctx);
                }
                else continue;
                foreach (var s in m.Slots) ctx.Send(s.UserId, "MatchState", Payload(m, s.UserId));
            }

            foreach (var e in _endedMatches.Values.Where(x => now > x.EndedAt.AddSeconds(RematchSeconds * 2)).ToList())
                _endedMatches.Remove(e.Id);
        }
        await CompleteAsync(ctx);
    }

    /// <summary>Server tắt: hủy mọi trận đang chơi, không ghi DB, không đổi rating.</summary>
    public async Task ShutdownAsync()
    {
        var ctx = new Ctx();
        lock (_gate)
        {
            foreach (var m in _matches.Values.Where(x => x.Active).ToList())
            {
                m.Active = false;
                m.Reason = "SERVER_RESTART";
                foreach (var s in m.Slots)
                {
                    _userMatch.Remove(s.UserId);
                    ctx.StatusChanged.Add(s.UserId);
                    ctx.Send(s.UserId, "MatchEnded", new
                    {
                        matchId = m.Id, winnerId = (int?)null, reason = "SERVER_RESTART", mode = m.Mode,
                        ratingChanges = Array.Empty<object>(),
                    });
                }
                _matches.Remove(m.Id);
            }
        }
        await CompleteAsync(ctx);
    }

    // ---------- Kết thúc trận ----------

    private void EndLocked(Live m, int? winnerId, string reason, Ctx ctx)
    {
        var now = _clock.UtcNow;
        m.Active = false;
        m.EndedAt = now;
        m.WinnerId = winnerId;
        m.Reason = reason;
        m.DrawOfferFrom = null;
        var ranked = m.Mode == "RANKED";
        var totalSec = (int)Math.Max((now - m.StartedAt).TotalSeconds, 1);
        var draw = winnerId is null;

        PlayerOutcome Outcome(Slot s, Slot other)
        {
            var result = m.Kind == "COOP"
                ? (reason == "COOP_WIN" ? "WIN" : "LOSE")
                : (draw ? "DRAW" : s.UserId == winnerId ? "WIN" : reason == "ABANDON" ? "ABANDONED" : "LOSE");
            var time = result == "WIN" && s.FinishMs is int ms ? Math.Max((int)Math.Round(ms / 1000.0), 1) : totalSec;
            var moves = m.Kind == "COOP" ? s.Moves : (m.Kind == "TURN" ? s.Moves : 0);
            var score = result == "WIN" || (result == "DRAW" && m.GameCode == "CARO")
                ? ScoreCalculator.Calculate(m.Difficulty, time, s.Mistakes, result, m.GameCode, moves)
                : 0;
            var before = s.Info.Rating;
            var after = before;
            if (ranked)
            {
                var sc = result == "WIN" ? 1.0 : result == "DRAW" ? 0.5 : 0.0;
                after = Elo.NewRating(before, other.Info.Rating, sc, s.Info.RatedGames);
            }
            return new PlayerOutcome(s.UserId, result, score, time, s.Mistakes, moves, before, after);
        }

        var p1 = Outcome(m.Slots[0], m.Slots[1]);
        var p2 = Outcome(m.Slots[1], m.Slots[0]);
        m.Record = new MatchResultRecord(m.GameCode, m.Difficulty, m.Mode, m.Kind, m.Seed, m.StartedAt, now,
            winnerId, reason, p1, p2);

        _matches.Remove(m.Id);
        foreach (var s in m.Slots)
        {
            _userMatch.Remove(s.UserId);
            ctx.StatusChanged.Add(s.UserId);
        }
        _endedMatches[m.Id] = m;
        ctx.Ended.Add(m);
    }

    // ---------- Gửi / lưu sau khi nhả khóa ----------

    private async Task CompleteAsync(Ctx ctx)
    {
        foreach (var (user, method, args) in ctx.Out) await _notifier.SendAsync(user, method, args);

        foreach (var m in ctx.Ended)
        {
            var r = m.Record!;
            try { await _data.SaveResultAsync(r); }
            catch (Exception ex) { _log.LogError(ex, "Không ghi được kết quả trận {MatchId}", m.Id); }

            var changes = new[] { r.P1, r.P2 }.Select(o => new { userId = o.UserId, before = o.RatingBefore, after = o.RatingAfter }).ToList();
            var scores = new[] { r.P1, r.P2 }.Select(o => new { userId = o.UserId, result = o.Result, score = o.Score }).ToList();
            foreach (var s in m.Slots)
                await _notifier.SendAsync(s.UserId, "MatchEnded", new
                {
                    matchId = m.Id, winnerId = r.WinnerId, reason = r.Reason, mode = m.Mode,
                    ratingChanges = changes, results = scores,
                });
        }

        foreach (var uid in ctx.StatusChanged.Distinct())
            try { InMatchChanged?.Invoke(uid); } catch (Exception ex) { _log.LogWarning(ex, "InMatchChanged lỗi"); }
    }

    // ---------- Tiện ích ----------

    private Live FindFor(int userId, string matchId)
    {
        if (matchId is null) throw new HubException("Thiếu mã trận");
        if (_matches.TryGetValue(matchId, out var m) && m.Has(userId)) return m;
        if (_endedMatches.TryGetValue(matchId, out var e) && e.Has(userId)) return e;
        throw new HubException("Trận đấu không tồn tại hoặc bạn không tham gia");
    }

    private Live ActiveFor(int userId, string matchId)
    {
        var m = FindFor(userId, matchId);
        if (!m.Active) throw new HubException("Trận đấu đã kết thúc");
        return m;
    }

    private static string NormalizeGame(string? gameCode)
    {
        var code = (gameCode ?? "").Trim().ToUpperInvariant();
        if (!GameCodes.Contains(code)) throw new HubException("Game không tồn tại");
        return code;
    }

    private static void ValidateDifficulty(int d, string? gameCode = null)
    {
        var max = DifficultyRules.MaxFor(gameCode);
        if (d < 1 || d > max) throw new HubException($"Độ khó phải từ 1 đến {max}");
    }
}
