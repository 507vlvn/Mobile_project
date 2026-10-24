import 'dart:isolate';
import 'dart:math';

import '../../../core/models/difficulty.dart';
import 'sudoku_solver.dart';

/// Một đề Sudoku: [puzzle] (0 = trống) và lời giải duy nhất [solution].
class SudokuPuzzle {
  final List<int> puzzle;
  final List<int> solution;

  const SudokuPuzzle(this.puzzle, this.solution);

  int get givens => puzzle.where((v) => v != 0).length;
}

/// Số ô cho sẵn mục tiêu: Dễ ~40, Vừa ~32, Khó ~26.
int targetGivens(Difficulty d) => switch (d) {
      Difficulty.easy => 40,
      Difficulty.medium => 32,
      Difficulty.hard => 26,
    };

/// Sinh đề có đúng một lời giải. Có thể truyền [random] có seed để tái lập.
SudokuPuzzle generatePuzzle(Difficulty difficulty, {Random? random}) {
  final rnd = random ?? Random();
  final target = targetGivens(difficulty);
  while (true) {
    final solution = generateFullGrid(rnd);
    final puzzle = List<int>.of(solution);
    final order = List<int>.generate(81, (i) => i)..shuffle(rnd);
    var givens = 81;
    for (final i in order) {
      if (givens <= target) break;
      final backup = puzzle[i];
      puzzle[i] = 0;
      if (countSolutions(puzzle, limit: 2) == 1) {
        givens--;
      } else {
        puzzle[i] = backup;
      }
    }
    // Chấp nhận dư tối đa 3 ô nếu tính duy nhất chặn việc xoá tiếp
    if (givens <= target + 3) return SudokuPuzzle(puzzle, solution);
  }
}

/// Sinh đề trong isolate riêng để không làm giật giao diện.
/// Truyền [seed] (chế độ thách đấu) để cả hai người chơi nhận cùng một đề.
Future<SudokuPuzzle> generatePuzzleInIsolate(Difficulty difficulty,
        {int? seed}) =>
    Isolate.run(() => generatePuzzle(difficulty,
        random: seed == null ? null : Random(seed)));
