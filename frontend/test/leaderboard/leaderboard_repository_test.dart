import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/network/api_exception.dart';
import 'package:mobile_rubik/core/network/models.dart';
import 'package:mobile_rubik/features/leaderboard/leaderboard_controller.dart';
import 'package:mobile_rubik/features/leaderboard/leaderboard_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/fakes.dart';

const _rubikAll = BoardQuery(gameCode: 'RUBIK', board: BoardType.record);

void main() {
  late FakeApiClient api;
  late DateTime now;
  late LeaderboardRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = FakeApiClient()
      ..onLeaderboard = ((q) async => const [
            BoardEntry(
                rank: 1,
                userId: 1,
                username: 'a',
                value: 900,
                bestTimeSeconds: 60),
          ])
      ..onMyRank =
          ((q) async => const BoardMe(rank: 5, value: 500, bestTimeSeconds: 90))
      ..onSeason = () async => SeasonInfo(
            startsAt: DateTime.utc(2026, 10, 19),
            endsAt: DateTime.utc(2026, 10, 26),
          );
    now = DateTime(2026, 1, 1, 12);
    repo = LeaderboardRepository(api, clock: () => now);
  });

  test('second load within 60s uses cache', () async {
    await repo.load(_rubikAll, userId: 7);
    now = now.add(const Duration(seconds: 59));
    final d = await repo.load(_rubikAll, userId: 7);
    expect(api.leaderboardCalls, 1);
    expect(api.myRankCalls, 1);
    expect(d.me?.rank, 5);
  });

  test('refetches after TTL expires', () async {
    await repo.load(_rubikAll, userId: 7);
    now = now.add(const Duration(seconds: 61));
    await repo.load(_rubikAll, userId: 7);
    expect(api.leaderboardCalls, 2);
  });

  test('force bypasses cache', () async {
    await repo.load(_rubikAll);
    await repo.load(_rubikAll, force: true);
    expect(api.leaderboardCalls, 2);
  });

  test('cache is keyed by every query parameter and the user', () async {
    await repo.load(_rubikAll);
    await repo.load(const BoardQuery(gameCode: 'SUDOKU', board: BoardType.record));
    await repo.load(const BoardQuery(
        gameCode: 'RUBIK', board: BoardType.record, difficulty: 3));
    await repo.load(const BoardQuery(gameCode: 'RUBIK', board: BoardType.ranked));
    await repo.load(const BoardQuery(
        gameCode: 'RUBIK', board: BoardType.record, scope: BoardScope.friends));
    await repo.load(const BoardQuery(
        gameCode: 'RUBIK', board: BoardType.record, period: BoardPeriod.all));
    await repo.load(_rubikAll, userId: 7);
    expect(api.leaderboardCalls, 7);
  });

  test('query params match the REST contract', () {
    expect(
      const BoardQuery(
        gameCode: 'CARO',
        board: BoardType.record,
        difficulty: 2,
        scope: BoardScope.friends,
        period: BoardPeriod.all,
      ).toQuery(),
      {
        'gameCode': 'CARO',
        'board': 'record',
        'difficulty': 2,
        'scope': 'friends',
        'period': 'all',
      },
    );
    // Ranked bỏ qua độ khó; "tất cả độ khó" = không gửi difficulty
    expect(
      const BoardQuery(gameCode: 'CARO', board: BoardType.ranked, difficulty: 2)
          .toQuery()
          .containsKey('difficulty'),
      isFalse,
    );
    expect(_rubikAll.toQuery().containsKey('difficulty'), isFalse);
    expect(_rubikAll.toQuery()['period'], 'season');
    expect(_rubikAll.toQuery()['scope'], 'global');
  });

  test('guest does not call /me', () async {
    final d = await repo.load(_rubikAll);
    expect(api.myRankCalls, 0);
    expect(d.me, isNull);
  });

  test('failed /me is not cached and does not fail the load', () async {
    api.onMyRank = (q) async => throw const ApiException('x', statusCode: 500);
    final d = await repo.load(_rubikAll, userId: 7);
    expect(d.entries.length, 1);
    expect(d.me, isNull);
    expect(repo.cached(_rubikAll, 7), isNull);
  });

  test('top-list failure propagates', () async {
    api.onLeaderboard = (q) async =>
        throw const ApiException(ApiException.networkMessage, isNetwork: true);
    expect(() => repo.load(_rubikAll), throwsA(isA<ApiException>()));
  });

  test('season is cached for 5 minutes', () async {
    await repo.season();
    now = now.add(const Duration(minutes: 4));
    await repo.season();
    expect(api.seasonCalls, 1);
    now = now.add(const Duration(minutes: 2));
    await repo.season();
    expect(api.seasonCalls, 2);
  });

  group('LeaderboardController', () {
    test('guest chọn Bạn bè: không gọi API, cần đăng nhập', () async {
      final c = LeaderboardController(repository: repo);
      await c.reload();
      c.select(c.selection.copyWith(scope: BoardScope.friends));
      await Future<void>.delayed(Duration.zero);
      expect(c.needsLogin, isTrue);
      expect(api.lastBoardQuery?.scope, isNot(BoardScope.friends));
      c.dispose();
    });

    test('đổi lựa chọn tải bảng mới và nhớ lựa chọn', () async {
      final c = LeaderboardController(repository: repo);
      c.setUser(7);
      await c.reload();
      c.select(c.selection.copyWith(
          gameCode: 'CARO', board: BoardType.ranked, period: BoardPeriod.all));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(api.lastBoardQuery?.gameCode, 'CARO');
      expect(api.lastBoardQuery?.board, BoardType.ranked);
      expect(api.lastBoardQuery?.period, BoardPeriod.all);
      expect(c.data?.entries.single.rank, 1);

      final saved = await BoardSelection.load();
      expect(saved.gameCode, 'CARO');
      expect(saved.board, BoardType.ranked);
      expect(saved.period, BoardPeriod.all);
      c.dispose();
    });

    test('mặc định: Kỷ lục, Tất cả độ khó, Toàn server, Mùa này', () async {
      final s = await BoardSelection.load();
      expect(s.board, BoardType.record);
      expect(s.difficulty, isNull);
      expect(s.scope, BoardScope.global);
      expect(s.period, BoardPeriod.season);
    });

    test('đếm ngược mùa lấy từ /leaderboard/season', () async {
      final c = LeaderboardController(
          repository: repo, clock: () => DateTime.utc(2026, 10, 23, 8));
      await c.reload();
      expect(c.season, isNotNull);
      expect(seasonCountdownVi(c.seasonRemaining!), 'Mùa kết thúc sau 2 ngày 16 giờ');
      c.dispose();
    });
  });

  test('seasonCountdownVi', () {
    expect(seasonCountdownVi(const Duration(days: 3, hours: 4, minutes: 20)),
        'Mùa kết thúc sau 3 ngày 4 giờ');
    expect(seasonCountdownVi(const Duration(hours: 5, minutes: 7)),
        'Mùa kết thúc sau 5 giờ 7 phút');
    expect(seasonCountdownVi(const Duration(seconds: 20)),
        'Mùa kết thúc sau 1 phút');
    expect(seasonCountdownVi(Duration.zero), 'Mùa vừa kết thúc');
  });
}
