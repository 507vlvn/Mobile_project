import 'package:frontend_new/core/network/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_new/caro/models/caro_mode.dart';
import 'package:frontend_new/caro/models/difficulty.dart';
import 'package:frontend_new/caro/services/score_reporter.dart';
import 'package:frontend_new/caro/caro_controller.dart';
import 'package:frontend_new/caro/logic/caro_ai.dart';
import 'package:frontend_new/caro/logic/caro_board.dart';
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

  test('Local PvP: 2 người đánh luân phiên, không gọi AI, undo 1 nước', () async {
    final c = make();
    c.newGame(difficulty: Difficulty.easy, playerFirst: true, mode: CaroGameMode.pvpLocal);
    expect(c.isPvP, isTrue);
    expect(c.currentTurnPlayer, kCaroPlayer);

    // Người 1 (X) đánh
    expect(c.placePlayer(caroIndex(7, 7)), isTrue);
    await settle();
    expect(c.history.length, 1);
    expect(c.cells[caroIndex(7, 7)], kCaroPlayer);
    expect(c.currentTurnPlayer, kCaroAi); // Lượt Người 2 (O)

    // Người 2 (O) đánh
    expect(c.placePlayer(caroIndex(7, 8)), isTrue);
    await settle();
    expect(c.history.length, 2);
    expect(c.cells[caroIndex(7, 8)], kCaroAi);
    expect(c.currentTurnPlayer, kCaroPlayer); // Trở lại Người 1

    // Undo 1 nước của Người 2
    expect(c.undo(), isTrue);
    expect(c.history.length, 1);
    expect(c.cells[caroIndex(7, 8)], kCaroEmpty);
    expect(c.currentTurnPlayer, kCaroAi); // Vẫn là lượt Người 2

    c.dispose();
  });

  test('Fading: quân thứ 7 làm quân thứ 1 biến mất', () async {
    final c = CaroController(
      aiRunner: (r) async => caroIndex(0, 2 * r.cells.where((x) => x == kCaroAi).length),
      minThinkTime: Duration.zero,
    );
    c.newGame(difficulty: Difficulty.easy, playerFirst: true, mode: CaroGameMode.fading);
    expect(c.isFading, isTrue);

    // Người chơi đánh 6 quân rải rác (không tạo thành 5 quân liên tiếp)
    final positions = [
      caroIndex(5, 0),
      caroIndex(5, 2),
      caroIndex(5, 4),
      caroIndex(5, 6),
      caroIndex(5, 8),
      caroIndex(5, 10),
    ];
    for (final pos in positions) {
      expect(c.placePlayer(pos), isTrue);
      await settle();
    }
    expect(c.playerXStones.length, 6);
    expect(c.cells[positions.first], kCaroPlayer);

    // Đánh quân thứ 7: quân ở positions.first phải biến mất
    expect(c.placePlayer(caroIndex(6, 0)), isTrue);
    await settle();
    expect(c.cells[positions.first], kCaroEmpty, reason: 'Quân cũ nhất phải biến mất');
    expect(c.playerXStones.length, 6);
    expect(c.playerXStones.contains(caroIndex(6, 0)), isTrue);

    c.dispose();
  });

  test('Hint: gợi ý nước đi giảm số lượt gợi ý', () async {
    final c = make();
    c.newGame(difficulty: Difficulty.easy, playerFirst: true);
    expect(c.hintsRemaining, 3);
    final hint = await c.requestHint();
    expect(hint, isNotNull);
    expect(c.hintCell, hint);
    expect(c.hintsRemaining, 2);
    expect(c.cells[hint!], kCaroEmpty);

    // Đặt quân thì xoá hint
    c.placePlayer(hint);
    expect(c.hintCell, isNull);
    c.dispose();
  });

  test('tiến trình ván chơi cô lập tuyệt đối giữa các tài khoản (User 1 vs User 2)', () async {
    // 1. Tài khoản 1 (userId: 1) đăng nhập và chơi nửa chừng
    final user1Ctrl = CaroController(
      userId: 1,
      aiRunner: (r) async => chooseCaroMove(r),
      minThinkTime: Duration.zero,
    );
    user1Ctrl.newGame(difficulty: Difficulty.hard, playerFirst: true);
    user1Ctrl.placePlayer(caroIndex(7, 7));
    await settle();
    await user1Ctrl.save();

    // User 1 có ván lưu
    expect(await CaroController.hasSavedGame(userId: 1), isTrue);

    // 2. Tài khoản 2 (userId: 2) đăng nhập -> tuyệt đối KHÔNG có tiến trình của Tài khoản 1
    expect(await CaroController.hasSavedGame(userId: 2), isFalse);

    final user2Ctrl = CaroController(
      userId: 2,
      aiRunner: (r) async => chooseCaroMove(r),
      minThinkTime: Duration.zero,
    );
    expect(await user2Ctrl.restore(), isFalse);

    // Tài khoản 2 chơi ván riêng của mình
    user2Ctrl.newGame(difficulty: Difficulty.easy, playerFirst: true);
    user2Ctrl.placePlayer(caroIndex(3, 3));
    await settle();
    await user2Ctrl.save();

    // Cả 2 tài khoản đều có ván lưu riêng biệt
    expect(await CaroController.hasSavedGame(userId: 1), isTrue);
    expect(await CaroController.hasSavedGame(userId: 2), isTrue);

    // Khôi phục cho Tài khoản 1 -> Đúng bàn cờ của User 1
    final restoreUser1 = CaroController(userId: 1, minThinkTime: Duration.zero);
    expect(await restoreUser1.restore(), isTrue);
    expect(restoreUser1.history.first, caroIndex(7, 7));
    expect(restoreUser1.difficulty, Difficulty.hard);

    // Khôi phục cho Tài khoản 2 -> Đúng bàn cờ của User 2
    final restoreUser2 = CaroController(userId: 2, minThinkTime: Duration.zero);
    expect(await restoreUser2.restore(), isTrue);
    expect(restoreUser2.history.first, caroIndex(3, 3));
    expect(restoreUser2.difficulty, Difficulty.easy);

    // 3. User 1 xoá ván của mình -> Không ảnh hưởng ván của User 2
    await restoreUser1.clearSave();
    expect(await CaroController.hasSavedGame(userId: 1), isFalse);
    expect(await CaroController.hasSavedGame(userId: 2), isTrue);

    user1Ctrl.dispose();
    user2Ctrl.dispose();
    restoreUser1.dispose();
    restoreUser2.dispose();
  });

  test('khôi phục ván chơi từ CaroSavedGame tải từ server', () async {
    final c = make();
    final serverSave = CaroSavedGame(
      id: 99,
      gameMode: 'pve',
      difficulty: 3,
      playerFirst: true,
      history: [caroIndex(7, 7), caroIndex(7, 8)],
      undos: 1,
      elapsedSeconds: 120,
      hintsRemaining: 2,
    );

    final ok = c.restoreFromSavedGame(serverSave);
    expect(ok, isTrue);
    expect(c.history, [caroIndex(7, 7), caroIndex(7, 8)]);
    expect(c.difficulty, Difficulty.hard);
    expect(c.undos, 1);
    expect(c.hintsRemaining, 2);
    expect(c.clock.seconds, 120);
    expect(c.isPlaying, isTrue);
    c.dispose();
  });
}