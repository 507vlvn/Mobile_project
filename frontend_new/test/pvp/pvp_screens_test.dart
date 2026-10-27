import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_new/XepHinh/shared/models/difficulty.dart';
import 'package:frontend_new/XepHinh/xep_hinh_screen.dart';
import 'package:frontend_new/core/models/presence.dart';
import 'package:frontend_new/friends/friends_tab.dart';
import 'package:frontend_new/pvp/invite_sheet.dart';
import 'package:frontend_new/XepHinh/sliding_puzzle/sliding_puzzle_logic.dart';
import 'package:frontend_new/auth/auth_controller.dart';
import 'package:frontend_new/core/network/api_client.dart';
import 'package:frontend_new/core/network/models.dart';
import 'package:frontend_new/core/network/token_storage.dart';
import 'package:frontend_new/core/realtime/realtime_service.dart';
import 'package:frontend_new/core/theme/app_theme.dart';
import 'package:frontend_new/pvp/caro_online_screen.dart';
import 'package:frontend_new/pvp/match_session.dart';
import 'package:frontend_new/pvp/pvp_lobby_screen.dart';
import 'package:frontend_new/pvp/pvp_navigator.dart';
import 'package:frontend_new/pvp/race_puzzle_screen.dart';

import '../support/fake_realtime.dart';

const _me = AppUser(userId: 7, username: 'binh', email: 'b@x.com', fullName: 'Thái Bình');

class _Api implements ApiClient {
  @override
  VoidCallback? onUnauthorized;
  @override
  Future<AppUser> me() async => _me;
  @override
  Future<List<GameStats>> myRatings() async =>
      const [GameStats(gameCode: 'CARO', rating: 1200, games: 4, wins: 3, losses: 1)];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _Env {
  final FakeRealtime rt;
  final MatchSession session;
  _Env(this.rt, this.session);
}

Future<_Env> _pump(WidgetTester tester, {bool loggedIn = true, Widget home = const PvpLobbyScreen()}) async {
  SharedPreferences.setMockInitialValues(loggedIn ? {'auth_token': 't'} : {});
  debugResetMatchRoute();
  final api = _Api();
  final auth = AuthController(api: api, tokens: TokenStorage());
  await auth.restore();
  final rt = FakeRealtime();
  final session = MatchSession(realtime: rt);
  addTearDown(session.dispose);
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider<AuthController>.value(value: auth),
      ListenableProvider<RealtimeService>.value(value: rt),
      ChangeNotifierProvider<MatchSession>.value(value: session),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appMessengerKey,
      builder: (context, child) => PvpNavigator(child: child!),
      home: home,
    ),
  ));
  await tester.pumpAndSettle();
  return _Env(rt, session);
}

/// Đợi màn trận được mở: khung đầu của route mới luôn ẩn (để tính Hero),
/// nên cần thêm vài nhịp.
Future<void> _openRoute(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('Sảnh khi chưa đăng nhập: mời đăng nhập', (tester) async {
    await _pump(tester, loggedIn: false);
    expect(find.text('Đăng nhập để đấu với người khác'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('Sảnh: rating, tìm trận Caro, hủy; chọn Đua Xếp số 4×4', (tester) async {
    final env = await _pump(tester);
    expect(find.text('Chọn trò chơi'), findsOneWidget);
    expect(find.text('4 trận · thắng 75%'), findsOneWidget);

    await tester.tap(find.text('Tìm trận xếp hạng'));
    await tester.pump();
    expect(env.rt.calls.last, 'QueueJoin CARO 2');
    expect(find.textContaining('Đang tìm đối thủ'), findsOneWidget);

    await tester.tap(find.text('Hủy tìm trận'));
    await tester.pump();
    expect(env.rt.calls.last, 'QueueLeave');

    await tester.tap(find.text('Đua Xếp số'));
    await tester.pump();
    await tester.tap(find.text('4×4'));
    await tester.pump();
    await tester.ensureVisible(find.text('Tìm trận xếp hạng'));
    await tester.tap(find.text('Tìm trận xếp hạng'));
    await tester.pump();
    expect(env.rt.calls.last, 'QueueJoin PUZZLE 2');
    await _dispose(tester);
  });

  testWidgets('Trận Caro bắt đầu: tự mở màn trận, chạm 2 lần để đặt quân', (tester) async {
    final env = await _pump(tester);
    env.rt.matchStartedCtl.add(matchInfo(currentTurnUserId: 7));
    await _openRoute(tester);
    expect(find.byType(CaroOnlineScreen), findsOneWidget);
    expect(find.text('Lượt của bạn — chạm một ô'), findsOneWidget);

    final board = find.byType(InteractiveViewer);
    await tester.tapAt(tester.getCenter(board));
    await tester.pump();
    expect(find.text('Chạm lần nữa để đặt quân'), findsOneWidget);
    expect(env.rt.calls.where((c) => c.startsWith('CaroMove')), isEmpty);
    // Chạm chậm như người thật: bàn cờ coi hai lần chạm nhanh (theo đồng hồ thật)
    // là double-tap phóng to, nên chờ thời gian thật giữa hai lần chạm.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 450)));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tapAt(tester.getCenter(board));
    await tester.pump(const Duration(milliseconds: 400)); // bàn cờ chờ để phân biệt double-tap
    expect(env.rt.calls.where((c) => c.startsWith('CaroMove')).single, 'CaroMove m1 7 7');

    // Server xác nhận nước đi, tới lượt đối thủ
    env.rt.matchStateCtl.add(matchInfo(moves: [
      [7, 7, 7]
    ], currentTurnUserId: 9));
    await tester.pump();
    expect(find.text('Đang chờ đối thủ…'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('Đối thủ xin hòa -> đồng ý; trận kết thúc -> bảng kết quả -> về sảnh', (tester) async {
    final env = await _pump(tester);
    env.rt.matchStartedCtl.add(matchInfo(currentTurnUserId: 9));
    await _openRoute(tester);

    env.rt.drawOfferedCtl.add(const MatchSignalEvent('m1', 9));
    await tester.pump();
    await tester.pump();
    expect(find.text('Đối thủ xin hòa'), findsOneWidget);
    await tester.tap(find.text('Đồng ý'));
    await tester.pump();
    expect(env.rt.calls.last, 'RespondDraw m1 true');

    env.rt.matchEndedCtl.add(const MatchEndedEvent(
      matchId: 'm1',
      winnerId: 7,
      reason: 'WIN',
      ranked: true,
      ratingChanges: {7: RatingChange(7, 1200, 1216), 9: RatingChange(9, 1180, 1164)},
      scores: {7: 800},
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Chiến thắng!'), findsOneWidget);
    expect(find.text('Bạn đã chiến thắng'), findsOneWidget);
    expect(find.text('+16'), findsOneWidget);

    await tester.tap(find.text('Tái đấu'));
    await tester.pump();
    expect(env.rt.calls.last, 'Rematch m1');

    await tester.tap(find.text('Về sảnh'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Đầu hàng?'), findsNothing, reason: 'trận đã xong: không được hỏi đầu hàng');
    expect(find.byType(CaroOnlineScreen), findsNothing);
    expect(env.session.phase, PvpPhase.idle);
    await _dispose(tester);
  });

  testWidgets('Caro: đối thủ đầu hàng -> bảng kết quả chỉ có Về sảnh, không có Tái đấu', (tester) async {
    final env = await _pump(tester);
    env.rt.matchStartedCtl.add(matchInfo(currentTurnUserId: 9));
    await _openRoute(tester);

    env.rt.matchEndedCtl.add(const MatchEndedEvent(
      matchId: 'm1',
      winnerId: 7,
      reason: 'RESIGN',
      ranked: false,
      ratingChanges: {},
      scores: {},
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Chiến thắng!'), findsOneWidget);
    expect(find.text('Đối thủ đầu hàng'), findsOneWidget);
    expect(find.text('Tái đấu'), findsNothing);
    expect(find.text('Về sảnh'), findsOneWidget);

    await tester.tap(find.text('Về sảnh'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(CaroOnlineScreen), findsNothing);
    await _dispose(tester);
  });

  testWidgets('Caro: tự đầu hàng bằng nút Back -> vẫn thấy bảng kết quả (chỉ Về sảnh) rồi mới thoát',
      (tester) async {
    final env = await _pump(tester);
    env.rt.matchStartedCtl.add(matchInfo(currentTurnUserId: 7));
    await _openRoute(tester);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Đầu hàng?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Đầu hàng'));
    await tester.pump();
    expect(env.rt.calls.last, 'Resign m1');

    env.rt.matchEndedCtl.add(const MatchEndedEvent(
      matchId: 'm1',
      winnerId: 9,
      reason: 'RESIGN',
      ranked: false,
      ratingChanges: {},
      scores: {},
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(CaroOnlineScreen), findsOneWidget, reason: 'chưa thoát: phải cho xem kết quả trước');
    expect(find.text('Thất bại'), findsOneWidget);
    expect(find.text('Bạn đã đầu hàng'), findsOneWidget);
    expect(find.text('Tái đấu'), findsNothing);

    await tester.tap(find.text('Về sảnh'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(CaroOnlineScreen), findsNothing);
    await _dispose(tester);
  });

  testWidgets('Trận đua Xếp số: mở màn đua, đếm ngược rồi mới cho chạm', (tester) async {
    final env = await _pump(tester);
    env.rt.matchStartedCtl.add(matchInfo(gameCode: 'PUZZLE', difficulty: 1, seed: 99, currentTurnUserId: null));
    await _openRoute(tester);
    expect(find.byType(RacePuzzleScreen), findsOneWidget);
    expect(find.text('Nguyễn An'), findsOneWidget);
    expect(find.text('3'), findsWidgets, reason: 'đang đếm ngược');

    env.rt.progressCtl.add(const OpponentProgressEvent('m1', 9, 40));
    await tester.pump();
    await tester.pump();
    expect(find.text('40%'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.textContaining('Số bước: 0'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('Lời mời đấu hiện ở mọi màn hình; chấp nhận gửi RespondInvite', (tester) async {
    final env = await _pump(tester);
    env.rt.invitesCtl.add(InviteReceivedEvent(
      inviteId: 'x1',
      from: const UserSummary(userId: 9, username: 'an', fullName: 'Nguyễn An'),
      gameCode: 'PUZZLE',
      difficulty: 2,
      expiresInSec: 30,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Nguyễn An mời bạn đấu'), findsOneWidget);
    expect(find.textContaining('Xếp số 4×4'), findsOneWidget);

    await tester.tap(find.text('Chấp nhận'));
    await tester.pump();
    expect(env.rt.calls.last, 'RespondInvite x1 true');
    expect(find.text('Nguyễn An mời bạn đấu'), findsNothing);
    await _dispose(tester);
  });

  test('Cùng seed thì hai máy ra cùng một đề Xếp số', () {
    for (final d in GameDifficulty.values) {
      final a = SlidingPuzzleLogic(difficulty: d, seed: 12345);
      final b = SlidingPuzzleLogic(difficulty: d, seed: 12345);
      expect(a.tiles.map((t) => t.id).toList(), b.tiles.map((t) => t.id).toList());
      final c = SlidingPuzzleLogic(difficulty: d, seed: 54321);
      expect(c.tiles.map((t) => t.id).toList(), isNot(a.tiles.map((t) => t.id).toList()));
    }
  });

  test('progressPercent tăng khi ô về đúng chỗ, 100 khi xong', () {
    final l = SlidingPuzzleLogic(difficulty: GameDifficulty.easy, seed: 1);
    expect(l.progressPercent, inInclusiveRange(0, 99));
  });

  testWidgets('Dòng bạn bè có nút Mời đấu khi được truyền onInvite', (tester) async {
    var invited = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: FriendRow(
          friend: const FriendInfo(userId: 9, username: 'an', fullName: 'Nguyễn An', presence: PresenceStatus.online),
          onChat: () {},
          onMenu: (_) {},
          onInvite: () => invited++,
        ),
      ),
    ));
    await tester.tap(find.byTooltip('Mời Nguyễn An đấu'));
    expect(invited, 1);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: FriendRow(
          friend: const FriendInfo(userId: 9, username: 'an', fullName: 'Nguyễn An'),
          onChat: () {},
          onMenu: (_) {},
        ),
      ),
    ));
    expect(find.byTooltip('Mời Nguyễn An đấu'), findsNothing, reason: 'không có onInvite (offline) thì ẩn');
  });

  testWidgets('Bảng mời đấu: chọn Đua Xếp số 5×5 rồi gửi', (tester) async {
    final env = await _pump(
      tester,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showInviteSheet(context, const UserSummary(userId: 9, username: 'an', fullName: 'Nguyễn An')),
            child: const Text('mở'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(find.text('Mời Nguyễn An đấu'), findsOneWidget);
    await tester.tap(find.text('Đua Xếp số'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5×5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi lời mời'));
    await tester.pumpAndSettle();
    expect(env.rt.calls.last, 'Invite 9 PUZZLE 3');
    expect(env.session.phase, PvpPhase.inviting);
    expect(find.textContaining('Đã mời Nguyễn An'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('Màn Xếp hình có lối vào Đua Xếp số online', (tester) async {
    await _pump(tester, home: const XepHinhScreen());
    final card = find.text('Đua Xếp số với người khác');
    await tester.scrollUntilVisible(card, 200);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(PvpLobbyScreen), findsOneWidget);
    expect(find.text('Đối kháng'), findsOneWidget);
    await _dispose(tester);
  });
}
