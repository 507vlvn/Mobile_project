import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_new/XepHinh/mode_selection_screen.dart';
import 'package:frontend_new/XepHinh/phaseshift/phaseshift_screen.dart';
import 'package:frontend_new/XepHinh/shared/models/difficulty.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Màn chọn chế độ: nút Luật chơi chỉ hiện khi chọn PhaseShift và mở được luật',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ModeSelectionScreen()));

    expect(find.text('Luật chơi PhaseShift'), findsNothing);

    await tester.tap(find.text('PhaseShift (Xếp khối nguyên tố)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Luật chơi PhaseShift'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Luật chơi PhaseShift'));
    await tester.pumpAndSettle();

    expect(find.text('🎯 Mục tiêu'), findsOneWidget);
    expect(find.text('🎮 Điều khiển'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('💀 Thua cuộc'), 300,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('💀 Thua cuộc'), findsOneWidget);
  });

  testWidgets('Trong game: nút ? tạm dừng, đóng luật thì chơi tiếp', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PhaseShiftScreen(difficulty: GameDifficulty.easy),
    ));
    await tester.pump();

    await tester.tap(find.byTooltip('Luật chơi'));
    await tester.pumpAndSettle();
    expect(find.text('Luật chơi PhaseShift'), findsOneWidget);

    // Đóng bảng luật (vuốt xuống / bấm ra ngoài).
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Luật chơi PhaseShift'), findsNothing);
    expect(find.text('Tạm Dừng Game'), findsNothing);

    // Dọn màn chơi để dừng các Timer của game.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
