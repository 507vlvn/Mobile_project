import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/models/difficulty.dart';
import 'package:mobile_rubik/core/services/score_reporter.dart';
import 'package:mobile_rubik/features/caro/caro_controller.dart';
import 'package:mobile_rubik/features/caro/logic/caro_ai.dart';
import 'package:mobile_rubik/features/caro/logic/caro_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  CaroController make() => CaroController(
        aiRunner: (r) async => chooseCaroMove(r),
        minThinkTime: Duration.zero,
      );

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

  test('người đi trước: đặt quân, máy đáp trả, đi lại xoá cả hai', () async {
    final c = make();
    c.newGame(difficulty: Difficulty.easy, playerFirst: true);
    expect(c.canPlayerMove, isTrue);
    expect(c.placePlayer(caroIndex(7, 7)), isTrue);
    await settle();
    expect(c.history.length, 2);
    expect(c.canPlayerMove, isTrue);
    expect(c.placePlayer(caroIndex(7, 7)), isFalse, reason: 'ô đã có quân');
    expect(c.undo(), isTrue);
    expect(c.history, isEmpty);
    expect(c.undos, 1);
    c.dispose();
  });

  test('máy đi trước: máy đánh nước đầu, chưa thể đi lại', () async {
    final c = make();
    c.newGame(difficulty: Difficulty.medium, playerFirst: false);
    await settle();
    expect(c.history.length, 1);
    expect(c.cells[c.history.first], kCaroAi);
    expect(c.canUndo, isFalse);
    c.dispose();
  });

  test('người thắng → bản ghi WIN, đường thắng 5 ô', () async {
    // Máy luôn đánh vào ô trống đầu tiên của hàng 0 để không cản đường.
    final c = CaroController(
      aiRunner: (r) async => r.cells.indexOf(kCaroEmpty),
      minThinkTime: Duration.zero,
    );
    c.newGame(difficulty: Difficulty.easy, playerFirst: true);
    for (var col = 3; col < 8; col++) {
      expect(c.placePlayer(caroIndex(10, col)), isTrue);
      await settle();
    }
    expect(c.phase, CaroPhase.finished);
    expect(c.result, CaroResult.playerWin);
    expect(c.winLine!.length, 5);
    final rec = c.toRecord();
    expect(rec.gameCode, 'CARO');
    expect(rec.outcome, GameOutcome.win);
    expect(rec.moves, 5);
    expect(rec.mistakes, 0);
    c.dispose();
  });

  test('lưu và khôi phục ván đang dở', () async {
    final c = make();
    c.newGame(difficulty: Difficulty.hard, playerFirst: true);
    c.placePlayer(caroIndex(7, 7));
    await settle();
    await c.save();
    expect(await CaroController.hasSavedGame(), isTrue);
    final saved = c.history;

    final c2 = make();
    expect(await c2.restore(), isTrue);
    expect(c2.history, saved);
    expect(c2.difficulty, Difficulty.hard);
    expect(c2.canPlayerMove, isTrue);
    c.dispose();
    c2.dispose();
  });
}
