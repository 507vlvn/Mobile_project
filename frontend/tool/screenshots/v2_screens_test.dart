// ignore_for_file: invalid_use_of_visible_for_testing_member
// Chụp ảnh các màn v2: Xếp hạng, hồ sơ người chơi, Bạn bè, thông báo mời đấu, Hồ sơ.
// Chạy: flutter test tool/screenshots/v2_screens_test.dart --dart-define=OUT=<thư mục>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/models/presence.dart';
import 'package:mobile_rubik/core/models/rank.dart';
import 'package:mobile_rubik/core/network/api_client.dart';
import 'package:mobile_rubik/core/network/models.dart';
import 'package:mobile_rubik/core/realtime/notification_overlay.dart';
import 'package:mobile_rubik/core/realtime/realtime_service.dart';
import 'package:mobile_rubik/core/services/shell_navigation.dart';
import 'package:mobile_rubik/core/theme/app_theme.dart';
import 'package:mobile_rubik/core/theme/theme_controller.dart';
import 'package:mobile_rubik/features/auth/auth_controller.dart';
import 'package:mobile_rubik/features/leaderboard/leaderboard_screen.dart';
import 'package:mobile_rubik/features/profile/player_profile_sheet.dart';
import 'package:mobile_rubik/features/profile/profile_screen.dart';
import 'package:mobile_rubik/features/social/social_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/core/fake_realtime.dart';
import '../../test/core/fakes.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/screenshots');
final _boundary = GlobalKey();

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      final bytes = File(p).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('BeVietnamPro', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/BeVietnamPro-$w.ttf',
  ]);
  final flutterRoot = File(Platform.resolvedExecutable)
      .parent
      .parent
      .parent
      .parent
      .parent
      .parent
      .path;
  final iconFont =
      '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf';
  if (File(iconFont).existsSync()) {
    await load('MaterialIcons', [iconFont]);
  }
}

final _navKey = GlobalKey<NavigatorState>();

Widget _app(Widget home, ThemeMode mode, FakeApiClient api,
    AuthController auth, FakeRealtimeService rt) {
  final controller = ThemeController()..setMode(mode);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: controller),
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider<AuthController>.value(value: auth),
      ListenableProvider<RealtimeService>.value(value: rt),
      ChangeNotifierProvider(create: (_) => ShellNavigation()),
    ],
    child: RepaintBoundary(
      key: _boundary,
      child: MaterialApp(
        navigatorKey: _navKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        builder: (context, child) => NotificationOverlay(
          navigatorKey: _navKey,
          myId: () => 7,
          child: child!,
        ),
        home: home,
      ),
    ),
  );
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 50));
  final boundary =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_out/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

FriendInfo _f(int id, String user, String? name, PresenceStatus p,
        [Duration? ago]) =>
    FriendInfo(
      userId: id,
      username: user,
      fullName: name,
      presence: p,
      lastSeenAt: ago == null ? null : DateTime.now().subtract(ago),
    );

List<GameStats> _stats() => const [
      GameStats(
          gameCode: 'RUBIK',
          rating: 1120,
          games: 8,
          wins: 5,
          losses: 3,
          bestScore: 2410),
      GameStats(
          gameCode: 'SUDOKU',
          rating: 1265,
          games: 22,
          wins: 14,
          losses: 7,
          draws: 1,
          bestScore: 2980),
      GameStats(gameCode: 'PUZZLE', bestScore: 1500),
      GameStats(
          gameCode: 'CARO',
          rating: 1612,
          games: 41,
          wins: 29,
          losses: 10,
          draws: 2,
          bestScore: 3000),
    ];

FakeApiClient _api() {
  final api = FakeApiClient();
  api.onLogin = () async => const AuthResult(token: 't', user: testUser);
  api.onSeason = () async => SeasonInfo(
        startsAt: DateTime.now().subtract(const Duration(days: 3, hours: 20)),
        endsAt: DateTime.now().add(const Duration(days: 3, hours: 4, minutes: 20)),
      );
  api.onLeaderboard = (q) async {
    final ranked = q.board == BoardType.ranked;
    const names = [
      ('minh_tran', 'Trần Quang Minh'),
      ('lan_pham', 'Phạm Thị Lan'),
      ('hoang99', null),
      ('bao_le', 'Lê Gia Bảo'),
      ('thuy', 'Nguyễn Thu Thủy'),
      ('an_nguyen', 'Nguyễn Văn An'),
      ('khoa_vo', null),
      ('ngoc_anh', 'Đỗ Ngọc Ánh'),
    ];
    final ranks = [1, 2, 2, 4, 5, 6, 7, 8];
    final ratings = [1688, 1540, 1540, 1402, 1263, 1120, 1090, 1035];
    final scores = [2891, 2740, 2740, 2400, 2310, 2102, 1990, 1800];
    var entries = [
      for (var i = 0; i < names.length; i++)
        BoardEntry(
          rank: ranks[i],
          userId: i == 5 ? 7 : 11 + i,
          username: names[i].$1,
          fullName: names[i].$2,
          value: ranked ? ratings[i] : scores[i],
          bestTimeSeconds: ranked ? null : 84 + i * 40,
          games: ranked ? 40 - i * 3 : null,
          tier: ranked ? Tier.fromRating(ratings[i]) : null,
        ),
    ];
    if (q.scope == BoardScope.friends) entries = entries.take(4).toList();
    return entries;
  };
  api.onMyRank = (q) async => q.board == BoardType.ranked
      ? const BoardMe(rank: 6, value: 1120, games: 12)
      : const BoardMe(rank: 6, value: 2102, bestTimeSeconds: 301);
  api.onFriends = () async => [
        _f(1, 'lan_pham', 'Phạm Thị Lan', PresenceStatus.offline,
            const Duration(minutes: 25)),
        _f(2, 'minh_tran', 'Trần Quang Minh', PresenceStatus.online),
        _f(3, 'hoang99', null, PresenceStatus.inMatch),
        _f(4, 'bao_le', 'Lê Gia Bảo', PresenceStatus.offline,
            const Duration(days: 2)),
        _f(5, 'thuy', 'Nguyễn Thu Thủy', PresenceStatus.online),
      ];
  api.onFriendRequests = () async => FriendRequests(
        incoming: [
          FriendRequestItem(
              requestId: 1,
              user: const UserSummary(
                  userId: 31, username: 'khoa_vo', fullName: 'Võ Đăng Khoa')),
          FriendRequestItem(
              requestId: 2,
              user: const UserSummary(userId: 32, username: 'ngoc_anh')),
        ],
        outgoing: [
          FriendRequestItem(
              requestId: 3,
              user: const UserSummary(
                  userId: 33, username: 'tuan_kiet', fullName: 'Tuấn Kiệt')),
        ],
      );
  api.onUserProfile = (id) async => PlayerProfile(
        userId: id,
        username: 'lan_pham',
        fullName: 'Phạm Thị Lan',
        relationship: Relationship.friends,
        presence: PresenceStatus.online,
        stats: _stats(),
      );
  api.onMyRatings = () async => _stats();
  api.onMatches = (page) async {
    final t = DateTime.now();
    UserSummary o(String u, String n) =>
        UserSummary(userId: 50, username: u, fullName: n);
    final items = [
      MatchHistoryItem(
          matchId: '9',
          gameCode: 'CARO',
          opponent: o('lan_pham', 'Phạm Thị Lan'),
          result: MatchResult.win,
          ratingBefore: 1590,
          ratingAfter: 1612,
          endedAt: t.subtract(const Duration(minutes: 30))),
      MatchHistoryItem(
          matchId: '8',
          gameCode: 'SUDOKU',
          opponent: o('minh_tran', 'Trần Quang Minh'),
          result: MatchResult.lose,
          ratingBefore: 1280,
          ratingAfter: 1265,
          endedAt: t.subtract(const Duration(hours: 5))),
      MatchHistoryItem(
          matchId: '7',
          gameCode: 'CARO',
          ranked: false,
          opponent: o('bao_le', 'Lê Gia Bảo'),
          result: MatchResult.draw,
          endedAt: t.subtract(const Duration(days: 1))),
      MatchHistoryItem(
          matchId: '6',
          gameCode: 'RUBIK',
          opponent: o('hoang99', 'hoang99'),
          result: MatchResult.draw,
          ratingBefore: 1120,
          ratingAfter: 1120,
          endedAt: t.subtract(const Duration(days: 3))),
    ];
    return PagedResult(items: items, page: 1, pageSize: 20, total: 9);
  };
  return api;
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 2, 851 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Future<AuthController> loggedIn(WidgetTester tester, FakeApiClient api) async {
    final auth = AuthController(api: api, tokens: FakeTokenStorage());
    await tester.runAsync(() => auth.login('an', 'x'));
    return auth;
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final tag = mode.name;

    testWidgets('leaderboard $tag', (tester) async {
      await phone(tester);
      final api = _api();
      final auth = await loggedIn(tester, api);
      final rt = FakeRealtimeService();
      await tester.pumpWidget(
          _app(const LeaderboardScreen(), mode, api, auth, rt));
      await tester.pumpAndSettle();
      await _shot(tester, '01_leaderboard_record_$tag');

      await tester.tap(find.text('Đối kháng'));
      await tester.pumpAndSettle();
      await _shot(tester, '02_leaderboard_ranked_$tag');

      await tester.tap(find.text('Bạn bè'));
      await tester.pumpAndSettle();
      await _shot(tester, '03_leaderboard_friends_$tag');
    });

    testWidgets('leaderboard guest friends $tag', (tester) async {
      await phone(tester);
      final api = _api();
      final auth = AuthController(api: api, tokens: FakeTokenStorage());
      await tester.runAsync(auth.restore);
      await tester.pumpWidget(_app(
          const LeaderboardScreen(), mode, api, auth, FakeRealtimeService()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bạn bè'));
      await tester.pumpAndSettle();
      await _shot(tester, '04_leaderboard_guest_friends_$tag');
    });

    testWidgets('profile sheet $tag', (tester) async {
      await phone(tester);
      final api = _api();
      final auth = await loggedIn(tester, api);
      final rt = FakeRealtimeService();
      await tester.pumpWidget(_app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showPlayerProfileSheet(context,
                    const UserSummary(userId: 12, username: 'lan_pham')),
                child: const Text('mở'),
              ),
            ),
          ),
        ),
        mode,
        api,
        auth,
        rt,
      ));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      await _shot(tester, '05_profile_sheet_$tag');

      await tester.tap(find.text('Mời đấu'));
      await tester.pumpAndSettle();
      await _shot(tester, '06_invite_picker_$tag');
      await tester.tap(find.text('Gửi lời mời'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await _shot(tester, '07_invite_waiting_$tag');
      // đóng sheet để dọn Timer
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
    });

    testWidgets('friends $tag', (tester) async {
      await phone(tester);
      final api = _api();
      final auth = await loggedIn(tester, api);
      final rt = FakeRealtimeService();
      await tester.pumpWidget(
          _app(const SocialScreen(), mode, api, auth, rt));
      await tester.pumpAndSettle();
      await _shot(tester, '08_friends_list_$tag');

      await tester.tap(find.text('Lời mời'));
      await tester.pumpAndSettle();
      await _shot(tester, '09_friend_requests_$tag');
    });

    testWidgets('friends search $tag', (tester) async {
      await phone(tester);
      final api = _api();
      api.onSearchUsers = (q) async => const [
            UserSummary(userId: 2, username: 'minh_tran', fullName: 'Trần Quang Minh'),
            UserSummary(userId: 31, username: 'khoa_vo', fullName: 'Võ Đăng Khoa'),
            UserSummary(userId: 33, username: 'tuan_kiet', fullName: 'Tuấn Kiệt'),
            UserSummary(userId: 40, username: 'minh_chau'),
          ];
      final auth = await loggedIn(tester, api);
      await tester.pumpWidget(_app(
          const SocialScreen(), mode, api, auth, FakeRealtimeService()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'minh');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      await _shot(tester, '10_friend_search_$tag');
    });

    testWidgets('invite banner $tag', (tester) async {
      await phone(tester);
      final api = _api();
      final auth = await loggedIn(tester, api);
      final rt = FakeRealtimeService();
      await tester.pumpWidget(
          _app(const SocialScreen(), mode, api, auth, rt));
      await tester.pumpAndSettle();
      rt.emitInvite(InviteReceivedEvent(
        inviteId: 'abc',
        from: const RtUser(
            userId: 12, username: 'lan_pham', fullName: 'Phạm Thị Lan'),
        gameCode: 'CARO',
        difficulty: 3,
        receivedAt: DateTime.now().subtract(const Duration(seconds: 8)),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await _shot(tester, '11_invite_banner_$tag');
      // dọn: từ chối để dừng Timer
      await tester.tap(find.text('Từ chối'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('profile v2 $tag', (tester) async {
      await phone(tester);
      final api = _api();
      final auth = await loggedIn(tester, api);
      await tester.pumpWidget(_app(
          const ProfileScreen(), mode, api, auth, FakeRealtimeService()));
      await tester.pumpAndSettle();
      await _shot(tester, '12_profile_top_$tag');
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      await _shot(tester, '13_profile_history_$tag');
    });
  }
}
