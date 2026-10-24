enum SudokuDifficulty {
  easy('Dễ', 40, 360),
  medium('Trung bình', 32, 720),
  hard('Khó', 26, 1500),
  expert('Chuyên gia', 22, 2000),
  nightmare('Ác mộng', 17, 3000);

  final String label;
  final int clues;
  final int parSeconds;

  const SudokuDifficulty(this.label, this.clues, this.parSeconds);
}

enum SudokuStatus { notStarted, playing, paused, won, lost }

class SudokuCell {
  final int row;
  final int col;
  final int solution;
  final bool isGiven;
  int value;
  Set<int> notes;
  bool isError;

  SudokuCell({
    required this.row,
    required this.col,
    required this.solution,
    required this.isGiven,
    required this.value,
    Set<int>? notes,
    this.isError = false,
  }) : notes = notes ?? <int>{};

  SudokuCell copy() {
    return SudokuCell(
      row: row,
      col: col,
      solution: solution,
      isGiven: isGiven,
      value: value,
      notes: Set<int>.from(notes),
      isError: isError,
    );
  }
}

class SudokuMove {
  final int row;
  final int col;
  final int oldValue;
  final int newValue;
  final Set<int> oldNotes;
  final Set<int> newNotes;

  const SudokuMove({
    required this.row,
    required this.col,
    required this.oldValue,
    required this.newValue,
    required this.oldNotes,
    required this.newNotes,
  });
}
