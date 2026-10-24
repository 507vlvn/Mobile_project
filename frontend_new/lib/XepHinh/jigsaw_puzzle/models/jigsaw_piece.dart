class JigsawPiece {
  final int id;
  final int correctRow;
  final int correctCol;
  int currentRow;
  int currentCol;
  bool isPlaced;

  JigsawPiece({
    required this.id,
    required this.correctRow,
    required this.correctCol,
    required this.currentRow,
    required this.currentCol,
    this.isPlaced = false,
  });

  bool get isCorrect => correctRow == currentRow && correctCol == currentCol;
}
