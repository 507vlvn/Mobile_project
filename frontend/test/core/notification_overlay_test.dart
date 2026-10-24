import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/realtime/active_chat.dart';
import 'package:mobile_rubik/core/realtime/banner_queue.dart';
import 'package:mobile_rubik/core/realtime/notification_overlay.dart';
import 'package:mobile_rubik/core/realtime/realtime_service.dart';
import 'package:mobile_rubik/core/services/match_launcher.dart';
import 'package:mobile_rubik/core/services/shell_navigation.dart';
import 'package:mobile_rubik/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'fake_realtime.dart';

final _t0 = DateTime(2026, 10, 24, 9);

InviteReceivedEvent invite(String id, {int ttl = 30, int from = 12}) =>
    InviteReceivedEvent(
      inviteId: id,
      from: RtUser(userId: from, username: 'lan_pham', fullName: 'Phạm Lan'),
      gameCode: 'CARO',
      difficulty: 2,
      receivedAt: _t0,
      ttlSec: ttl,
    );

MessageReceivedEvent msgEvent(int id, int sender) => MessageReceivedEvent.parse([
      {
        'messageId': id,
        'senderId': sender,
        'receiverId': 7,
        'content': 'chào bạn',
        'sentAt': '2026-10-24T09:00:00Z',
        'sender': {'userId': sender, 'username': 'u$sender', 'fullName': 'Bạn $sender'},
      }
    ])!;

FriendRequestEvent reqEvent(int id, int from) => FriendRequestEvent.parse([
      {
        'requestId': id,
        'from': {'userId': from, 'username': 'u$from', 'fullName': 'Người $from'},
      }
    ])!;

void main() {
  group('BannerQueue', () {
    test('tối đa một thông báo hiển thị, còn lại xếp hàng', () {
      final q = BannerQueue(now: () => _t0);
      q.add(FriendRequestBanner(reqEvent(1, 20)));
      q.add(FriendRequestBanner(reqEvent(2, 21)));
      q.add(MessageBanner(msgEvent(1, 30)));
      expect(q.current?.key, 'friend:20');
      expect(q.waiting.map((b) => b.key), ['friend:21', 'msg:30']);
      q.dismissCurrent();
      expect(q.current?.key, 'friend:21');
      q.dismissCurrent();
      expect(q.current?.key, 'msg:30');
      q.dismissCurrent();
      expect(q.current, isNull);
    });

    test('lời mời đấu chen lên trước các thông báo khác đang chờ', () {
      final q = BannerQueue(now: () => _t0);
      q.add(FriendRequestBanner(reqEvent(1, 20)));
      q.add(MessageBanner(msgEvent(1, 30)));
      q.add(InviteBanner(invite('a')));
      expect(q.waiting.first.key, 'invite:a');
    });

    test('chống trùng: tin mới cùng người thay thế tin đang chờ / đang hiện', () {
      final q = BannerQueue(now: () => _t0);
      q.add(MessageBanner(msgEvent(1, 30)));
      q.add(MessageBanner(msgEvent(2, 30)));
      expect((q.current as MessageBanner).message.message.messageId, 2);
      expect(q.waiting, isEmpty);
      q.add(FriendRequestBanner(reqEvent(1, 20)));
      q.add(FriendRequestBanner(reqEvent(9, 20)));
      expect(q.waiting.length, 1);
    });

    test('lời mời hết hạn trong lúc chờ thì bị bỏ qua', () {
      var now = _t0;
      final q = BannerQueue(now: () => now);
      q.add(FriendRequestBanner(reqEvent(1, 20)));
      q.add(InviteBanner(invite('a', ttl: 30)));
      q.add(MessageBanner(msgEvent(1, 30)));
      now = _t0.add(const Duration(seconds: 31));
      q.dismissCurrent();
      expect(q.current?.key, 'msg:30');
    });

    test('dismissKey xóa cả thông báo đang chờ', () {
      final q = BannerQueue(now: () => _t0);
      q.add(MessageBanner(msgEvent(1, 30)));
      q.add(FriendRequestBanner(reqEvent(1, 20)));
      q.dismissKey('friend:20');
      expect(q.waiting, isEmpty);
      q.dismissKey('msg:30');
      expect(q.current, isNull);
    });
  });

  test('InviteReceivedEvent.remainingSec đếm theo đồng hồ', () {
    final e = invite('a');
    expect(e.remainingSec(_t0), 30);
    expect(e.remainingSec(_t0.add(const Duration(seconds: 12))), 18);
    expect(e.remainingSec(_t0.add(const Duration(seconds: 40))), 0);
    final byDeadline = InviteReceivedEvent.parse([
      {
        'inviteId': 1,
        'from': {'userId': 2, 'username': 'x'},
        'expiresAt': '2026-10-24T09:00:20Z',
      }
    ], now: DateTime.utc(2026, 10, 24, 9))!;
    expect(byDeadline.ttlSec, 20);
  });

  group('NotificationOverlay', () {
    late FakeRealtimeService rt;
    late ShellNavigation nav;
    var now = _t0;
    final navKey = GlobalKey<NavigatorState>();

    Widget host() => MultiProvider(
          providers: [
            ListenableProvider<RealtimeService>.value(value: rt),
            ChangeNotifierProvider<ShellNavigation>.value(value: nav),
          ],
          child: MaterialApp(
            navigatorKey: navKey,
            theme: AppTheme.light(),
            builder: (context, child) => NotificationOverlay(
              navigatorKey: navKey,
              myId: () => 7,
              clock: () => now,
              child: child!,
            ),
            home: const Scaffold(body: Center(child: Text('Trang chính'))),
          ),
        );

    setUp(() {
      rt = FakeRealtimeService();
      nav = ShellNavigation();
      now = _t0;
      ActiveChat.partnerId = null;
      MatchLauncher.reset();
    });

    tearDown(() => ActiveChat.partnerId = null);

    testWidgets('lời mời đấu: hiện đồng hồ, Chấp nhận gọi RespondInvite',
        (tester) async {
      await tester.pumpWidget(host());
      rt.emitInvite(invite('inv-1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Phạm Lan mời bạn đấu'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('Chấp nhận'), findsOneWidget);
      expect(find.text('Từ chối'), findsOneWidget);

      await tester.tap(find.text('Chấp nhận'));
      await tester.pump();
      expect(rt.calls, ['RespondInvite(inv-1, true)']);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Chấp nhận'), findsNothing);
      expect(find.text('Đang mở trận…'), findsOneWidget);
    });

    testWidgets('Từ chối gọi RespondInvite false và đóng banner',
        (tester) async {
      await tester.pumpWidget(host());
      rt.emitInvite(invite('5'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Từ chối'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(rt.calls, ['RespondInvite(5, false)']);
      expect(find.text('Từ chối'), findsNothing);
    });

    testWidgets('đếm ngược 30 giây rồi tự đóng', (tester) async {
      await tester.pumpWidget(host());
      rt.emitInvite(invite('a'));
      await tester.pump(const Duration(milliseconds: 300));
      now = _t0.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('20'), findsOneWidget);
      now = _t0.add(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Chấp nhận'), findsNothing);
    });

    testWidgets('chỉ một banner tại một thời điểm; cái sau hiện khi đóng cái trước',
        (tester) async {
      await tester.pumpWidget(host());
      rt.emitFriendRequest(reqEvent(1, 20));
      rt.emitInvite(invite('a'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Người 20'), findsOneWidget);
      expect(find.text('Chấp nhận'), findsNothing);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Người 20'), findsNothing);
      expect(find.text('Chấp nhận'), findsOneWidget);
    });

    testWidgets('lời mời kết bạn: Xem chuyển sang tab Bạn bè, phân đoạn Lời mời',
        (tester) async {
      await tester.pumpWidget(host());
      rt.emitFriendRequest(reqEvent(1, 20));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Gửi lời mời kết bạn'), findsOneWidget);
      await tester.tap(find.text('Xem'));
      await tester.pump();
      expect(nav.requestedTab, ShellTab.friends);
      expect(nav.requestedSegment, FriendsSegment.requests);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('tin nhắn: hiện khi chưa mở chat; bỏ qua khi đang xem đúng chat hoặc tin của mình',
        (tester) async {
      await tester.pumpWidget(host());
      ActiveChat.partnerId = 30;
      rt.emitMessage(msgEvent(1, 30));
      rt.emitMessage(msgEvent(2, 7));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('chào bạn'), findsNothing);

      rt.emitMessage(msgEvent(3, 31));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Bạn 31'), findsOneWidget);
      expect(find.text('chào bạn'), findsOneWidget);
      // tự đóng sau 5 giây
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('chào bạn'), findsNothing);
    });

    testWidgets('trận giao hữu bắt đầu: có MatchLauncher thì mở, chỉ một lần',
        (tester) async {
      final opened = <String>[];
      MatchLauncher.register((nav, m) => opened.add(m.matchId));
      await tester.pumpWidget(host());
      final m = MatchInfo.parse([
        {'matchId': 'm1', 'gameCode': 'CARO', 'mode': 'FRIENDLY'}
      ])!;
      rt.emitMatchStarted(m);
      rt.emitMatchStarted(m);
      await tester.pump();
      expect(opened, ['m1']);
      expect(find.text('Đang mở trận…'), findsNothing);
    });

    testWidgets('chưa đăng ký MatchLauncher: hiện SnackBar Đang mở trận…',
        (tester) async {
      await tester.pumpWidget(host());
      rt.emitMatchStarted(MatchInfo.parse([
        {'matchId': 'm2', 'gameCode': 'CARO', 'mode': 'FRIENDLY'}
      ])!);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Đang mở trận…'), findsOneWidget);
    });

    testWidgets('trận xếp hạng không do lớp thông báo mở', (tester) async {
      final opened = <String>[];
      MatchLauncher.register((nav, m) => opened.add(m.matchId));
      await tester.pumpWidget(host());
      rt.emitMatchStarted(MatchInfo.parse([
        {'matchId': 'm3', 'gameCode': 'CARO', 'mode': 'RANKED'}
      ])!);
      await tester.pump();
      expect(opened, isEmpty);
    });

    testWidgets('lỗi từ hub khi trả lời lời mời hiện thông điệp', (tester) async {
      rt.failWith = const RealtimeException('Lời mời đã hết hạn');
      await tester.pumpWidget(host());
      rt.emitInvite(invite('a'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Chấp nhận'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Lời mời đã hết hạn'), findsOneWidget);
    });
  });
}
