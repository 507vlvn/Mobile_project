// ignore_for_file: invalid_use_of_visible_for_testing_member
// Chụp ảnh các màn tài khoản / lịch sử / xếp hạng (giao diện sáng + tối).
// Chạy: flutter test tool/screenshots/account_screens_test.dart --dart-define=OUT=<thư mục>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/network/api_client.dart';
import 'package:mobile_rubik/core/network/models.dart';
import 'package:mobile_rubik/core/theme/app_theme.dart';
import 'package:mobile_rubik/core/theme/theme_controller.dart';
import 'package:mobile_rubik/features/auth/auth_controller.dart';
import 'package:mobile_rubik/features/auth/login_screen.dart';
import 'package:mobile_rubik/features/auth/register_screen.dart';
import 'package:mobile_rubik/features/history/history_screen.dart';
import 'package:mobile_rubik/features/leaderboard/leaderboard_screen.dart';
import 'package:mobile_rubik/features/profile/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  await load(kFontFamily, [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/BeVietnamPro-$w.ttf',
  ]);
  final flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final iconFont = '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf';
  if (File(iconFont).existsSync()) {
    await load('MaterialIcons', [iconFont]);
  }
}

Widget _app(Widget home, ThemeMode mode, FakeApiClient api, AuthController auth) {
  final controller = ThemeController()..setMode(mode);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: controller),
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider<AuthController>.value(value: auth),
    ],
    child: RepaintBoundary(
      key: _boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: home,
      ),
    ),
  );
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 50));
  final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_out/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

HistoryItem _h(int id, String game, String name, int diff, String dn, int t,
    int m, String res, int score, Duration ago) {
  return HistoryItem(
    historyId: id,
    gameCode: game,
    gameName: name,
    difficulty: diff,
    difficultyName: dn,
    timeSpentSeconds: t,
    mistakesCount: m,
    result: res,
    score: score,
    playedAt: DateTime.now().subtract(ago),
  );
}

FakeApiClient _api() {
  final api = FakeApiClient();
  api.onLogin = () async => const AuthResult(token: 't', user: testUser);
  api.onMe = () async => testUser;
  api.onHistory = (game, page, size) async {
    final all = [
      _h(1, 'SUDOKU', 'Sudoku', 2, 'Vừa', 412, 2, 'COMPLETED', 1488, const Duration(minutes: 12)),
      _h(2, 'CARO', 'Caro', 3, 'Khó', 95, 0, 'WIN', 2905, const Duration(hours: 3)),
      _h(3, 'CARO', 'Caro', 1, 'Dễ', 40, 1, 'LOSE', 0, const Duration(hours: 5)),
      _h(4, 'PUZZLE', 'Xếp hình', 1, 'Dễ', 3700, 4, 'ABANDONED', 0, const Duration(days: 1)),
      _h(5, 'RUBIK', 'Rubik 3D', 2, 'Vừa', 230, 1, 'COMPLETED', 1720, const Duration(days: 3)),
      _h(6, 'CARO', 'Caro', 2, 'Vừa', 120, 0, 'DRAW', 940, const Duration(days: 12)),
      _h(7, 'SUDOKU', 'Sudoku', 1, 'Dễ', 300, 0, 'COMPLETED', 700, const Duration(days: 20)),
    ];
    return PagedResult(items: all, page: 1, pageSize: 20, total: all.length);
  };
  api.onLeaderboard = (q) async => [
        const BoardEntry(rank: 1, userId: 11, username: 'minh_tran', fullName: 'Trần Quang Minh', value: 2891, bestTimeSeconds: 84),
        const BoardEntry(rank: 2, userId: 12, username: 'lan_pham', fullName: 'Phạm Thị Lan', value: 2740, bestTimeSeconds: 131),
        const BoardEntry(rank: 3, userId: 13, username: 'hoang99', value: 2655, bestTimeSeconds: 160),
        const BoardEntry(rank: 4, userId: 14, username: 'bao_le', fullName: 'Lê Gia Bảo', value: 2400, bestTimeSeconds: 198),
        const BoardEntry(rank: 5, userId: 15, username: 'thuy', fullName: 'Nguyễn Thu Thủy', value: 2310, bestTimeSeconds: 245),
        const BoardEntry(rank: 6, userId: 7, username: 'an_nguyen', fullName: 'Nguyễn Văn An', value: 2102, bestTimeSeconds: 301),
        const BoardEntry(rank: 7, userId: 16, username: 'khoa_vo', value: 1990, bestTimeSeconds: 355),
        const BoardEntry(rank: 8, userId: 17, username: 'ngoc_anh', fullName: 'Đỗ Ngọc Ánh', value: 1800, bestTimeSeconds: 402),
      ];
  api.onMyRank = (q) async =>
      const BoardMe(rank: 6, value: 2102, bestTimeSeconds: 301);
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

  AuthController guest(FakeApiClient api) =>
      AuthController(api: api, tokens: FakeTokenStorage());

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final tag = mode.name;

    testWidgets('login $tag', (tester) async {
      await phone(tester);
      final api = _api();
      await tester.pumpWidget(_app(const LoginScreen(), mode, api, guest(api)));
      await tester.pumpAndSettle();
      await _shot(tester, '01_login_$tag');

      // lỗi từ server
      api.onLogin = () async => throw Exception('x');
      await tester.enterText(find.byType(TextFormField).first, 'an');
      await tester.enterText(find.byType(TextFormField).last, 'sai');
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();
      await _shot(tester, '02_login_error_$tag');
    });

    testWidgets('register $tag', (tester) async {
      await phone(tester);
      final api = _api();
      await tester.pumpWidget(_app(const RegisterScreen(), mode, api, guest(api)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'a b');
      await tester.enterText(find.byType(TextFormField).at(1), 'khong-phai-email');
      await tester.enterText(find.byType(TextFormField).at(3), '123');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.pumpAndSettle();
      await _shot(tester, '03_register_errors_$tag');
    });

    testWidgets('profile guest $tag', (tester) async {
      await phone(tester);
      final api = _api();
      await tester.pumpWidget(_app(const ProfileScreen(), mode, api, guest(api)));
      await tester.pumpAndSettle();
      await _shot(tester, '04_profile_guest_$tag');
    });

    testWidgets('profile user $tag', (tester) async {
      await phone(tester);
      final api = _api();
      final auth = await loggedIn(tester, api);
      await tester.pumpWidget(_app(const ProfileScreen(), mode, api, auth));
      await tester.pumpAndSettle();
      await _shot(tester, '05_profile_user_$tag');
    });

    testWidgets('history $tag', (tester) async {
      await phone(tester);
      final api = _api();
      final auth = await loggedIn(tester, api);
      await tester.pumpWidget(_app(const HistoryScreen(), mode, api, auth));
      await tester.pumpAndSettle();
      await _shot(tester, '06_history_$tag');
    });

    testWidgets('leaderboard $tag', (tester) async {
      await phone(tester);
      final api = _api();
      final auth = await loggedIn(tester, api);
      await tester.pumpWidget(_app(const LeaderboardScreen(), mode, api, auth));
      await tester.pumpAndSettle();
      await _shot(tester, '07_leaderboard_$tag');
    });

    testWidgets('leaderboard guest $tag', (tester) async {
      await phone(tester);
      final api = _api();
      await tester.pumpWidget(_app(const LeaderboardScreen(), mode, api, guest(api)));
      await tester.pumpAndSettle();
      await _shot(tester, '08_leaderboard_guest_$tag');
    });
  }
}
