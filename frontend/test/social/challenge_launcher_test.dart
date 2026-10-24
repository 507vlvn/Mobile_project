import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/models/challenge_context.dart';
import 'package:mobile_rubik/core/models/difficulty.dart';
import 'package:mobile_rubik/core/services/challenge_launcher.dart';

void main() {
  const ctx = ChallengeContext(
    challengeId: 9,
    gameCode: 'SUDOKU',
    difficulty: Difficulty.hard,
  );

  tearDown(ChallengeLauncher.clear);

  Future<void> pumpHost(WidgetTester tester, void Function(BuildContext) onTap) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => onTap(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));
  }

  test('seed là id thách đấu', () {
    expect(ctx.seed, 9);
  });

  testWidgets('chưa đăng ký game thì hiện SnackBar', (tester) async {
    await pumpHost(tester, (c) => ChallengeLauncher.open(c, ctx));
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(find.text('Game này chưa hỗ trợ thách đấu'), findsOneWidget);
  });

  testWidgets('đã đăng ký thì mở màn của game với đúng ngữ cảnh', (tester) async {
    ChallengeContext? received;
    ChallengeLauncher.register('sudoku', (c) {
      received = c;
      return const Scaffold(body: Text('SUDOKU SCREEN'));
    });
    expect(ChallengeLauncher.isSupported('SUDOKU'), isTrue);
    await pumpHost(tester, (c) => ChallengeLauncher.open(c, ctx));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('SUDOKU SCREEN'), findsOneWidget);
    expect(received!.seed, 9);
    expect(received!.difficulty, Difficulty.hard);
    expect(find.text('Game này chưa hỗ trợ thách đấu'), findsNothing);
  });
}
