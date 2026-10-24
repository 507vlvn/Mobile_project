import 'package:mobile_rubik/core/network/models.dart';

ChatMessage msg(
  int id, {
  int from = 2,
  int to = 7,
  String text = 'hi',
  bool read = false,
  DateTime? at,
}) =>
    ChatMessage(
      messageId: id,
      senderId: from,
      receiverId: to,
      content: text,
      isRead: read,
      sentAt: at ?? DateTime(2026, 10, 14, 9, 0).add(Duration(minutes: id)),
    );

Challenge challenge(
  int id, {
  ChallengeStatus status = ChallengeStatus.pending,
  int challengerId = 7,
  int opponentId = 2,
  String game = 'SUDOKU',
  int difficulty = 2,
  DateTime? createdAt,
  DateTime? completedAt,
  ChallengeResult? mine,
  ChallengeResult? theirs,
  int? winnerId,
}) =>
    Challenge(
      id: id,
      gameCode: game,
      gameName: game,
      difficulty: difficulty,
      status: status,
      createdAt: createdAt ?? DateTime(2026, 10, 14).add(Duration(minutes: id)),
      completedAt: completedAt,
      challenger: ChallengeUser(userId: challengerId, username: 'u$challengerId'),
      opponent: ChallengeUser(userId: opponentId, username: 'u$opponentId'),
      myResult: mine,
      theirResult: theirs,
      winnerId: winnerId,
    );
