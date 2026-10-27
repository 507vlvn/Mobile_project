import 'dart:math' as math;

import 'difficulty.dart';

/// Thời gian chuẩn (par, giây) theo game và độ khó — TASKS_V2 §2.1.
/// CARO không dùng thời gian: par tính theo số nước (xem [caroParMoves]).
/// Sudoku có thêm mức 4 (Chuyên gia) và 5 (Ác mộng).
const Map<String, List<int>> kParSeconds = {
  'SUDOKU': [6 * 60, 12 * 60, 25 * 60, 2000, 50 * 60],
  'PUZZLE': [60, 4 * 60, 10 * 60],
  'RUBIK': [90, 4 * 60, 10 * 60],
};

/// Số nước chuẩn khi thắng máy Caro: Dễ / Vừa / Khó.
const List<int> caroParMoves = [20, 30, 45];

/// Hệ số thời gian được giới hạn trong khoảng này.
const double kMinTimeFactor = 0.25;
const double kMaxTimeFactor = 1.5;

/// Mỗi lỗi nhân điểm với hệ số này.
const double kMistakeFactor = 0.92;

/// Mỗi lần dùng gợi ý nhân điểm với hệ số này (nặng hơn lỗi vì cho thẳng đáp án).
const double kHintFactor = 0.85;

/// Caro hòa được 30% điểm.
const double kCaroDrawShare = 0.3;

/// Par của [gameCode] ở [difficulty] (giây, hoặc số nước với CARO).
/// [level] (4–5, chỉ Sudoku) thay cho [difficulty] khi có.
int parFor(String gameCode, Difficulty difficulty, {int? level}) {
  if (gameCode == 'CARO') return caroParMoves[difficulty.value - 1];
  final table = kParSeconds[gameCode] ?? kParSeconds['PUZZLE']!;
  return table[((level ?? difficulty.value) - 1).clamp(0, table.length - 1)];
}

/// Công thức điểm v2 (giống hệt ScoreCalculator phía server — server là nguồn chuẩn).
/// Chỉ dùng ở client để hiển thị tạm khi chưa đăng nhập / mất mạng.
///
/// ```
/// hệ số = clamp(par / thực tế, 0.25, 1.5)      // thực tế = giây (CARO: số nước)
/// điểm  = round(base × hệ số × 0.92^lỗi × 0.85^gợi ý)   // base = 1000 / 2000 / 3000
/// ```
/// [completed] = false (thua / bỏ cuộc) cho 0 điểm.
int computeScore({
  required String gameCode,
  required Difficulty difficulty,
  required int timeSeconds,
  required int mistakes,
  int moves = 0,
  int hints = 0,
  int? level,
  bool completed = true,
}) {
  if (!completed) return 0;
  final base = (level ?? difficulty.value) * 1000;
  final par = parFor(gameCode, difficulty, level: level);
  final actual = gameCode == 'CARO' ? moves : timeSeconds;
  final timeFactor = actual <= 0
      ? kMaxTimeFactor
      : (par / actual).clamp(kMinTimeFactor, kMaxTimeFactor).toDouble();
  final mistakeFactor = math.pow(kMistakeFactor, mistakes < 0 ? 0 : mistakes);
  final hintFactor = math.pow(kHintFactor, hints < 0 ? 0 : hints);
  return (base * timeFactor * mistakeFactor * hintFactor).round();
}
