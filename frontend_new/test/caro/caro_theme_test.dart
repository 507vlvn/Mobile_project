import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_new/caro/caro_home_screen.dart';
import 'package:frontend_new/caro/theme/caro_theme.dart';
import 'package:frontend_new/caro/widgets/caro_board_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Caro Theme Tests', () {
    test('Có đủ 8 skin giao diện bàn cờ', () {
      expect(CaroBoardTheme.values.length, 8);
      final names = CaroBoardTheme.values.map((t) => t.name).toList();
      expect(names, containsAll([
        'wood',
        'notebook',
        'go',
        'cyber',
        'sakura',
        'galaxy',
        'calligraphy',
        'retro',
      ]));
    });

    test('Mỗi theme tạo đúng CaroThemeData với đầy đủ màu sắc và cờ phân loại', () {
      for (final t in CaroBoardTheme.values) {
        final data = CaroThemeData.fromTheme(t);
        expect(data.surfaceColor, isNotNull);
        expect(data.gridColor, isNotNull);
        expect(data.xColor, isNotNull);
        expect(data.oColor, isNotNull);
      }

      expect(CaroThemeData.fromTheme(CaroBoardTheme.sakura).isSakura, isTrue);
      expect(CaroThemeData.fromTheme(CaroBoardTheme.galaxy).isGalaxy, isTrue);
      expect(CaroThemeData.fromTheme(CaroBoardTheme.calligraphy).isCalligraphy, isTrue);
      expect(CaroThemeData.fromTheme(CaroBoardTheme.retro).isPixel, isTrue);
      expect(CaroThemeData.fromTheme(CaroBoardTheme.go).isGoStones, isTrue);
      expect(CaroThemeData.fromTheme(CaroBoardTheme.cyber).isNeonGlow, isTrue);
      expect(CaroThemeData.fromTheme(CaroBoardTheme.notebook).isPaperGrid, isTrue);
    });

    testWidgets('CaroHomeScreen hiển thị preview bàn cờ và danh sách 8 skin không bị tràn',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: CaroHomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Kiểm tra có widget CaroBoardView làm preview
      expect(find.byType(CaroBoardView), findsOneWidget);

      // Kiểm tra các nhãn của theme
      expect(find.text('Gỗ cổ điển'), findsWidgets);
      expect(find.text('Vở ô ly'), findsOneWidget);
      expect(find.text('Cờ vây đá'), findsOneWidget);

      // Đảm bảo không có exception/overflow
      expect(tester.takeException(), isNull);
    });
  });
}
