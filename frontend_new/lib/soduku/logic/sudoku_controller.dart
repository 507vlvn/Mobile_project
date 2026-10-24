import 'dart:async';
import 'package:flutter/foundation.dart';
import 'sudoku_generator.dart';
import 'sudoku_learning_manager.dart';
import 'sudoku_models.dart';

class SudokuController extends ChangeNotifier {
  static final SudokuController instance = SudokuController();

  List<List<SudokuCell>> board = [];
  SudokuDifficulty difficulty = SudokuDifficulty.medium;
  SudokuStatus status = SudokuStatus.notStarted;

  // Level chế độ học tập (1 đến 30). Nếu null tức là đang chơi Chế độ Cổ điển.
  int? currentLearningLevel;

  int? selectedRow;
  int? selectedCol;

  int mistakes = 0;
  final int maxMistakes = 3;

  int elapsedSeconds = 0;
  Timer? _timer;

  bool isNotesMode = false;
  final List<SudokuMove> _history = [];

  int _totalBlanks = 0;
  int? _currentSeed;

  SudokuController({SudokuDifficulty initialDifficulty = SudokuDifficulty.medium, int? seed}) {
    difficulty = initialDifficulty;
    _currentSeed = seed;
  }

  bool get isLearningMode => currentLearningLevel != null;

  String get displayTitle =>
      isLearningMode ? 'Cấp độ $currentLearningLevel' : difficulty.label;

  bool get hasOngoingGame =>
      board.isNotEmpty && (status == SudokuStatus.playing || status == SudokuStatus.paused);

  String get elapsedFormatted {
    final m = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void startNewGame({
    SudokuDifficulty? difficulty,
    int? seed,
    bool autoStartTimer = true,
  }) {
    currentLearningLevel = null;
    if (difficulty != null) this.difficulty = difficulty;
    _currentSeed = seed;

    final puzzleData = SudokuGenerator.generate(
      difficulty: this.difficulty,
      seed: seed,
    );

    _initBoardWithPuzzle(puzzleData, autoStartTimer: autoStartTimer);
  }

  void startLearningLevel(int level, {bool autoStartTimer = true}) {
    currentLearningLevel = level;
    final clues = SudokuLearningManager.getCluesForLevel(level);
    final seed = SudokuLearningManager.getSeedForLevel(level);
    _currentSeed = seed;

    final puzzleData = SudokuGenerator.generate(
      customClues: clues,
      seed: seed,
    );

    _initBoardWithPuzzle(puzzleData, autoStartTimer: autoStartTimer);
  }

  void _initBoardWithPuzzle(SudokuPuzzleData puzzleData, {required bool autoStartTimer}) {
    _totalBlanks = 0;
    board = List.generate(9, (r) {
      return List.generate(9, (c) {
        final val = puzzleData.puzzle[r][c];
        final sol = puzzleData.solution[r][c];
        final isGiven = val != 0;
        if (!isGiven) _totalBlanks++;

        return SudokuCell(
          row: r,
          col: c,
          solution: sol,
          isGiven: isGiven,
          value: val,
        );
      });
    });

    selectedRow = null;
    selectedCol = null;
    mistakes = 0;
    elapsedSeconds = 0;
    isNotesMode = false;
    _history.clear();
    stopTimer();

    if (autoStartTimer) {
      status = SudokuStatus.playing;
      _startTimer();
    } else {
      status = SudokuStatus.paused;
    }

    notifyListeners();
  }

  void restartCurrentGame() {
    if (isLearningMode) {
      startLearningLevel(currentLearningLevel!);
    } else {
      startNewGame(difficulty: difficulty, seed: _currentSeed);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (status == SudokuStatus.playing) {
        elapsedSeconds++;
        notifyListeners();
      }
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void pauseTimer() {
    stopTimer();
    if (status == SudokuStatus.playing) {
      status = SudokuStatus.paused;
      notifyListeners();
    }
  }

  void resumeTimer() {
    if (status == SudokuStatus.paused || status == SudokuStatus.notStarted) {
      status = SudokuStatus.playing;
      _startTimer();
      notifyListeners();
    }
  }

  void togglePause() {
    if (status == SudokuStatus.playing) {
      pauseTimer();
    } else if (status == SudokuStatus.paused) {
      resumeTimer();
    }
  }

  void selectCell(int r, int c) {
    if (status != SudokuStatus.playing) return;
    selectedRow = r;
    selectedCol = c;
    notifyListeners();
  }

  void toggleNotesMode() {
    isNotesMode = !isNotesMode;
    notifyListeners();
  }

  /// Nhập số 1-9 vào ô được chọn
  void inputNumber(int number) {
    if (status != SudokuStatus.playing) return;
    if (selectedRow == null || selectedCol == null) return;

    final cell = board[selectedRow!][selectedCol!];
    if (cell.isGiven) return;
    if (cell.value == cell.solution && !cell.isError) return;

    if (isNotesMode) {
      final oldNotes = Set<int>.from(cell.notes);
      final newNotes = Set<int>.from(cell.notes);
      if (newNotes.contains(number)) {
        newNotes.remove(number);
      } else {
        newNotes.add(number);
      }

      _history.add(SudokuMove(
        row: selectedRow!,
        col: selectedCol!,
        oldValue: cell.value,
        newValue: cell.value,
        oldNotes: oldNotes,
        newNotes: newNotes,
      ));

      cell.notes = newNotes;
      notifyListeners();
      return;
    }

    final oldValue = cell.value;
    final oldNotes = Set<int>.from(cell.notes);

    if (cell.value == number) {
      return;
    }

    final isCorrect = number == cell.solution;

    _history.add(SudokuMove(
      row: selectedRow!,
      col: selectedCol!,
      oldValue: oldValue,
      newValue: number,
      oldNotes: oldNotes,
      newNotes: {},
    ));

    cell.value = number;
    cell.notes.clear();

    if (isCorrect) {
      cell.isError = false;
      _removeNoteFromPeers(selectedRow!, selectedCol!, number);

      if (_checkWin()) {
        status = SudokuStatus.won;
        stopTimer();
        if (isLearningMode) {
          SudokuLearningManager.instance.recordWin(currentLearningLevel!, elapsedSeconds);
        }
      }
    } else {
      cell.isError = true;
      mistakes++;
      if (mistakes >= maxMistakes) {
        status = SudokuStatus.lost;
        stopTimer();
      }
    }

    notifyListeners();
  }

  void erase() {
    if (status != SudokuStatus.playing) return;
    if (selectedRow == null || selectedCol == null) return;

    final cell = board[selectedRow!][selectedCol!];
    if (cell.isGiven) return;
    if (cell.value == 0 && cell.notes.isEmpty) return;

    _history.add(SudokuMove(
      row: selectedRow!,
      col: selectedCol!,
      oldValue: cell.value,
      newValue: 0,
      oldNotes: Set<int>.from(cell.notes),
      newNotes: {},
    ));

    cell.value = 0;
    cell.notes.clear();
    cell.isError = false;
    notifyListeners();
  }

  void undo() {
    if (status != SudokuStatus.playing) return;
    if (_history.isEmpty) return;

    final lastMove = _history.removeLast();
    final cell = board[lastMove.row][lastMove.col];

    cell.value = lastMove.oldValue;
    cell.notes = Set<int>.from(lastMove.oldNotes);
    cell.isError = cell.value != 0 && cell.value != cell.solution;

    selectedRow = lastMove.row;
    selectedCol = lastMove.col;
    notifyListeners();
  }

  void hint() {
    if (status != SudokuStatus.playing) return;
    if (selectedRow == null || selectedCol == null) return;

    final cell = board[selectedRow!][selectedCol!];
    if (cell.isGiven || (cell.value == cell.solution && !cell.isError)) return;

    inputNumber(cell.solution);
  }

  void _removeNoteFromPeers(int row, int col, int num) {
    for (int i = 0; i < 9; i++) {
      board[row][i].notes.remove(num);
      board[i][col].notes.remove(num);
    }
    final startRow = (row ~/ 3) * 3;
    final startCol = (col ~/ 3) * 3;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        board[startRow + r][startCol + c].notes.remove(num);
      }
    }
  }

  bool _checkWin() {
    if (board.isEmpty) return false;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final cell = board[r][c];
        if (cell.value == 0 || cell.value != cell.solution) {
          return false;
        }
      }
    }
    return true;
  }

  double get progressPercent {
    if (_totalBlanks == 0) return 100.0;
    int correctCount = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final cell = board[r][c];
        if (!cell.isGiven && cell.value == cell.solution) {
          correctCount++;
        }
      }
    }
    return (correctCount / _totalBlanks) * 100;
  }

  Map<int, int> get numberCounts {
    final counts = {for (int i = 1; i <= 9; i++) i: 0};
    if (board.isEmpty) return counts;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final v = board[r][c].value;
        if (v >= 1 && v <= 9 && !board[r][c].isError) {
          counts[v] = (counts[v] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  SudokuCell? get selectedCell {
    if (selectedRow == null || selectedCol == null || board.isEmpty) return null;
    return board[selectedRow!][selectedCol!];
  }

  @override
  void dispose() {
    stopTimer();
    super.dispose();
  }
}
