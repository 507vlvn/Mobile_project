
import 'dart:async' show TimeoutException;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/realtime/realtime_lifecycle.dart';
import 'package:mobile_rubik/core/realtime/realtime_service.dart';
import 'package:mobile_rubik/features/auth/auth_controller.dart';
import 'package:mobile_rubik/core/network/models.dart';

import 'fake_realtime.dart';
import 'fakes.dart';

void main() {
  late FakeHubGateway hub;
  late List<Duration> sleeps;

  SignalRRealtimeService make({Future<void> Function(Duration)? sleep}) =>
      SignalRRealtimeService(
        tokens: FakeTokenStorage('t'),
        hubUrl: 'https://x/hubs/game',
        gatewayFactory: (url, token) => hub,
        sleep: sleep ?? (d) async => sleeps.add(d),
      );

  setUp(() {
    hub = FakeHubGateway();
    sleeps = [];
  });

  test('hubUrlFromApi bỏ /api và thêm /hubs/game', () {
    expect(hubUrlFromApi('https://api.example.com/api'),
        'https://api.example.com/hubs/game');
    expect(hubUrlFromApi('http://127.0.0.1:5214/api/'),
        'http://127.0.0.1:5214/hubs/game');
    expect(hubUrlFromApi('http://h:1'), 'http://h:1/hubs/game');
  });

  group('máy trạng thái kết nối', () {
    test('kết nối thành công: disconnected -> connecting -> connected',
        () async {
      final s = make();
      final seen = <RealtimeStatus>[];
      s.addListener(() => seen.add(s.status));
      expect(s.status, RealtimeStatus.disconnected);
      await s.connect();
      expect(seen, [RealtimeStatus.connecting, RealtimeStatus.connected]);
      expect(s.isConnected, isTrue);
      expect(sleeps, isEmpty);
      s.dispose();
    });

    test('start thất bại: thử lại với backoff 0, 2, 5, 10, 30 rồi giữ 30s',
        () async {
      hub.failStarts = 7;
      final s = make();
      await s.connect();
      expect(sleeps, const [
        Duration.zero,
        Duration(seconds: 2),
        Duration(seconds: 5),
        Duration(seconds: 10),
        Duration(seconds: 30),
        Duration(seconds: 30),
        Duration(seconds: 30),
      ]);
      expect(hub.startCalls, 8);
      expect(s.status, RealtimeStatus.connected);
      s.dispose();
    });

    test('lần kết nối đầu tiên không phát reconnected', () async {
      hub.failStarts = 1;
      final s = make();
      var n = 0;
      s.reconnected.listen((_) => n++);
      await s.connect();
      await Future<void>.delayed(Duration.zero);
      expect(n, 0);
      s.dispose();
    });

    test('mất kết nối: reconnecting -> connected và phát reconnected một lần',
        () async {
      final s = make();
      await s.connect();
      final seen = <RealtimeStatus>[];
      s.addListener(() => seen.add(s.status));
      var reconnected = 0;
      s.reconnected.listen((_) => reconnected++);

      hub.failStarts = 2;
      hub.dropConnection();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(seen.first, RealtimeStatus.reconnecting);
      expect(seen.last, RealtimeStatus.connected);
      expect(seen.where((x) => x == RealtimeStatus.connecting), isEmpty);
      expect(reconnected, 1);
      // backoff bắt đầu lại từ 0
      expect(sleeps, const [Duration.zero, Duration(seconds: 2)]);
      s.dispose();
    });

    test('disconnect dừng vòng thử lại và không tự kết nối lại', () async {
      hub.failStarts = 1000;
      late SignalRRealtimeService s;
      var calls = 0;
      s = make(sleep: (d) async {
        calls++;
        if (calls == 3) await s.disconnect();
      });
      await s.connect();
      expect(s.status, RealtimeStatus.disconnected);
      expect(hub.startCalls, 3);
      // hub.stop() gọi onClosed nhưng service không kết nối lại
      await Future<void>.delayed(Duration.zero);
      expect(hub.startCalls, 3);
      s.dispose();
    });

    test('connect sau disconnect (đăng nhập lại) bắt đầu như lần đầu',
        () async {
      final s = make();
      await s.connect();
      await s.disconnect();
      expect(s.status, RealtimeStatus.disconnected);
      var reconnected = 0;
      s.reconnected.listen((_) => reconnected++);
      await s.connect();
      await Future<void>.delayed(Duration.zero);
      expect(s.status, RealtimeStatus.connected);
      expect(reconnected, 0);
      s.dispose();
    });
  });

  group('sự kiện server -> client', () {
    test('Presence dạng tham số rời và dạng object', () async {
      final s = make();
      await s.connect();
      final got = <PresenceEvent>[];
      s.presence.listen(got.add);
      hub.emit('Presence', [5, 'online']);
      hub.emit('Presence', [
        {'userId': 6, 'status': 'in_match'}
      ]);
      hub.emit('Presence', [
        {'userId': 7, 'status': 'offline', 'lastSeenAt': '2026-10-24T08:00:00Z'}
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(got.map((e) => (e.userId, e.status.code)),
          [(5, 'online'), (6, 'in_match'), (7, 'offline')]);
      expect(got.last.lastSeenAt, isNotNull);
      s.dispose();
    });

    test('payload hỏng bị bỏ qua, không làm sập', () async {
      final s = make();
      await s.connect();
      var n = 0;
      s.presence.listen((_) => n++);
      s.invitesReceived.listen((_) => n++);
      hub.emit('Presence', null);
      hub.emit('Presence', ['x']);
      hub.emit('InviteReceived', [
        {'nothing': 1}
      ]);
      hub.emit('InviteReceived', ['not a map']);
      await Future<void>.delayed(Duration.zero);
      expect(n, 0);
      s.dispose();
    });

    test('InviteReceived, FriendRequest, MessageReceived', () async {
      final s = make();
      await s.connect();
      final invites = <InviteReceivedEvent>[];
      final reqs = <FriendRequestEvent>[];
      final msgs = <MessageReceivedEvent>[];
      s.invitesReceived.listen(invites.add);
      s.friendRequests.listen(reqs.add);
      s.messages.listen(msgs.add);
      hub.emit('InviteReceived', [
        {
          'inviteId': 'abc',
          'from': {'userId': 12, 'username': 'lan_pham', 'fullName': 'Phạm Lan'},
          'gameCode': 'CARO',
          'difficulty': 3,
          'expiresInSec': 25,
          'expiresAtUtc': '2030-01-01T00:00:00Z',
        }
      ]);
      hub.emit('FriendRequest', [
        {
          'requestId': 4,
          'from': {'userId': 13, 'username': 'hoang99'},
        }
      ]);
      hub.emit('MessageReceived', [
        {
          'messageId': 9,
          'senderId': 12,
          'receiverId': 7,
          'content': 'chào',
          'sentAt': '2026-10-24T08:00:00Z',
          'sender': {'userId': 12, 'username': 'lan_pham'},
        }
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(invites.single.inviteId, 'abc');
      expect(invites.single.from.displayName, 'Phạm Lan');
      expect(invites.single.ttlSec, 25);
      expect(invites.single.difficulty, 3);
      expect(reqs.single.requestId, 4);
      expect(reqs.single.from.username, 'hoang99');
      expect(msgs.single.message.messageId, 9);
      expect(msgs.single.sender?.username, 'lan_pham');
      s.dispose();
    });

    test('MatchStarted / MatchState / MatchEnded', () async {
      final s = make();
      await s.connect();
      final started = <MatchInfo>[];
      final ended = <MatchEndedEvent>[];
      s.matchStarted.listen(started.add);
      s.matchEnded.listen(ended.add);
      hub.emit('MatchStarted', [
        {
          'matchId': 'a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4',
          'gameCode': 'CARO',
          'difficulty': 2,
          'mode': 'FRIENDLY',
          'kind': 'TURN',
          'seed': 99,
          'status': 'ACTIVE',
          'startedAtUtc': '2026-10-24T08:00:00Z',
          'you': 7,
          'players': [
            {'userId': 7, 'username': 'an', 'rating': 1000, 'tier': 'BRONZE', 'connected': true},
            {'userId': 12, 'username': 'lan_pham', 'rating': 1260, 'tier': 'GOLD', 'tierName': 'Vàng', 'connected': false},
          ],
          'caro': {
            'size': 15,
            'moves': [
              {'row': 7, 'col': 7, 'userId': 7}
            ],
            'currentTurnUserId': 12,
            'turnDeadlineUtc': '2026-10-24T08:00:30Z',
            'drawOfferedBy': null,
          },
          'race': null,
        }
      ]);
      hub.emit('MatchEnded', [
        {
          'matchId': 'a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4',
          'winnerId': 7,
          'reason': 'FIVE_IN_ROW',
          'mode': 'FRIENDLY',
          'results': [
            {'userId': 7, 'result': 'WIN', 'score': 0},
            {'userId': 12, 'result': 'LOSE', 'score': 0},
          ],
          'ratingChanges': [
            {'userId': 7, 'before': 1000, 'after': 1020},
            {'userId': 12, 'before': 1260, 'after': 1241},
          ],
        }
      ]);
      await Future<void>.delayed(Duration.zero);
      final m = started.single;
      expect(m.matchId, 'a1b2c3d4a1b2c3d4a1b2c3d4a1b2c3d4');
      expect(m.mode, MatchMode.friendly);
      expect(m.kind, MatchKind.turn);
      expect(m.youId, 7);
      expect(m.you?.username, 'an');
      expect(m.opponent?.rating, 1260);
      expect(m.opponent?.connected, isFalse);
      expect(m.caro?.moves.single.row, 7);
      expect(m.caro?.moves.single.userId, 7);
      expect(m.caro?.currentTurnUserId, 12);
      expect(m.caro?.turnDeadline, isNotNull);
      expect(m.race, isNull);
      final e = ended.single;
      expect(e.winnerId, 7);
      expect(e.ratingChanges[7]?.delta, 20);
      expect(e.results[7], 'WIN');
      expect(e.mode, 'FRIENDLY');
      expect(e.ratingChanges[12]?.delta, -19);
      s.dispose();
    });

    test('MatchEnded với ratingChanges dạng map và hòa', () {
      final e = MatchEndedEvent.parse([
        {
          'matchId': '5',
          'winnerId': null,
          'reason': 'DRAW',
          'ratingChanges': {
            '7': {'before': 1000, 'delta': 5},
          },
        }
      ])!;
      expect(e.matchId, '5');
      expect(e.isDraw, isTrue);
      expect(e.ratingChanges[7]?.after, 1005);
    });

    test('QueueStatus, OpponentProgress, QuickChat, OpponentConnection', () {
      final q = QueueStatusEvent.parse([true, 12, 200])!;
      expect((q.searching, q.waitedSec, q.range), (true, 12, 200));
      final qo = QueueStatusEvent.parse([
        {'searching': false}
      ])!;
      expect(qo.searching, isFalse);
      expect(OpponentProgressEvent.parse(['m', 140])!.percent, 100);
      expect(
          OpponentProgressEvent.parse([
            {'matchId': 'm', 'percent': 42.5}
          ])!
              .percent,
          42.5);
      final c = QuickChatEvent.parse([
        {'matchId': 'm', 'fromUserId': 12, 'code': 'GG'}
      ])!;
      expect((c.fromUserId, c.code), (12, 'GG'));
      final oc = OpponentConnectionEvent.parse([false, 30])!;
      expect((oc.connected, oc.graceSec), (false, 30));
      final ir = InviteResultEvent.parse([
        {'inviteId': '1', 'status': 'declined'}
      ])!;
      expect(ir.outcome, InviteOutcome.declined);
      expect(ir.inviteId, '1');
      expect(
          InviteResultEvent.parse([
            {'inviteId': '1', 'status': 'accepted', 'userId': 12, 'matchId': 'm'}
          ])!
              .outcome,
          InviteOutcome.accepted);
    });

    test('DrawOffered / DrawResponded / RematchRequested', () {
      final d = DrawOfferedEvent.parse([
        {'matchId': 'm', 'fromUserId': 12}
      ])!;
      expect(d.fromUserId, 12);
      final r = DrawRespondedEvent.parse([
        {'matchId': 'm', 'accepted': false, 'byUserId': 12}
      ])!;
      expect((r.accepted, r.byUserId), (false, 12));
      final rm = RematchRequestedEvent.parse([
        {'matchId': 'm', 'fromUserId': 12}
      ])!;
      expect(rm.matchId, 'm');
    });

    test('FriendAccepted', () {
      final e = FriendAcceptedEvent.parse([
        {
          'user': {'userId': 4, 'username': 'a'}
        }
      ])!;
      expect(e.user.userId, 4);
    });
  });

  group('gọi lên server', () {
    test('chưa kết nối thì báo lỗi tiếng Việt, không gọi hub', () async {
      final s = make();
      await expectLater(
        s.queueJoin('CARO', 2),
        throwsA(isA<RealtimeException>()
            .having((e) => e.message, 'message', contains('Chưa kết nối'))),
      );
      expect(hub.invocations, isEmpty);
      s.dispose();
    });

    test('gửi đúng tên method và tham số theo §3', () async {
      final s = make();
      await s.connect();
      await s.queueJoin('CARO', 2);
      await s.queueLeave();
      await s.invite(5, 'SUDOKU', 3);
      await s.respondInvite('abc', true);
      await s.caroMove('12', 7, 8);
      await s.raceProgress('12', 40);
      await s.raceFinish('12', 91000, 2);
      await s.resign('12');
      await s.offerDraw('12');
      await s.respondDraw('12', false);
      await s.rematch('12');
      await s.quickChat('12', 'GG');
      await s.rejoin('12');
      expect(hub.invocations, [
        'QueueJoin(CARO, 2)',
        'QueueLeave()',
        'Invite(5, SUDOKU, 3)',
        'RespondInvite(abc, true)',
        'CaroMove(12, 7, 8)',
        'RaceProgress(12, 40)',
        'RaceFinish(12, 91000, 2)',
        'Resign(12)',
        'OfferDraw(12)',
        'RespondDraw(12, false)',
        'Rematch(12)',
        'QuickChat(12, GG)',
        'Rejoin(12)',
      ]);
      s.dispose();
    });

    test('HubException hiện thông điệp của server', () async {
      final s = make();
      await s.connect();
      hub.invokeError = const RealtimeException('Bạn chưa là bạn bè');
      await expectLater(
        s.invite(5, 'CARO', 2),
        throwsA(isA<RealtimeException>()
            .having((e) => e.message, 'message', 'Bạn chưa là bạn bè')),
      );
      s.dispose();
    });
  });

  group('hubErrorMessage', () {
    test('lấy phần sau HubException: cuối cùng', () {
      expect(
          hubErrorMessage(Exception(
              "An unexpected error occurred invoking 'Invite' on the server. HubException: Bạn chưa là bạn bè")),
          'Bạn chưa là bạn bè');
      expect(
          hubErrorMessage(
              'x HubException: a HubException: Lời mời đã hết hạn'),
          'Lời mời đã hết hạn');
    });

    test('lỗi mạng / timeout -> thông điệp mất kết nối', () {
      expect(hubErrorMessage(Exception('SocketException: Connection refused')),
          kConnectionLostMessage);
      expect(hubErrorMessage(TimeoutException('x')), kConnectionLostMessage);
      expect(
          hubErrorMessage(Exception(
              "Cannot send data if the connection is not in the 'Connected' State.")),
          kConnectionLostMessage);
    });

    test('còn lại giữ nguyên thông điệp', () {
      expect(hubErrorMessage(Exception('Lỗi lạ')), 'Lỗi lạ');
      expect(hubErrorMessage(''), kConnectionLostMessage);
    });
  });

  group('vòng đời theo đăng nhập và nền', () {
    late FakeApiClient api;
    late AuthController auth;
    late FakeRealtimeService rt;
    late RealtimeLifecycle life;

    setUp(() async {
      api = FakeApiClient();
      api.onLogin = () async => const AuthResult(token: 't', user: testUser);
      auth = AuthController(api: api, tokens: FakeTokenStorage());
      rt = FakeRealtimeService()..setStatus(RealtimeStatus.disconnected);
      life = RealtimeLifecycle(service: rt, auth: auth);
    });

    tearDown(() => life.detach());

    testWidgets('đăng nhập -> connect, đăng xuất -> disconnect', (tester) async {
      life.attach();
      expect(rt.connectCalls, 0);
      await tester.runAsync(() => auth.login('an', 'x'));
      expect(rt.connectCalls, 1);
      await tester.runAsync(auth.logout);
      expect(rt.disconnectCalls, greaterThanOrEqualTo(1));
      expect(rt.status, RealtimeStatus.disconnected);
    });

    testWidgets('ở nền quá 2 phút thì ngắt, quay lại thì kết nối lại',
        (tester) async {
      await tester.runAsync(() => auth.login('an', 'x'));
      life.attach();
      final connects = rt.connectCalls;

      life.onLifecycle(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 119));
      expect(rt.disconnectCalls, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(rt.disconnectCalls, 1);

      life.onLifecycle(AppLifecycleState.resumed);
      expect(rt.connectCalls, connects + 1);
    });

    testWidgets('ra nền ngắn rồi quay lại thì giữ nguyên kết nối',
        (tester) async {
      await tester.runAsync(() => auth.login('an', 'x'));
      life.attach();
      final connects = rt.connectCalls;
      life.onLifecycle(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 30));
      life.onLifecycle(AppLifecycleState.resumed);
      await tester.pump(const Duration(minutes: 5));
      expect(rt.disconnectCalls, 0);
      expect(rt.connectCalls, connects);
    });

    testWidgets('khách ra nền: không làm gì', (tester) async {
      life.attach();
      life.onLifecycle(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 5));
      life.onLifecycle(AppLifecycleState.resumed);
      expect(rt.connectCalls, 0);
    });
  });
}
