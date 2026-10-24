import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/models.dart';
import 'leaderboard_repository.dart';

/// Lựa chọn hiện tại của màn Xếp hạng; được ghi nhớ giữa các lần mở app.
class BoardSelection {
  final String gameCode;
  final BoardType board;

  /// 1..3; null = Tất cả độ khó (chỉ có nghĩa với [BoardType.record]).
  final int? difficulty;
  final BoardScope scope;
  final BoardPeriod period;

  const BoardSelection({
    this.gameCode = 'RUBIK',
    this.board = BoardType.record,
    this.difficulty,
    this.scope = BoardScope.global,
    this.period = BoardPeriod.season,
  });

  BoardSelection copyWith({
    String? gameCode,
    BoardType? board,
    Object? difficulty = _keep,
    BoardScope? scope,
    BoardPeriod? period,
  }) =>
      BoardSelection(
        gameCode: gameCode ?? this.gameCode,
        board: board ?? this.board,
        difficulty: identical(difficulty, _keep)
            ? this.difficulty
            : difficulty as int?,
        scope: scope ?? this.scope,
        period: period ?? this.period,
      );

  static const Object _keep = Object();

  BoardQuery get query => BoardQuery(
        gameCode: gameCode,
        board: board,
        difficulty: board == BoardType.record ? difficulty : null,
        scope: scope,
        period: period,
      );

  static const _kGame = 'lb_game';
  static const _kBoard = 'lb_board';
  static const _kDiff = 'lb_difficulty';
  static const _kScope = 'lb_scope';
  static const _kPeriod = 'lb_period';

  static Future<BoardSelection> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      int idx(String k, int max) {
        final v = p.getInt(k) ?? 0;
        return v >= 0 && v < max ? v : 0;
      }

      final d = p.getInt(_kDiff) ?? 0;
      return BoardSelection(
        gameCode: p.getString(_kGame) ?? 'RUBIK',
        board: p.containsKey(_kBoard)
            ? BoardType.values[idx(_kBoard, BoardType.values.length)]
            : BoardType.record,
        difficulty: d >= 1 && d <= 3 ? d : null,
        scope: BoardScope.values[idx(_kScope, BoardScope.values.length)],
        period: BoardPeriod.values[idx(_kPeriod, BoardPeriod.values.length)],
      );
    } catch (_) {
      return const BoardSelection();
    }
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kGame, gameCode);
      await p.setInt(_kBoard, board.index);
      await p.setInt(_kDiff, difficulty ?? 0);
      await p.setInt(_kScope, scope.index);
      await p.setInt(_kPeriod, period.index);
    } catch (_) {}
  }
}

/// Trạng thái màn Xếp hạng: lựa chọn + dữ liệu + tải (có chống kết quả cũ về muộn).
class LeaderboardController extends ChangeNotifier {
  LeaderboardController({
    required this.repository,
    BoardSelection selection = const BoardSelection(),
    DateTime Function()? clock,
  })  : _selection = selection,
        _clock = clock ?? DateTime.now;

  final LeaderboardRepository repository;
  final DateTime Function() _clock;

  BoardSelection _selection;
  LeaderboardData? _data;
  SeasonInfo? _season;
  String? _error;
  bool _loading = false;
  int? _userId;
  int _requestId = 0;
  bool _disposed = false;
  bool _started = false;

  BoardSelection get selection => _selection;
  LeaderboardData? get data => _data;
  SeasonInfo? get season => _season;
  String? get error => _error;
  bool get loading => _loading;
  int? get userId => _userId;
  bool get loggedIn => _userId != null;

  /// Khách chọn "Bạn bè": không có dữ liệu, cần đăng nhập.
  bool get needsLogin => _selection.scope == BoardScope.friends && !loggedIn;

  /// Thời gian còn lại của mùa (null nếu chưa biết).
  Duration? get seasonRemaining => _season?.remaining(_clock());

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Khôi phục lựa chọn đã lưu rồi tải.
  Future<void> restore() async {
    _selection = await BoardSelection.load();
    await reload();
  }

  /// Đặt người dùng hiện tại; tải lại nếu đổi (đăng nhập / đăng xuất).
  void setUser(int? userId) {
    if (userId == _userId) return;
    _userId = userId;
    repository.clear();
    _season = null;
    if (_started) reload();
  }

  void select(BoardSelection s) {
    if (s.gameCode == _selection.gameCode &&
        s.board == _selection.board &&
        s.difficulty == _selection.difficulty &&
        s.scope == _selection.scope &&
        s.period == _selection.period) {
      return;
    }
    _selection = s;
    s.save();
    if (_started) reload();
  }

  Future<void> reload({bool force = false}) async {
    _started = true;
    final id = ++_requestId;
    final sel = _selection;
    if (needsLogin) {
      _data = null;
      _error = null;
      _loading = false;
      _notify();
      return;
    }
    final q = sel.query;
    final hit = force ? null : repository.cached(q, _userId);
    if (hit != null) {
      _data = hit;
      _error = null;
      _loading = false;
      _notify();
    } else {
      _loading = true;
      _error = null;
      if (!force) _data = null;
      _notify();
      try {
        final d = await repository.load(q, userId: _userId, force: force);
        if (_disposed || id != _requestId) return;
        _data = d;
        _loading = false;
      } on ApiException catch (e) {
        if (_disposed || id != _requestId) return;
        _error = e.message;
        _loading = false;
      }
      _notify();
    }
    if (sel.period == BoardPeriod.season && _season == null) {
      final s = await repository.season(force: force);
      if (_disposed) return;
      if (s != null) {
        _season = s;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
