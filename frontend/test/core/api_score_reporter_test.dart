import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/models/difficulty.dart';
import 'package:mobile_rubik/core/network/api_exception.dart';
import 'package:mobile_rubik/core/services/api_score_reporter.dart';
import 'package:mobile_rubik/core/services/score_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

GameRecord rec(int seconds) => GameRecord(
      gameCode: 'SUDOKU',
      difficulty: Difficulty.easy,
      timeSeconds: seconds,
      mistakes: 0,
      outcome: GameOutcome.completed,
    );

const net = ApiException(ApiException.networkMessage, isNetwork: true);

void main() {
  late FakeApiClient api;
  var loggedIn = true;

  ApiScoreReporter make() => ApiScoreReporter(
      api: api, isLoggedIn: () => loggedIn, gap: Duration.zero);

  Future<List<String>> queue() async =>
      (await SharedPreferences.getInstance())
          .getStringList(ApiScoreReporter.queueKey) ??
      [];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = FakeApiClient();
    loggedIn = true;
  });

  test('guest: local score + login message, no request', () async {
    loggedIn = false;
    api.onSubmit = (_) async => fail('không được gọi');
    final o = await make().submit(rec(100));
    expect(o.score, rec(100).localScore);
    expect(o.synced, false);
    expect(o.message, ApiScoreReporter.guestMessage);
    expect(api.submitted, isEmpty);
  });

  test('logged in success: server score + personal best', () async {
    api.onSubmit = (r) async => fakeSubmitResult(r, score: 777, best: true);
    final o = await make().submit(rec(100));
    expect(o.score, 777);
    expect(o.isPersonalBest, true);
    expect(o.synced, true);
    expect(await queue(), isEmpty);
  });

  test('network failure: queued, local score, message; never throws', () async {
    api.onSubmit = (_) async => throw net;
    final o = await make().submit(rec(100));
    expect(o.synced, false);
    expect(o.score, rec(100).localScore);
    expect(o.message, ApiScoreReporter.queuedMessage);
    final q = await queue();
    expect(q.length, 1);
    expect(jsonDecode(q.first)['timeSpentSeconds'], 100);
    expect(api.submitted.length, 1, reason: 'POST không tự thử lại');
  });

  test('4xx validation error: not queued, message from server', () async {
    api.onSubmit = (_) async => throw const ApiException(
        'Thời gian chơi không hợp lệ',
        statusCode: 400);
    final o = await make().submit(rec(100));
    expect(o.message, 'Thời gian chơi không hợp lệ');
    expect(o.score, rec(100).localScore);
    expect(await queue(), isEmpty);
  });

  test('unexpected error never throws', () async {
    api.onSubmit = (_) async => throw StateError('boom');
    final o = await make().submit(rec(100));
    expect(o.synced, false);
  });

  test('flush sends in order and empties the queue', () async {
    api.onSubmit = (_) async => throw net;
    final reporter = make();
    await reporter.submit(rec(1));
    await reporter.submit(rec(2));
    await reporter.submit(rec(3));
    api.submitted.clear();
    api.onSubmit = (r) async => fakeSubmitResult(r);
    await reporter.flushQueue();
    expect(api.submitted.map((r) => r.timeSeconds), [1, 2, 3]);
    expect(await queue(), isEmpty);
  });

  test('flush stops at first network failure and keeps the rest', () async {
    api.onSubmit = (_) async => throw net;
    final reporter = make();
    for (final s in [1, 2, 3]) {
      await reporter.submit(rec(s));
    }
    api.submitted.clear();
    api.onSubmit = (r) async {
      if (r.timeSeconds == 2) throw net;
      return fakeSubmitResult(r);
    };
    await reporter.flushQueue();
    expect(api.submitted.map((r) => r.timeSeconds), [1, 2]);
    final q = await queue();
    expect(q.map((e) => jsonDecode(e)['timeSpentSeconds']), [2, 3]);
  });

  test('flush drops records rejected with 4xx and continues', () async {
    api.onSubmit = (_) async => throw net;
    final reporter = make();
    for (final s in [1, 2]) {
      await reporter.submit(rec(s));
    }
    api.submitted.clear();
    api.onSubmit = (r) async {
      if (r.timeSeconds == 1) {
        throw const ApiException('bad', statusCode: 400);
      }
      return fakeSubmitResult(r);
    };
    await reporter.flushQueue();
    expect(api.submitted.map((r) => r.timeSeconds), [1, 2]);
    expect(await queue(), isEmpty);
  });

  test('flush does nothing for guests', () async {
    api.onSubmit = (_) async => throw net;
    await make().submit(rec(1));
    loggedIn = false;
    api.submitted.clear();
    await make().flushQueue();
    expect(api.submitted, isEmpty);
    expect((await queue()).length, 1);
  });
}
