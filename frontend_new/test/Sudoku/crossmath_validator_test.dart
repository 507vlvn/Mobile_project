import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_new/sudoku/logic/crossmath_levels.dart';
import 'package:frontend_new/sudoku/models/crossmath_models.dart';

void main() {
  test('Kiểm tra tính đúng đắn toán học của các màn CrossMath', () {
    for (int lvl = 1; lvl <= 30; lvl++) {
      final levelData = CrossMathLevelProvider.getLevel(lvl);
      final grid = <int, Map<int, CrossMathCell>>{};

      for (final cell in levelData.cells) {
        grid.putIfAbsent(cell.row, () => {})[cell.col] = cell;
      }

      String getVal(CrossMathCell? c) {
        if (c == null) return '';
        if (c.isBlank) return c.targetText ?? '';
        return c.label;
      }

      bool isNum(String s) => int.tryParse(s) != null;
      bool isOp(String s) => ['+', '-', 'x', '÷'].contains(s);

      int calc(int a, String op, int b) {
        switch (op) {
          case '+': return a + b;
          case '-': return a - b;
          case 'x': return a * b;
          case '÷': return b != 0 && a % b == 0 ? a ~/ b : -999999;
          default: return -999999;
        }
      }

      print('=== KIỂM TRA LEVEL $lvl ===');

      // Kiểm tra ngang (rows)
      for (int r = 0; r < levelData.rows; r++) {
        for (int c = 0; c <= levelData.cols - 5; c++) {
          final c0 = grid[r]?[c];
          final c1 = grid[r]?[c + 1];
          final c2 = grid[r]?[c + 2];
          final c3 = grid[r]?[c + 3];
          final c4 = grid[r]?[c + 4];

          final v0 = getVal(c0);
          final op = getVal(c1);
          final v2 = getVal(c2);
          final eq = getVal(c3);
          final v4 = getVal(c4);

          if (isNum(v0) && isOp(op) && isNum(v2) && eq == '=' && isNum(v4)) {
            final a = int.parse(v0);
            final b = int.parse(v2);
            final expected = int.parse(v4);
            final actual = calc(a, op, b);
            if (actual != expected) {
              print('LỖI NGANG ở row $r, col $c: $a $op $b = $expected (thực tế tính ra: $actual)');
            }
          }
        }
      }

      // Kiểm tra dọc (cols)
      for (int c = 0; c < levelData.cols; c++) {
        for (int r = 0; r <= levelData.rows - 5; r++) {
          final c0 = grid[r]?[c];
          final c1 = grid[r + 1]?[c];
          final c2 = grid[r + 2]?[c];
          final c3 = grid[r + 3]?[c];
          final c4 = grid[r + 4]?[c];

          final v0 = getVal(c0);
          final op = getVal(c1);
          final v2 = getVal(c2);
          final eq = getVal(c3);
          final v4 = getVal(c4);

          if (isNum(v0) && isOp(op) && isNum(v2) && eq == '=' && isNum(v4)) {
            final a = int.parse(v0);
            final b = int.parse(v2);
            final expected = int.parse(v4);
            final actual = calc(a, op, b);
            if (actual != expected) {
              print('LỖI DỌC ở row $r, col $c: $a $op $b = $expected (thực tế tính ra: $actual)');
            }
          }
        }
      }
    }
  });
}
