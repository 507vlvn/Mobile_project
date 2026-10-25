import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_new/XepHinh/phaseshift/phaseshift_screen.dart';
import 'package:frontend_new/XepHinh/phaseshift/widgets/game_board.dart';
import 'package:frontend_new/XepHinh/shared/models/difficulty.dart';

void main() {
  testWidgets('Đổi cột rồi thả: khối nằm ở cột mới, khối kế tiếp ra ở cột đó', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
        const MaterialApp(home: PhaseShiftScreen(difficulty: GameDifficulty.easy)));
    await tester.pump();
    PhaseShiftGameBoard board() =>
        tester.widget<PhaseShiftGameBoard>(find.byType(PhaseShiftGameBoard));

    expect(board().activePosition!.col, 4, reason: 'khối đầu tiên ra ở cột giữa');

    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump();
    expect(board().activePosition!.col, 6);

    await tester.tap(find.byIcon(Icons.keyboard_double_arrow_down_rounded));
    await tester.pump();

    final bottom = board().board[board().rows - 1];
    expect(bottom[6], isNotNull, reason: 'khối đã thả phải nằm ở cột 6');
    expect(bottom[4], isNull, reason: 'không được quay về cột cũ');
    expect(board().activePosition!.col, 6, reason: 'khối kế tiếp ra ở cột vừa đặt');

    // Dọn màn chơi để dừng các Timer của game.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
