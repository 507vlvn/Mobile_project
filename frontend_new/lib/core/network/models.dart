import 'dart:convert';
import '../models/presence.dart';
import '../models/rank.dart';

// Các model khớp DTO của backend (camelCase), xem backend/GameHub.Api/model/Dtos.cs.

DateTime parseServerDate(Object? v) {
  if (v is! String) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  // Server lưu UTC nhưng có thể không kèm hậu tố múi giờ.
  final hasZone = v.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(v);
  return (DateTime.tryParse(hasZone ? v : '${v}Z') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
      .toLocal();
}

String _displayName(String? fullName, String username) =>
    (fullName != null && fullName.trim().isNotEmpty)
        ? fullName.trim()
        : username;

/// `UserDto`: {userId, username, email, fullName?, avatarUrl?, createdAt}.
class AppUser {
  final int userId;
  final String username;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final DateTime? createdAt;

  const AppUser({
    required this.userId,
    required this.username,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.createdAt,
  });

  /// Tên hiển thị: họ tên nếu có, không thì username.
  String get displayName => _displayName(fullName, username);

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        userId: j['userId'] as int,
        username: j['username'] as String,
        email: (j['email'] as String?) ?? '',
        fullName: j['fullName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        createdAt:
            j['createdAt'] == null ? null : parseServerDate(j['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'email': email,
        'fullName': fullName,
        'avatarUrl': avatarUrl,
        'createdAt': createdAt?.toUtc().toIso8601String(),
      };
}

/// `UserSummaryDto`: {userId, username, fullName?, avatarUrl?}.
class UserSummary {
  final int userId;
  final String username;
  final String? fullName;

  const UserSummary({
    required this.userId,
    required this.username,
    this.fullName,
  });

  String get displayName => _displayName(fullName, username);

  factory UserSummary.fromJson(Map<String, dynamic> j) => UserSummary(
        userId: j['userId'] as int,
        username: j['username'] as String,
        fullName: j['fullName'] as String?,
      );
}

/// `AuthResponse`: {token, user}.
class AuthResult {
  final String token;
  final AppUser user;
  const AuthResult({required this.token, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        token: j['token'] as String,
        user: AppUser.fromJson(j['user'] as Map<String, dynamic>),
      );
}

/// `PagedResult<T>`: {items, page, pageSize, total}.
class PagedResult<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final int total;
  const PagedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory PagedResult.fromJson(
          Map<String, dynamic> j, T Function(Map<String, dynamic>) parse) =>
      PagedResult(
        items: [
          for (final e in (j['items'] as List? ?? const []))
            parse((e as Map).cast<String, dynamic>()),
        ],
        page: (j['page'] as int?) ?? 1,
        pageSize: (j['pageSize'] as int?) ?? 20,
        total: (j['total'] as int?) ?? 0,
      );
}

/// Thống kê/rating của mình ở một game.
/// Đọc được cả `RatingDto` (GET /ratings/me) lẫn `GameStatsDto`
/// (trường `stats` của GET /users/{id}/profile, có thêm `bestRecordScore`).
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

  GameStats withBestScore(int? best) => GameStats(
        gameCode: gameCode,
        rating: rating,
        tier: _tier,
        games: games,
        wins: wins,
        losses: losses,
        draws: draws,
        peakRating: peakRating,
        bestScore: best,
      );

  factory GameStats.fromJson(Map<String, dynamic> j) {
    final rating = (j['rating'] as int?) ?? Tier.startRating;
    return GameStats(
      gameCode: (j['gameCode'] as String?) ?? '',
      rating: rating,
      tier: Tier.tryParse(j['tier'] as String?),
      games: (j['games'] as int?) ?? 0,
      wins: (j['wins'] as int?) ?? 0,
      losses: (j['losses'] as int?) ?? 0,
      draws: (j['draws'] as int?) ?? 0,
      peakRating: j['peakRating'] as int?,
      bestScore: j['bestRecordScore'] as int?,
    );
  }
}

/// `SubmitHistoryResponse` của POST /history: {record: HistoryDto, isPersonalBest}.
/// Chỉ giữ phần app cần: điểm server tính và có phải kỷ lục cá nhân không.
class SubmitResult {
  final int score;
  final bool isPersonalBest;

  const SubmitResult({required this.score, this.isPersonalBest = false});

  factory SubmitResult.fromJson(Map<String, dynamic> j) => SubmitResult(
        score: ((j['record'] as Map?)?['score'] as int?) ?? 0,
        isPersonalBest: (j['isPersonalBest'] as bool?) ?? false,
      );
}

// ------------------------------------------------------------ bảng xếp hạng

/// Tham số của GET /leaderboard và /leaderboard/me (LeaderboardController.Parse).
class LeaderboardQuery {
  final String gameCode;

  /// true = bảng đối kháng (rating, bảng `PlayerRatings`);
  /// false = bảng kỷ lục (điểm cao nhất chơi đơn, bảng `History`).
  final bool ranked;

  /// 1..3; null = mọi độ khó (chỉ có ý nghĩa với bảng kỷ lục).
  final int? difficulty;
  final bool friendsOnly;

  /// true = mùa hiện tại (tuần, từ thứ Hai); false = mọi lúc.
  final bool season;

  const LeaderboardQuery({
    required this.gameCode,
    this.ranked = false,
    this.difficulty,
    this.friendsOnly = false,
    this.season = true,
  });

  LeaderboardQuery copyWith({
    String? gameCode,
    bool? ranked,
    int? Function()? difficulty,
    bool? friendsOnly,
    bool? season,
  }) =>
      LeaderboardQuery(
        gameCode: gameCode ?? this.gameCode,
        ranked: ranked ?? this.ranked,
        difficulty: difficulty != null ? difficulty() : this.difficulty,
        friendsOnly: friendsOnly ?? this.friendsOnly,
        season: season ?? this.season,
      );

  Map<String, Object> toQuery() => {
        'gameCode': gameCode,
        'board': ranked ? 'ranked' : 'record',
        if (!ranked && difficulty != null) 'difficulty': difficulty!,
        'scope': friendsOnly ? 'friends' : 'global',
        'period': season ? 'season' : 'all',
      };

  /// Khóa để nhớ kết quả đã tải.
  String get key => toQuery().entries.map((e) => '${e.key}=${e.value}').join('&');
}

/// `LeaderboardEntryDto`: {rank, userId, username, fullName, avatarUrl, bestScore,
/// bestTimeSeconds, rating?, tier?, tierName?, games?, wins?}.
/// Bảng đối kháng: bestScore = rating, bestTimeSeconds = 0.
class LeaderboardEntry {
  final int rank;
  final UserSummary user;
  final int bestScore;
  final int bestTimeSeconds;
  final int? rating;
  final Tier? tier;
  final int? games;
  final int? wins;

  const LeaderboardEntry({
    required this.rank,
    required this.user,
    required this.bestScore,
    this.bestTimeSeconds = 0,
    this.rating,
    this.tier,
    this.games,
    this.wins,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) {
    final rating = j['rating'] as int?;
    return LeaderboardEntry(
      rank: (j['rank'] as int?) ?? 0,
      user: UserSummary.fromJson(j),
      bestScore: (j['bestScore'] as int?) ?? 0,
      bestTimeSeconds: (j['bestTimeSeconds'] as int?) ?? 0,
      rating: rating,
      tier: Tier.tryParse(j['tier'] as String?) ?? (rating == null ? null : Tier.fromRating(rating)),
      games: j['games'] as int?,
      wins: j['wins'] as int?,
    );
  }
}

/// `MyRankDto`: {rank?, bestScore?, bestTimeSeconds?, rating?, tier?, games?, wins?}.
/// rank null = mình chưa có trong bảng này.
class MyRank {
  final int? rank;
  final int? bestScore;
  final int? bestTimeSeconds;
  final int? rating;
  final Tier? tier;
  final int? games;
  final int? wins;

  const MyRank({this.rank, this.bestScore, this.bestTimeSeconds, this.rating, this.tier, this.games, this.wins});

  factory MyRank.fromJson(Map<String, dynamic> j) {
    final rating = j['rating'] as int?;
    return MyRank(
      rank: j['rank'] as int?,
      bestScore: j['bestScore'] as int?,
      bestTimeSeconds: j['bestTimeSeconds'] as int?,
      rating: rating,
      tier: Tier.tryParse(j['tier'] as String?) ?? (rating == null ? null : Tier.fromRating(rating)),
      games: j['games'] as int?,
      wins: j['wins'] as int?,
    );
  }
}

/// `SeasonDto`: {startUtc, endUtc, now} — mùa theo tuần (thứ Hai → thứ Hai).
class SeasonInfo {
  final DateTime start;
  final DateTime end;

  /// Lệch giờ giữa server và máy (để đếm ngược đúng).
  final Duration clockOffset;

  const SeasonInfo({required this.start, required this.end, this.clockOffset = Duration.zero});

  /// Thời gian còn lại của mùa theo đồng hồ server.
  Duration remaining([DateTime? now]) => end.difference((now ?? DateTime.now()).add(clockOffset));

  factory SeasonInfo.fromJson(Map<String, dynamic> j) {
    final serverNow = parseServerDate(j['now']);
    return SeasonInfo(
      start: parseServerDate(j['startUtc']),
      end: parseServerDate(j['endUtc']),
      clockOffset: serverNow.difference(DateTime.now()),
    );
  }
}

/// "2 ngày 5 giờ" / "3 giờ 12 phút" / "8 phút".
String seasonCountdownVi(Duration d) {
  if (d.isNegative) return 'sắp kết thúc';
  if (d.inDays > 0) return '${d.inDays} ngày ${d.inHours % 24} giờ';
  if (d.inHours > 0) return '${d.inHours} giờ ${d.inMinutes % 60} phút';
  return '${d.inMinutes} phút';
}

// ------------------------------------------------------------ bạn bè

/// `FriendDto`: {userId, username, fullName?, avatarUrl?, status: online|in_match|offline, lastSeenAt?}.
class FriendInfo {
  final int userId;
  final String username;
  final String? fullName;
  final PresenceStatus presence;
  final DateTime? lastSeenAt;

  const FriendInfo({
    required this.userId,
    required this.username,
    this.fullName,
    this.presence = PresenceStatus.offline,
    this.lastSeenAt,
  });

  String get displayName => _displayName(fullName, username);

  UserSummary get summary =>
      UserSummary(userId: userId, username: username, fullName: fullName);

  FriendInfo withPresence(PresenceStatus s, {DateTime? lastSeenAt}) =>
      FriendInfo(
        userId: userId,
        username: username,
        fullName: fullName,
        presence: s,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      );

  factory FriendInfo.fromJson(Map<String, dynamic> j) => FriendInfo(
        userId: j['userId'] as int,
        username: j['username'] as String,
        fullName: j['fullName'] as String?,
        presence: PresenceStatus.parse(j['status']),
        lastSeenAt:
            j['lastSeenAt'] == null ? null : parseServerDate(j['lastSeenAt']),
      );
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

/// `FriendRequestDto`: {requestId, userId, username, fullName?, avatarUrl?, createdAt}.
class FriendRequestItem {
  final int requestId;
  final UserSummary user;

  const FriendRequestItem({required this.requestId, required this.user});

  String get displayName => user.displayName;

  factory FriendRequestItem.fromJson(Map<String, dynamic> j) =>
      FriendRequestItem(
        requestId: j['requestId'] as int,
        user: UserSummary.fromJson(j),
      );
}

/// `FriendRequestsDto`: {incoming:[...], outgoing:[...]}.
class FriendRequests {
  final List<FriendRequestItem> incoming;
  final List<FriendRequestItem> outgoing;

  const FriendRequests({this.incoming = const [], this.outgoing = const []});

  factory FriendRequests.fromJson(Map<String, dynamic> j) {
    List<FriendRequestItem> list(Object? v) => [
          for (final e in (v as List? ?? const []))
            FriendRequestItem.fromJson((e as Map).cast<String, dynamic>()),
        ];
    return FriendRequests(
        incoming: list(j['incoming']), outgoing: list(j['outgoing']));
  }
}

/// Quan hệ của mình với một người chơi.
enum Relationship {
  none,
  friends,
  pendingOut,
  pendingIn,
  self;

  /// `friendshipStatus` của ProfileDto: NONE | SELF | ACCEPTED | PENDING_SENT | PENDING_RECEIVED.
  static Relationship parse(Object? v) => switch (v) {
        'ACCEPTED' => friends,
        'PENDING_SENT' => pendingOut,
        'PENDING_RECEIVED' => pendingIn,
        'SELF' => self,
        _ => none,
      };
}

/// `ProfileDto` của GET /users/{id}/profile.
class PlayerProfile {
  final UserSummary user;
  final Relationship relationship;

  /// Id lời mời đang chờ (để Chấp nhận / Từ chối), nếu có.
  final int? requestId;
  final PresenceStatus presence;
  final List<GameStats> stats;

  const PlayerProfile({
    required this.user,
    this.relationship = Relationship.none,
    this.requestId,
    this.presence = PresenceStatus.offline,
    this.stats = const [],
  });

  int get userId => user.userId;
  String get username => user.username;
  String get displayName => user.displayName;

  GameStats? statsFor(String gameCode) {
    for (final s in stats) {
      if (s.gameCode == gameCode) return s;
    }
    return null;
  }

  /// Game có rating cao nhất trong số đã đấu (null nếu chưa đấu trận nào).
  GameStats? get best {
    GameStats? b;
    for (final s in stats) {
      if (s.games == 0) continue;
      if (b == null || s.rating > b.rating) b = s;
    }
    return b;
  }

  PlayerProfile withRelationship(Relationship r) => PlayerProfile(
        user: user,
        relationship: r,
        requestId: requestId,
        presence: presence,
        stats: stats,
      );

  factory PlayerProfile.fromJson(Map<String, dynamic> j) => PlayerProfile(
        user: UserSummary.fromJson((j['user'] as Map).cast<String, dynamic>()),
        relationship: Relationship.parse(j['friendshipStatus']),
        requestId: j['pendingRequestId'] as int?,
        presence: PresenceStatus.parse(j['status']),
        stats: [
          for (final e in (j['stats'] as List? ?? const []))
            GameStats.fromJson((e as Map).cast<String, dynamic>()),
        ],
      );
}

// ------------------------------------------------------------ tin nhắn

/// `MessageDto`: {messageId, senderId, receiverId, content, isRead, sentAt}.
class ChatMessage {
  final int messageId;
  final int senderId;
  final int receiverId;
  final String content;
  final bool isRead;
  final DateTime sentAt;

  const ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.isRead,
    required this.sentAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        messageId: j['messageId'] as int,
        senderId: j['senderId'] as int,
        receiverId: j['receiverId'] as int,
        content: j['content'] as String,
        isRead: (j['isRead'] as bool?) ?? false,
        sentAt: parseServerDate(j['sentAt']),
      );
}

/// `ConversationDto`: {userId, username, fullName?, avatarUrl?, lastMessage,
/// lastMessageAt, lastFromMe, unreadCount}.
class Conversation {
  final UserSummary user;
  final String lastMessage;
  final DateTime lastMessageAt;
  final bool lastFromMe;
  final int unreadCount;

  const Conversation({
    required this.user,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastFromMe,
    required this.unreadCount,
  });

  String get displayName => user.displayName;

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        user: UserSummary.fromJson(j),
        lastMessage: (j['lastMessage'] as String?) ?? '',
        lastMessageAt: parseServerDate(j['lastMessageAt']),
        lastFromMe: (j['lastFromMe'] as bool?) ?? false,
        unreadCount: (j['unreadCount'] as int?) ?? 0,
      );
}

// ------------------------------------------------------------ trận đấu

enum MatchResult { win, lose, draw }

/// `MatchHistoryDto` của GET /matches (kết quả theo góc nhìn của mình).
class MatchHistoryItem {
  final int matchId;
  final String gameCode;
  final bool ranked;
  final UserSummary opponent;
  final MatchResult result;
  final int? ratingDelta;
  final DateTime? endedAt;

  const MatchHistoryItem({
    required this.matchId,
    required this.gameCode,
    required this.ranked,
    required this.opponent,
    required this.result,
    this.ratingDelta,
    this.endedAt,
  });

  String get opponentName => opponent.displayName;

  factory MatchHistoryItem.fromJson(Map<String, dynamic> j) => MatchHistoryItem(
        matchId: j['matchId'] as int,
        gameCode: j['gameCode'] as String,
        ranked: ((j['mode'] as String?) ?? 'RANKED').toUpperCase() != 'FRIENDLY',
        opponent: UserSummary.fromJson(
            (j['opponent'] as Map).cast<String, dynamic>()),
        result: switch (((j['result'] as String?) ?? '').toUpperCase()) {
          'WIN' => MatchResult.win,
          'LOSE' => MatchResult.lose,
          _ => MatchResult.draw,
        },
        ratingDelta: j['ratingDelta'] as int?,
        endedAt: j['endedAt'] == null ? null : parseServerDate(j['endedAt']),
      );
}

// ------------------------------------------------------------ Sudoku

/// Tiến trình 1 level học tập (khớp SudokuLevelDto).
class SudokuLevelProgress {
  final int level;
  final int clues;
  final bool isUnlocked;
  final int? bestTimeSeconds;
  final DateTime? completedAt;

  const SudokuLevelProgress({
    required this.level,
    required this.clues,
    required this.isUnlocked,
    this.bestTimeSeconds,
    this.completedAt,
  });

  bool get isCompleted => bestTimeSeconds != null;

  factory SudokuLevelProgress.fromJson(Map<String, dynamic> j) =>
      SudokuLevelProgress(
        level: j['level'] as int,
        clues: (j['clues'] as int?) ?? 0,
        isUnlocked: (j['isUnlocked'] as bool?) ?? false,
        bestTimeSeconds: j['bestTimeSeconds'] as int?,
        completedAt:
            j['completedAt'] == null ? null : parseServerDate(j['completedAt']),
      );
}

/// Tổng quan tiến trình học tập (khớp SudokuProgressSummaryDto).
class SudokuProgressSummary {
  final int completedCount;
  final int highestUnlockedLevel;
  final List<SudokuLevelProgress> levels;

  const SudokuProgressSummary({
    required this.completedCount,
    required this.highestUnlockedLevel,
    required this.levels,
  });

  factory SudokuProgressSummary.fromJson(Map<String, dynamic> j) =>
      SudokuProgressSummary(
        completedCount: (j['completedCount'] as int?) ?? 0,
        highestUnlockedLevel: (j['highestUnlockedLevel'] as int?) ?? 1,
        levels: [
          for (final e in (j['levels'] as List? ?? const []))
            SudokuLevelProgress.fromJson((e as Map).cast<String, dynamic>()),
        ],
      );
}

/// Phản hồi khi cập nhật level (khớp UpdateSudokuProgressResponse).
class UpdateSudokuProgressResponse {
  final bool isNewBest;
  final int level;
  final int bestTimeSeconds;
  final int nextUnlockedLevel;
  final String message;

  const UpdateSudokuProgressResponse({
    required this.isNewBest,
    required this.level,
    required this.bestTimeSeconds,
    required this.nextUnlockedLevel,
    required this.message,
  });

  factory UpdateSudokuProgressResponse.fromJson(Map<String, dynamic> j) =>
      UpdateSudokuProgressResponse(
        isNewBest: (j['isNewBest'] as bool?) ?? false,
        level: (j['level'] as int?) ?? 1,
        bestTimeSeconds: (j['bestTimeSeconds'] as int?) ?? 0,
        nextUnlockedLevel: (j['nextUnlockedLevel'] as int?) ?? 1,
        message: (j['message'] as String?) ?? '',
      );
}

/// Ván cờ dở dang (khớp SudokuSavedGameDto).
class SudokuSavedGame {
  final int id;
  final String gameMode;
  final int? level;
  final int difficulty;
  final int seed;
  final String boardCurrent;
  final String? notesData;
  final int mistakes;
  final int elapsedSeconds;
  final DateTime? updatedAt;

  const SudokuSavedGame({
    required this.id,
    required this.gameMode,
    this.level,
    required this.difficulty,
    required this.seed,
    required this.boardCurrent,
    this.notesData,
    required this.mistakes,
    required this.elapsedSeconds,
    this.updatedAt,
  });

  factory SudokuSavedGame.fromJson(Map<String, dynamic> j) => SudokuSavedGame(
        id: (j['id'] as int?) ?? 0,
        gameMode: (j['gameMode'] as String?) ?? 'CLASSIC',
        level: j['level'] as int?,
        difficulty: (j['difficulty'] as int?) ?? 2,
        seed: (j['seed'] as num?)?.toInt() ?? 0,
        boardCurrent: (j['boardCurrent'] as String?) ?? '',
        notesData: j['notesData'] as String?,
        mistakes: (j['mistakes'] as int?) ?? 0,
        elapsedSeconds: (j['elapsedSeconds'] as int?) ?? 0,
        updatedAt:
            j['updatedAt'] == null ? null : parseServerDate(j['updatedAt']),
      );
}

/// Thống kê Sudoku theo độ khó (Dễ, Trung bình, Khó, Chuyên gia).
class DifficultyStats {
  final int difficulty; // 1: Dễ, 2: Trung bình, 3: Khó, 4: Chuyên gia
  int gamesStarted;
  int gamesWon;
  int winWithoutMistakes;
  int? bestTimeSeconds;
  int totalWinTimeSeconds;

  DifficultyStats({
    required this.difficulty,
    this.gamesStarted = 0,
    this.gamesWon = 0,
    this.winWithoutMistakes = 0,
    this.bestTimeSeconds,
    this.totalWinTimeSeconds = 0,
  });

  double get winRate => gamesStarted == 0 ? 0.0 : (gamesWon / gamesStarted) * 100;

  String get winRateFormatted => '${winRate.toStringAsFixed(0)}%';

  String get bestTimeFormatted {
    if (bestTimeSeconds == null || bestTimeSeconds == 0) return '-';
    final m = (bestTimeSeconds! ~/ 60).toString().padLeft(2, '0');
    final s = (bestTimeSeconds! % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Map<String, dynamic> toJson() => {
        'difficulty': difficulty,
        'gamesStarted': gamesStarted,
        'gamesWon': gamesWon,
        'winWithoutMistakes': winWithoutMistakes,
        'bestTimeSeconds': bestTimeSeconds,
        'totalWinTimeSeconds': totalWinTimeSeconds,
      };

  factory DifficultyStats.fromJson(Map<String, dynamic> j) => DifficultyStats(
        difficulty: (j['difficulty'] as int?) ?? 1,
        gamesStarted: (j['gamesStarted'] as int?) ?? 0,
        gamesWon: (j['gamesWon'] as int?) ?? 0,
        winWithoutMistakes: (j['winWithoutMistakes'] as int?) ?? 0,
        bestTimeSeconds: j['bestTimeSeconds'] as int?,
        totalWinTimeSeconds: (j['totalWinTimeSeconds'] as int?) ?? 0,
      );
}



/// Ván Caro dở dang (khớp CaroSavedGameDto).
class CaroSavedGame {
  final int id;
  final String gameMode;
  final int difficulty;
  final bool playerFirst;
  final List<int> history;
  final int undos;
  final int elapsedSeconds;
  final int hintsRemaining;
  final DateTime? updatedAt;

  const CaroSavedGame({
    required this.id,
    required this.gameMode,
    required this.difficulty,
    required this.playerFirst,
    required this.history,
    required this.undos,
    required this.elapsedSeconds,
    required this.hintsRemaining,
    this.updatedAt,
  });

  factory CaroSavedGame.fromJson(Map<String, dynamic> json) {
    List<int> parseHistory(dynamic raw) {
      if (raw is List) return raw.map((e) => (e as num).toInt()).toList();
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) return decoded.map((e) => (e as num).toInt()).toList();
        } catch (_) {}
      }
      return const [];
    }

    return CaroSavedGame(
      id: (json['id'] as num?)?.toInt() ?? 0,
      gameMode: json['gameMode'] as String? ?? 'pve',
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 2,
      playerFirst: json['playerFirst'] as bool? ?? true,
      history: parseHistory(json['historyData'] ?? json['history']),
      undos: (json['undos'] as num?)?.toInt() ?? 0,
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      hintsRemaining: (json['hintsRemaining'] as num?)?.toInt() ?? 3,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'gameMode': gameMode,
        'difficulty': difficulty,
        'playerFirst': playerFirst,
        'historyData': jsonEncode(history),
        'undos': undos,
        'elapsedSeconds': elapsedSeconds,
        'hintsRemaining': hintsRemaining,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };
}