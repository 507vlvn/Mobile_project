import 'dart:math';

/// Bộ giải Sudoku bằng bitmask + backtracking (chọn ô ít ứng viên nhất).
/// Lưới là danh sách 81 số nguyên, 0 = ô trống, đọc theo hàng.
const int _all = 0x1FF; // 9 bit, bit (d-1) = chữ số d

final List<int> _popCount = List<int>.generate(512, (m) {
  var c = 0;
  for (var x = m; x != 0; x &= x - 1) {
    c++;
  }
  return c;
});

int _boxOf(int i) => (i ~/ 27) * 3 + (i % 9) ~/ 3;

class _Search {
  _Search(this.cells, this.limit, this.random);

  final List<int> cells;
  final int limit;
  final Random? random;
  final rows = List<int>.filled(9, 0);
  final cols = List<int>.filled(9, 0);
  final boxes = List<int>.filled(9, 0);
  int count = 0;
  List<int>? firstSolution;

  /// Nạp các ô đã có; trả về false nếu đề tự mâu thuẫn.
  bool init() {
    for (var i = 0; i < 81; i++) {
      final v = cells[i];
      if (v == 0) continue;
      if (v < 0 || v > 9) return false;
      final bit = 1 << (v - 1);
      final r = i ~/ 9, c = i % 9, b = _boxOf(i);
      if ((rows[r] | cols[c] | boxes[b]) & bit != 0) return false;
      rows[r] |= bit;
      cols[c] |= bit;
      boxes[b] |= bit;
    }
    return true;
  }

  /// Trả về true khi đã đủ [limit] lời giải và cần dừng.
  bool dfs() {
    var best = -1;
    var bestMask = 0;
    var bestCount = 10;
    for (var i = 0; i < 81; i++) {
      if (cells[i] != 0) continue;
      final mask = _all & ~(rows[i ~/ 9] | cols[i % 9] | boxes[_boxOf(i)]);
      final n = _popCount[mask];
      if (n < bestCount) {
        best = i;
        bestMask = mask;
        bestCount = n;
        if (n <= 1) break;
      }
    }
    if (best == -1) {
      count++;
      firstSolution ??= List<int>.of(cells);
      return count >= limit;
    }
    if (bestCount == 0) return false;

    final digits = <int>[
      for (var d = 1; d <= 9; d++)
        if (bestMask & (1 << (d - 1)) != 0) d,
    ];
    if (random != null) digits.shuffle(random);

    final r = best ~/ 9, c = best % 9, b = _boxOf(best);
    for (final d in digits) {
      final bit = 1 << (d - 1);
      cells[best] = d;
      rows[r] |= bit;
      cols[c] |= bit;
      boxes[b] |= bit;
      final stop = dfs();
      rows[r] &= ~bit;
      cols[c] &= ~bit;
      boxes[b] &= ~bit;
      cells[best] = 0;
      if (stop) return true;
    }
    return false;
  }
}

_Search _run(List<int> grid, int limit, Random? random) {
  assert(grid.length == 81);
  final s = _Search(List<int>.of(grid), limit, random);
  if (s.init()) s.dfs();
  return s;
}

/// Đếm số lời giải của [grid], dừng sớm khi đạt [limit].
int countSolutions(List<int> grid, {int limit = 2}) =>
    _run(grid, limit, null).count;

/// Lời giải đầu tiên tìm được, hoặc null nếu vô nghiệm.
List<int>? solveGrid(List<int> grid) => _run(grid, 1, null).firstSolution;

/// Lưới 9×9 đầy đủ, hợp lệ, ngẫu nhiên.
List<int> generateFullGrid(Random random) =>
    _run(List<int>.filled(81, 0), 1, random).firstSolution!;

/// Lưới có hợp lệ (không trùng số trong hàng/cột/khối) không.
bool isValidPartial(List<int> grid) =>
    _Search(List<int>.of(grid), 1, null).init();
