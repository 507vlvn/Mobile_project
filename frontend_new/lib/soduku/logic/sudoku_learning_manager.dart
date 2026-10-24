import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LearningLevelInfo {
  final int level;
  final int clues;
  final bool isUnlocked;
  final int? bestTimeSeconds;

  const LearningLevelInfo({
    required this.level,
    required this.clues,
    required this.isUnlocked,
    this.bestTimeSeconds,
  });

  bool get isCompleted => bestTimeSeconds != null;

  String get timeFormatted {
    if (bestTimeSeconds == null) return '--:--';
    final m = (bestTimeSeconds! ~/ 60).toString().padLeft(2, '0');
    final s = (bestTimeSeconds! % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class SudokuLearningManager extends ChangeNotifier {
  static final SudokuLearningManager instance = SudokuLearningManager._();
  SudokuLearningManager._();

  static const int totalLevels = 30;
  static const String _prefKey = 'sudoku_learning_progress';

  // Lưu trữ thời gian hoàn thành tốt nhất của từng level (level -> seconds)
  final Map<int, int> _bestTimes = {};
  int _highestUnlockedLevel = 1;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  int get completedCount => _bestTimes.length;
  int get highestUnlockedLevel => _highestUnlockedLevel;

  /// Tính số ô cho sẵn (clues) theo level từ 1 đến 30:
  /// Level 1: 50 ô (rất dễ để học)
  /// Level 30: 18 ô (thử thách đỉnh cao)
  static int getCluesForLevel(int level) {
    if (level <= 1) return 50;
    if (level >= totalLevels) return 18;
    return 50 - ((level - 1) * (50 - 18) ~/ (totalLevels - 1));
  }

  /// Seed cố định cho từng level để mỗi màn có đề bài đặc trưng
  static int getSeedForLevel(int level) => 888000 + level * 101;

  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_prefKey);
      if (dataStr != null) {
        final Map<String, dynamic> decoded = jsonDecode(dataStr);
        _bestTimes.clear();
        decoded.forEach((k, v) {
          final lvl = int.tryParse(k);
          if (lvl != null && v is int) {
            _bestTimes[lvl] = v;
          }
        });
      }
      // Level mở khóa cao nhất = level cao nhất đã hoàn thành + 1
      if (_bestTimes.isNotEmpty) {
        final maxCompleted = _bestTimes.keys.reduce((a, b) => a > b ? a : b);
        _highestUnlockedLevel = (maxCompleted + 1).clamp(1, totalLevels);
      } else {
        _highestUnlockedLevel = 1;
      }
    } catch (e) {
      debugPrint('Lỗi đọc tiến trình học tập: $e');
    }
    _isLoaded = true;
    notifyListeners();
  }

  List<LearningLevelInfo> getLevels() {
    return List.generate(totalLevels, (i) {
      final lvl = i + 1;
      final isUnlocked = lvl <= _highestUnlockedLevel;
      final bestTime = _bestTimes[lvl];

      return LearningLevelInfo(
        level: lvl,
        clues: getCluesForLevel(lvl),
        isUnlocked: isUnlocked,
        bestTimeSeconds: bestTime,
      );
    });
  }

  Future<void> recordWin(int level, int timeSeconds) async {
    final currentBest = _bestTimes[level];
    if (currentBest == null || timeSeconds < currentBest) {
      _bestTimes[level] = timeSeconds;
    }

    if (level >= _highestUnlockedLevel && level < totalLevels) {
      _highestUnlockedLevel = level + 1;
    }

    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> mapToSave = {
        for (var entry in _bestTimes.entries) entry.key.toString(): entry.value,
      };
      await prefs.setString(_prefKey, jsonEncode(mapToSave));
    } catch (e) {
      debugPrint('Lỗi lưu tiến trình học tập: $e');
    }
  }
}
