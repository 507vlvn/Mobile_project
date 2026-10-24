import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frontend_new/main.dart';
import 'package:frontend_new/caro/services/score_reporter.dart';

void main() {
  testWidgets('CaroApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ScoreReporter>(
            create: (_) => LocalScoreReporter(),
          ),
        ],
        child: const CaroApp(),
      ),
    );
    await tester.pump();

    // Verify Caro game screen renders
    expect(find.text('Caro với máy'), findsOneWidget);
  });
}
