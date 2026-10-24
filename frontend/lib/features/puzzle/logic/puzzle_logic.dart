import 'dart:math';

import '../../../core/models/difficulty.dart';

/// Logic thuần Dart của trò Xếp hình (trượt ô số).
///
/// Bảng là `List<int>` độ dài n*n, theo hàng; `0` là ô trống. Trạng thái
/// đã giải: 1, 2, …, n*n-1, 0 (ô trống ở góc dưới phải).
///
/// **Quy ước đếm bước:** chạm vào bất kỳ ô nào cùng hàng/cột với ô trống sẽ
/// trượt cả đoạn ô nằm giữa; một lần trượt k ô được tính là **k bước** (mỗi ô
/// dịch một ô trống = 1 bước). Nhờ vậy số bước của người chơi so sánh được với
/// số bước tối ưu tính theo từng ô đơn lẻ.
abstract final class PuzzleLogic {
  /// Cạnh bảng theo độ khó: Dễ 3, Vừa 4, Khó 5.
  static int sizeOf(Difficulty d) => switch (d) {
        Difficulty.easy => 3,
        Difficulty.medium => 4,
        Difficulty.hard => 5,
      };

  /// Số nước xáo ngẫu nhiên từ trạng thái đã giải.
  static int shuffleSteps(int n) => switch (n) {
        3 => 60,
        4 => 120,
        _ => 220,
      };

  static List<int> solved(int n) =>
      List<int>.generate(n * n, (i) => i == n * n - 1 ? 0 : i + 1);

  static bool isSolved(List<int> board) {
    for (var i = 0; i < board.length - 1; i++) {
      if (board[i] != i + 1) return false;
    }
    return board.last == 0;
  }

  /// Số ô đang nằm đúng vị trí (không tính ô trống).
  static int correctCount(List<int> board) {
    var c = 0;
    for (var i = 0; i < board.length; i++) {
      if (board[i] != 0 && board[i] == i + 1) c++;
    }
    return c;
  }

  /// Kiểm tra bảng có giải được không (quy tắc chẵn lẻ nghịch thế).
  static bool isSolvable(List<int> board, int n) {
    var inv = 0;
    for (var i = 0; i < board.length; i++) {
      if (board[i] == 0) continue;
      for (var j = i + 1; j < board.length; j++) {
        if (board[j] != 0 && board[j] < board[i]) inv++;
      }
    }
    if (n.isOdd) return inv.isEven;
    final blankRowFromBottom = n - board.indexOf(0) ~/ n; // 1 = hàng cuối
    return blankRowFromBottom.isOdd ? inv.isEven : inv.isOdd;
  }

  /// Các ô kề (trên, dưới, trái, phải) của [index].
  static List<int> neighbors(int index, int n) {
    final r = index ~/ n, c = index % n;
    return [
      if (r > 0) index - n,
      if (r < n - 1) index + n,
      if (c > 0) index - 1,
      if (c < n - 1) index + 1,
    ];
  }

  /// Trượt đoạn ô từ [index] về phía ô trống. Trả về null nếu ô không cùng
  /// hàng/cột với ô trống (hoặc chính là ô trống).
  static SlideResult? slide(List<int> board, int n, int index) {
    final blank = board.indexOf(0);
    if (index == blank || index < 0 || index >= board.length) return null;
    final sameRow = index ~/ n == blank ~/ n;
    final sameCol = index % n == blank % n;
    if (!sameRow && !sameCol) return null;
    final step = sameRow ? (index > blank ? 1 : -1) : (index > blank ? n : -n);
    final next = List<int>.of(board);
    var p = blank;
    while (p != index) {
      next[p] = next[p + step];
      p += step;
    }
    next[index] = 0;
    final cost = (index - blank).abs() ~/ (sameRow ? 1 : n);
    return SlideResult(
      board: next,
      blankBefore: blank,
      blankAfter: index,
      cost: cost,
      lastStepFrom: index - step,
    );
  }

  /// Xáo bằng [steps] nước hợp lệ từ trạng thái đã giải, không bao giờ đi
  /// ngược nước vừa đi; xáo lại nếu kết quả trùng trạng thái đã giải.
  static PuzzleShuffle shuffle(int n, Random rnd, {int? steps}) {
    final count = steps ?? shuffleSteps(n);
    while (true) {
      final board = solved(n);
      var blank = n * n - 1;
      var prev = -1;
      final path = <int>[blank];
      for (var i = 0; i < count; i++) {
        final options = neighbors(blank, n).where((x) => x != prev).toList();
        final next = options[rnd.nextInt(options.length)];
        board[blank] = board[next];
        board[next] = 0;
        prev = blank;
        blank = next;
        path.add(blank);
      }
      if (!isSolved(board)) return PuzzleShuffle(board, path);
    }
  }

  /// Rút gọn đường đi của ô trống bằng cách triệt tiêu các cặp đi-rồi-quay-lại.
  static List<int> cancelBacktracking(List<int> blankPath) {
    final out = <int>[];
    for (final p in blankPath) {
      if (out.length >= 2 && out[out.length - 2] == p) {
        out.removeLast();
      } else {
        out.add(p);
      }
    }
    return out;
  }

  /// Heuristic: Manhattan + xung đột tuyến tính (linear conflict). Chấp nhận
  /// được (không đánh giá quá), dùng cho IDA* và gợi ý tham lam.
  static int heuristic(List<int> board, int n) {
    var h = 0;
    for (var i = 0; i < board.length; i++) {
      final t = board[i];
      if (t == 0) continue;
      final g = t - 1;
      h += (i ~/ n - g ~/ n).abs() + (i % n - g % n).abs();
    }
    // Xung đột hàng/cột: mỗi tuyến cần đưa ít nhất (m - LIS) ô ra rồi vào lại.
    final seq = List<int>.filled(n, 0);
    for (var r = 0; r < n; r++) {
      var m = 0;
      for (var c = 0; c < n; c++) {
        final t = board[r * n + c];
        if (t != 0 && (t - 1) ~/ n == r) seq[m++] = (t - 1) % n;
      }
      h += 2 * (m - _lis(seq, m));
    }
    for (var c = 0; c < n; c++) {
      var m = 0;
      for (var r = 0; r < n; r++) {
        final t = board[r * n + c];
        if (t != 0 && (t - 1) % n == c) seq[m++] = (t - 1) ~/ n;
      }
      h += 2 * (m - _lis(seq, m));
    }
    return h;
  }

  static int _lis(List<int> a, int m) {
    var best = 0;
    final len = List<int>.filled(m, 1);
    for (var i = 0; i < m; i++) {
      for (var j = 0; j < i; j++) {
        if (a[j] < a[i] && len[j] + 1 > len[i]) len[i] = len[j] + 1;
      }
      if (len[i] > best) best = len[i];
    }
    return best;
  }

  /// Gợi ý tham lam cho bảng lớn (4×4, 5×5): chọn một ô kề ô trống sao cho
  /// heuristic sau khi đi là nhỏ nhất, tránh đi ngược nước trước
  /// ([avoidBlank] = vị trí ô trống ngay trước đó). Trả về vị trí ô cần trượt.
  /// Đây chỉ là gợi ý cục bộ, không đảm bảo tối ưu.
  static int? greedyHint(List<int> board, int n, {int? avoidBlank}) {
    if (isSolved(board)) return null;
    final blank = board.indexOf(0);
    final work = List<int>.of(board);
    int? best;
    var bestH = 1 << 30;
    var candidates = neighbors(blank, n);
    if (candidates.length > 1 && avoidBlank != null) {
      candidates = candidates.where((x) => x != avoidBlank).toList();
    }
    for (final nb in candidates) {
      work[blank] = work[nb];
      work[nb] = 0;
      final h = heuristic(work, n);
      work[nb] = work[blank];
      work[blank] = 0;
      if (h < bestH) {
        bestH = h;
        best = nb;
      }
    }
    return best;
  }

  /// Số bước thừa = max(0, bước đã đi − mốc tham chiếu).
  static int extraMoves(int playerMoves, int reference) =>
      max(0, playerMoves - reference);
}

class SlideResult {
  final List<int> board;
  final int blankBefore;
  final int blankAfter;

  /// Số ô đã dịch = số bước được tính.
  final int cost;

  /// Vị trí ô trống ngay trước bước đơn cuối cùng (dùng để tránh gợi ý đi ngược).
  final int lastStepFrom;

  const SlideResult({
    required this.board,
    required this.blankBefore,
    required this.blankAfter,
    required this.cost,
    required this.lastStepFrom,
  });
}

class PuzzleShuffle {
  final List<int> board;

  /// Các vị trí ô trống qua từng nước xáo (bắt đầu từ góc dưới phải).
  final List<int> blankPath;

  const PuzzleShuffle(this.board, this.blankPath);

  /// Mốc tham chiếu cho bảng 4×4 trở lên: độ dài đường xáo sau khi triệt tiêu
  /// đi-rồi-quay-lại. Đây là **cận trên** của số bước tối ưu, không phải tối ưu thật.
  int get referenceMoves => PuzzleLogic.cancelBacktracking(blankPath).length - 1;
}
