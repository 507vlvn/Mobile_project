import 'package:flutter/foundation.dart';

import 'package:frontend_new/core/network/api_client.dart';
import 'package:frontend_new/core/network/models.dart';
import 'package:frontend_new/core/services/score_reporter.dart';

/// ApiClient giả cho test nộp điểm: chỉ cài [submitHistory], các hàm khác
/// ném lỗi nếu bị gọi (qua [noSuchMethod]).
class FakeApiClient implements ApiClient {
  @override
  VoidCallback? onUnauthorized;

  /// Cách server giả trả lời mỗi lần nộp điểm.
  Future<SubmitResult> Function(GameRecord r)? onSubmit;

  /// Các bản ghi đã được gửi (theo thứ tự).
  final List<GameRecord> submitted = [];

  @override
  Future<SubmitResult> submitHistory(GameRecord record) {
    submitted.add(record);
    return onSubmit!(record);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeApiClient: ${invocation.memberName}');
}

SubmitResult fakeSubmitResult(GameRecord r,
        {int score = 1234, bool best = true}) =>
    SubmitResult(score: score, isPersonalBest: best);
