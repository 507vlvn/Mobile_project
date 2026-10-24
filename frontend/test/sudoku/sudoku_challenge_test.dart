import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/models/challenge_context.dart';
import 'package:mobile_rubik/core/models/difficulty.dart';
import 'package:mobile_rubik/features/sudoku/sudoku_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const ctx = ChallengeContext(
      challengeId: 4242, gameCode: 'SUDOKU', difficulty: Difficulty.easy);

  test('cùng seed thách đấu → cùng đề (isolate), không ghi autosave', () async {
    final a = SudokuController(challenge: ctx);
    final b = SudokuController(challenge: ctx);
    await a.startNewGame(ctx.difficulty);
    await b.startNewGame(ctx.difficulty);
    expect(a.phase, SudokuPhase.playing);
    expect(a.board!.givens, b.board!.givens);
    expect(a.board!.solution, b.board!.solution);

    final i = [
      for (var k = 0; k < 81; k++)
        if (a.board!.isEmpty(k)) k
    ].first;
    a.select(i);
    a.input(a.board!.solution[i]);
    await a.saveNow();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(SudokuController.saveKey), isFalse);
    expect(await SudokuController.hasSavedGame(), isFalse);
    a.dispose();
    b.dispose();
  });

  test('seed khác → đề khác', () async {
    final a = SudokuController(challenge: ctx);
    final b = SudokuController(
        challenge: const ChallengeContext(
            challengeId: 4243,
            gameCode: 'SUDOKU',
            difficulty: Difficulty.easy));
    await a.startNewGame(Difficulty.easy);
    await b.startNewGame(Difficulty.easy);
    expect(a.board!.solution, isNot(b.board!.solution));
    a.dispose();
    b.dispose();
  });
}
