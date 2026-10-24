import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_new/main.dart';

void main() {
  testWidgets('Home hiển thị danh sách trò chơi', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Chọn trò chơi'), findsOneWidget);
    for (final name in ['Rubik 3D', 'Sudoku', 'Xếp hình & PhaseShift', 'Caro']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('Thanh điều hướng dưới chuyển được tab', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    for (final label in ['Trò chơi', 'Đối kháng', 'Xếp hạng', 'Bạn bè', 'Hồ sơ']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Đang được phát triển'), findsOneWidget);
  });
}
