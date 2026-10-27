import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_new/sudoku/logic/crossmath_levels.dart';
import 'package:frontend_new/sudoku/logic/sudoku_controller.dart';
import 'package:frontend_new/sudoku/logic/sudoku_generator.dart';
import 'package:frontend_new/sudoku/logic/sudoku_learning_manager.dart';
import 'package:frontend_new/sudoku/models/sudoku_models.dart';

void main() {
  group('Sudoku Generator Tests', () {
    test('Generate with seed produces deterministic puzzle', () {
      final puzzle1 = SudokuGenerator.generate(difficulty: SudokuDifficulty.easy, seed: 12345);
      final puzzle2 = SudokuGenerator.generate(difficulty: SudokuDifficulty.easy, seed: 12345);

      expect(puzzle1.puzzle, equals(puzzle2.puzzle));
      expect(puzzle1.solution, equals(puzzle2.solution));
    });

    test('Solution has valid Sudoku constraints', () {
      final puzzle = SudokuGenerator.generate(difficulty: SudokuDifficulty.medium, seed: 999);
      final solution = puzzle.solution;

      for (int i = 0; i < 9; i++) {
        final rowSet = solution[i].toSet();
        expect(rowSet.length, equals(9));
        expect(rowSet.contains(0), isFalse);

        final colSet = {for (int r = 0; r < 9; r++) solution[r][i]};
        expect(colSet.length, equals(9));
      }
    });
  });

  group('Sudoku Learning Mode Tests', () {
    test('Clues difficulty progression from level 1 to 30', () {
      final level1Clues = SudokuLearningManager.getCluesForLevel(1);
      final level15Clues = SudokuLearningManager.getCluesForLevel(15);
      final level30Clues = SudokuLearningManager.getCluesForLevel(30);

      expect(level1Clues, equals(50));
      expect(level30Clues, equals(18));
      expect(level1Clues > level15Clues, isTrue);
      expect(level15Clues > level30Clues, isTrue);
    });

    test('Controller handles learning mode correctly', () {
      final controller = SudokuController();
      controller.startLearningLevel(5, autoStartTimer: false);

      expect(controller.isLearningMode, isTrue);
      expect(controller.currentLearningLevel, equals(5));
      expect(controller.displayTitle, equals('Cấp độ 5'));

      controller.stopTimer();
      controller.dispose();
    });
  });

  group('Sudoku Controller Tests', () {
    test('Initial controller state', () {
      final controller = SudokuController(initialDifficulty: SudokuDifficulty.easy, seed: 42);
      controller.startNewGame(difficulty: SudokuDifficulty.easy, seed: 42, autoStartTimer: false);

      expect(controller.mistakes, equals(0));
      expect(controller.status, equals(SudokuStatus.paused));
      expect(controller.isNotesMode, isFalse);
      expect(controller.board.length, equals(9));
      expect(controller.board[0].length, equals(9));

      controller.dispose();
    });

    test('Notes mode toggling and input', () {
      final controller = SudokuController(initialDifficulty: SudokuDifficulty.easy, seed: 42);
      controller.startNewGame(difficulty: SudokuDifficulty.easy, seed: 42, autoStartTimer: false);
      controller.resumeTimer();

      int? targetR, targetC;
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (!controller.board[r][c].isGiven) {
            targetR = r;
            targetC = c;
            break;
          }
        }
        if (targetR != null) break;
      }

      controller.selectCell(targetR!, targetC!);
      controller.toggleNotesMode();
      expect(controller.isNotesMode, isTrue);

      controller.inputNumber(5);
      expect(controller.board[targetR][targetC].notes.contains(5), isTrue);

      controller.undo();
      expect(controller.board[targetR][targetC].notes.contains(5), isFalse);

      controller.stopTimer();
      controller.dispose();
    });
  });

  group('CrossMath Tests', () {
    test('Level 1 matches user screenshot exactly', () {
      final level1 = CrossMathLevelProvider.getLevel(1);
      expect(level1.rows, equals(11));
      expect(level1.cols, equals(9));

      final blanks = level1.cells.where((c) => c.isBlank).toList();
      expect(blanks.length, equals(15));

      // Kiểm tra 15 ô trong khay
      expect(level1.numberPool.length, equals(15));
      expect(level1.numberPool.contains('x'), isTrue);
      expect(level1.numberPool.contains('22'), isTrue);
      expect(level1.numberPool.contains('55'), isTrue);
      expect(level1.numberPool.contains('39'), isTrue);
      expect(level1.numberPool.contains('84'), isFalse); // 84 là ô có sẵn
    });
  });
}

