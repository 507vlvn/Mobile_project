// ignore_for_file: invalid_use_of_visible_for_testing_member
// Ảnh chụp các màn Quét & giải / Trình phát lời giải / Màn camera để rà UI.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/theme/app_theme.dart';
import 'package:mobile_rubik/features/rubik/model/cube_model.dart';
import 'package:mobile_rubik/features/rubik/scanner/camera_scanner_view.dart';
import 'package:mobile_rubik/features/rubik/screens/scan_solve_screen.dart';
import 'package:mobile_rubik/features/rubik/screens/solve_player_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/screenshots');
final _boundary = GlobalKey();

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      loader.addFont(Future.value(ByteData.view(File(p).readAsBytesSync().buffer)));
    }
    await loader.load();
  }

  await load(kFontFamily, [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) 'assets/fonts/BeVietnamPro-$w.ttf',
  ]);
  final root = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final icons = '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf';
  if (File(icons).existsSync()) await load('MaterialIcons', [icons]);
}

Widget _app(Widget home, ThemeMode mode) => RepaintBoundary(
      key: _boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: home,
      ),
    );

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 50));
  final b = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final img = await b.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 2, 851 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final tag = mode.name;

    testWidgets('scan solve $tag', (tester) async {
      await phone(tester);
      await tester.pumpWidget(_app(const ScanSolveScreen(), mode));
      await tester.pumpAndSettle();
      await _shot(tester, 's1_scan_intro_$tag');

      // Xáo thử nghiệm → hợp lệ
      await tester.tap(find.byTooltip('Tuỳ chọn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xáo ngẫu nhiên (thử nghiệm)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sơ đồ phẳng'));
      await tester.pumpAndSettle();
      await _shot(tester, 's2_scan_net_valid_$tag');

      // Bật chế độ tô màu ở 3D và tô sai 1 ô
      await tester.tap(find.text('Khối 3D'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tô màu'));
      await tester.pumpAndSettle();
      await _shot(tester, 's3_scan_paint_$tag');
    });

    testWidgets('scan net error $tag', (tester) async {
      await phone(tester);
      await tester.pumpWidget(_app(const ScanSolveScreen(), mode));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sơ đồ phẳng'));
      await tester.pumpAndSettle();
      // Mở sửa mặt Trước, tô 1 ô thành Cam → thừa màu
      await tester.tap(find.bySemanticsLabel(RegExp('Mặt Trước')));
      await tester.pumpAndSettle();
      await _shot(tester, 's4_face_editor_$tag');
      await tester.tap(find.bySemanticsLabel('Bút màu Cam'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel(RegExp('^Ô 1,')));
      await tester.pump();
      await tester.tap(find.text('Lưu mặt này'));
      await tester.pumpAndSettle();
      await _shot(tester, 's5_scan_net_error_$tag');
    });

    testWidgets('solve player $tag', (tester) async {
      await phone(tester);
      final cube = Cube3DState()..applyMoves(['R', 'U', "R'", 'F2', "L'", 'D']);
      await tester.pumpWidget(_app(
        SolvePlayerScreen(
          initialCubeState: cube,
          moves: const ["D'", 'L', 'F2', 'R', "U'", "R'"],
        ),
        mode,
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await _shot(tester, 's6_player_$tag');
    });

    testWidgets('camera scanner $tag', (tester) async {
      await phone(tester);
      await tester.pumpWidget(_app(CameraScannerView(initialState: Cube3DState()), mode));
      await tester.pump(const Duration(milliseconds: 500));
      await _shot(tester, 's7_camera_$tag');
    });
  }
}
