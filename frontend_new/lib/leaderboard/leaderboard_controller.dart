import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/models.dart';

/// Trạng thái màn Xếp hạng: bộ lọc hiện tại, danh sách top, hạng của mình và
/// thời gian còn lại của mùa. Nhớ kết quả theo từng bộ lọc để đổi qua lại không
/// phải tải lại (kéo xuống để làm mới). Các request gọi TUẦN TỰ.
class LeaderboardController extends ChangeNotifier {
  LeaderboardController({required ApiClient api, required bool Function() isLoggedIn})
      : _api = api,
        _isLoggedIn = isLoggedIn;

  final ApiClient _api;
  final bool Function() _isLoggedIn;

  LeaderboardQuery _query = const LeaderboardQuery(gameCode: 'SUDOKU');
  List<LeaderboardEntry> _entries = const [];
  MyRank? _myRank;
  SeasonInfo? _season;
  bool _loading = false;
  String? _error;
  bool _disposed = false;
  int _requestId = 0;
  final Map<String, (List<LeaderboardEntry>, MyRank?)> _cache = {};

  LeaderboardQuery get query => _query;
  List<LeaderboardEntry> get entries => _entries;
  MyRank? get myRank => _myRank;
  SeasonInfo? get season => _season;
  bool get loading => _loading;
  String? get error => _error;

  /// Bảng bạn bè cần đăng nhập.
  bool get needsLogin => _query.friendsOnly && !_isLoggedIn();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Đổi bộ lọc: hiện ngay kết quả đã nhớ (nếu có) rồi tải nếu chưa có.
  Future<void> setQuery(LeaderboardQuery q) async {
    _query = q;
    _requestId++; // bỏ kết quả của lần tải đang dở (bộ lọc cũ)
    _loading = false;
    final cached = _cache[q.key];
    _entries = cached?.$1 ?? const [];
    _myRank = cached?.$2;
    _error = null;
    _notify();
    if (cached == null) await load();
  }

  /// Tải bảng hiện tại ([force] = bỏ qua kết quả đã nhớ, dùng khi kéo làm mới).
  Future<void> load({bool force = false}) async {
    final q = _query;
    if (needsLogin) {
      _entries = const [];
      _myRank = null;
      _loading = false;
      _notify();
      return;
    }
    if (!force && _cache.containsKey(q.key)) return;
    final id = ++_requestId;
    _loading = true;
    _error = null;
    _notify();
    try {
      final season = _season ?? await _api.season();
      final top = await _api.leaderboard(q);
      MyRank? me;
      if (_isLoggedIn()) {
        try {
          me = await _api.myRank(q);
        } on ApiException {
          // Không lấy được hạng của mình thì vẫn hiện bảng.
        }
      }
      if (_disposed || id != _requestId) return;
      _season = season;
      _cache[q.key] = (top, me);
      _entries = top;
      _myRank = me;
      _loading = false;
    } on ApiException catch (e) {
      if (_disposed || id != _requestId) return;
      _error = e.message;
      _loading = false;
    }
    _notify();
  }

  /// Đăng nhập / đăng xuất: hạng của mình và bảng bạn bè thay đổi.
  void clearCache() {
    _cache.clear();
    _myRank = null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
