/// Mức độ khó dùng chung cho mọi game (giá trị khớp cột GameLevels.difficulty).
enum Difficulty {
  easy(1, 'Dễ'),
  medium(2, 'Vừa'),
  hard(3, 'Khó');

  const Difficulty(this.value, this.label);

  final int value;
  final String label;

  static Difficulty fromValue(int? v) =>
      Difficulty.values.firstWhere((d) => d.value == v, orElse: () => medium);
}
