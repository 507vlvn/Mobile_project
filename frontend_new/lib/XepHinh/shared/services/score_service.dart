import '../models/difficulty.dart';

class ScoreService {
  static int calculateScore({
    required int moves,
    required int timeInSeconds,
    required GameDifficulty difficulty,
  }) {
    const int baseScore = 10000;
    final int difficultyMultiplier = difficulty.gridSize;
    final int moveDeduction = moves * 10;
    final int timeDeduction = timeInSeconds * 5;

    final int totalScore = (baseScore - moveDeduction - timeDeduction) * difficultyMultiplier;
    return totalScore > 0 ? totalScore : 100;
  }
}
