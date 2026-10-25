import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/network/models.dart';
import '../core/realtime/realtime_service.dart';

/// Giai đoạn của người chơi trong phần Đối kháng.
enum PvpPhase { idle, queued, inviting, active, ended }

/// Lời mời mình đã gửi, đang chờ bạn trả lời.
class OutgoingInvite {
  final String inviteId;
  final UserSummary friend;
  final String gameCode;
  final int difficulty;
  final DateTime expiresAt;
  const OutgoingInvite(this.inviteId, this.friend, this.gameCode, this.difficulty, this.expiresAt);
}

/// Trạng thái Đối kháng cho cả app (một instance, Provider trong main.dart).
///
/// Server là nguồn chuẩn: mọi thay đổi bàn cờ / tiến độ / kết quả đều đến từ sự
/// kiện hub (`MatchStarted`, `MatchState`, `MatchEnded`...). Lớp này chỉ gửi lệnh,
/// gom sự kiện thành trạng thái dễ hiển thị và tự `Rejoin` khi kết nối lại
/// (server không tự gửi lại trận sau khi mất kết nối).
class MatchSession extends ChangeNotifier {
  MatchSession({required RealtimeService realtime, DateTime Function()? now})
      : _rt = realtime,
        _now = now ?? DateTime.now {
    _subs.addAll([
      _rt.queueStatus.listen(_onQueue),
      _rt.invitesReceived.listen(_onInviteReceived),
      _rt.inviteResults.listen(_onInviteResult),
      _rt.matchStarted.listen(_onMatchStarted),
      _rt.matchState.listen(_onMatchState),
      _rt.opponentProgress.listen(_onOpponentProgress),
      _rt.opponentConnection.listen(_onOpponentConnection),
      _rt.drawOffered.listen(_onDrawOffered),
      _rt.drawResponded.listen(_onDrawResponded),
      _rt.rematchRequested.listen(_onRematchRequested),
      _rt.quickChats.listen(_onQuickChat),
      _rt.matchEnded.listen(_onMatchEnded),
      _rt.reconnected.listen((_) => unawaited(_onReconnected())),
    ]);
  }

  /// Thời gian một nước Caro / hạn lời mời (MatchService.TurnSeconds / InviteSeconds).
  static const turnSeconds = 30;
  static const inviteSeconds = 30;

  /// Server bỏ qua cập nhật tiến độ nhanh hơn 4 lần/giây; chừa dư một chút.
  static const progressGap = Duration(milliseconds: 280);

  /// Số lần xin hòa tối đa mỗi trận (MatchService.MaxDrawOffers).
  static const maxDrawOffers = 3;

  final RealtimeService _rt;
  final DateTime Function() _now;
  final List<StreamSubscription<Object?>> _subs = [];
  final _starts = StreamController<MatchInfo>.broadcast();
  final _notices = StreamController<String>.broadcast();
  bool _disposed = false;

  RealtimeService get realtime => _rt;
  bool get connected => _rt.isConnected;

  /// Phát khi một trận bắt đầu (kể cả tái đấu) — lớp giao diện mở màn trận.
  Stream<MatchInfo> get starts => _starts.stream;

  /// Thông báo ngắn để hiện SnackBar (từ chối, hết hạn, lỗi...).
  Stream<String> get notices => _notices.stream;

  // ---------------------------------------------------------- trạng thái

  PvpPhase _phase = PvpPhase.idle;
  PvpPhase get phase => _phase;

  String? _queueGame;
  int _queueDifficulty = 1;
  DateTime? _queueSince;
  int _queueRange = 0;
  String? get queueGame => _queueGame;
  int get queueDifficulty => _queueDifficulty;
  DateTime? get queueSince => _queueSince;

  /// Khoảng chênh lệch rating đang được ghép (0 = không giới hạn).
  int get queueRatingRange => _queueRange;

  OutgoingInvite? _outgoing;
  OutgoingInvite? get outgoingInvite => _outgoing;

  final List<InviteReceivedEvent> _incoming = [];
  List<InviteReceivedEvent> get incomingInvites => List.unmodifiable(_incoming);

  MatchInfo? _match;
  MatchInfo? get match => _match;
  MatchEndedEvent? _ended;
  MatchEndedEvent? get ended => _ended;

  /// Người đi nước đầu (cầm quân X) của trận Caro hiện tại.
  int? _firstMover;
  int? get firstMoverId => _firstMover;

  DateTime? _turnDeadline;

  /// Hạn nước đi hiện tại theo đồng hồ máy (đã chặn trong 0..30 giây để
  /// không lệch khi giờ máy khác giờ server).
  DateTime? get turnDeadline => _turnDeadline;

  DateTime? _matchStartedAt;

  /// Lúc nhận `MatchStarted` theo đồng hồ máy (gần đúng lúc server bắt đầu trận).
  DateTime? get matchStartedAt => _matchStartedAt;

  bool _opponentConnected = true;
  DateTime? _opponentGraceUntil;
  bool get opponentConnected => _opponentConnected;
  DateTime? get opponentGraceUntil => _opponentGraceUntil;

  bool _opponentDrawOffer = false;
  bool _myDrawPending = false;
  int _drawOffersUsed = 0;
  bool get opponentOfferedDraw => _opponentDrawOffer;
  bool get myDrawPending => _myDrawPending;
  int get drawOffersLeft => maxDrawOffers - _drawOffersUsed;

  bool _rematchByOpponent = false;
  bool _rematchSent = false;
  bool get rematchRequestedByOpponent => _rematchByOpponent;
  bool get rematchSent => _rematchSent;

  final Map<int, (String, DateTime)> _chats = {};

  /// Tin chat nhanh gần nhất của [userId] (mã + lúc nhận), nếu có.
  (String, DateTime)? chatOf(int userId) => _chats[userId];

  int _opponentProgress = 0;
  int get opponentProgress => _opponentProgress;

  bool _busy = false;

  /// Đang chờ server xử lý một lệnh (vd nước đi vừa gửi).
  bool get busy => _busy;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _notice(String m) {
    if (!_disposed) _notices.add(m);
  }

  /// Gửi lệnh; lỗi hub hiện thành thông báo. Trả về true nếu thành công.
  Future<bool> _run(Future<void> Function() call, {bool markBusy = false}) async {
    if (markBusy) {
      _busy = true;
      _notify();
    }
    try {
      await call();
      return true;
    } on RealtimeException catch (e) {
      _notice(e.message);
      return false;
    } finally {
      if (markBusy) {
        _busy = false;
        _notify();
      }
    }
  }

  // ---------------------------------------------------------- hàng chờ

  /// Tìm trận xếp hạng (ghép theo rating, tính Elo).
  Future<bool> findMatch(String gameCode, int difficulty) async {
    if (_phase == PvpPhase.active) return false;
    _queueGame = gameCode;
    _queueDifficulty = difficulty;
    final ok = await _run(() => _rt.queueJoin(gameCode, difficulty));
    if (ok && _phase != PvpPhase.active) {
      _phase = PvpPhase.queued;
      _queueSince = _now();
      _ended = null;
      _notify();
    }
    return ok;
  }

  Future<void> cancelQueue() async {
    if (_phase != PvpPhase.queued) return;
    _phase = PvpPhase.idle;
    _queueSince = null;
    _notify();
    await _run(_rt.queueLeave);
  }

  void _onQueue(QueueStatusEvent e) {
    if (e.inQueue) {
      if (_phase == PvpPhase.active) return;
      _phase = PvpPhase.queued;
      _queueSince ??= _now().subtract(Duration(seconds: e.waitedSec));
      _queueRange = e.ratingRange;
    } else if (_phase == PvpPhase.queued) {
      _phase = PvpPhase.idle; // MatchStarted (nếu ghép được) đến ngay sau
      _queueSince = null;
    }
    _notify();
  }

  // ---------------------------------------------------------- lời mời

  /// Mời bạn đấu giao hữu (không tính rating). Lời mời hết hạn sau 30 giây.
  Future<bool> invite(UserSummary friend, String gameCode, int difficulty) async {
    if (_phase == PvpPhase.active || _phase == PvpPhase.queued) {
      _notice(_phase == PvpPhase.queued
          ? 'Bạn đang tìm trận, hãy hủy tìm trước'
          : 'Bạn đang trong một trận đấu');
      return false;
    }
    String? id;
    final ok = await _run(() async => id = await _rt.invite(friend.userId, gameCode, difficulty));
    if (ok) {
      _outgoing = OutgoingInvite(id ?? '', friend, gameCode, difficulty,
          _now().add(const Duration(seconds: inviteSeconds)));
      _phase = PvpPhase.inviting;
      _ended = null;
      _notify();
    }
    return ok;
  }

  /// Ẩn lời mời đang chờ (server không có lệnh hủy; lời mời tự hết hạn sau 30 giây).
  void dismissOutgoing() {
    if (_phase != PvpPhase.inviting) return;
    _phase = PvpPhase.idle;
    _notify();
  }

  Future<bool> respondInvite(InviteReceivedEvent inv, bool accept) async {
    _incoming.removeWhere((i) => i.inviteId == inv.inviteId);
    _notify();
    return _run(() => _rt.respondInvite(inv.inviteId, accept));
  }

  void _onInviteReceived(InviteReceivedEvent e) {
    if (_incoming.any((i) => i.inviteId == e.inviteId)) return;
    _incoming.add(e);
    _notify();
  }

  void _onInviteResult(InviteResultEvent e) {
    final before = _incoming.length;
    _incoming.removeWhere((i) => i.inviteId == e.inviteId);
    final out = _outgoing;
    if (out != null && out.inviteId == e.inviteId) {
      if (e.status != InviteStatus.accepted) {
        _outgoing = null;
        if (_phase == PvpPhase.inviting) _phase = PvpPhase.idle;
        _notice(e.status == InviteStatus.declined
            ? '${out.friend.displayName} đã từ chối lời mời'
            : 'Lời mời đã hết hạn');
      }
      _notify();
    } else if (_incoming.length != before) {
      _notify();
    }
  }

  // ---------------------------------------------------------- trận đấu

  void _onMatchStarted(MatchInfo m) {
    _match = m;
    _ended = null;
    _phase = PvpPhase.active;
    _queueSince = null;
    _outgoing = null;
    _incoming.clear();
    _matchStartedAt = _now();
    _firstMover = _firstMoverOf(m);
    _opponentConnected = true;
    _opponentGraceUntil = null;
    _opponentDrawOffer = false;
    _myDrawPending = false;
    _drawOffersUsed = 0;
    _rematchByOpponent = false;
    _rematchSent = false;
    _chats.clear();
    _opponentProgress = m.race?.progress[m.opponent?.userId] ?? 0;
    _bestProgress = 0;
    _sentProgress = 0;
    _lastProgressAt = null;
    _progressTimer?.cancel();
    _applyCaro(m);
    _notify();
    _starts.add(m);
  }

  void _onMatchState(MatchInfo m) {
    final cur = _match;
    if (cur == null || cur.matchId != m.matchId) return;
    _match = m;
    _firstMover ??= _firstMoverOf(m);
    _applyCaro(m);
    final opp = m.opponent?.userId;
    final p = m.race?.progress[opp];
    if (p != null && p > _opponentProgress) _opponentProgress = p;
    _notify();
  }

  int? _firstMoverOf(MatchInfo m) {
    final c = m.caro;
    if (c == null) return null;
    if (c.moves.isNotEmpty) return c.moves.first.userId;
    return c.currentTurnUserId;
  }

  void _applyCaro(MatchInfo m) {
    final c = m.caro;
    if (c == null) return;
    final d = c.turnDeadline;
    if (d == null || !m.active) {
      _turnDeadline = null;
    } else {
      var left = d.difference(_now());
      if (left.isNegative) left = Duration.zero;
      if (left > const Duration(seconds: turnSeconds)) left = const Duration(seconds: turnSeconds);
      _turnDeadline = _now().add(left);
    }
    final opp = m.opponent?.userId;
    _opponentDrawOffer = c.drawOfferedBy != null && c.drawOfferedBy == opp;
    if (c.drawOfferedBy == null) _myDrawPending = false;
  }

  void _onOpponentProgress(OpponentProgressEvent e) {
    if (_match?.matchId != e.matchId) return;
    if (e.percent > _opponentProgress) {
      _opponentProgress = e.percent;
      _notify();
    }
  }

  void _onOpponentConnection(OpponentConnectionEvent e) {
    if (_phase != PvpPhase.active) return;
    _opponentConnected = e.connected;
    _opponentGraceUntil = e.connected ? null : _now().add(Duration(seconds: e.graceSeconds));
    _notify();
  }

  void _onDrawOffered(MatchSignalEvent e) {
    if (_match?.matchId != e.matchId) return;
    _opponentDrawOffer = true;
    _notify();
  }

  void _onDrawResponded(DrawRespondedEvent e) {
    if (_match?.matchId != e.matchId) return;
    if (!e.accepted && _myDrawPending) {
      _myDrawPending = false;
      _notice('Đối thủ từ chối hòa');
      _notify();
    }
  }

  void _onRematchRequested(MatchSignalEvent e) {
    if (_ended?.matchId != e.matchId) return;
    _rematchByOpponent = true;
    _notify();
  }

  void _onQuickChat(MatchSignalEvent e) {
    if (_match?.matchId != e.matchId || e.code == null) return;
    _chats[e.fromUserId] = (e.code!, _now());
    _notify();
  }

  void _onMatchEnded(MatchEndedEvent e) {
    final cur = _match;
    if (cur != null && cur.matchId != e.matchId) return;
    _ended = e;
    _phase = PvpPhase.ended;
    _turnDeadline = null;
    _opponentDrawOffer = false;
    _myDrawPending = false;
    _progressTimer?.cancel();
    _notify();
  }

  Future<void> _onReconnected() async {
    switch (_phase) {
      case PvpPhase.active:
        final m = _match;
        if (m != null) await _run(() => _rt.rejoin(m.matchId));
      case PvpPhase.queued:
        // Server bỏ mình khỏi hàng chờ khi mất kết nối: vào lại với cùng lựa chọn.
        final g = _queueGame;
        if (g != null) await _run(() => _rt.queueJoin(g, _queueDifficulty));
      case PvpPhase.inviting:
        _phase = PvpPhase.idle;
        _outgoing = null;
        _notice('Mất kết nối nên lời mời đã bị hủy');
        _notify();
      case PvpPhase.idle:
      case PvpPhase.ended:
        break;
    }
  }

  // ---------------------------------------------------------- lệnh trong trận

  Future<bool> caroMove(int row, int col) async {
    final m = _match;
    if (m == null || _phase != PvpPhase.active || !m.isMyTurn || _busy) return false;
    return _run(() => _rt.caroMove(m.matchId, row, col), markBusy: true);
  }

  Future<bool> offerDraw() async {
    final m = _match;
    if (m == null || _phase != PvpPhase.active || _myDrawPending || drawOffersLeft <= 0) return false;
    final ok = await _run(() => _rt.offerDraw(m.matchId));
    if (ok) {
      _myDrawPending = true;
      _drawOffersUsed++;
      _notify();
    }
    return ok;
  }

  Future<bool> respondDraw(bool accept) async {
    final m = _match;
    if (m == null || !_opponentDrawOffer) return false;
    _opponentDrawOffer = false;
    _notify();
    return _run(() => _rt.respondDraw(m.matchId, accept));
  }

  Future<bool> resign() async {
    final m = _match;
    if (m == null || _phase != PvpPhase.active) return false;
    return _run(() => _rt.resign(m.matchId));
  }

  Future<bool> quickChat(String code) async {
    final m = _match;
    final me = m?.you;
    if (m == null || me == null) return false;
    _chats[me] = (code, _now());
    _notify();
    return _run(() => _rt.quickChat(m.matchId, code));
  }

  /// Mời tái đấu (trong 30 giây sau khi trận kết thúc). Hai bên cùng mời thì
  /// server bắt đầu trận mới (đổi bên đi trước).
  Future<bool> rematch() async {
    final e = _ended;
    if (e == null || _rematchSent) return false;
    final ok = await _run(() => _rt.rematch(e.matchId));
    if (ok) {
      _rematchSent = true;
      _notify();
    }
    return ok;
  }

  /// Rời màn kết quả, về sảnh.
  void leaveResult() {
    if (_phase != PvpPhase.ended) return;
    _phase = PvpPhase.idle;
    _match = null;
    _ended = null;
    _notify();
  }

  // ---------------------------------------------------------- đua (RACE)

  int _bestProgress = 0;
  int _sentProgress = 0;
  DateTime? _lastProgressAt;
  Timer? _progressTimer;

  /// Báo tiến độ của mình (0..100). Chỉ gửi khi tăng và không quá 4 lần/giây
  /// (server bỏ qua lần gửi quá nhanh hoặc không tăng).
  void reportProgress(int percent) {
    final m = _match;
    if (m == null || _phase != PvpPhase.active || m.isTurn) return;
    final p = percent.clamp(0, 100);
    if (p <= _bestProgress) return;
    _bestProgress = p;
    _scheduleProgress();
  }

  void _scheduleProgress() {
    if (_progressTimer?.isActive ?? false) return;
    final last = _lastProgressAt;
    final wait = last == null ? Duration.zero : progressGap - _now().difference(last);
    if (wait <= Duration.zero) {
      unawaited(_sendProgress());
    } else {
      _progressTimer = Timer(wait, () => unawaited(_sendProgress()));
    }
  }

  Future<void> _sendProgress() async {
    final m = _match;
    if (m == null || _phase != PvpPhase.active || _bestProgress <= _sentProgress) return;
    final p = _bestProgress;
    _sentProgress = p;
    _lastProgressAt = _now();
    try {
      await _rt.raceProgress(m.matchId, p);
    } on RealtimeException {
      _sentProgress = 0; // gửi lại ở lần sau
    }
  }

  /// Xếp xong: gửi tiến độ 100% rồi nộp kết quả. Server cần đã nhận ≥ 90% và
  /// thời gian không nhỏ hơn mức tối thiểu ([minTimeMs]); nếu xong quá nhanh thì
  /// chờ cho đủ thời gian tối thiểu rồi mới nộp.
  Future<bool> finishRace({required int timeMs, int mistakes = 0, int minTimeMs = 0}) async {
    final m = _match;
    if (m == null || _phase != PvpPhase.active || m.isTurn) return false;
    _progressTimer?.cancel();
    _busy = true;
    _notify();
    try {
      final last = _lastProgressAt;
      if (last != null) {
        final wait = progressGap - _now().difference(last);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      _bestProgress = 100;
      _sentProgress = 100;
      _lastProgressAt = _now();
      await _rt.raceProgress(m.matchId, 100);
      var t = timeMs;
      if (t < minTimeMs) {
        await Future<void>.delayed(Duration(milliseconds: minTimeMs - t));
        t = minTimeMs;
      }
      await _rt.raceFinish(m.matchId, t, mistakes);
      return true;
    } on RealtimeException catch (e) {
      _notice(e.message);
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Đăng xuất: xóa mọi trạng thái.
  void reset() {
    _phase = PvpPhase.idle;
    _match = null;
    _ended = null;
    _outgoing = null;
    _incoming.clear();
    _queueSince = null;
    _progressTimer?.cancel();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _progressTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _starts.close();
    _notices.close();
    super.dispose();
  }
}

/// Thời gian tối thiểu hợp lệ của trận đua (RaceRules.MinTimeMs trong backend).
int raceMinTimeMs(String gameCode, int difficulty) {
  final d = difficulty.clamp(1, 3);
  return switch (gameCode) {
    'SUDOKU' => 30000,
    'PUZZLE' => const [5000, 20000, 40000][d - 1],
    'RUBIK' => 5000 * d,
    _ => 5000,
  };
}
