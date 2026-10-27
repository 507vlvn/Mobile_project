import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/models.dart';

/// Số liệu màn Hồ sơ: rating (GET /ratings/me), hồ sơ công khai của mình
/// (GET /users/{me}/profile, lấy kỷ lục) và lịch sử trận (GET /matches, phân trang).
/// Các request gọi TUẦN TỰ.
class ProfileController extends ChangeNotifier {
  ProfileController({required ApiClient api, required this.myId}) : _api = api;

  final ApiClient _api;
  final int myId;

  List<GameStats> _ratings = const [];
  List<GameStats> _profileStats = const [];
  final List<MatchHistoryItem> _matches = [];
  int _page = 0;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  bool _disposed = false;

  List<MatchHistoryItem> get matches => List.unmodifiable(_matches);
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  String? get error => _error;
  bool get hasMoreMatches => _matches.length < _total;

  /// Tổng số trận phía server (có thể lớn hơn số đã tải).
  int get totalMatches => _total;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static GameStats? _find(List<GameStats> list, String gameCode) {
    for (final s in list) {
      if (s.gameCode == gameCode) return s;
    }
    return null;
  }

  /// Thống kê một game: ưu tiên `/ratings/me`, bổ sung kỷ lục từ hồ sơ.
  GameStats statsFor(String gameCode) {
    final r = _find(_ratings, gameCode);
    final p = _find(_profileStats, gameCode);
    final base = r ?? p ?? GameStats(gameCode: gameCode);
    final best = r?.bestScore ?? p?.bestScore;
    return best == base.bestScore ? base : base.withBestScore(best);
  }

  /// Game có rating cao nhất trong số đã đấu xếp hạng (null nếu chưa đấu).
  GameStats? get best {
    GameStats? b;
    for (final code in const ['RUBIK', 'SUDOKU', 'PUZZLE', 'CARO']) {
      final s = statsFor(code);
      if (s.games == 0) continue;
      if (b == null || s.rating > b.rating) b = s;
    }
    return b;
  }

  Future<void> load() async {
    _loading = _matches.isEmpty && _ratings.isEmpty;
    _error = null;
    _notify();
    try {
      _ratings = await _api.myRatings();
      try {
        _profileStats = (await _api.userProfile(myId)).stats;
      } on ApiException {
        // Hồ sơ chỉ bổ sung kỷ lục: bỏ qua nếu lỗi.
      }
      final page = await _api.matches(page: 1);
      _matches
        ..clear()
        ..addAll(page.items);
      _page = 1;
      _total = page.total;
      _loading = false;
    } on ApiException catch (e) {
      _error = e.message;
      _loading = false;
    }
    _notify();
  }

  Future<void> loadMore() async {
    if (_loadingMore || !hasMoreMatches) return;
    _loadingMore = true;
    _notify();
    try {
      final page = await _api.matches(page: _page + 1);
      final known = _matches.map((m) => m.matchId).toSet();
      _matches.addAll(page.items.where((m) => !known.contains(m.matchId)));
      _page++;
      _total = page.total;
      if (page.items.isEmpty) _total = _matches.length; // chặn lặp vô hạn
    } on ApiException {
      // Giữ danh sách; người dùng bấm lại.
    }
    _loadingMore = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
