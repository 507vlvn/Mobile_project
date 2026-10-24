import 'dart:isolate';
import 'dart:typed_data';

import 'puzzle_logic.dart';

/// IDA* với heuristic Manhattan + linear conflict. Dành cho bảng 3×3 (tối ưu
/// chính xác, thường vài chục ms). Trả về dãy vị trí ô cần trượt (= vị trí mà
/// ô trống lần lượt đi tới); rỗng nếu đã giải; null nếu không giải được.
List<int>? solveOptimal(List<int> start, int n) {
  if (!PuzzleLogic.isSolvable(start, n)) return null;
  return _Ida(start, n).run();
}

/// Chạy [solveOptimal] trên isolate riêng để không giật UI.
Future<List<int>?> solveOptimalInIsolate(List<int> start, int n) {
  final copy = List<int>.of(start);
  return Isolate.run(() => solveOptimal(copy, n));
}

class _Ida {
  _Ida(List<int> start, this.n)
      : board = Int8List.fromList(start),
        blank = start.indexOf(0);

  final int n;
  final Int8List board;
  int blank;
  final List<int> path = [];
  static const _found = -1;

  List<int>? run() {
    var bound = PuzzleLogic.heuristic(board, n);
    while (bound < 200) {
      final t = _search(0, bound, -1);
      if (t == _found) return List<int>.of(path);
      bound = t;
    }
    return null;
  }

  int _search(int g, int bound, int prev) {
    final h = PuzzleLogic.heuristic(board, n);
    final f = g + h;
    if (f > bound) return f;
    if (h == 0) return _found;
    var min = 1 << 30;
    final from = blank;
    for (final nb in PuzzleLogic.neighbors(from, n)) {
      if (nb == prev) continue;
      board[from] = board[nb];
      board[nb] = 0;
      blank = nb;
      path.add(nb);
      final t = _search(g + 1, bound, from);
      if (t == _found) return _found;
      path.removeLast();
      board[nb] = board[from];
      board[from] = 0;
      blank = from;
      if (t < min) min = t;
    }
    return min;
  }
}
