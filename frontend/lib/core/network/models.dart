import 'social_models.dart';
export 'social_models.dart';
export 'v2_models.dart';

// Các model đơn giản khớp DTO của backend (camelCase).

DateTime parseServerDate(Object? v) {
  if (v is! String) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  // Server lưu UTC nhưng có thể không kèm hậu tố múi giờ.
  final hasZone = v.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(v);
  return (DateTime.tryParse(hasZone ? v : '${v}Z') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
      .toLocal();
}

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
  String get displayName => (fullName != null && fullName!.trim().isNotEmpty)
      ? fullName!.trim()
      : username;

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

class UserSummary {
  final int userId;
  final String username;
  final String? fullName;
  final String? avatarUrl;

  const UserSummary({
    required this.userId,
    required this.username,
    this.fullName,
    this.avatarUrl,
  });

  factory UserSummary.fromJson(Map<String, dynamic> j) => UserSummary(
        userId: j['userId'] as int,
        username: j['username'] as String,
        fullName: j['fullName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
      );
}

class AuthResult {
  final String token;
  final AppUser user;
  const AuthResult({required this.token, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        token: j['token'] as String,
        user: AppUser.fromJson(j['user'] as Map<String, dynamic>),
      );
}

class GameLevelInfo {
  final int levelId;
  final int difficulty;
  final String difficultyName;
  const GameLevelInfo(this.levelId, this.difficulty, this.difficultyName);
}

class GameInfo {
  final int gameId;
  final String gameCode;
  final String gameName;
  final String? description;
  final List<GameLevelInfo> levels;

  const GameInfo({
    required this.gameId,
    required this.gameCode,
    required this.gameName,
    this.description,
    this.levels = const [],
  });

  factory GameInfo.fromJson(Map<String, dynamic> j) => GameInfo(
        gameId: j['gameId'] as int,
        gameCode: j['gameCode'] as String,
        gameName: j['gameName'] as String,
        description: j['description'] as String?,
        levels: [
          for (final l in (j['levels'] as List? ?? const []))
            GameLevelInfo(l['levelId'] as int, l['difficulty'] as int,
                l['difficultyName'] as String),
        ],
      );
}

class HistoryItem {
  final int historyId;
  final String gameCode;
  final String gameName;
  final int? difficulty;
  final String? difficultyName;
  final int timeSpentSeconds;
  final int mistakesCount;
  final int movesCount;
  final int hintsUsed;
  final String result;
  final int score;
  final int? challengeId;
  final DateTime playedAt;

  const HistoryItem({
    required this.historyId,
    required this.gameCode,
    required this.gameName,
    this.difficulty,
    this.difficultyName,
    required this.timeSpentSeconds,
    required this.mistakesCount,
    this.movesCount = 0,
    this.hintsUsed = 0,
    required this.result,
    required this.score,
    this.challengeId,
    required this.playedAt,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        historyId: j['historyId'] as int,
        gameCode: j['gameCode'] as String,
        gameName: (j['gameName'] as String?) ?? (j['gameCode'] as String),
        difficulty: j['difficulty'] as int?,
        difficultyName: j['difficultyName'] as String?,
        timeSpentSeconds: j['timeSpentSeconds'] as int,
        mistakesCount: j['mistakesCount'] as int,
        movesCount: (j['movesCount'] as int?) ?? 0,
        hintsUsed: (j['hintsUsed'] as int?) ?? 0,
        result: j['result'] as String,
        score: j['score'] as int,
        challengeId: j['challengeId'] as int?,
        playedAt: parseServerDate(j['playedAt']),
      );
}

class SubmitResult {
  final HistoryItem record;
  final bool isPersonalBest;

  /// Có khi ván này thuộc một thách đấu (đã cập nhật trạng thái / người thắng).
  final Challenge? challenge;
  const SubmitResult({
    required this.record,
    required this.isPersonalBest,
    this.challenge,
  });

  factory SubmitResult.fromJson(Map<String, dynamic> j) => SubmitResult(
        record: HistoryItem.fromJson(j['record'] as Map<String, dynamic>),
        isPersonalBest: (j['isPersonalBest'] as bool?) ?? false,
        challenge: j['challenge'] is Map
            ? Challenge.fromJson((j['challenge'] as Map).cast<String, dynamic>())
            : null,
      );
}

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
            parse(e as Map<String, dynamic>),
        ],
        page: (j['page'] as int?) ?? 1,
        pageSize: (j['pageSize'] as int?) ?? 20,
        total: (j['total'] as int?) ?? 0,
      );
}
