import 'dart:math';
import '../models/sudoku_models.dart';

class SudokuPuzzleData {
  final List<List<int>> puzzle;
  final List<List<int>> solution;

  const SudokuPuzzleData({
    required this.puzzle,
    required this.solution,
  });
}

class SudokuGenerator {
  /// Sinh bảng Sudoku mới theo độ khó hoặc số ô cho sẵn [customClues].
  /// Có thể truyền [seed] để tạo đề bài cố định lặp lại được.
  static SudokuPuzzleData generate({
    SudokuDifficulty difficulty = SudokuDifficulty.medium,
    int? customClues,
    int? seed,
  }) {
    final random = seed != null ? Random(seed) : Random();
    final board = List.generate(9, (_) => List.filled(9, 0));

    // 1. Điền 3 khối chéo 3x3 (độc lập, không xung đột dòng/cột)
    _fillDiagonalBoxes(board, random);

    // 2. Điền các ô còn lại bằng backtracking
    _solve(board, random);

    // 3. Sao lưu lời giải hoàn chỉnh
    final solution = List.generate(9, (r) => List<int>.from(board[r]));

    // 4. Xóa ô theo độ khó hoặc customClues để tạo đề bài
    final puzzle = List.generate(9, (r) => List<int>.from(board[r]));
    final targetClues = (customClues ?? difficulty.clues).clamp(17, 80);
    final cellsToRemove = 81 - targetClues;

    final positions = List.generate(81, (i) => i)..shuffle(random);
    for (int i = 0; i < cellsToRemove; i++) {
      final pos = positions[i];
      final r = pos ~/ 9;
      final c = pos % 9;
      puzzle[r][c] = 0;
    }

    return SudokuPuzzleData(puzzle: puzzle, solution: solution);
  }

  static void _fillDiagonalBoxes(List<List<int>> board, Random random) {
    for (int box = 0; box < 9; box += 3) {
      final numbers = List.generate(9, (i) => i + 1)..shuffle(random);
      int idx = 0;
      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
          board[box + r][box + c] = numbers[idx++];
        }
      }
    }
  }

  static bool _solve(List<List<int>> board, Random random) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (board[r][c] == 0) {
          final numbers = List.generate(9, (i) => i + 1)..shuffle(random);
          for (final num in numbers) {
            if (_isSafe(board, r, c, num)) {
              board[r][c] = num;
              if (_solve(board, random)) return true;
              board[r][c] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }

  static bool _isSafe(List<List<int>> board, int row, int col, int num) {
    for (int i = 0; i < 9; i++) {
      if (board[row][i] == num) return false;
      if (board[i][col] == num) return false;
    }
    final startRow = (row ~/ 3) * 3;
    final startCol = (col ~/ 3) * 3;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        if (board[startRow + r][startCol + c] == num) return false;
      }
    }
    return true;
  }
}
