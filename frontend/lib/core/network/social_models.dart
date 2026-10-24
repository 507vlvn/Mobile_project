// Model thách đấu & tin nhắn, khớp DTO của backend (camelCase).
import 'models.dart';

class ChallengeUser {
  final int userId;
  final String username;
  final String? fullName;
  const ChallengeUser({
    required this.userId,
    required this.username,
    this.fullName,
  });

  String get displayName => (fullName != null && fullName!.trim().isNotEmpty)
      ? fullName!.trim()
      : username;

  factory ChallengeUser.fromJson(Map<String, dynamic> j) => ChallengeUser(
        userId: j['userId'] as int,
        username: j['username'] as String,
        fullName: j['fullName'] as String?,
      );
}

class ChallengeResult {
  final int score;
  final int timeSeconds;
  final int mistakes;
  final String result;
  const ChallengeResult({
    required this.score,
    required this.timeSeconds,
    this.mistakes = 0,
    this.result = 'COMPLETED',
  });

  factory ChallengeResult.fromJson(Map<String, dynamic> j) => ChallengeResult(
        score: j['score'] as int,
        timeSeconds: (j['timeSeconds'] as int?) ?? 0,
        mistakes: (j['mistakes'] as int?) ?? 0,
        result: (j['result'] as String?) ?? 'COMPLETED',
      );
}

enum ChallengeStatus {
  pending,
  accepted,
  declined,
  completed,
  expired;

  static ChallengeStatus parse(String? v) => switch (v) {
        'ACCEPTED' => accepted,
        'DECLINED' => declined,
        'COMPLETED' => completed,
        'EXPIRED' => expired,
        _ => pending,
      };
}

class Challenge {
  final int id;
  final String gameCode;
  final String gameName;
  final int difficulty;
  final ChallengeStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final ChallengeUser challenger;
  final ChallengeUser opponent;
  final ChallengeResult? myResult;
  final ChallengeResult? theirResult;
  final int? winnerId;

  /// Seed của đề: hai bên sinh cùng một đề từ giá trị này (= id thách đấu).
  final int seed;

  const Challenge({
    required this.id,
    required this.gameCode,
    required this.gameName,
    required this.difficulty,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.completedAt,
    required this.challenger,
    required this.opponent,
    this.myResult,
    this.theirResult,
    this.winnerId,
    int? seed,
  }) : seed = seed ?? id;

  /// Đối thủ của [myId] trong thách đấu này.
  ChallengeUser otherOf(int myId) =>
      challenger.userId == myId ? opponent : challenger;

  factory Challenge.fromJson(Map<String, dynamic> j) {
    ChallengeResult? res(Object? v) =>
        v is Map ? ChallengeResult.fromJson(v.cast<String, dynamic>()) : null;
    return Challenge(
      id: j['id'] as int,
      gameCode: j['gameCode'] as String,
      gameName: (j['gameName'] as String?) ?? (j['gameCode'] as String),
      difficulty: (j['difficulty'] as int?) ?? 2,
      status: ChallengeStatus.parse(j['status'] as String?),
      createdAt: parseServerDate(j['createdAt']),
      acceptedAt:
          j['acceptedAt'] == null ? null : parseServerDate(j['acceptedAt']),
      completedAt:
          j['completedAt'] == null ? null : parseServerDate(j['completedAt']),
      challenger: ChallengeUser.fromJson(
          (j['challenger'] as Map).cast<String, dynamic>()),
      opponent:
          ChallengeUser.fromJson((j['opponent'] as Map).cast<String, dynamic>()),
      myResult: res(j['myResult']),
      theirResult: res(j['theirResult']),
      winnerId: j['winnerId'] as int?,
      seed: j['seed'] as int?,
    );
  }
}

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
    this.isRead = false,
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

class Conversation {
  final int userId;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final String lastMessage;
  final DateTime lastMessageAt;
  final bool lastFromMe;
  final int unreadCount;

  const Conversation({
    required this.userId,
    required this.username,
    this.fullName,
    this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageAt,
    this.lastFromMe = false,
    this.unreadCount = 0,
  });

  String get displayName => (fullName != null && fullName!.trim().isNotEmpty)
      ? fullName!.trim()
      : username;

  UserSummary get user => UserSummary(
        userId: userId,
        username: username,
        fullName: fullName,
        avatarUrl: avatarUrl,
      );

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        userId: j['userId'] as int,
        username: j['username'] as String,
        fullName: j['fullName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        lastMessage: (j['lastMessage'] as String?) ?? '',
        lastMessageAt: parseServerDate(j['lastMessageAt']),
        lastFromMe: (j['lastFromMe'] as bool?) ?? false,
        unreadCount: (j['unreadCount'] as int?) ?? 0,
      );
}

class SocialSummary {
  final int unreadMessages;
  final int incomingChallenges;
  final int activeChallenges;

  /// Lời mời kết bạn đang chờ mình trả lời (`incomingFriendRequests` hoặc
  /// `pendingFriendRequests` trong `/social/summary`).
  final int incomingFriendRequests;
  const SocialSummary({
    this.unreadMessages = 0,
    this.incomingChallenges = 0,
    this.activeChallenges = 0,
    this.incomingFriendRequests = 0,
  });

  /// Số hiển thị trên huy hiệu Bạn bè: lời mời kết bạn + tin chưa đọc +
  /// lời thách đang chờ trả lời.
  int get badgeCount =>
      unreadMessages + incomingChallenges + incomingFriendRequests;

  SocialSummary copyWith({
    int? unreadMessages,
    int? incomingChallenges,
    int? activeChallenges,
    int? incomingFriendRequests,
  }) =>
      SocialSummary(
        unreadMessages: unreadMessages ?? this.unreadMessages,
        incomingChallenges: incomingChallenges ?? this.incomingChallenges,
        activeChallenges: activeChallenges ?? this.activeChallenges,
        incomingFriendRequests:
            incomingFriendRequests ?? this.incomingFriendRequests,
      );

  factory SocialSummary.fromJson(Map<String, dynamic> j) => SocialSummary(
        unreadMessages: (j['unreadMessages'] as int?) ?? 0,
        incomingChallenges: (j['incomingChallenges'] as int?) ?? 0,
        activeChallenges: (j['activeChallenges'] as int?) ?? 0,
        incomingFriendRequests: (j['incomingFriendRequests'] as int?) ??
            (j['pendingFriendRequests'] as int?) ??
            (j['friendRequests'] as int?) ??
            0,
      );
}
