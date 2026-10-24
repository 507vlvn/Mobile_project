import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/difficulty.dart';

class PhaseShiftScoreService {
  static const String _keyPrefix = 'phaseshift_high_score_';

  static Future<int> getHighScore(GameDifficulty difficulty) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('$_keyPrefix${difficulty.name}') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> saveHighScore(GameDifficulty difficulty, int score) async {
    try {
      final currentHigh = await getHighScore(difficulty);
      if (score > currentHigh) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('$_keyPrefix${difficulty.name}', score);
        return true; // New record!
      }
    } catch (_) {}
    return false;
  }
}
