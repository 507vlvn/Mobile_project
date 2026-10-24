class SlidingTile {
  final int id; // 0 represents the empty tile
  final int correctIndex;
  int currentIndex;

  SlidingTile({
    required this.id,
    required this.correctIndex,
    required this.currentIndex,
  });

  bool get isCorrect => correctIndex == currentIndex;
  bool get isEmpty => id == 0;
}
