import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_new/core/models/rank.dart';
import 'package:frontend_new/core/network/api_client.dart';
import 'package:frontend_new/core/network/models.dart';
import 'package:frontend_new/leaderboard/leaderboard_controller.dart';

class _Api implements ApiClient {
  final calls = <String>[];
  Completer<void>? gate;

  @override
  VoidCallback? onUnauthorized;

  @override
  Future<SeasonInfo> season() async {
    calls.add('season');
    return SeasonInfo(start: DateTime(2026, 10, 19), end: DateTime(2026, 10, 26));
  }

  @override
  Future<List<LeaderboardEntry>> leaderboard(LeaderboardQuery query, {int top = 50}) async {
    calls.add('top ${query.key}');
    await gate?.future;
    return [
      LeaderboardEntry(
          rank: 1,
          user: UserSummary(userId: 9, username: query.gameCode.toLowerCase()),
          bestScore: 100),
    ];
  }

  @override
  Future<MyRank> myRank(LeaderboardQuery query) async {
    calls.add('me ${query.key}');
    return const MyRank(rank: 4, bestScore: 80, bestTimeSeconds: 90);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

void main() {
  group('Đọc DTO đúng như LeaderboardController.cs', () {
    test('LeaderboardEntryDto bảng kỷ lục', () {
      final e = LeaderboardEntry.fromJson({
        'rank': 3, 'userId': 9, 'username': 'an', 'fullName': 'Nguyễn An', 'avatarUrl': null,
        'bestScore': 2840, 'bestTimeSeconds': 312,
        'rating': null, 'tier': null, 'tierName': null, 'games': null, 'wins': null,
      });
      expect((e.rank, e.user.displayName, e.bestScore, e.bestTimeSeconds), (3, 'Nguyễn An', 2840, 312));
      expect(e.rating, isNull);
    });

    test('LeaderboardEntryDto bảng đối kháng', () {
      final e = LeaderboardEntry.fromJson({
        'rank': 1, 'userId': 9, 'username': 'an', 'fullName': null, 'avatarUrl': null,
        'bestScore': 1450, 'bestTimeSeconds': 0,
        'rating': 1450, 'tier': 'PLATINUM', 'tierName': 'Bạch kim', 'games': 20, 'wins': 14,
      });
      expect(e.rating, 1450);
      expect(e.tier, Tier.platinum);
      expect((e.games, e.wins), (20, 14));
    });

    test('MyRankDto khi chưa có trong bảng', () {
      final m = MyRank.fromJson({'rank': null, 'bestScore': null, 'bestTimeSeconds': null});
      expect(m.rank, isNull);
    });

    test('SeasonDto: đếm ngược theo giờ server', () {
      final s = SeasonInfo.fromJson({
        'startUtc': '2026-10-19T00:00:00Z',
        'endUtc': '2026-10-26T00:00:00Z',
        'now': DateTime.now().toUtc().toIso8601String(),
      });
      expect(s.end.difference(s.start).inDays, 7);
      expect(seasonCountdownVi(const Duration(days: 2, hours: 5)), '2 ngày 5 giờ');
      expect(seasonCountdownVi(const Duration(hours: 3, minutes: 12)), '3 giờ 12 phút');
    });

    test('LeaderboardQuery -> tham số query', () {
      expect(const LeaderboardQuery(gameCode: 'SUDOKU', difficulty: 2).toQuery(),
          {'gameCode': 'SUDOKU', 'board': 'record', 'difficulty': 2, 'scope': 'global', 'period': 'season'});
      expect(
          const LeaderboardQuery(gameCode: 'CARO', ranked: true, difficulty: 2, friendsOnly: true, season: false)
              .toQuery(),
          {'gameCode': 'CARO', 'board': 'ranked', 'scope': 'friends', 'period': 'all'},
          reason: 'bảng đối kháng không lọc độ khó');
    });
  });

  group('LeaderboardController', () {
    test('tải top + hạng của mình; đổi lại bộ lọc cũ thì dùng kết quả đã nhớ', () async {
      final api = _Api();
      final c = LeaderboardController(api: api, isLoggedIn: () => true);
      await c.load();
      expect(c.entries.single.user.username, 'sudoku');
      expect(c.myRank!.rank, 4);
      expect(c.season, isNotNull);

      await c.setQuery(c.query.copyWith(gameCode: 'RUBIK'));
      expect(c.entries.single.user.username, 'rubik');
      final n = api.calls.length;
      await c.setQuery(c.query.copyWith(gameCode: 'SUDOKU'));
      expect(c.entries.single.user.username, 'sudoku');
      expect(api.calls.length, n, reason: 'đã nhớ: không gọi lại API');

      await c.load(force: true);
      expect(api.calls.length, greaterThan(n), reason: 'kéo làm mới thì gọi lại');
      expect(api.calls.where((x) => x == 'season').length, 1, reason: 'mùa chỉ tải một lần');
    });

    test('chưa đăng nhập: không gọi /me; bảng bạn bè không gọi API', () async {
      final api = _Api();
      final c = LeaderboardController(api: api, isLoggedIn: () => false);
      await c.load();
      expect(api.calls.any((x) => x.startsWith('me')), isFalse);

      await c.setQuery(c.query.copyWith(friendsOnly: true));
      expect(c.needsLogin, isTrue);
      expect(api.calls.any((x) => x.contains('scope=friends')), isFalse);
    });

    test('đổi bộ lọc nhanh: kết quả cũ về sau không đè kết quả mới', () async {
      final oldGate = Completer<void>();
      final api = _Api()..gate = oldGate;
      final c = LeaderboardController(api: api, isLoggedIn: () => false);
      final slow = c.load(); // SUDOKU: treo chờ oldGate
      await Future<void>.delayed(Duration.zero);
      api.gate = null;
      await c.setQuery(c.query.copyWith(gameCode: 'CARO'));
      expect(c.entries.single.user.username, 'caro');

      oldGate.complete(); // request SUDOKU cũ giờ mới trả về
      await slow;
      expect(c.query.gameCode, 'CARO');
      expect(c.entries.single.user.username, 'caro', reason: 'không bị kết quả SUDOKU cũ đè');
    });

    test('đang tải bảng A mà chuyển sang bảng B đã nhớ: kết quả A về muộn không đè', () async {
      final api = _Api();
      final c = LeaderboardController(api: api, isLoggedIn: () => false);
      await c.setQuery(c.query.copyWith(gameCode: 'CARO')); // nhớ sẵn CARO
      final gate = Completer<void>();
      api.gate = gate;
      final slow = c.setQuery(c.query.copyWith(gameCode: 'RUBIK')); // RUBIK đang treo
      await Future<void>.delayed(Duration.zero);
      await c.setQuery(c.query.copyWith(gameCode: 'CARO')); // về bảng đã nhớ
      gate.complete();
      await slow;
      expect(c.entries.single.user.username, 'caro');
      expect(c.loading, isFalse);
    });
  });
}
