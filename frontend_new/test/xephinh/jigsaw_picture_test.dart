import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_new/XepHinh/jigsaw_puzzle/jigsaw_puzzle_screen.dart';
import 'package:frontend_new/XepHinh/jigsaw_puzzle/models/jigsaw_picture.dart';
import 'package:frontend_new/XepHinh/jigsaw_puzzle/widgets/jigsaw_piece_image.dart';
import 'package:frontend_new/XepHinh/mode_selection_screen.dart';
import 'package:frontend_new/XepHinh/shared/models/difficulty.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Mảnh ghép hiện hình (không còn chữ Piece #), mỗi mảnh một phần khác nhau',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: JigsawPuzzleScreen(
          difficulty: GameDifficulty.easy, picture: JigsawPicture.builtIns[1]),
    ));
    await tester.pump();

    expect(find.textContaining('Piece #'), findsNothing);
    final pieces = tester.widgetList<JigsawPieceImage>(find.byType(JigsawPieceImage)).toList();
    expect(pieces.length, 9);
    expect(pieces.map((p) => '${p.row},${p.col}').toSet().length, 9,
        reason: '9 mảnh là 9 phần khác nhau của hình');
    expect(pieces.every((p) => p.picture.name == 'Biển đảo'), isTrue);

    // Hình bên trong mỗi mảnh phải lớn gấp 3 lần ô (chỉ hiện 1/9 hình),
    // không phải cả bức hình bị thu nhỏ vào ô.
    final piece = find.byType(JigsawPieceImage).first;
    final tile = tester.getSize(piece);
    final drawn = tester.getSize(find.descendant(of: piece, matching: find.byType(CustomPaint)).first);
    expect(drawn.width, closeTo(tile.width * 3, 0.5));
    expect(drawn.height, closeTo(tile.height * 3, 0.5));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Nút số gợi ý và xem ảnh gốc', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: JigsawPuzzleScreen(
          difficulty: GameDifficulty.easy, picture: JigsawPicture.builtIns[0]),
    ));
    await tester.pump();

    expect(find.text('5'), findsNothing);
    await tester.tap(find.byTooltip('Hiện số gợi ý'));
    await tester.pump();
    for (var i = 1; i <= 9; i++) {
      expect(find.text('$i'), findsOneWidget);
    }

    await tester.tap(find.byTooltip('Xem ảnh gốc'));
    await tester.pumpAndSettle();
    expect(find.text('Ảnh gốc: Hoàng hôn'), findsOneWidget);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Màn chọn chế độ: chọn tranh rồi bắt đầu thì màn chơi dùng đúng tranh đó',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ModeSelectionScreen()));
    expect(find.text('3. Chọn hình'), findsNothing);

    await tester.tap(find.text('Jigsaw Puzzle (Ghép mảnh hình)'));
    await tester.pumpAndSettle();
    expect(find.text('3. Chọn hình'), findsOneWidget);
    expect(find.text('Từ thư viện'), findsOneWidget);

    await tester.ensureVisible(find.text('Thành phố đêm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thành phố đêm'));
    await tester.pump();
    await tester.ensureVisible(find.text('Bắt Đầu Chơi'));
    await tester.tap(find.text('Bắt Đầu Chơi'));
    await tester.pumpAndSettle();

    final screen = tester.widget<JigsawPuzzleScreen>(find.byType(JigsawPuzzleScreen));
    expect(screen.picture?.name, 'Thành phố đêm');

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
