import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/models/difficulty.dart';
import 'package:mobile_rubik/features/sudoku/logic/sudoku_generator.dart';
import 'package:mobile_rubik/features/sudoku/logic/sudoku_solver.dart';

const _known =
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
const _knownSolution =
    '534678912672195348198342567859761423426853791713924856961537284287419635345286179';

List<int> _g(String s) => [for (final c in s.split('')) int.parse(c)];

bool _validFull(List<int> g) {
  for (var u = 0; u < 9; u++) {
    final row = <int>{}, col = <int>{}, box = <int>{};
    for (var k = 0; k < 9; k++) {
      row.add(g[u * 9 + k]);
      col.add(g[k * 9 + u]);
      box.add(g[((u ~/ 3) * 3 + k ~/ 3) * 9 + (u % 3) * 3 + k % 3]);
    }
    if (row.length != 9 ||
        col.length != 9 ||
        box.length != 9 ||
        row.contains(0)) {
      return false;
    }
  }
  return true;
}

void main() {
  group('solver', () {
    test('giải đúng đề mẫu', () {
      expect(solveGrid(_g(_known)), _g(_knownSolution));
      expect(countSolutions(_g(_known)), 1);
    });

    test('phát hiện nhiều lời giải', () {
      expect(countSolutions(List<int>.filled(81, 0), limit: 2), 2);
      // Xoá mọi ô chứa 1 và 2 -> hoán đổi 1<->2 cho ra lời giải thứ hai
      final multi = [
        for (final v in _g(_knownSolution)) (v == 1 || v == 2) ? 0 : v
      ];
      expect(countSolutions(multi), greaterThan(1));
    });

    test('đề mâu thuẫn -> 0 lời giải', () {
      final g = _g(_known);
      g[2] = 5; // trùng 5 ở hàng 1
      expect(countSolutions(g), 0);
      expect(solveGrid(g), isNull);
    });

    test('lưới đầy ngẫu nhiên hợp lệ', () {
      for (var s = 0; s < 5; s++) {
        expect(_validFull(generateFullGrid(Random(s))), isTrue);
      }
    });
  });

  group('generator', () {
    for (final d in Difficulty.values) {
      test('đề ${d.label} duy nhất nghiệm, số ô cho sẵn đúng khoảng', () {
        final target = targetGivens(d);
        for (final seed in [1, 2, 3]) {
          final p = generatePuzzle(d, random: Random(seed));
          expect(countSolutions(p.puzzle), 1, reason: 'seed $seed');
          expect(solveGrid(p.puzzle), p.solution);
          expect(_validFull(p.solution), isTrue);
          expect(p.givens, inInclusiveRange(target, target + 3),
              reason: 'seed $seed');
          for (var i = 0; i < 81; i++) {
            if (p.puzzle[i] != 0) expect(p.puzzle[i], p.solution[i]);
          }
        }
      });
    }

    test('cùng seed cho cùng đề', () {
      final a = generatePuzzle(Difficulty.easy, random: Random(7));
      final b = generatePuzzle(Difficulty.easy, random: Random(7));
      expect(a.puzzle, b.puzzle);
    });

    test('sinh trong isolate', () async {
      final p = await generatePuzzleInIsolate(Difficulty.easy);
      expect(countSolutions(p.puzzle), 1);
    });
  });
}
