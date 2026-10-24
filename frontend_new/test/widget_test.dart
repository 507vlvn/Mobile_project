import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_new/main.dart';

void main() {
  testWidgets('XepHinhApp loads XepHinhScreen successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const XepHinhApp());

    expect(find.text('Xếp Hình Master'), findsOneWidget);
  });
}
