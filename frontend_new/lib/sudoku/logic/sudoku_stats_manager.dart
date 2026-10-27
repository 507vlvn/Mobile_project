import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/network/models.dart';

class SudokuStatsManager extends ChangeNotifier {
  static final SudokuStatsManager instance = SudokuStatsManager._();
  SudokuStatsManager._();

  int? _currentUserId;
  ApiClient? _api;
  bool _isLoaded = false;

  /// Số mức độ khó Sudoku: Dễ, Trung bình, Khó, Chuyên gia, Ác mộng.
  static const int difficultyCount = 5;

  final Map<int, DifficultyStats> _stats = {
    for (int d = 1; d <= difficultyCount; d++) d: DifficultyStats(difficulty: d),
  };

  void attachApi(ApiClient api) => _api = api;
  ApiClient? get api => _api;

  String get _prefKey => 'sudoku_stats_${_currentUserId ?? "guest"}';

  DifficultyStats getStats(int difficulty) {
    return _stats[difficulty] ?? DifficultyStats(difficulty: difficulty);
  }

  Future<void> switchUser(int? userId) async {
    if (_currentUserId == userId && _isLoaded) return;
    _currentUserId = userId;
    _isLoaded = false;
    _resetToDefaults();
    notifyListeners();
    await init();
  }

  void _resetToDefaults() {
    for (int d = 1; d <= difficultyCount; d++) {
      _stats[d] = DifficultyStats(difficulty: d);
    }
  }

  Future<void> init({ApiClient? api, int? userId}) async {
    if (api != null) _api = api;
    if (userId != null && userId != _currentUserId) {
      await switchUser(userId);
      return;
    } else if (userId != null) {
      _currentUserId = userId;
    }

    if (!_isLoaded) {
      await _loadLocalCache();
      _isLoaded = true;
      notifyListeners();
    }

    if (_currentUserId != null) {
      unawaited(syncWithServer());
    }
  }

  Future<void> syncWithServer() async {
    if (_api == null || _currentUserId == null) return;
    try {
      final serverStats = await _api!.getSudokuDifficultyStats();
      if (serverStats.isNotEmpty) {
        for (final stat in serverStats) {
          _stats[stat.difficulty] = stat;
        }
        await _saveLocalCache();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _loadLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_prefKey);
      if (str != null) {
        final Map<String, dynamic> decoded = jsonDecode(str);
        decoded.forEach((key, val) {
          final d = int.tryParse(key);
          if (d != null && val is Map<String, dynamic>) {
            _stats[d] = DifficultyStats.fromJson(val);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        for (final e in _stats.entries) e.key.toString(): e.value.toJson(),
      };
      await prefs.setString(_prefKey, jsonEncode(map));
    } catch (_) {}
  }

  Future<void> recordGameStarted(int difficulty) async {
    final s = getStats(difficulty);
    s.gamesStarted++;
    notifyListeners();
    await _saveLocalCache();

    if (_api != null && _currentUserId != null) {
      unawaited(_api!.recordSudokuDifficultyStat(
        difficulty: difficulty,
        isGameStarted: true,
      ));
    }
  }

  Future<void> recordGameWon(int difficulty, int elapsedSeconds, {int mistakes = 0}) async {
    final s = getStats(difficulty);
    s.gamesWon++;
    if (mistakes == 0) {
      s.winWithoutMistakes++;
    }
    if (s.bestTimeSeconds == null || s.bestTimeSeconds == 0 || elapsedSeconds < s.bestTimeSeconds!) {
      s.bestTimeSeconds = elapsedSeconds;
    }
    s.totalWinTimeSeconds += elapsedSeconds;
    notifyListeners();
    await _saveLocalCache();

    if (_api != null && _currentUserId != null) {
      unawaited(_api!.recordSudokuDifficultyStat(
        difficulty: difficulty,
        isWin: true,
        elapsedSeconds: elapsedSeconds,
        mistakes: mistakes,
      ));
    }
  }
}
