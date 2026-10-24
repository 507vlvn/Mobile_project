// ignore_for_file: invalid_use_of_visible_for_testing_member
// Chụp ảnh màn hình Caro (sáng/tối) để rà soát giao diện.
// Chạy: flutter test tool/screenshots/caro_screens_test.dart --dart-define=OUT=<thư mục>
import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/models/difficulty.dart';
import 'package:mobile_rubik/core/models/challenge_context.dart';
import 'package:mobile_rubik/core/services/score_reporter.dart';
import 'package:mobile_rubik/core/theme/app_theme.dart';
import 'package:mobile_rubik/core/theme/theme_controller.dart';
import 'package:mobile_rubik/features/caro/caro_controller.dart';
import 'package:mobile_rubik/features/caro/caro_screen.dart';
import 'package:mobile_rubik/features/caro/logic/caro_ai.dart';
import 'package:mobile_rubik/features/caro/logic/caro_board.dart';
import 'package:mobile_rubik/features/caro/widgets/caro_board_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) 'assets/fonts/BeVietnamPro-$w.ttf',
  ]);
  final flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final iconFont = '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf';
  if (File(iconFont).existsSync()) {
    await load('MaterialIcons', [iconFont]);
  }
}

Widget _app(Widget home, ThemeMode mode) {
  final controller = ThemeController()..setMode(mode);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: controller),
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

int _i(int r, int c) => caroIndex(r, c);

/// Máy đánh theo kịch bản (rồi rơi về AI Vừa).
CaroController _scripted(List<int> aiMoves) {
  final q = Queue<int>.of(aiMoves);
  return CaroController(
    aiRunner: (r) async => q.isNotEmpty ? q.removeFirst() : chooseCaroMove(r),
    minThinkTime: Duration.zero,
  );
}

Offset _cellPoint(WidgetTester tester, int r, int c) {
  final paint = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is CaroBoardPainter);
  final box = tester.renderObject<RenderBox>(paint);
  final geo = CaroGeometry(box.size.shortestSide);
  return box.localToGlobal(geo.center(_i(r, c)));
}

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({'caro_onboarding_done': true});
  });

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 2, 851 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Future<void> closeScreen(WidgetTester tester, CaroController c) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
    c.dispose();
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final tag = mode.name;

    testWidgets('challenge $tag', (tester) async {
      await phone(tester);
      const ctx = ChallengeContext(challengeId: 2024, gameCode: 'CARO', difficulty: Difficulty.easy);
      final c = CaroController(
        challenge: ctx,
        aiRunner: (r) async => chooseCaroMove(r),
        minThinkTime: Duration.zero,
      );
      await tester.pumpWidget(_app(CaroScreen(controller: c, challenge: ctx), mode));
      await tester.pumpAndSettle();
      for (final m in [_i(7, 7), _i(8, 8)]) {
        c.placePlayer(m);
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pumpAndSettle();
      await _shot(tester, '09_challenge_$tag');
      await closeScreen(tester, c);
    });

    testWidgets('setup $tag', (tester) async {
      await phone(tester);
      final c = _scripted([]);
      await tester.pumpWidget(_app(CaroScreen(controller: c), mode));
      await tester.pumpAndSettle();
      await _shot(tester, '01_setup_$tag');
      await closeScreen(tester, c);
    });

    testWidgets('mid-game ghost $tag', (tester) async {
      await phone(tester);
      final c = _scripted([_i(7, 8), _i(6, 6), _i(10, 10), _i(5, 9)]);
      await tester.pumpWidget(_app(CaroScreen(controller: c), mode));
      await tester.pumpAndSettle();
      c.newGame(difficulty: Difficulty.medium, playerFirst: true);
      for (final m in [_i(7, 7), _i(8, 8), _i(9, 9), _i(6, 8)]) {
        c.placePlayer(m);
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pumpAndSettle();
      await _shot(tester, '02_midgame_$tag');

      await tester.tapAt(_cellPoint(tester, 8, 6));
      await tester.pumpAndSettle();
      await _shot(tester, '03_ghost_$tag');
      await closeScreen(tester, c);
    });

    testWidgets('zoomed $tag', (tester) async {
      await phone(tester);
      final c = _scripted([_i(7, 8), _i(6, 6)]);
      await tester.pumpWidget(_app(CaroScreen(controller: c), mode));
      await tester.pumpAndSettle();
      c.newGame(difficulty: Difficulty.medium, playerFirst: true);
      for (final m in [_i(7, 7), _i(8, 8)]) {
        c.placePlayer(m);
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 400));
      }
      final p = _cellPoint(tester, 7, 7);
      await tester.tapAt(p);
      await tester.tapAt(p);
      await tester.pumpAndSettle();
      await _shot(tester, '04_zoomed_$tag');
      await closeScreen(tester, c);
    });

    testWidgets('thinking $tag', (tester) async {
      await phone(tester);
      final never = Completer<int>();
      final c = CaroController(aiRunner: (r) => never.future, minThinkTime: Duration.zero);
      await tester.pumpWidget(_app(CaroScreen(controller: c), mode));
      await tester.pumpAndSettle();
      c.newGame(difficulty: Difficulty.hard, playerFirst: true);
      c.placePlayer(_i(7, 7));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 450));
      await _shot(tester, '05_thinking_$tag');
      await closeScreen(tester, c);
    });

    testWidgets('finished $tag', (tester) async {
      await phone(tester);
      final c = _scripted([_i(0, 0), _i(0, 2), _i(0, 4), _i(0, 6)]);
      await tester.pumpWidget(_app(CaroScreen(controller: c), mode));
      await tester.pumpAndSettle();
      c.newGame(difficulty: Difficulty.medium, playerFirst: true);
      for (var col = 4; col < 9; col++) {
        c.placePlayer(_i(9, col));
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pump(const Duration(milliseconds: 700));
      await _shot(tester, '06_finished_$tag');

      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      await _shot(tester, '07_result_$tag');
      await closeScreen(tester, c);
    });
  }

  testWidgets('onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await phone(tester);
    final c = _scripted([]);
    await tester.pumpWidget(_app(CaroScreen(controller: c), ThemeMode.light));
    await tester.pumpAndSettle();
    await _shot(tester, '08_onboarding_light');
    await closeScreen(tester, c);
  });
}
