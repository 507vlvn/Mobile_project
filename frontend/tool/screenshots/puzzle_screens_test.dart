// ignore_for_file: invalid_use_of_visible_for_testing_member
// Chụp ảnh màn Xếp hình (sáng/tối) bằng widget test.
// Chạy: flutter test tool/screenshots/puzzle_screens_test.dart --dart-define=OUT=<thư mục>
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/services/score_reporter.dart';
import 'package:mobile_rubik/core/theme/app_theme.dart';
import 'package:mobile_rubik/core/models/difficulty.dart';
import 'package:mobile_rubik/core/models/challenge_context.dart';
import 'package:mobile_rubik/features/puzzle/logic/ida_star.dart';
import 'package:mobile_rubik/features/puzzle/puzzle_controller.dart';
import 'package:mobile_rubik/features/puzzle/puzzle_screen.dart';
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

Widget _app(PuzzleController c, ThemeMode mode) {
  return Provider<ScoreReporter>.value(
    value: LocalScoreReporter(),
    child: RepaintBoundary(
      key: _boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: PuzzleScreen(controller: c),
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

PuzzleController _controller() => PuzzleController(
      random: Random(5),
      solver: (b, n) async => solveOptimal(b, n),
    );

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({'puzzle_onboarding_done': true});
  });

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 2, 851 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final tag = mode.name;

    testWidgets('challenge $tag', (tester) async {
      await phone(tester);
      const ctx = ChallengeContext(challengeId: 2024, gameCode: 'PUZZLE', difficulty: Difficulty.medium);
      final c = PuzzleController(
          challenge: ctx, solver: (b, n) async => solveOptimal(b, n));
      await tester.pumpWidget(Provider<ScoreReporter>.value(
        value: LocalScoreReporter(),
        child: RepaintBoundary(
          key: _boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            home: PuzzleScreen(controller: c, challenge: ctx),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await _shot(tester, '09_challenge_$tag');
      c.clock.pause();
    });

    testWidgets('puzzle $tag', (tester) async {
      await phone(tester);
      final c = _controller();
      await tester.pumpWidget(_app(c, mode));
      await tester.pumpAndSettle();
      await _shot(tester, '01_setup_$tag');

      // 3×3 đang chơi: đi gần xong để thấy dấu tích ô đúng vị trí
      c.newGame(Difficulty.easy);
      await tester.pumpAndSettle();
      final path = solveOptimal(c.board, 3)!;
      for (final idx in path.take(path.length - 6)) {
        c.tap(idx);
      }
      await tester.pumpAndSettle();
      await _shot(tester, '02_play3_$tag');

      // Gợi ý
      await c.requestHint();
      await tester.pump(const Duration(milliseconds: 450));
      await _shot(tester, '03_hint3_$tag');

      // Tạm dừng
      await tester.tap(find.byTooltip('Tạm dừng'));
      await tester.pump(const Duration(milliseconds: 400));
      await _shot(tester, '04_paused_$tag');
      await tester.tap(find.text('Tiếp tục').first);
      await tester.pump(const Duration(milliseconds: 400));

      // Mục tiêu
      await tester.tap(find.text('Mục tiêu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 600));
      await _shot(tester, '05_goal_$tag');
      await tester.tap(find.text('Đã rõ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 600));

      // 5×5
      c.newGame(Difficulty.hard);
      await tester.pumpAndSettle();
      await _shot(tester, '06_play5_$tag');
      await c.requestHint();
      await tester.pump(const Duration(milliseconds: 450));
      await _shot(tester, '07_hint5_$tag');

      // Giải xong 3×3 → bảng kết quả
      c.newGame(Difficulty.easy);
      await tester.pumpAndSettle();
      for (final idx in solveOptimal(c.board, 3)!) {
        c.tap(idx);
      }
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await _shot(tester, '08_result_$tag');
    });
  }

  testWidgets('trợ giúp lần đầu', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await phone(tester);
    await tester.pumpWidget(_app(_controller(), ThemeMode.light));
    await tester.pumpAndSettle();
    await _shot(tester, '09_help_light');
  });

  testWidgets('chạm và vuốt trượt ô', (tester) async {
    await phone(tester);
    final c = _controller();
    await tester.pumpWidget(_app(c, ThemeMode.light));
    await tester.pumpAndSettle();
    c.newGame(Difficulty.easy);
    await tester.pumpAndSettle();
    final before = List<int>.of(c.board);
    final blank = before.indexOf(0);
    // chạm ô kề ô trống
    final nb = blank % 3 > 0 ? blank - 1 : blank + 1;
    final boardRect = tester.getRect(find.bySemanticsLabel(RegExp('Bảng xếp hình')));
    final cell = (boardRect.width - 2 * max(6, boardRect.width * 0.02)) / 3;
    Offset centerOf(int i) => boardRect.topLeft +
        Offset(max(6, boardRect.width * 0.02) + (i % 3 + .5) * cell,
            max(6, boardRect.width * 0.02) + (i ~/ 3 + .5) * cell);
    await tester.tapAt(centerOf(nb));
    await tester.pumpAndSettle();
    expect(c.moves, 1);
    expect(c.board.indexOf(0), nb);
    // vuốt: kéo sang phải khi ô trống có ô bên trái
    final b2 = c.board.indexOf(0);
    if (b2 % 3 > 0) {
      await tester.dragFrom(centerOf(b2 - 1), const Offset(80, 0));
      await tester.pumpAndSettle();
      expect(c.moves, 2);
    }
    c.clock.pause();
  });
}
