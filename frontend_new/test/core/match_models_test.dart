import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_new/core/models/rank.dart';
import 'package:frontend_new/core/network/token_storage.dart';
import 'package:frontend_new/core/realtime/hub_gateway.dart';
import 'package:frontend_new/core/realtime/realtime_service.dart';

import '../support/fake_realtime.dart';

/// Hub giả tối thiểu: ghi lại lệnh gọi, đẩy sự kiện xuống.
class _Gateway implements HubGateway {
  final handlers = <String, void Function(List<Object?>?)>{};
  final invoked = <String>[];
  Object? result;

  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<Object?> invoke(String method, List<Object> args) async {
    invoked.add('$method ${args.join(' ')}'.trim());
    return result;
  }

  @override
  void on(String method, void Function(List<Object?>? args) handler) => handlers[method] = handler;
  @override
  void setOnClosed(void Function(Object? error)? callback) {}
  void push(String m, List<Object?> args) => handlers[m]!(args);
}

void main() {
  group('Đọc payload đúng như MatchService.cs gửi', () {
    test('MatchStarted Caro', () {
      final m = MatchInfo.parse([
        matchPayload(moves: [
          [7, 7, 9],
          [7, 8, 7]
        ], currentTurnUserId: 9, drawOfferedBy: 9)
      ])!;
      expect(m.matchId, 'm1');
      expect(m.gameCode, 'CARO');
      expect(m.isTurn, isTrue);
      expect(m.ranked, isTrue);
      expect(m.active, isTrue);
      expect(m.you, 7);
      expect(m.me!.displayName, 'Thái Bình');
      expect(m.opponent!.userId, 9);
      expect(m.opponent!.tier, Tier.bronze);
      expect(m.caro!.moves.length, 2);
      expect(m.caro!.moves.first.userId, 9);
      expect(m.caro!.currentTurnUserId, 9);
      expect(m.isMyTurn, isFalse);
      expect(m.caro!.turnDeadline, isNotNull);
      expect(m.caro!.drawOfferedBy, 9);
      expect(m.race, isNull);
    });

    test('MatchState trận đua Xếp số', () {
      final m = MatchInfo.parse([
        matchPayload(gameCode: 'PUZZLE', mode: 'FRIENDLY', seed: 123, progress: {9: 40})
      ])!;
      expect(m.isTurn, isFalse);
      expect(m.ranked, isFalse);
      expect(m.seed, 123);
      expect(m.race!.progress[9], 40);
      expect(m.race!.deadline, isNotNull);
      expect(m.caro, isNull);
    });

    test('QueueStatus và OpponentConnection là tham số rời', () {
      final q = QueueStatusEvent.parse([true, 12, 200])!;
      expect((q.inQueue, q.waitedSec, q.ratingRange), (true, 12, 200));
      final c = OpponentConnectionEvent.parse([false, 30])!;
      expect((c.connected, c.graceSeconds), (false, 30));
    });

    test('InviteReceived / InviteResult', () {
      final inv = InviteReceivedEvent.parse([
        {
          'inviteId': 'abc',
          'from': {'userId': 9, 'username': 'an', 'fullName': 'Nguyễn An', 'avatarUrl': null},
          'gameCode': 'PUZZLE',
          'difficulty': 2,
          'expiresAtUtc': '2026-10-25T10:00:30Z',
          'expiresInSec': 30,
        }
      ])!;
      expect(inv.inviteId, 'abc');
      expect(inv.from.displayName, 'Nguyễn An');
      expect(inv.gameCode, 'PUZZLE');
      expect(inv.difficulty, 2);
      expect(inv.expiresAt.difference(inv.receivedAt).inSeconds, 30);

      final r = InviteResultEvent.parse([
        {'inviteId': 'abc', 'status': 'accepted', 'userId': 9, 'gameCode': 'CARO', 'difficulty': 2, 'matchId': 'm1'}
      ])!;
      expect(r.status, InviteStatus.accepted);
      expect(r.matchId, 'm1');
      expect(InviteResultEvent.parse([
        {'inviteId': 'abc', 'status': 'declined', 'matchId': null}
      ])!.status, InviteStatus.declined);
    });

    test('MatchEnded có thay đổi rating và điểm', () {
      final e = MatchEndedEvent.parse([
        {
          'matchId': 'm1',
          'winnerId': 7,
          'reason': 'RESIGN',
          'mode': 'RANKED',
          'ratingChanges': [
            {'userId': 7, 'before': 1200, 'after': 1216},
            {'userId': 9, 'before': 1180, 'after': 1164},
          ],
          'results': [
            {'userId': 7, 'result': 'WIN', 'score': 850},
            {'userId': 9, 'result': 'LOSE', 'score': 0},
          ],
        }
      ])!;
      expect(e.winnerId, 7);
      expect(e.ranked, isTrue);
      expect(e.ratingChanges[7]!.delta, 16);
      expect(e.ratingChanges[9]!.delta, -16);
      expect(e.scores[7], 850);
      expect(matchEndReasonVi(e, 7), 'Đối thủ đầu hàng');
      expect(matchEndReasonVi(e, 9), 'Bạn đã đầu hàng');
    });

    test('MatchEnded do server khởi động lại (không có results)', () {
      final e = MatchEndedEvent.parse([
        {'matchId': 'm1', 'winnerId': null, 'reason': 'SERVER_RESTART', 'mode': 'FRIENDLY', 'ratingChanges': []}
      ])!;
      expect(e.isDraw, isTrue);
      expect(e.scores, isEmpty);
      expect(matchEndReasonVi(e, 7), contains('máy chủ'));
    });

    test('payload sai dạng trả null, không ném lỗi', () {
      expect(MatchInfo.parse(null), isNull);
      expect(MatchInfo.parse([42]), isNull);
      expect(QueueStatusEvent.parse(['x']), isNull);
      expect(MatchEndedEvent.parse([{}]), isNull);
    });
  });

  group('SignalRRealtimeService: phần đối kháng', () {
    late _Gateway gw;
    late SignalRRealtimeService rt;

    setUp(() async {
      gw = _Gateway();
      rt = SignalRRealtimeService(
        tokens: TokenStorage(),
        hubUrl: 'http://x/hubs/game',
        gatewayFactory: (_, _) => gw,
        sleep: (_) async {},
      );
      await rt.connect();
    });

    tearDown(() => rt.dispose());

    test('sự kiện server được đọc thành model và phát ra stream', () async {
      final started = expectLater(rt.matchStarted, emits(isA<MatchInfo>().having((m) => m.matchId, 'id', 'm1')));
      final queue = expectLater(rt.queueStatus, emits(isA<QueueStatusEvent>().having((q) => q.waitedSec, 'w', 6)));
      final ended = expectLater(rt.matchEnded, emits(isA<MatchEndedEvent>().having((e) => e.reason, 'r', 'TIMEOUT')));
      gw.push('MatchStarted', [matchPayload()]);
      gw.push('QueueStatus', [true, 6, 100]);
      gw.push('MatchEnded', [
        {'matchId': 'm1', 'winnerId': 9, 'reason': 'TIMEOUT', 'mode': 'RANKED', 'ratingChanges': []}
      ]);
      await Future.wait([started, queue, ended]);
    });

    test('lệnh gửi đúng tên hub method và thứ tự tham số', () async {
      gw.result = 'inv-123';
      expect(await rt.invite(9, 'CARO', 2), 'inv-123');
      await rt.queueJoin('PUZZLE', 1);
      await rt.caroMove('m1', 7, 8);
      await rt.raceProgress('m1', 55);
      await rt.raceFinish('m1', 12000, 0);
      await rt.respondDraw('m1', false);
      await rt.quickChat('m1', 'gg');
      await rt.rejoin('m1');
      expect(gw.invoked, [
        'Invite 9 CARO 2',
        'QueueJoin PUZZLE 1',
        'CaroMove m1 7 8',
        'RaceProgress m1 55',
        'RaceFinish m1 12000 0',
        'RespondDraw m1 false',
        'QuickChat m1 gg',
        'Rejoin m1',
      ]);
    });

    test('chưa kết nối thì báo lỗi dễ hiểu, không gọi hub', () async {
      await rt.disconnect();
      await expectLater(rt.queueJoin('CARO', 2), throwsA(isA<RealtimeException>()));
      expect(gw.invoked, isEmpty);
    });
  });
}
