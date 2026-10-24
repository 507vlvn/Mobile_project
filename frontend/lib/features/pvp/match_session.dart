import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/realtime/realtime_service.dart';

/// Tin nhắn nhanh trong trận (chỉ các câu dựng sẵn, không gõ tự do).
const Map<String, String> kQuickChats = {
  'hello': 'Chào bạn!',
  'nice': 'Hay lắm!',
  'gg': 'Ván hay!',
  'oops': 'Ối, nhầm rồi!',
  'thanks': 'Cảm ơn!',
  'rematch': 'Chơi lại nhé?',
};

/// Trạng thái kết thúc trận nhìn từ phía người chơi hiện tại.
enum MatchOutcome { win, lose, draw }

/// Điều phối một trận đấu trực tiếp: nhận sự kiện realtime của đúng trận này,
/// giữ trạng thái mới nhất, đếm ngược đồng hồ và gửi hành động lên server.
///
/// Màn hình chỉ cần lắng nghe [MatchSession] (ChangeNotifier) — không đụng
/// trực tiếp tới SignalR.
class MatchSession extends ChangeNotifier {
  MatchSession({
    required RealtimeService realtime,
    required MatchInfo initial,
    DateTime Function()? clock,
  })  : _rt = realtime,
        _info = initial,
        _clock = clock ?? DateTime.now {
    _subs.addAll([
      _rt.matchState.where(_mine).listen(_onState),
      _rt.matchStarted.listen(_onStarted),
      _rt.opponentProgress.where((e) => e.matchId == matchId).listen(_onProgress),
      _rt.quickChats.where((e) => e.matchId == matchId).listen(_onQuickChat),
      _rt.opponentConnection
          .where((e) => e.matchId == null || e.matchId == matchId)
          .listen(_onConnection),
      _rt.drawOffered.where((e) => e.matchId == matchId).listen(_onDrawOffered),
      _rt.drawResponded.where((e) => e.matchId == matchId).listen(_onDrawResponded),
      _rt.rematchRequested.where((e) => e.matchId == matchId).listen(_onRematchRequested),
      _rt.matchEnded.where((e) => e.matchId == matchId).listen(_onEnded),
      _rt.reconnected.listen((_) => _rejoin()),
    ]);
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  final RealtimeService _rt;
  final DateTime Function() _clock;
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _ticker;

  MatchInfo _info;
  MatchInfo get info => _info;
  String get matchId => _info.matchId;
  int? get myId => _info.youId;
  RtUser? get me => _info.you;
  RtUser? get opponent => _info.opponent;

  bool _mine(MatchInfo m) => m.matchId == matchId;

  // ---------------------------------------------------------------- Caro
  bool get isMyTurn =>
      !isEnded && _info.caro?.currentTurnUserId != null && _info.caro!.currentTurnUserId == myId;

  /// Thời gian còn lại của lượt hiện tại (null nếu không áp dụng).
  Duration? get turnRemaining {
    final d = _info.caro?.turnDeadline;
    if (d == null || isEnded) return null;
    final left = d.difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  bool _moveInFlight = false;
  bool get moveInFlight => _moveInFlight;

  // ---------------------------------------------------------------- Race
  double _myProgress = 0;
  double get myProgress => _myProgress;

  double get opponentProgress {
    final oid = opponent?.userId;
    if (oid == null) return 0;
    return _oppProgress ?? _info.race?.progress[oid] ?? 0;
  }

  double? _oppProgress;
  bool _opponentFinished = false;
  bool get opponentFinished => _opponentFinished;

  /// Thời gian còn lại của trận đua (giới hạn 15 phút).
  Duration? get raceRemaining {
    final d = _info.race?.deadline;
    if (d == null || isEnded) return null;
    final left = d.difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  DateTime? _lastProgressSent;
  int _lastPercentSent = -1;
  Timer? _progressFlush;
  int? _pendingPercent;

  // ---------------------------------------------------------------- Kết nối
  bool _opponentConnected = true;
  bool get opponentConnected => _opponentConnected;
  DateTime? _graceUntil;
  Duration? get opponentGraceRemaining {
    if (_opponentConnected || _graceUntil == null) return null;
    final left = _graceUntil!.difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  bool get iAmConnected => _rt.isConnected;

  // ---------------------------------------------------------------- Hòa / tái đấu / chat
  int? _drawOfferedBy;
  bool get opponentOffersDraw => _drawOfferedBy != null && _drawOfferedBy != myId;
  bool get iOfferedDraw => _drawOfferedBy != null && _drawOfferedBy == myId;

  bool _iRequestedRematch = false;
  bool get iRequestedRematch => _iRequestedRematch;
  bool _opponentRequestedRematch = false;
  bool get opponentRequestedRematch => _opponentRequestedRematch;

  /// Trận mới sau khi cả hai đồng ý tái đấu — màn hình sẽ chuyển sang trận này.
  final _rematchStarted = StreamController<MatchInfo>.broadcast();
  Stream<MatchInfo> get rematchStarted => _rematchStarted.stream;

  ({String text, bool fromMe, DateTime at})? _lastChat;
  ({String text, bool fromMe, DateTime at})? get lastChat {
    final c = _lastChat;
    if (c == null) return null;
    return _clock().difference(c.at) < const Duration(seconds: 4) ? c : null;
  }

  DateTime? _lastChatSent;

  // ---------------------------------------------------------------- Kết thúc
  MatchEndedEvent? _ended;
  MatchEndedEvent? get ended => _ended;
  bool get isEnded => _ended != null;

  MatchOutcome? get outcome {
    final e = _ended;
    if (e == null) return null;
    if (e.winnerId == null) return MatchOutcome.draw;
    return e.winnerId == myId ? MatchOutcome.win : MatchOutcome.lose;
  }

  RatingChange? get myRatingChange => myId == null ? null : _ended?.ratingChanges[myId];

  // ---------------------------------------------------------------- Lỗi
  final _errors = StreamController<String>.broadcast();
  Stream<String> get errors => _errors.stream;

  // =================================================================
  // Xử lý sự kiện
  // =================================================================

  void _onState(MatchInfo m) {
    _info = m;
    _moveInFlight = false;
    final c = m.caro;
    if (c != null) _drawOfferedBy = c.drawOfferedBy;
    final oid = opponent?.userId;
    if (oid != null && m.race != null) _oppProgress = m.race!.progress[oid];
    notifyListeners();
  }

  void _onStarted(MatchInfo m) {
    if (m.matchId == matchId) {
      _onState(m);
      return;
    }
    // Trận mới với cùng đối thủ sau khi đã kết thúc trận này → tái đấu
    final oid = opponent?.userId;
    if (isEnded && oid != null && m.players.any((p) => p.userId == oid)) {
      _rematchStarted.add(m);
    }
  }

  void _onProgress(OpponentProgressEvent e) {
    _oppProgress = e.percent;
    if (e.percent >= 100) _opponentFinished = true;
    notifyListeners();
  }

  void _onQuickChat(QuickChatEvent e) {
    _lastChat = (
      text: kQuickChats[e.code] ?? e.code,
      fromMe: e.fromUserId == myId,
      at: _clock(),
    );
    notifyListeners();
  }

  void _onConnection(OpponentConnectionEvent e) {
    _opponentConnected = e.connected;
    _graceUntil = e.connected ? null : _clock().add(Duration(seconds: e.graceSec));
    notifyListeners();
  }

  void _onDrawOffered(DrawOfferedEvent e) {
    _drawOfferedBy = e.fromUserId;
    notifyListeners();
  }

  void _onDrawResponded(DrawRespondedEvent e) {
    _drawOfferedBy = null;
    if (!e.accepted && e.byUserId != myId) {
      _errors.add('Đối thủ đã từ chối hòa');
    }
    notifyListeners();
  }

  void _onRematchRequested(RematchRequestedEvent e) {
    if (e.fromUserId == myId) {
      _iRequestedRematch = true;
    } else {
      _opponentRequestedRematch = true;
    }
    notifyListeners();
  }

  void _onEnded(MatchEndedEvent e) {
    _ended = e;
    _drawOfferedBy = null;
    _progressFlush?.cancel();
    notifyListeners();
  }

  void _tick() {
    // Chỉ cần vẽ lại khi có đồng hồ đang chạy
    if (isEnded) return;
    if (turnRemaining != null || raceRemaining != null || opponentGraceRemaining != null ||
        _lastChat != null) {
      notifyListeners();
    }
  }

  Future<void> _rejoin() async {
    if (isEnded) return;
    await _guard(() => _rt.rejoin(matchId));
  }

  // =================================================================
  // Hành động
  // =================================================================

  Future<bool> _guard(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (e) {
      _errors.add(_message(e));
      return false;
    }
  }

  static String _message(Object e) {
    final s = e.toString();
    final i = s.lastIndexOf('HubException: ');
    if (i >= 0) return s.substring(i + 'HubException: '.length).trim();
    return s.replaceFirst('Exception: ', '');
  }

  /// Đánh Caro tại (row, col). Trả về false nếu bị từ chối.
  Future<bool> caroMove(int row, int col) async {
    if (!isMyTurn || _moveInFlight) return false;
    _moveInFlight = true;
    notifyListeners();
    final ok = await _guard(() => _rt.caroMove(matchId, row, col));
    if (!ok) {
      _moveInFlight = false;
      notifyListeners();
    }
    return ok;
  }

  /// Báo tiến độ trò đua (0–100). Tự gộp để không gửi quá 4 lần/giây.
  void reportProgress(double percent) {
    if (isEnded) return;
    final p = percent.clamp(0, 100).round();
    if (p <= _lastPercentSent) return;
    _myProgress = p.toDouble();
    notifyListeners();
    final now = _clock();
    final last = _lastProgressSent;
    if (last == null || now.difference(last) >= const Duration(milliseconds: 260)) {
      _sendProgress(p);
    } else {
      _pendingPercent = p;
      _progressFlush ??= Timer(const Duration(milliseconds: 300), () {
        _progressFlush = null;
        final pending = _pendingPercent;
        _pendingPercent = null;
        if (pending != null && pending > _lastPercentSent) _sendProgress(pending);
      });
    }
  }

  void _sendProgress(int p) {
    _lastPercentSent = p;
    _lastProgressSent = _clock();
    _guard(() => _rt.raceProgress(matchId, p));
  }

  /// Báo đã giải xong trò đua.
  Future<bool> finishRace({required Duration time, required int mistakes}) async {
    if (isEnded) return false;
    // Đảm bảo server đã nhận tiến độ 100% trước khi về đích
    if (_lastPercentSent < 100) _sendProgress(100);
    _myProgress = 100;
    notifyListeners();
    return _guard(() => _rt.raceFinish(matchId, time.inMilliseconds, mistakes));
  }

  Future<bool> resign() => _guard(() => _rt.resign(matchId));

  Future<bool> offerDraw() async {
    final ok = await _guard(() => _rt.offerDraw(matchId));
    if (ok) {
      _drawOfferedBy = myId;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> respondDraw(bool accept) async {
    final ok = await _guard(() => _rt.respondDraw(matchId, accept));
    if (ok) {
      _drawOfferedBy = null;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> requestRematch() async {
    final ok = await _guard(() => _rt.rematch(matchId));
    if (ok) {
      _iRequestedRematch = true;
      notifyListeners();
    }
    return ok;
  }

  /// Gửi tin nhắn nhanh (tối đa 1 tin / 2 giây).
  Future<void> sendQuickChat(String code) async {
    final now = _clock();
    if (_lastChatSent != null && now.difference(_lastChatSent!) < const Duration(seconds: 2)) {
      return;
    }
    _lastChatSent = now;
    _lastChat = (text: kQuickChats[code] ?? code, fromMe: true, at: now);
    notifyListeners();
    await _guard(() => _rt.quickChat(matchId, code));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _progressFlush?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _rematchStarted.close();
    _errors.close();
    super.dispose();
  }
}
