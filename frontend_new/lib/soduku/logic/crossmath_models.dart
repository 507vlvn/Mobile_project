enum CrossMathCellType {
  none,
  fixedNumber,
  operator,
  blank,
}

class CrossMathCell {
  final int row;
  final int col;
  final CrossMathCellType type;
  final String label;
  final String? targetText;
  String? userText;

  CrossMathCell({
    required this.row,
    required this.col,
    required this.type,
    this.label = '',
    String? targetText,
    String? userText,
    int? targetValue,
    int? userValue,
  })  : targetText = targetText ?? (targetValue?.toString()),
        userText = userText ?? (userValue?.toString());

  bool get isBlank => type == CrossMathCellType.blank;
  bool get isCorrect => isBlank && userText != null && userText == targetText;

  int? get targetValue => targetText != null ? int.tryParse(targetText!) : null;
  int? get userValue => userText != null ? int.tryParse(userText!) : null;
  set userValue(int? val) => userText = val?.toString();

  CrossMathCell copy() {
    return CrossMathCell(
      row: row,
      col: col,
      type: type,
      label: label,
      targetText: targetText,
      userText: userText,
    );
  }
}

class CrossMathLevelData {
  final int level;
  final int rows;
  final int cols;
  final List<CrossMathCell> cells;
  final List<String> numberPool; // Các thẻ ở khay bên dưới (có thể là số hoặc toán tử như 'x')

  CrossMathLevelData({
    required this.level,
    required this.rows,
    required this.cols,
    required this.cells,
    required this.numberPool,
  });
}
