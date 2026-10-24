// Model REST của giai đoạn 2 (bạn bè, hồ sơ, bảng xếp hạng v2, trận đấu, rating),
// theo hợp đồng TASKS_V2 §3. Đọc JSON khoan dung vì backend làm song song:
// chấp nhận cả mảng trần lẫn object bọc ({"items":[...]}), tên trường thay thế
// và trường thiếu. Mọi chỗ điều chỉnh khi đối chiếu với backend đều ở file này.
import '../models/presence.dart';
import '../models/rank.dart';
import '../realtime/realtime_models.dart'
    show asDate, asInt, asMap, asString, pick;
import 'models.dart';

/// Rút danh sách từ phản hồi: mảng trần, hoặc object chứa mảng ở một trong [keys].
List<Map<String, dynamic>> extractList(Object? d,
    [List<String> keys = const ['items', 'data', 'results']]) {
  Object? list = d;
  if (d is Map) {
    list = null;
    for (final k in keys) {
      if (d[k] is List) {
        list = d[k];
        break;
      }
    }
  }
  if (list is! List) return const [];
  return [
    for (final e in list)
      if (e is Map) e.cast<String, dynamic>(),
  ];
}

String _displayName(String? fullName, String username) =>
    (fullName != null && fullName.trim().isNotEmpty)
        ? fullName.trim()
        : username;

// ------------------------------------------------------------ bạn bè

/// Một người bạn trong `GET /friends`:
/// `{userId, username, fullName?, avatarUrl?, status: online|in_match|offline, lastSeenAt?}`.
class FriendInfo {
  final int userId;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final PresenceStatus presence;
  final DateTime? lastSeenAt;

  const FriendInfo({
    required this.userId,
    required this.username,
    this.fullName,
    this.avatarUrl,
    this.presence = PresenceStatus.offline,
    this.lastSeenAt,
  });

  String get displayName => _displayName(fullName, username);

  UserSummary get summary => UserSummary(
      userId: userId,
      username: username,
      fullName: fullName,
      avatarUrl: avatarUrl);

  FriendInfo withPresence(PresenceStatus s, {DateTime? lastSeenAt}) =>
      FriendInfo(
        userId: userId,
        username: username,
        fullName: fullName,
        avatarUrl: avatarUrl,
        presence: s,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      );

  factory FriendInfo.fromJson(Map<String, dynamic> j) {
    final u = asMap(j['user']) ?? j;
    return FriendInfo(
      userId: asInt(pick(u, ['userId', 'id'])) ?? 0,
      username: asString(pick(u, ['username', 'userName'])) ?? '',
      fullName: asString(u['fullName']),
      avatarUrl: asString(u['avatarUrl']),
      presence: PresenceStatus.parse(pick(j, ['status', 'presence', 'state'])),
      lastSeenAt: asDate(pick(j, ['lastSeenAt', 'lastSeen'])),
    );
  }
}

/// Sắp xếp bạn bè: đang online -> đang trong trận -> offline (mới thấy gần nhất
/// trước); cùng nhóm thì theo tên.
List<FriendInfo> sortFriends(Iterable<FriendInfo> friends) {
  int rank(PresenceStatus s) => switch (s) {
        PresenceStatus.online => 0,
        PresenceStatus.inMatch => 1,
        PresenceStatus.offline => 2,
      };
  final list = friends.toList();
  list.sort((a, b) {
    final r = rank(a.presence).compareTo(rank(b.presence));
    if (r != 0) return r;
    if (a.presence == PresenceStatus.offline) {
      final la = a.lastSeenAt;
      final lb = b.lastSeenAt;
      if (la != null && lb != null) {
        final c = lb.compareTo(la);
        if (c != 0) return c;
      } else if (la != null) {
        return -1;
      } else if (lb != null) {
        return 1;
      }
    }
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  });
  return list;
}

/// Một lời mời kết bạn (đến hoặc đi): `{requestId|id|friendshipId, user:{...}|userId..., createdAt}`.
class FriendRequestItem {
  final int requestId;
  final UserSummary user;
  final DateTime? createdAt;
  const FriendRequestItem(
      {required this.requestId, required this.user, this.createdAt});

  String get displayName => _displayName(user.fullName, user.username);

  factory FriendRequestItem.fromJson(Map<String, dynamic> j) {
    final u = asMap(pick(j, ['user', 'from', 'to', 'requester', 'addressee'])) ??
        j;
    return FriendRequestItem(
      requestId: asInt(pick(j, ['requestId', 'friendshipId', 'id'])) ?? 0,
      user: UserSummary(
        userId: asInt(pick(u, ['userId', 'id'])) ?? 0,
        username: asString(pick(u, ['username', 'userName'])) ?? '',
        fullName: asString(u['fullName']),
        avatarUrl: asString(u['avatarUrl']),
      ),
      createdAt: asDate(j['createdAt']),
    );
  }
}

/// `GET /friends/requests` -> `{incoming:[...], outgoing:[...]}` (hoặc `received`/`sent`).
class FriendRequests {
  final List<FriendRequestItem> incoming;
  final List<FriendRequestItem> outgoing;
  const FriendRequests({this.incoming = const [], this.outgoing = const []});

  factory FriendRequests.fromJson(Object? d) {
    final m = asMap(d) ?? const <String, dynamic>{};
    List<FriendRequestItem> read(List<String> keys) => [
          for (final e in extractList(pick(m, keys) ?? const [], keys))
            FriendRequestItem.fromJson(e),
        ];
    return FriendRequests(
      incoming: read(['incoming', 'received']),
      outgoing: read(['outgoing', 'sent']),
    );
  }
}

// ------------------------------------------------------------ hồ sơ

enum Relationship {
  none,
  friends,
  pendingOut,
  pendingIn,
  self;

  static Relationship parse(Object? v) {
    final s = (v is String ? v : '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z]'), '');
    return switch (s) {
      'friends' || 'friend' || 'accepted' => friends,
      'pendingout' ||
      'outgoing' ||
      'requestsent' ||
      'sent' ||
      'pendingsent' =>
        pendingOut,
      'pendingin' ||
      'incoming' ||
      'requestreceived' ||
      'received' ||
      'pendingreceived' =>
        pendingIn,
      'self' || 'me' => self,
      _ => none,
    };
  }
}

/// Thống kê/rating của một người ở một game.
/// `{gameCode, rating, tier?, games, wins, losses, draws, peakRating?, bestScore?}`.
class GameStats {
  final String gameCode;
  final int rating;
  final Tier? _tier;
  final int games;
  final int wins;
  final int losses;
  final int draws;
  final int peakRating;
  final int? bestScore;

  const GameStats({
    required this.gameCode,
    this.rating = Tier.startRating,
    Tier? tier,
    this.games = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    int? peakRating,
    this.bestScore,
  })  : _tier = tier,
        peakRating = peakRating ?? rating;

  /// Bậc theo rating (ưu tiên mã bậc server gửi).
  Tier get tier => _tier ?? Tier.fromRating(rating);

  /// Tỉ lệ thắng 0..1 (0 khi chưa có trận).
  double get winRate => games == 0 ? 0 : wins / games;

  factory GameStats.fromJson(Map<String, dynamic> j) {
    final rating = asInt(j['rating']) ?? Tier.startRating;
    final wins = asInt(j['wins']) ?? 0;
    final losses = asInt(j['losses']) ?? 0;
    final draws = asInt(j['draws']) ?? 0;
    return GameStats(
      gameCode: asString(j['gameCode']) ?? '',
      rating: rating,
      tier: Tier.tryParse(asString(j['tier'])) ?? Tier.fromRating(rating),
      games: asInt(pick(j, ['games', 'played', 'total'])) ??
          (wins + losses + draws),
      wins: wins,
      losses: losses,
      draws: draws,
      peakRating: asInt(pick(j, ['peakRating', 'peak'])),
      bestScore: asInt(pick(j, ['bestRecordScore', 'bestScore', 'best'])),
    );
  }
}

/// `GET /ratings/me` -> mảng (hoặc `{ratings:[...]}`) các [GameStats].
List<GameStats> parseRatings(Object? d) => [
      for (final e in extractList(d, ['ratings', 'items', 'games']))
        GameStats.fromJson(e),
    ];

/// `GET /users/{id}/profile`:
/// `{userId, username, fullName?, avatarUrl?, createdAt?, relationship: none|friends|pending_out|pending_in|self,
///   requestId?, status?, stats|ratings|games:[GameStats...], totalGames?, totalWins?}`.
class PlayerProfile {
  final int userId;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final DateTime? createdAt;
  final Relationship relationship;

  /// Id lời mời đang chờ (để Chấp nhận / Hủy lời mời), nếu có.
  final int? requestId;
  final PresenceStatus? presence;
  final List<GameStats> stats;

  const PlayerProfile({
    required this.userId,
    required this.username,
    this.fullName,
    this.avatarUrl,
    this.createdAt,
    this.relationship = Relationship.none,
    this.requestId,
    this.presence,
    this.stats = const [],
  });

  String get displayName => _displayName(fullName, username);

  UserSummary get summary => UserSummary(
      userId: userId,
      username: username,
      fullName: fullName,
      avatarUrl: avatarUrl);

  GameStats? statsFor(String gameCode) {
    for (final s in stats) {
      if (s.gameCode == gameCode) return s;
    }
    return null;
  }

  /// Bậc cao nhất trong các game đã chơi đối kháng (null nếu chưa đấu trận nào).
  GameStats? get best {
    GameStats? b;
    for (final s in stats) {
      if (s.games == 0) continue;
      if (b == null || s.rating > b.rating) b = s;
    }
    return b;
  }

  PlayerProfile copyWith({Relationship? relationship, int? requestId}) =>
      PlayerProfile(
        userId: userId,
        username: username,
        fullName: fullName,
        avatarUrl: avatarUrl,
        createdAt: createdAt,
        relationship: relationship ?? this.relationship,
        requestId: requestId ?? this.requestId,
        presence: presence,
        stats: stats,
      );

  factory PlayerProfile.fromJson(Map<String, dynamic> j) {
    final u = asMap(j['user']) ?? j;
    final statsRaw = pick(j, ['stats', 'ratings', 'perGame', 'games']);
    return PlayerProfile(
      userId: asInt(pick(u, ['userId', 'id'])) ?? 0,
      username: asString(pick(u, ['username', 'userName'])) ?? '',
      fullName: asString(u['fullName']),
      avatarUrl: asString(u['avatarUrl']),
      createdAt: asDate(u['createdAt']),
      relationship:
          Relationship.parse(
          pick(j, ['friendshipStatus', 'relationship', 'friendship', 'relation'])),
      requestId: asInt(pick(j, ['pendingRequestId', 'requestId', 'friendshipId'])),
      presence: j['status'] == null && j['presence'] == null
          ? null
          : PresenceStatus.parse(pick(j, ['status', 'presence'])),
      stats: statsRaw is List || statsRaw is Map
          ? [
              for (final e in extractList(statsRaw, ['items', 'games']))
                GameStats.fromJson(e),
            ]
          : const [],
    );
  }
}

// ------------------------------------------------------------ xếp hạng v2

enum BoardType { ranked, record }

enum BoardScope { global, friends }

enum BoardPeriod { season, all }

/// Tham số của một bảng xếp hạng; cũng là khóa cache.
class BoardQuery {
  final String gameCode;
  final BoardType board;

  /// Chỉ dùng cho [BoardType.record]; null = tất cả độ khó.
  final int? difficulty;
  final BoardScope scope;
  final BoardPeriod period;

  const BoardQuery({
    required this.gameCode,
    this.board = BoardType.ranked,
    this.difficulty,
    this.scope = BoardScope.global,
    this.period = BoardPeriod.season,
  });

  Map<String, dynamic> toQuery() => {
        'gameCode': gameCode,
        'board': board == BoardType.ranked ? 'ranked' : 'record',
        if (board == BoardType.record && difficulty != null)
          'difficulty': difficulty,
        'scope': scope == BoardScope.global ? 'global' : 'friends',
        'period': period == BoardPeriod.season ? 'season' : 'all',
      };

  String cacheKey(int? userId) =>
      '${toQuery().entries.map((e) => '${e.key}=${e.value}').join('&')}|u${userId ?? 0}';

  @override
  bool operator ==(Object other) =>
      other is BoardQuery && other.toQuery().toString() == toQuery().toString();

  @override
  int get hashCode => toQuery().toString().hashCode;
}

/// Một dòng bảng xếp hạng. [value] là rating (Đối kháng) hoặc điểm (Kỷ lục).
/// Server: `{rank, userId, username, fullName?, avatarUrl?, rating|bestScore|score|value,
/// bestTimeSeconds?, games?, tier?}`. Hạng kiểu thi đấu (1,2,2,4) do server tính.
class BoardEntry {
  final int rank;
  final int userId;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final int value;
  final int? bestTimeSeconds;
  final int? games;
  final Tier? tier;

  const BoardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    this.fullName,
    this.avatarUrl,
    required this.value,
    this.bestTimeSeconds,
    this.games,
    this.tier,
  });

  String get displayName => _displayName(fullName, username);

  UserSummary get summary => UserSummary(
      userId: userId,
      username: username,
      fullName: fullName,
      avatarUrl: avatarUrl);

  factory BoardEntry.fromJson(Map<String, dynamic> j, {required BoardType board}) {
    final u = asMap(j['user']) ?? j;
    final value = board == BoardType.ranked
        ? asInt(pick(j, ['rating', 'value', 'score', 'bestScore']))
        : asInt(pick(j, ['bestScore', 'score', 'value', 'rating']));
    final tierCode = asString(j['tier']);
    return BoardEntry(
      rank: asInt(j['rank']) ?? 0,
      userId: asInt(pick(u, ['userId', 'id'])) ?? 0,
      username: asString(pick(u, ['username', 'userName'])) ?? '',
      fullName: asString(u['fullName']),
      avatarUrl: asString(u['avatarUrl']),
      value: value ?? 0,
      bestTimeSeconds: asInt(pick(j, ['bestTimeSeconds', 'timeSeconds'])),
      games: asInt(pick(j, ['games', 'gamesPlayed'])),
      tier: Tier.tryParse(tierCode) ??
          (board == BoardType.ranked && value != null
              ? Tier.fromRating(value)
              : null),
    );
  }
}

/// Hạng của mình trên một bảng: `{rank?, rating|bestScore|score?, bestTimeSeconds?, games?}`.
class BoardMe {
  final int? rank;
  final int? value;
  final int? bestTimeSeconds;
  final int? games;
  const BoardMe({this.rank, this.value, this.bestTimeSeconds, this.games});

  bool get hasPlayed => rank != null && value != null;

  factory BoardMe.fromJson(Map<String, dynamic> j, {required BoardType board}) {
    final value = board == BoardType.ranked
        ? asInt(pick(j, ['rating', 'value', 'score', 'bestScore']))
        : asInt(pick(j, ['bestScore', 'score', 'value', 'rating']));
    return BoardMe(
      rank: asInt(j['rank']),
      value: value,
      bestTimeSeconds: asInt(pick(j, ['bestTimeSeconds', 'timeSeconds'])),
      games: asInt(pick(j, ['games', 'gamesPlayed'])),
    );
  }
}

/// `GET /leaderboard/season` -> `{startsAt|start|startAt, endsAt|end|endAt}` (UTC).
class SeasonInfo {
  final DateTime startsAt;
  final DateTime endsAt;
  const SeasonInfo({required this.startsAt, required this.endsAt});

  Duration remaining(DateTime now) {
    final d = endsAt.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  factory SeasonInfo.fromJson(Map<String, dynamic> j) => SeasonInfo(
        startsAt: asDate(pick(j, ['startUtc', 'startsAt', 'start', 'startAt', 'from'])) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        endsAt: asDate(pick(j, ['endUtc', 'endsAt', 'end', 'endAt', 'to'])) ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// "Mùa kết thúc sau 3 ngày 4 giờ" / "… 4 giờ 12 phút" / "… 12 phút".
String seasonCountdownVi(Duration d) {
  if (d <= Duration.zero) return 'Mùa vừa kết thúc';
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  final String left;
  if (days > 0) {
    left = hours > 0 ? '$days ngày $hours giờ' : '$days ngày';
  } else if (d.inHours > 0) {
    left = minutes > 0 ? '${d.inHours} giờ $minutes phút' : '${d.inHours} giờ';
  } else {
    left = '${d.inMinutes < 1 ? 1 : d.inMinutes} phút';
  }
  return 'Mùa kết thúc sau $left';
}

// ------------------------------------------------------------ lịch sử trận

enum MatchResult { win, lose, draw }

/// `GET /matches?page` -> trang `{items,page,pageSize,total}` (hoặc mảng) của:
/// `{matchId, gameCode, difficulty?, mode: RANKED|FRIENDLY, opponent:{userId,username,fullName?},
///   result: WIN|LOSE|DRAW (theo góc nhìn của mình) | winnerId, endReason?,
///   ratingBefore?, ratingAfter?, ratingDelta?, endedAt}`.
class MatchHistoryItem {
  final String matchId;
  final String gameCode;
  final int? difficulty;
  final bool ranked;
  final UserSummary? opponent;
  final MatchResult result;
  final String? endReason;
  final int? ratingBefore;
  final int? ratingAfter;
  final DateTime? endedAt;

  const MatchHistoryItem({
    required this.matchId,
    required this.gameCode,
    this.difficulty,
    this.ranked = true,
    this.opponent,
    required this.result,
    this.endReason,
    this.ratingBefore,
    this.ratingAfter,
    this.endedAt,
  });

  /// Chênh lệch rating (null khi trận giao hữu / không có số liệu).
  int? get ratingDelta => ratingBefore != null && ratingAfter != null
      ? ratingAfter! - ratingBefore!
      : null;

  String get opponentName =>
      opponent == null ? 'Đối thủ' : _displayName(opponent!.fullName, opponent!.username);

  factory MatchHistoryItem.fromJson(Map<String, dynamic> j, {int? myId}) {
    final o = asMap(j['opponent']);
    final res = (asString(j['result']) ?? '').toUpperCase();
    final winnerId = asInt(j['winnerId']);
    final MatchResult result = switch (res) {
      'WIN' || 'WON' => MatchResult.win,
      'LOSE' || 'LOSS' || 'LOST' => MatchResult.lose,
      'DRAW' => MatchResult.draw,
      _ => winnerId == null || winnerId <= 0
          ? MatchResult.draw
          : (myId != null && winnerId == myId
              ? MatchResult.win
              : MatchResult.lose),
    };
    final before = asInt(pick(j, ['ratingBefore', 'myRatingBefore']));
    final after = asInt(pick(j, ['ratingAfter', 'myRatingAfter']));
    final delta = asInt(j['ratingDelta']);
    return MatchHistoryItem(
      matchId: asString(pick(j, ['matchId', 'id'])) ?? '',
      gameCode: asString(j['gameCode']) ?? '',
      difficulty: asInt(j['difficulty']),
      ranked: (asString(j['mode']) ?? 'RANKED').toUpperCase() != 'FRIENDLY',
      opponent: o == null
          ? null
          : UserSummary(
              userId: asInt(pick(o, ['userId', 'id'])) ?? 0,
              username: asString(pick(o, ['username', 'userName'])) ?? '',
              fullName: asString(o['fullName']),
              avatarUrl: asString(o['avatarUrl']),
            ),
      result: result,
      endReason: asString(pick(j, ['endReason', 'reason'])),
      ratingBefore: before,
      ratingAfter: after ?? (before != null && delta != null ? before + delta : null),
      endedAt: asDate(pick(j, ['endedAt', 'playedAt'])),
    );
  }
}

/// Trang lịch sử trận từ `GET /matches`.
PagedResult<MatchHistoryItem> parseMatchPage(Object? d, {int? myId, int page = 1}) {
  final m = asMap(d);
  final items = [
    for (final e in extractList(d))
      MatchHistoryItem.fromJson(e, myId: myId),
  ];
  return PagedResult(
    items: items,
    page: asInt(m?['page']) ?? page,
    pageSize: asInt(m?['pageSize']) ?? items.length,
    total: asInt(m?['total']) ?? items.length,
  );
}
