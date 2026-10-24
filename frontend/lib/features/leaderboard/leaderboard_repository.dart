import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/models.dart';

class LeaderboardData {
  final List<BoardEntry> entries;

  /// null khi khách hoặc không tải được.
  final BoardMe? me;
  final DateTime fetchedAt;

  const LeaderboardData({
    required this.entries,
    required this.me,
    required this.fetchedAt,
  });
}

/// Tải bảng xếp hạng, lưu tạm trong bộ nhớ 60 giây theo (tham số bảng, người dùng).
/// Các request (top rồi /me) gọi TUẦN TỰ, không song song.
class LeaderboardRepository {
  LeaderboardRepository(
    this._api, {
    this.ttl = const Duration(seconds: 60),
    this.seasonTtl = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ApiClient _api;
  final Duration ttl;
  final Duration seasonTtl;
  final DateTime Function() _clock;
  final Map<String, LeaderboardData> _cache = {};
  SeasonInfo? _season;
  DateTime? _seasonAt;

  /// Dữ liệu còn hạn trong cache (hoặc null).
  LeaderboardData? cached(BoardQuery q, int? userId) {
    final d = _cache[q.cacheKey(userId)];
    if (d == null) return null;
    return _clock().difference(d.fetchedAt) < ttl ? d : null;
  }

  Future<LeaderboardData> load(
    BoardQuery q, {
    int? userId,
    bool force = false,
  }) async {
    if (!force) {
      final hit = cached(q, userId);
      if (hit != null) return hit;
    }
    final entries = await _api.leaderboard(q);
    BoardMe? me;
    var meOk = true;
    if (userId != null) {
      try {
        me = await _api.myRank(q);
      } on ApiException {
        meOk = false;
      }
    }
    final data = LeaderboardData(entries: entries, me: me, fetchedAt: _clock());
    if (meOk) _cache[q.cacheKey(userId)] = data;
    return data;
  }

  /// Mốc mùa hiện tại (cache 5 phút). Trả về null nếu không tải được.
  Future<SeasonInfo?> season({bool force = false}) async {
    final at = _seasonAt;
    if (!force && _season != null && at != null &&
        _clock().difference(at) < seasonTtl) {
      return _season;
    }
    try {
      _season = await _api.season();
      _seasonAt = _clock();
    } on ApiException {
      // Giữ mốc cũ nếu có.
    }
    return _season;
  }

  void clear() {
    _cache.clear();
    _season = null;
    _seasonAt = null;
  }
}
