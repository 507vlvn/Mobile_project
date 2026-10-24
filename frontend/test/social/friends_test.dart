import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/models/presence.dart';
import 'package:mobile_rubik/core/network/api_client.dart';
import 'package:mobile_rubik/core/network/models.dart';
import 'package:mobile_rubik/core/realtime/active_chat.dart';
import 'package:mobile_rubik/core/realtime/realtime_service.dart';
import 'package:mobile_rubik/core/theme/app_theme.dart';
import 'package:mobile_rubik/features/auth/auth_controller.dart';
import 'package:mobile_rubik/features/social/friends_controller.dart';
import 'package:mobile_rubik/features/social/friends_tab.dart' show FriendMenu;
import 'package:mobile_rubik/features/social/social_screen.dart';
import 'package:mobile_rubik/features/social/social_summary_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/fake_realtime.dart';
import '../core/fakes.dart';
import 'helpers.dart';

final _now = DateTime(2026, 10, 24, 10);

FriendInfo friend(
  int id,
  String name,
  PresenceStatus p, {
  Duration? seenAgo,
}) =>
    FriendInfo(
      userId: id,
      username: 'u$id',
      fullName: name,
      presence: p,
      lastSeenAt: seenAgo == null ? null : _now.subtract(seenAgo),
    );

List<String> names(Iterable<FriendInfo> f) => [for (final x in f) x.displayName];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ActiveChat.partnerId = null;
  });

  group('sortFriends', () {
    test('online -> đang trong trận -> offline (mới thấy trước), rồi theo tên',
        () {
      final sorted = sortFriends([
        friend(1, 'Cường', PresenceStatus.offline,
            seenAgo: const Duration(hours: 3)),
        friend(2, 'Bình', PresenceStatus.inMatch),
        friend(3, 'Dung', PresenceStatus.online),
        friend(4, 'An', PresenceStatus.online),
        friend(5, 'Hà', PresenceStatus.offline,
            seenAgo: const Duration(minutes: 5)),
        friend(6, 'Ân', PresenceStatus.offline),
      ]);
      expect(names(sorted), ['An', 'Dung', 'Bình', 'Hà', 'Cường', 'Ân']);
    });
  });

  group('FriendsController', () {
    late FakeApiClient api;
    late FakeRealtimeService rt;
    late FriendsController c;

    setUp(() {
      api = FakeApiClient();
      rt = FakeRealtimeService();
      api.onFriends = () async => [
            friend(1, 'Cường', PresenceStatus.offline,
                seenAgo: const Duration(hours: 1)),
            friend(2, 'Bình', PresenceStatus.online),
            friend(3, 'An', PresenceStatus.inMatch),
          ];
      api.onFriendRequests = () async => FriendRequests(
            incoming: [
              FriendRequestItem(
                  requestId: 10,
                  user: const UserSummary(userId: 20, username: 'dung')),
            ],
            outgoing: [
              FriendRequestItem(
                  requestId: 11,
                  user: const UserSummary(userId: 21, username: 'hoa')),
            ],
          );
      c = FriendsController(api: api, realtime: rt, now: () => _now);
    });

    tearDown(() => c.dispose());

    test('load: sắp xếp, đếm online, tải tuần tự bạn bè rồi lời mời', () async {
      await c.load();
      expect(names(c.friends), ['Bình', 'An', 'Cường']);
      expect(c.onlineCount, 2);
      expect(c.incoming.length, 1);
      expect(c.outgoing.length, 1);
      expect(api.friendsCalls, 1);
      expect(api.friendRequestsCalls, 1);
    });

    test('presence realtime cập nhật và sắp xếp lại ngay, không gọi REST',
        () async {
      await c.load();
      rt.emitPresence(const PresenceEvent(
          userId: 1, status: PresenceStatus.online));
      await Future<void>.delayed(Duration.zero);
      expect(names(c.friends), ['Bình', 'Cường', 'An']);
      expect(c.friends.first.presence, PresenceStatus.online);

      rt.emitPresence(const PresenceEvent(
          userId: 2, status: PresenceStatus.offline));
      await Future<void>.delayed(Duration.zero);
      expect(names(c.friends), ['Cường', 'An', 'Bình']);
      final binh = c.friends.last;
      expect(binh.presence, PresenceStatus.offline);
      expect(binh.lastSeenAt, _now); // ghi mốc rời mạng
      expect(presenceText(binh, now: _now), 'Ngoại tuyến · Vừa xong');
      expect(api.friendsCalls, 1);
    });

    test('presence của người không phải bạn bị bỏ qua', () async {
      await c.load();
      var notified = 0;
      c.addListener(() => notified++);
      rt.emitPresence(const PresenceEvent(
          userId: 99, status: PresenceStatus.online));
      await Future<void>.delayed(Duration.zero);
      expect(notified, 0);
    });

    test('presenceText', () {
      expect(presenceText(friend(1, 'A', PresenceStatus.online)), 'Đang online');
      expect(presenceText(friend(1, 'A', PresenceStatus.inMatch)),
          'Đang trong trận');
      expect(presenceText(friend(1, 'A', PresenceStatus.offline)), 'Ngoại tuyến');
      expect(
          presenceText(
              friend(1, 'A', PresenceStatus.offline,
                  seenAgo: const Duration(minutes: 12)),
              now: _now),
          'Ngoại tuyến · 12 phút trước');
    });

    test('relationOf theo bạn bè / lời mời đến / đi', () async {
      await c.load();
      expect(c.relationOf(2), Relationship.friends);
      expect(c.relationOf(20), Relationship.pendingIn);
      expect(c.relationOf(21), Relationship.pendingOut);
      expect(c.relationOf(99), Relationship.none);
    });

    test('có lời mời / bạn mới / kết nối lại thì tải lại một lần', () async {
      await c.load();
      rt.emitFriendRequest(FriendRequestEvent(
          requestId: 12, from: const RtUser(userId: 22, username: 'x')));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(api.friendsCalls, 2);
      rt.simulateReconnect();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(api.friendsCalls, 3);
    });

    test('chấp nhận / từ chối / hủy lời mời / hủy kết bạn', () async {
      final calls = <String>[];
      api.onAcceptFriendRequest = (id) async => calls.add('accept $id');
      api.onDeclineFriendRequest = (id) async => calls.add('decline $id');
      api.onRemoveFriend = (id) async => calls.add('remove $id');
      await c.load();
      expect(await c.decline(c.incoming.first), isTrue);
      expect(c.incoming, isEmpty);
      expect(await c.cancelOutgoing(c.outgoing.first), isTrue);
      expect(c.outgoing, isEmpty);
      expect(await c.unfriend(c.friends.first), isTrue);
      expect(c.friends.length, 2);
      expect(await c.accept(FriendRequestItem(
          requestId: 10,
          user: const UserSummary(userId: 20, username: 'dung'))), isTrue);
      expect(calls, ['decline 10', 'remove 21', 'remove 2', 'accept 10']);
    });
  });

  group('SocialSummaryController realtime', () {
    late FakeApiClient api;
    late FakeRealtimeService rt;
    late SocialSummaryController s;

    setUp(() {
      api = FakeApiClient();
      rt = FakeRealtimeService();
      s = SocialSummaryController(api: api, realtime: rt, myId: () => 7);
    });
    tearDown(() => s.dispose());

    test('tin mới và lời mời kết bạn tăng huy hiệu tức thì, không gọi REST',
        () async {
      rt.emitMessage(MessageReceivedEvent(message: msg(1, from: 2)));
      rt.emitMessage(MessageReceivedEvent(message: msg(2, from: 3)));
      rt.emitFriendRequest(FriendRequestEvent(
          requestId: 1, from: const RtUser(userId: 5, username: 'a')));
      await Future<void>.delayed(Duration.zero);
      expect(s.summary.unreadMessages, 2);
      expect(s.summary.incomingFriendRequests, 1);
      expect(s.badgeCount, 3);
      expect(api.summaryCalls, 0);
    });

    test('bỏ qua tin của mình và tin của cuộc trò chuyện đang mở', () async {
      ActiveChat.partnerId = 2;
      rt.emitMessage(MessageReceivedEvent(message: msg(1, from: 2)));
      rt.emitMessage(MessageReceivedEvent(message: msg(2, from: 7, to: 2)));
      await Future<void>.delayed(Duration.zero);
      expect(s.badgeCount, 0);
    });

    test('kết nối lại làm mới số liệu từ REST một lần', () async {
      api.onSocialSummary = () async => const SocialSummary(
          unreadMessages: 4, incomingFriendRequests: 2, incomingChallenges: 1);
      rt.simulateReconnect();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(api.summaryCalls, 1);
      expect(s.badgeCount, 7);
    });
  });

  group('đọc JSON khoan dung', () {
    test('FriendInfo / FriendRequests', () {
      final f = FriendInfo.fromJson({
        'userId': 3,
        'username': 'lan',
        'status': 'in_match',
        'lastSeenAt': '2026-10-24T08:00:00Z',
      });
      expect(f.presence, PresenceStatus.inMatch);
      expect(f.lastSeenAt, isNotNull);
      final r = FriendRequests.fromJson({
        'received': [
          {'id': 5, 'user': {'userId': 9, 'username': 'a'}}
        ],
        'sent': [
          {'requestId': 6, 'userId': 10, 'username': 'b'}
        ],
      });
      expect(r.incoming.single.requestId, 5);
      expect(r.incoming.single.user.userId, 9);
      expect(r.outgoing.single.requestId, 6);
      expect(r.outgoing.single.user.username, 'b');
      expect(FriendRequests.fromJson(null).incoming, isEmpty);
    });

    test('PlayerProfile với stats và quan hệ', () {
      final p = PlayerProfile.fromJson({
        'userId': 12,
        'username': 'lan',
        'fullName': 'Phạm Lan',
        'relationship': 'pending_in',
        'requestId': 4,
        'stats': [
          {'gameCode': 'CARO', 'rating': 1260, 'games': 10, 'wins': 6, 'losses': 3, 'draws': 1},
          {'gameCode': 'SUDOKU', 'rating': 1010, 'games': 0},
        ],
      });
      expect(p.relationship, Relationship.pendingIn);
      expect(p.requestId, 4);
      expect(p.statsFor('CARO')!.tier.label, 'Vàng');
      expect(p.statsFor('CARO')!.winRate, closeTo(0.6, 1e-9));
      expect(p.best!.gameCode, 'CARO');
      expect(Relationship.parse('friends'), Relationship.friends);
      expect(Relationship.parse('pending_out'), Relationship.pendingOut);
      expect(Relationship.parse(null), Relationship.none);
    });

    test('BoardEntry: ranked đọc rating, record đọc điểm', () {
      final j = {
        'rank': 2,
        'userId': 3,
        'username': 'a',
        'rating': 1300,
        'bestScore': 2400,
        'bestTimeSeconds': 90,
      };
      expect(BoardEntry.fromJson(j, board: BoardType.ranked).value, 1300);
      expect(BoardEntry.fromJson(j, board: BoardType.ranked).tier!.label, 'Vàng');
      expect(BoardEntry.fromJson(j, board: BoardType.record).value, 2400);
      expect(BoardEntry.fromJson(j, board: BoardType.record).tier, isNull);
      expect(extractList({'entries': [j]}, ['entries']).length, 1);
      expect(extractList([j]).length, 1);
      expect(extractList(null), isEmpty);
    });

    test('MatchHistoryItem: result trực tiếp hoặc suy ra từ winnerId', () {
      final a = MatchHistoryItem.fromJson({
        'matchId': 1,
        'gameCode': 'CARO',
        'mode': 'RANKED',
        'opponent': {'userId': 2, 'username': 'x'},
        'result': 'WIN',
        'ratingBefore': 1000,
        'ratingAfter': 1020,
      });
      expect(a.result, MatchResult.win);
      expect(a.ratingDelta, 20);
      final b = MatchHistoryItem.fromJson(
          {'matchId': 2, 'gameCode': 'CARO', 'winnerId': 2, 'mode': 'FRIENDLY'},
          myId: 7);
      expect(b.result, MatchResult.lose);
      expect(b.ranked, isFalse);
      expect(b.ratingDelta, isNull);
      final c = MatchHistoryItem.fromJson(
          {'matchId': 3, 'gameCode': 'CARO', 'winnerId': null});
      expect(c.result, MatchResult.draw);
    });
  });

  group('màn Bạn bè', () {
    late FakeApiClient api;
    late FakeRealtimeService rt;
    late AuthController auth;

    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393 * 2, 851 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => auth.login('an', 'x'));
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: api),
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ListenableProvider<RealtimeService>.value(value: rt),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const SocialScreen()),
      ));
      await tester.pumpAndSettle();
    }

    setUp(() {
      api = FakeApiClient();
      rt = FakeRealtimeService();
      api.onLogin = () async => const AuthResult(token: 't', user: testUser);
      auth = AuthController(api: api, tokens: FakeTokenStorage());
      api.onFriends = () async => [
            FriendInfo(
                userId: 1,
                username: 'u1',
                fullName: 'Cường',
                lastSeenAt:
                    DateTime.now().subtract(const Duration(minutes: 20))),
            friend(2, 'Bình', PresenceStatus.online),
          ];
      api.onFriendRequests = () async => FriendRequests(incoming: [
            FriendRequestItem(
                requestId: 10,
                user: const UserSummary(
                    userId: 20, username: 'dung', fullName: 'Dung Lê')),
          ]);
    });

    testWidgets('danh sách bạn: online trước, trạng thái chữ, có nút hành động',
        (tester) async {
      await pumpScreen(tester);
      expect(find.text('1 đang online · 2 bạn bè'), findsOneWidget);
      expect(find.text('Đang online'), findsOneWidget);
      expect(find.text('Ngoại tuyến · 20 phút trước'), findsOneWidget);
      final binh = tester.getTopLeft(find.text('Bình')).dy;
      final cuong = tester.getTopLeft(find.text('Cường')).dy;
      expect(binh, lessThan(cuong));
      // Mời đấu bật với bạn online, tắt với bạn offline
      expect(find.byTooltip('Mời Bình đấu'), findsOneWidget);
      expect(find.byTooltip('Cường chưa sẵn sàng để đấu'), findsOneWidget);
      expect(find.byTooltip('Nhắn tin cho Bình'), findsOneWidget);
    });

    testWidgets('presence realtime đổi dòng ngay trên màn hình', (tester) async {
      await pumpScreen(tester);
      rt.emitPresence(const PresenceEvent(
          userId: 1, status: PresenceStatus.inMatch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      
      expect(find.text('Đang trong trận'), findsOneWidget);
    });

    testWidgets('huy hiệu Lời mời và danh sách lời mời đến', (tester) async {
      await pumpScreen(tester);
      expect(find.descendant(of: find.byType(Badge), matching: find.text('1')),
          findsOneWidget);
      await tester.tap(find.text('Lời mời'));
      await tester.pumpAndSettle();
      expect(find.text('Lời mời đến (1)'), findsOneWidget);
      expect(find.text('Dung Lê'), findsOneWidget);
      expect(find.text('Chấp nhận'), findsOneWidget);
      expect(find.text('Từ chối'), findsOneWidget);
    });

    testWidgets('hủy kết bạn có xác nhận', (tester) async {
      final removed = <int>[];
      api.onRemoveFriend = (id) async => removed.add(id);
      await pumpScreen(tester);
      await tester.tap(find.byType(PopupMenuButton<FriendMenu>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy kết bạn'));
      await tester.pumpAndSettle();
      expect(find.text('Hủy kết bạn?'), findsOneWidget);
      await tester.tap(find.text('Giữ lại'));
      await tester.pumpAndSettle();
      expect(removed, isEmpty);

      await tester.tap(find.byType(PopupMenuButton<FriendMenu>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy kết bạn'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Hủy kết bạn'));
      await tester.pumpAndSettle();
      expect(removed, [2]); // Bình đứng đầu danh sách
    });

    testWidgets('danh sách trống: gợi ý Tìm bạn', (tester) async {
      api.onFriends = () async => [];
      await pumpScreen(tester);
      expect(find.text('Chưa có bạn bè'), findsOneWidget);
      expect(find.text('Tìm bạn'), findsOneWidget);
    });

    testWidgets('tìm kiếm hiện trạng thái quan hệ ở từng kết quả',
        (tester) async {
      api.onFriendRequests = () async => FriendRequests(
            incoming: [
              FriendRequestItem(
                  requestId: 10,
                  user: const UserSummary(userId: 20, username: 'dung')),
            ],
            outgoing: [
              FriendRequestItem(
                  requestId: 11,
                  user: const UserSummary(userId: 21, username: 'hoa')),
            ],
          );
      api.onSearchUsers = (q) async => const [
            UserSummary(userId: 2, username: 'u2', fullName: 'Bình'),
            UserSummary(userId: 20, username: 'dung'),
            UserSummary(userId: 21, username: 'hoa'),
            UserSummary(userId: 30, username: 'moi'),
            UserSummary(userId: 7, username: 'an_nguyen'),
          ];
      final sent = <int>[];
      api.onSendFriendRequest = (id) async => sent.add(id);
      await pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'dun');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text('Bạn bè'), findsWidgets);
      expect(find.text('Chấp nhận'), findsOneWidget);
      expect(find.text('Đã gửi · Hủy'), findsOneWidget);
      expect(find.text('Kết bạn'), findsOneWidget);
      expect(find.text('@an_nguyen'), findsNothing); // không hiện chính mình
      await tester.tap(find.text('Kết bạn'));
      await tester.pumpAndSettle();
      expect(sent, [30]);
    });
  });
}
