import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_new/main.dart';
import 'package:frontend_new/soduku/logic/sudoku_controller.dart';
import 'package:frontend_new/soduku/ui/sudoku_home_screen.dart';

void main() {
  testWidgets('Sudoku home screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(SudokuHomeScreen), findsOneWidget);
    expect(find.text('Sudoku Classic'), findsOneWidget);
    expect(find.text('Tiếp tục Trò chơi'), findsOneWidget);
    expect(find.text('Trò chơi Mới'), findsOneWidget);

    SudokuController.instance.stopTimer();
  });
}
