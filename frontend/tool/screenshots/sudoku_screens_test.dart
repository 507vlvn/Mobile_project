// ignore_for_file: invalid_use_of_visible_for_testing_member
// Chụp ảnh màn hình Sudoku bằng widget test để rà soát giao diện sáng/tối.
// Chạy: flutter test tool/screenshots/sudoku_screens_test.dart --dart-define=OUT=<thư mục>
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/models/difficulty.dart';
import 'package:mobile_rubik/core/models/challenge_context.dart';
import 'package:mobile_rubik/core/theme/app_theme.dart';
import 'package:mobile_rubik/core/theme/theme_controller.dart';
import 'package:mobile_rubik/features/sudoku/logic/sudoku_board.dart';
import 'package:mobile_rubik/features/sudoku/logic/sudoku_generator.dart';
import 'package:mobile_rubik/features/sudoku/sudoku_controller.dart';
import 'package:mobile_rubik/features/sudoku/sudoku_screen.dart';
import 'package:mobile_rubik/features/sudoku/widgets/sudoku_board_view.dart';
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

Widget _app(Widget home, ThemeMode mode) {
  final controller = ThemeController()..setMode(mode);
  return ChangeNotifierProvider.value(
    value: controller,
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
  final boundary =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_out/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Ván dở có sẵn: vài ô đã điền đúng, một ô sai, một số ô có ghi chú.
Map<String, Object> _savedGame() {
  final p = generatePuzzle(Difficulty.medium, random: Random(11));
  final board = SudokuBoard(givens: p.puzzle, solution: p.solution);
  final empties = [
    for (var i = 0; i < 81; i++)
      if (board.isEmpty(i)) i
  ];
  for (final i in empties.take(14)) {
    board.values[i] = board.solution[i];
  }
  final rest = empties.skip(14).toList();
  board.values[rest[0]] = board.solution[rest[0]] % 9 + 1; // ô sai
  for (final i in rest.skip(1).take(10)) {
    final s = <int>{board.solution[i]};
    s.add((board.solution[i] + 2) % 9 + 1);
    s.add((board.solution[i] + 4) % 9 + 1);
    board.notes[i].addAll(s);
  }
  return {
    SudokuController.saveKey: jsonEncode({
      'difficulty': 2,
      'board': board.toJson(),
      'elapsedMs': 384000,
      'wrong': 1,
      'hints': 1,
      'entries': 15,
    }),
    'sudoku_onboarding_done': true,
  };
}

void main() {
  setUpAll(_loadFonts);

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 2, 851 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  /// Chạm vào ô [index] của bàn cờ.
  Future<void> tapCell(WidgetTester tester, int index) async {
    final rect = tester.getRect(find.byType(SudokuBoardView));
    final cell = rect.width / 9;
    final p = rect.topLeft +
        Offset((index % 9 + 0.5) * cell, (index ~/ 9 + 0.5) * cell);
    await tester.tapAt(p);
    await tester.pump(const Duration(milliseconds: 100));
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final tag = mode.name;

    testWidgets('challenge $tag', (tester) async {
      SharedPreferences.setMockInitialValues({'sudoku_onboarding_done': true});
      await phone(tester);
      await tester.pumpWidget(_app(
          SudokuScreen(
              challenge: const ChallengeContext(challengeId: 2024, gameCode: 'SUDOKU', difficulty: Difficulty.medium)),
          mode));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 3)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await _shot(tester, '09_challenge_$tag');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('setup + generating $tag', (tester) async {
      SharedPreferences.setMockInitialValues({'sudoku_onboarding_done': true});
      await phone(tester);
      await tester.pumpWidget(_app(const SudokuScreen(), mode));
      await tester.pumpAndSettle();
      await _shot(tester, '01_setup_$tag');

      await tester.tap(find.text('Tạo đề & bắt đầu'));
      await tester.pump(const Duration(milliseconds: 300));
      await _shot(tester, '02_generating_$tag');
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 3)));
      await tester.pump(const Duration(milliseconds: 300));
      await _shot(tester, '03_fresh_game_$tag');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('in game $tag', (tester) async {
      SharedPreferences.setMockInitialValues(_savedGame());
      await phone(tester);
      await tester.pumpWidget(_app(const SudokuScreen(), mode));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục')); // hộp thoại khôi phục
      await tester.pumpAndSettle();
      await _shot(tester, '04_restored_paused_$tag');

      await tester.tap(find.text('Tiếp tục').last);
      await tester.pump(const Duration(milliseconds: 300));

      // Chọn một ô đề bài để thấy tô cùng hàng/cột/khối và cùng số
      final saved =
          jsonDecode(_savedGame()[SudokuController.saveKey]! as String)
              as Map<String, dynamic>;
      final b = SudokuBoard.fromJson(saved['board'] as Map<String, dynamic>);
      final wrongIdx = [
        for (var i = 0; i < 81; i++)
          if (b.isWrong(i)) i
      ].first;
      // ô đề bài có cùng chữ số xuất hiện nhiều lần, gần ô sai
      var pick = -1;
      for (var i = 0; i < 81 && pick < 0; i++) {
        if (b.isGiven(i) && SudokuBoard.arePeers(i, wrongIdx)) pick = i;
      }
      await tapCell(tester, pick);
      await _shot(tester, '05_selected_wrong_notes_$tag');

      // Ô trống có ghi chú, bật chế độ ghi chú
      final emptyIdx = [
        for (var i = 0; i < 81; i++)
          if (b.isEmpty(i) && b.notes[i].isEmpty) i
      ].first;
      await tapCell(tester, emptyIdx);
      await tester.tap(find.bySemanticsLabel(RegExp('^Ghi chú')));
      await tester.pump(const Duration(milliseconds: 200));
      await _shot(tester, '06_notes_mode_$tag');

      await tester.tap(find.byTooltip('Tạm dừng'));
      await tester.pump(const Duration(milliseconds: 400));
      await _shot(tester, '07_paused_$tag');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('help $tag', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await phone(tester);
      await tester.pumpWidget(_app(const SudokuScreen(), mode));
      await tester.pumpAndSettle();
      await _shot(tester, '08_help_$tag');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
