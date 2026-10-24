import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/models/challenge_context.dart';
import 'package:mobile_rubik/core/models/difficulty.dart';
import 'package:mobile_rubik/features/puzzle/puzzle_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const ctx = ChallengeContext(
      challengeId: 777, gameCode: 'PUZZLE', difficulty: Difficulty.medium);

  PuzzleController make() =>
      PuzzleController(challenge: ctx, solver: (b, n) async => null);

  test('cùng seed → cùng bàn xáo và mốc tham chiếu; không ghi autosave',
      () async {
    final a = make()..newGame(ctx.difficulty);
    final b = make()..newGame(ctx.difficulty);
    expect(a.board, b.board);
    expect((await a.stats()).reference, (await b.stats()).reference);

    a.tap(a.board.indexOf(0) == 0 ? 1 : 0);
    await a.save();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(PuzzleController.saveKey), isFalse);
    expect(await PuzzleController.hasSavedGame(), isFalse);
    a.dispose();
    b.dispose();
  });
}
