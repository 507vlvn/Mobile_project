import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_new/XepHinh/jigsaw_puzzle/jigsaw_puzzle_logic.dart';
import 'package:frontend_new/XepHinh/shared/models/difficulty.dart';

void main() {
  test('ô thứ i trên màn hình luôn là mảnh đang ở vị trí i (kể cả sau khi đổi chỗ)', () {
    final logic = JigsawPuzzleLogic(difficulty: GameDifficulty.medium);
    final n = logic.gridSize;
    void check() {
      for (var i = 0; i < logic.pieces.length; i++) {
        final p = logic.pieces[i];
        expect(p.currentRow * n + p.currentCol, i);
      }
    }

    check();
    logic.selectOrSwapPiece(0);
    logic.selectOrSwapPiece(5);
    check();
  });

  test('bàn mới thật sự bị xáo (không hiện sẵn đúng thứ tự)', () {
    // Xác suất 16 mảnh tình cờ đúng hết là gần như bằng 0; thử vài lần cho chắc.
    var shuffled = false;
    for (var t = 0; t < 5 && !shuffled; t++) {
      final logic = JigsawPuzzleLogic(difficulty: GameDifficulty.medium);
      shuffled = logic.pieces.any((p) => !p.isCorrect);
    }
    expect(shuffled, isTrue);
  });

  test('đổi chỗ từng mảnh về đúng vị trí thì hoàn thành', () {
    final logic = JigsawPuzzleLogic(difficulty: GameDifficulty.easy);
    final n = logic.gridSize;
    for (var i = 0; i < logic.pieces.length; i++) {
      final j = logic.pieces.indexWhere((p) => p.correctRow * n + p.correctCol == i);
      if (j != i) {
        logic.selectOrSwapPiece(i);
        logic.selectOrSwapPiece(j);
      }
    }
    expect(logic.isCompleted, isTrue);
    expect(logic.pieces.every((p) => p.isCorrect), isTrue);
  });
}
