import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'score_reporter.dart';

/// Nộp điểm lên server; khách thì chỉ tính điểm tại máy; mất mạng thì xếp
/// hàng đợi (shared_preferences) và gửi lại tuần tự sau. Không bao giờ ném lỗi.
class ApiScoreReporter implements ScoreReporter {
  ApiScoreReporter({
    required ApiClient api,
    required bool Function() isLoggedIn,
    this.gap = const Duration(milliseconds: 500),
  })  : _api = api,
        _isLoggedIn = isLoggedIn;

  static const queueKey = 'score_queue_v1';
  static const guestMessage = 'Đăng nhập để lưu điểm lên bảng xếp hạng';
  static const queuedMessage =
      'Chưa có mạng — điểm đã lưu tạm và sẽ tự gửi sau';

  final ApiClient _api;
  final bool Function() _isLoggedIn;

  /// Khoảng nghỉ giữa hai lần gửi khi xả hàng đợi.
  final Duration gap;
  bool _flushing = false;

  @override
  Future<ReportOutcome> submit(GameRecord record) async {
    final local = record.localScore;
    if (!_isLoggedIn()) {
      return ReportOutcome(score: local, message: guestMessage);
    }
    try {
      final r = await _api.submitHistory(record);
      return ReportOutcome(
        score: r.record.score,
        isPersonalBest: r.isPersonalBest,
        synced: true,
      );
    } on ApiException catch (e) {
      if (e.isConnectivity || (e.statusCode != null && e.statusCode! >= 500)) {
        await _enqueue(record);
        return ReportOutcome(score: local, message: queuedMessage);
      }
      if (e.isUnauthorized) {
        return ReportOutcome(score: local, message: guestMessage);
      }
      return ReportOutcome(score: local, message: e.message);
    } catch (_) {
      return ReportOutcome(
        score: local,
        message: 'Không lưu được điểm lên máy chủ.',
      );
    }
  }

  /// Số bản ghi đang chờ gửi.
  Future<int> pendingCount() async => (await _readQueue()).length;

  /// Gửi lần lượt từng bản ghi trong hàng đợi (nghỉ [gap] giữa các lần).
  /// Dừng ngay khi lỗi mạng / 401 / 5xx; bỏ bản ghi bị 4xx (không hợp lệ).
  Future<void> flushQueue() async {
    if (_flushing || !_isLoggedIn()) return;
    _flushing = true;
    try {
      var first = true;
      while (true) {
        final queue = await _readQueue();
        if (queue.isEmpty) break;
        if (!first && gap > Duration.zero) await Future<void>.delayed(gap);
        first = false;
        if (!_isLoggedIn()) break;

        GameRecord record;
        try {
          record = GameRecord.fromJson(
              jsonDecode(queue.first) as Map<String, dynamic>);
        } catch (_) {
          await _writeQueue(queue.sublist(1)); // bản ghi hỏng
          continue;
        }
        try {
          await _api.submitHistory(record);
          await _writeQueue((await _readQueue()).sublist(1));
        } on ApiException catch (e) {
          if (e.isUnauthorized || e.isConnectivity || !e.isClientError) break;
          await _writeQueue((await _readQueue()).sublist(1)); // 4xx: bỏ
        } catch (_) {
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _enqueue(GameRecord record) async {
    final q = await _readQueue();
    q.add(jsonEncode(record.toJson()));
    await _writeQueue(q);
  }

  Future<List<String>> _readQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return List<String>.of(prefs.getStringList(queueKey) ?? const []);
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeQueue(List<String> q) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(queueKey, q);
    } catch (_) {}
  }
}
