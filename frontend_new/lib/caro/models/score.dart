import 'difficulty.dart';

/// Công thức điểm (giống hệt ScoreCalculator phía server).
int computeScore({
  required Difficulty difficulty,
  required int timeSeconds,
  required int mistakes,
  bool completed = true,
}) {
  if (!completed) return 0;
  final base = difficulty.value * 1000;
  final raw = base - timeSeconds - mistakes * 50;
  final floor = base ~/ 10;
  return raw < floor ? floor : raw;
}
