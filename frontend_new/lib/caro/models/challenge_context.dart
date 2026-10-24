import 'difficulty.dart';

/// Ngữ cảnh một ván thách đấu.
class ChallengeContext {
  final int challengeId;
  final String gameCode;
  final Difficulty difficulty;

  const ChallengeContext({
    required this.challengeId,
    required this.gameCode,
    required this.difficulty,
  });

  /// Seed xác định của đề = id thách đấu.
  int get seed => challengeId;
}
