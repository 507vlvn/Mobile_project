// ignore_for_file: invalid_use_of_visible_for_testing_member
// Chụp ảnh màn hình UI bằng widget test để rà soát giao diện sáng/tối.
// Chạy: flutter test tool/screenshots/screenshots_test.dart --dart-define=OUT=<thư mục>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/network/api_client.dart';
import 'package:mobile_rubik/core/network/models.dart';
import 'package:mobile_rubik/core/services/score_reporter.dart';
import 'package:mobile_rubik/core/theme/app_theme.dart';
import 'package:mobile_rubik/features/auth/auth_controller.dart';
import 'package:mobile_rubik/core/theme/theme_controller.dart';
import 'package:mobile_rubik/features/rubik/practice/practice_screen.dart';
import 'package:mobile_rubik/features/rubik/screens/rubik_home_screen.dart';
import 'package:mobile_rubik/features/shell/main_shell.dart';
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

Widget _app(Widget home, ThemeMode mode) {
  final controller = ThemeController()..setMode(mode);
  final api = FakeApiClient()
    ..onLeaderboard = ((_) async => <BoardEntry>[]);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: controller),
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider(
        create: (_) => AuthController(api: api, tokens: FakeTokenStorage()),
      ),
      Provider<ScoreReporter>.value(value: LocalScoreReporter()),
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

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({'rubik_onboarding_done': true});
  });

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 2, 851 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final tag = mode.name;

    testWidgets('hub $tag', (tester) async {
      await phone(tester);
      await tester.pumpWidget(_app(const MainShell(), mode));
      await tester.pumpAndSettle();
      await _shot(tester, '01_hub_$tag');
    });

    testWidgets('profile $tag', (tester) async {
      await phone(tester);
      await tester.pumpWidget(_app(const MainShell(), mode));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hồ sơ'));
      await tester.pumpAndSettle();
      await _shot(tester, '02_profile_$tag');
    });

    testWidgets('rubik home $tag', (tester) async {
      await phone(tester);
      await tester.pumpWidget(_app(const RubikHomeScreen(), mode));
      await tester.pumpAndSettle();
      await _shot(tester, '03_rubik_home_$tag');
    });

    testWidgets('practice $tag', (tester) async {
      await phone(tester);
      await tester.pumpWidget(_app(const PracticeScreen(), mode));
      await tester.pumpAndSettle();
      await _shot(tester, '04_practice_setup_$tag');

      await tester.tap(find.text('Xáo đề & bắt đầu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _shot(tester, '05_practice_scrambling_$tag');
      await tester.pumpAndSettle();
      await _shot(tester, '06_practice_playing_$tag');

      // Gợi ý: bộ giải chạy trên isolate thật
      await tester.tap(find.text('Gợi ý'));
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 3)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _shot(tester, '07_practice_hint_$tag');

      await tester.tap(find.text('Bảng nút'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5))
          .catchError((_) => 0);
      await tester.pump(const Duration(milliseconds: 400));
      await _shot(tester, '08_practice_pad_$tag');

      await tester.tap(find.byTooltip('Tạm dừng'));
      await tester.pump(const Duration(milliseconds: 400));
      await _shot(tester, '09_practice_paused_$tag');
    });
  }

  testWidgets('onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await phone(tester);
    await tester.pumpWidget(_app(const PracticeScreen(), ThemeMode.light));
    await tester.pumpAndSettle();
    await _shot(tester, '10_onboarding_light');
  });
}
