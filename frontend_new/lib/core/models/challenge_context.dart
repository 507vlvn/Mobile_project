import 'difficulty.dart';

/// Ngữ cảnh một ván thách đấu. Cả hai người chơi sinh CÙNG một đề từ [seed]
/// (ví dụ `Random(seed)` làm nguồn ngẫu nhiên cho bộ sinh đề) và gửi kết quả
/// kèm `challengeId` khi hoàn thành.
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
