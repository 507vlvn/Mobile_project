import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';

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

  ApiClient? _api;
  int? _currentUserId;

  String get _prefKey => 'sudoku_learning_progress_${_currentUserId ?? "guest"}';

  // Lưu trữ thời gian hoàn thành tốt nhất của từng level (level -> seconds)
  final Map<int, int> _bestTimes = {};
  int _highestUnlockedLevel = 1;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  int get completedCount => _bestTimes.length;
  int get highestUnlockedLevel => _highestUnlockedLevel;
  int? get currentUserId => _currentUserId;

  void attachApi(ApiClient api) {
    _api = api;
  }

  /// Lấy kỷ lục thời gian của một level (nếu có)
  int? getBestTimeForLevel(int level) => _bestTimes[level];

  /// Đổi tài khoản: dọn sạch dữ liệu cũ và nạp dữ liệu riêng của tài khoản đó
  Future<void> switchUser(int? userId) async {
    if (_currentUserId == userId && _isLoaded) return;
    _currentUserId = userId;
    _isLoaded = false;
    _bestTimes.clear();
    _highestUnlockedLevel = 1;
    notifyListeners();
    await init();
  }

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

  Future<void> init({ApiClient? api, int? userId}) async {
    if (api != null) _api = api;
    if (userId != null) _currentUserId = userId;

    // 1. Luôn tải cache từ local SharedPreferences theo đúng UserId trước (Offline-first)
    if (!_isLoaded) {
      await _loadLocalCache();
      _isLoaded = true;
      notifyListeners();
    }

    // 2. Đồng bộ với Database server theo tài khoản hiện tại
    await syncWithServer();
  }

  Future<void> _loadLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_prefKey);
      _bestTimes.clear();
      if (dataStr != null) {
        final Map<String, dynamic> decoded = jsonDecode(dataStr);
        decoded.forEach((k, v) {
          final lvl = int.tryParse(k);
          if (lvl != null && v is int) {
            _bestTimes[lvl] = v;
          }
        });
      }
      _recalculateHighestUnlocked();
    } catch (e) {
      debugPrint('Lỗi đọc tiến trình học tập từ cache ($_prefKey): $e');
    }
  }

  void _recalculateHighestUnlocked() {
    if (_bestTimes.isNotEmpty) {
      final maxCompleted = _bestTimes.keys.reduce((a, b) => a > b ? a : b);
      _highestUnlockedLevel = (maxCompleted + 1).clamp(1, totalLevels);
    } else {
      _highestUnlockedLevel = 1;
    }
  }

  Future<void> _saveLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> mapToSave = {
        for (var entry in _bestTimes.entries) entry.key.toString(): entry.value,
      };
      await prefs.setString(_prefKey, jsonEncode(mapToSave));
    } catch (e) {
      debugPrint('Lỗi lưu cache tiến trình học tập: $e');
    }
  }

  /// Đồng bộ hai chiều với Server Database theo tài khoản
  Future<void> syncWithServer() async {
    if (_api == null) return;
    try {
      final summary = await _api!.getSudokuProgress();

      // Nếu đang đăng nhập tài khoản, Database server là nguồn chuẩn xác nhất
      _bestTimes.clear();
      for (final lvl in summary.levels) {
        if (lvl.bestTimeSeconds != null) {
          _bestTimes[lvl.level] = lvl.bestTimeSeconds!;
        }
      }

      _highestUnlockedLevel = summary.highestUnlockedLevel.clamp(1, totalLevels);

      await _saveLocalCache();
      notifyListeners();
    } catch (e) {
      debugPrint('Không thể đồng bộ tiến trình Sudoku với máy chủ: $e');
    }
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

  /// Ghi nhận chiến thắng, cập nhật kỷ lục thời gian tốt nhất
  /// Trả về true nếu lần này là kỷ lục mới (thời gian ngắn hơn kỷ lục cũ)
  Future<bool> recordWin(int level, int timeSeconds, {int mistakes = 0}) async {
    final currentBest = _bestTimes[level];
    bool isNewBest = false;

    // Cập nhật kỷ lục nếu chưa từng chơi hoặc thời gian mới nhanh hơn
    if (currentBest == null || timeSeconds < currentBest) {
      _bestTimes[level] = timeSeconds;
      isNewBest = true;
    }

    if (level >= _highestUnlockedLevel && level < totalLevels) {
      _highestUnlockedLevel = level + 1;
    }

    notifyListeners();
    await _saveLocalCache();

    // Đồng bộ lên Server Database
    if (_api != null) {
      try {
        final res = await _api!.recordSudokuProgress(
          level: level,
          timeSpentSeconds: timeSeconds,
          mistakes: mistakes,
        );
        // Cập nhật lại kỷ lục chính xác từ server phản hồi
        if (res.bestTimeSeconds > 0) {
          _bestTimes[level] = res.bestTimeSeconds;
        }
        if (res.nextUnlockedLevel > _highestUnlockedLevel) {
          _highestUnlockedLevel = res.nextUnlockedLevel;
        }
        notifyListeners();
        await _saveLocalCache();
      } catch (e) {
        debugPrint('Lỗi nộp tiến trình Sudoku lên Database: $e');
      }
    }

    return isNewBest;
  }
}
