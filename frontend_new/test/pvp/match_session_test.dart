import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_new/caro/logic/caro_board.dart';
import 'package:frontend_new/core/network/models.dart';
import 'package:frontend_new/core/realtime/realtime_service.dart';
import 'package:frontend_new/pvp/caro_online_board.dart';
import 'package:frontend_new/pvp/match_session.dart';

import '../support/fake_realtime.dart';

const _an = UserSummary(userId: 9, username: 'an', fullName: 'Nguyễn An');

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeRealtime rt;
  late MatchSession s;

  setUp(() {
    rt = FakeRealtime();
    s = MatchSession(realtime: rt);
  });
  tearDown(() => s.dispose());

  group('Hàng chờ', () {
    test('tìm trận -> queued, server ghép được -> active và phát starts', () async {
      expect(await s.findMatch('CARO', 2), isTrue);
      expect(rt.calls, ['QueueJoin CARO 2']);
      expect(s.phase, PvpPhase.queued);

      rt.queueCtl.add(const QueueStatusEvent(true, 6, 200));
      await _tick();
      expect(s.queueRatingRange, 200);

      final started = expectLater(s.starts, emits(isA<MatchInfo>()));
      rt.queueCtl.add(const QueueStatusEvent(false, 0, 0));
      rt.matchStartedCtl.add(matchInfo());
      await started;
      expect(s.phase, PvpPhase.active);
      expect(s.match!.matchId, 'm1');
      expect(s.firstMoverId, 7, reason: 'chưa có nước nào: người tới lượt đi trước');
    });

    test('hủy tìm trận', () async {
      await s.findMatch('PUZZLE', 1);
      await s.cancelQueue();
      expect(s.phase, PvpPhase.idle);
      expect(rt.calls.last, 'QueueLeave');
    });

    test('lỗi hub hiện thành thông báo, không đổi trạng thái', () async {
      rt.failNext = 'Bạn đang trong một trận đấu';
      final notice = expectLater(s.notices, emits('Bạn đang trong một trận đấu'));
      expect(await s.findMatch('CARO', 2), isFalse);
      await notice;
      expect(s.phase, PvpPhase.idle);
    });
  });

  group('Lời mời', () {
    test('mời bạn, bạn từ chối -> về idle kèm thông báo', () async {
      expect(await s.invite(_an, 'CARO', 2), isTrue);
      expect(s.phase, PvpPhase.inviting);
      expect(s.outgoingInvite!.inviteId, 'inv1');

      final notice = expectLater(s.notices, emits(contains('từ chối')));
      rt.inviteResultsCtl.add(const InviteResultEvent('inv1', InviteStatus.declined, null));
      await notice;
      expect(s.phase, PvpPhase.idle);
      expect(s.outgoingInvite, isNull);
    });

    test('nhận lời mời, chấp nhận -> gửi RespondInvite và xóa khỏi danh sách', () async {
      final inv = InviteReceivedEvent(
          inviteId: 'x1', from: _an, gameCode: 'PUZZLE', difficulty: 2, expiresInSec: 30);
      rt.invitesCtl.add(inv);
      await _tick();
      expect(s.incomingInvites.single.inviteId, 'x1');
      await s.respondInvite(inv, true);
      expect(rt.calls.last, 'RespondInvite x1 true');
      expect(s.incomingInvites, isEmpty);
    });

    test('lời mời đến bị hủy/hết hạn thì tự biến mất', () async {
      rt.invitesCtl.add(InviteReceivedEvent(
          inviteId: 'x2', from: _an, gameCode: 'CARO', difficulty: 2, expiresInSec: 30));
      await _tick();
      rt.inviteResultsCtl.add(const InviteResultEvent('x2', InviteStatus.expired, null));
      await _tick();
      expect(s.incomingInvites, isEmpty);
    });
  });

  group('Trận Caro', () {
    setUp(() async {
      rt.matchStartedCtl.add(matchInfo(currentTurnUserId: 7));
      await _tick();
    });

    test('đi nước khi tới lượt; không tới lượt thì không gửi', () async {
      expect(await s.caroMove(7, 7), isTrue);
      expect(rt.calls.last, 'CaroMove m1 7 7');

      rt.matchStateCtl.add(matchInfo(moves: [
        [7, 7, 7]
      ], currentTurnUserId: 9));
      await _tick();
      expect(s.match!.isMyTurn, isFalse);
      rt.calls.clear();
      expect(await s.caroMove(8, 8), isFalse);
      expect(rt.calls, isEmpty);
    });

    test('xin hòa: tối đa 3 lần, đối thủ từ chối thì báo', () async {
      expect(await s.offerDraw(), isTrue);
      expect(s.myDrawPending, isTrue);
      expect(s.drawOffersLeft, 2);
      final notice = expectLater(s.notices, emits('Đối thủ từ chối hòa'));
      rt.drawRespondedCtl.add(const DrawRespondedEvent('m1', false, 9));
      await notice;
      expect(s.myDrawPending, isFalse);
    });

    test('đối thủ xin hòa -> trả lời', () async {
      rt.drawOfferedCtl.add(const MatchSignalEvent('m1', 9));
      await _tick();
      expect(s.opponentOfferedDraw, isTrue);
      await s.respondDraw(true);
      expect(rt.calls.last, 'RespondDraw m1 true');
      expect(s.opponentOfferedDraw, isFalse);
    });

    test('đối thủ mất kết nối, kết thúc trận, mời tái đấu', () async {
      rt.connectionCtl.add(const OpponentConnectionEvent(false, 30));
      await _tick();
      expect(s.opponentConnected, isFalse);
      expect(s.opponentGraceUntil, isNotNull);

      rt.matchEndedCtl.add(const MatchEndedEvent(
          matchId: 'm1', winnerId: 7, reason: 'ABANDON', ranked: true,
          ratingChanges: {7: RatingChange(7, 1200, 1216)}));
      await _tick();
      expect(s.phase, PvpPhase.ended);
      expect(s.ended!.ratingChanges[7]!.delta, 16);

      rt.rematchCtl.add(const MatchSignalEvent('m1', 9));
      await _tick();
      expect(s.rematchRequestedByOpponent, isTrue);
      expect(await s.rematch(), isTrue);
      expect(rt.calls.last, 'Rematch m1');
      s.leaveResult();
      expect(s.phase, PvpPhase.idle);
    });

    test('kết nối lại thì tự Rejoin trận đang chơi', () async {
      rt.reconnectedCtl.add(null);
      await _tick();
      expect(rt.calls.last, 'Rejoin m1');
    });

    test('chat nhanh hiện của cả hai bên', () async {
      await s.quickChat('gg');
      expect(rt.calls.last, 'QuickChat m1 gg');
      expect(s.chatOf(7)!.$1, 'gg');
      rt.chatCtl.add(const MatchSignalEvent('m1', 9, 'thanks'));
      await _tick();
      expect(s.chatOf(9)!.$1, 'thanks');
    });
  });

  group('Trận đua Xếp số', () {
    setUp(() async {
      rt.matchStartedCtl.add(matchInfo(gameCode: 'PUZZLE', difficulty: 1, currentTurnUserId: null));
      await _tick();
    });

    test('tiến độ chỉ gửi khi tăng và không quá nhanh', () async {
      s.reportProgress(20);
      s.reportProgress(10); // giảm: bỏ qua
      s.reportProgress(30); // quá nhanh: dồn lại gửi sau
      await _tick();
      expect(rt.calls.where((c) => c.startsWith('RaceProgress')), ['RaceProgress m1 20']);
      await Future<void>.delayed(MatchSession.progressGap + const Duration(milliseconds: 50));
      expect(rt.calls.where((c) => c.startsWith('RaceProgress')).last, 'RaceProgress m1 30');
    });

    test('tiến độ đối thủ cập nhật', () async {
      rt.progressCtl.add(const OpponentProgressEvent('m1', 9, 64));
      await _tick();
      expect(s.opponentProgress, 64);
      rt.progressCtl.add(const OpponentProgressEvent('m1', 9, 50));
      await _tick();
      expect(s.opponentProgress, 64, reason: 'chỉ tăng');
    });

    test('xong: gửi 100% trước rồi mới nộp kết quả', () async {
      expect(await s.finishRace(timeMs: 9000), isTrue);
      final race = rt.calls.where((c) => c.startsWith('Race')).toList();
      expect(race, ['RaceProgress m1 100', 'RaceFinish m1 9000 0']);
    });

    test('xong quá nhanh: chờ đủ thời gian tối thiểu', () async {
      final sw = Stopwatch()..start();
      await s.finishRace(timeMs: 100, minTimeMs: 300);
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(190));
      expect(rt.calls.last, 'RaceFinish m1 300 0');
    });
  });

  test('raceMinTimeMs khớp RaceRules của backend', () {
    expect(raceMinTimeMs('PUZZLE', 1), 5000);
    expect(raceMinTimeMs('PUZZLE', 2), 20000);
    expect(raceMinTimeMs('PUZZLE', 3), 40000);
  });

  group('CaroOnlineBoard', () {
    test('người đi trước cầm X, nước cuối và đường thắng', () {
      final m = matchInfo(moves: [
        for (var i = 0; i < 4; i++) ...[
          [7, 3 + i, 9],
          [8, 3 + i, 7]
        ],
        [7, 7, 9],
      ], currentTurnUserId: null, status: 'ENDED');
      final b = CaroOnlineBoard.from(m, 9);
      expect(b.iAmX, isFalse);
      expect(b.cells[caroIndex(7, 3)], kCaroPlayer);
      expect(b.cells[caroIndex(8, 3)], kCaroAi);
      expect(b.lastMove, caroIndex(7, 7));
      expect(b.winLine, [for (var c = 3; c <= 7; c++) caroIndex(7, c)]);
    });
  });
}
