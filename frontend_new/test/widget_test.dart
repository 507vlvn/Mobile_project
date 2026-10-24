import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_new/main.dart';

void main() {
  testWidgets('Home hiển thị danh sách trò chơi', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Chọn trò chơi'), findsOneWidget);
    for (final name in ['Rubik 3D', 'Sudoku', 'Xếp hình', 'Caro']) {
      expect(find.text(name), findsOneWidget);
    }

    // Chưa có chức năng: bấm vào game chỉ hiện thông báo.
    await tester.tap(find.text('Sudoku'));
    await tester.pump();
    expect(find.text('Sudoku đang được phát triển, sắp ra mắt!'), findsOneWidget);
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

  testWidgets('Bấm vào Caro mở màn hình game Caro', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Caro'));
    await tester.pumpAndSettle();
    expect(find.text('Caro với máy'), findsOneWidget);
  });
}
