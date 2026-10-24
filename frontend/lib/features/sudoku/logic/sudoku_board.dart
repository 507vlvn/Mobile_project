/// Mô hình bàn Sudoku: đề, giá trị hiện tại, ghi chú và lời giải.
class SudokuBoard {
  SudokuBoard({
    required this.givens,
    required this.solution,
    List<int>? values,
    List<Set<int>>? notes,
  })  : values = values ?? List<int>.of(givens),
        notes = notes ?? List<Set<int>>.generate(81, (_) => <int>{});

  /// Đề bài (0 = trống)
  final List<int> givens;
  final List<int> solution;
  final List<int> values;
  final List<Set<int>> notes;

  static int rowOf(int i) => i ~/ 9;
  static int colOf(int i) => i % 9;
  static int boxOf(int i) => (i ~/ 27) * 3 + (i % 9) ~/ 3;

  static bool arePeers(int a, int b) =>
      a != b &&
      (rowOf(a) == rowOf(b) || colOf(a) == colOf(b) || boxOf(a) == boxOf(b));

  /// 20 ô cùng hàng / cột / khối với [i].
  static List<int> peersOf(int i) => [
        for (var j = 0; j < 81; j++)
          if (arePeers(i, j)) j,
      ];

  bool isGiven(int i) => givens[i] != 0;
  bool isEmpty(int i) => values[i] == 0;
  bool isCorrect(int i) => values[i] != 0 && values[i] == solution[i];
  bool isWrong(int i) => values[i] != 0 && values[i] != solution[i];

  bool get isComplete {
    for (var i = 0; i < 81; i++) {
      if (values[i] != solution[i]) return false;
    }
    return true;
  }

  /// Số ô điền đúng của chữ số [d] (kể cả ô đề bài).
  int correctCount(int d) {
    var n = 0;
    for (var i = 0; i < 81; i++) {
      if (values[i] == d && solution[i] == d) n++;
    }
    return n;
  }

  static List<int> rowCells(int r) => [for (var c = 0; c < 9; c++) r * 9 + c];
  static List<int> colCells(int c) => [for (var r = 0; r < 9; r++) r * 9 + c];
  static List<int> boxCells(int b) => [
        for (var k = 0; k < 9; k++)
          ((b ~/ 3) * 3 + k ~/ 3) * 9 + (b % 3) * 3 + k % 3,
      ];

  bool unitCorrect(List<int> cells) => cells.every(isCorrect);

  /// Xoá chữ số [d] khỏi ghi chú của mọi ô cùng hàng/cột/khối với [i].
  void clearNotesOfPeers(int i, int d) {
    for (final p in peersOf(i)) {
      notes[p].remove(d);
    }
  }

  Map<String, dynamic> toJson() => {
        'givens': givens.join(),
        'solution': solution.join(),
        'values': values.join(),
        'notes': [
          for (final s in notes) s.fold<int>(0, (m, d) => m | (1 << (d - 1))),
        ],
      };

  static SudokuBoard fromJson(Map<String, dynamic> j) {
    List<int> digits(String s) {
      if (s.length != 81) throw const FormatException('bad length');
      return [for (final ch in s.split('')) int.parse(ch)];
    }

    final masks = (j['notes'] as List).cast<int>();
    if (masks.length != 81) throw const FormatException('bad notes');
    return SudokuBoard(
      givens: digits(j['givens'] as String),
      solution: digits(j['solution'] as String),
      values: digits(j['values'] as String),
      notes: [
        for (final m in masks)
          {
            for (var d = 1; d <= 9; d++)
              if (m & (1 << (d - 1)) != 0) d,
          },
      ],
    );
  }
}
