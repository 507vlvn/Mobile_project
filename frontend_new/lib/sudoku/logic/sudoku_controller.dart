import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../../core/network/models.dart';
import 'sudoku_generator.dart';
import 'sudoku_learning_manager.dart';
import '../models/sudoku_models.dart';
import 'sudoku_stats_manager.dart';

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

  int movesCount = 0;
  int hintsUsed = 0;

  int elapsedSeconds = 0;
  Timer? _timer;

  bool isNotesMode = false;
  final List<SudokuMove> _history = [];

  int _totalBlanks = 0;
  int? _currentSeed;
  int? _userId;

  SudokuController({SudokuDifficulty initialDifficulty = SudokuDifficulty.medium, int? seed}) {
    difficulty = initialDifficulty;
    _currentSeed = seed;
  }

  int? get currentSeed => _currentSeed;

  /// Đổi tài khoản hoặc đăng xuất: làm mới hoàn toàn ván chơi để không lưu ván của người trước
  void onUserChanged(int? newUserId) {
    if (_userId != newUserId) {
      _userId = newUserId;
      resetToNewGame();
    }
  }

  /// Khởi tạo lại một ván cờ hoàn toàn mới (chưa bắt đầu đếm giờ)
  void resetToNewGame({SudokuDifficulty? difficulty}) {
    stopTimer();
    currentLearningLevel = null;
    if (difficulty != null) this.difficulty = difficulty;
    _currentSeed = Random().nextInt(899999) + 100000;
    final puzzleData = SudokuGenerator.generate(
      difficulty: this.difficulty,
      seed: _currentSeed,
    );
    _initBoardWithPuzzle(puzzleData, autoStartTimer: false);
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

  int get difficultyNumeric {
    return switch (difficulty) {
      SudokuDifficulty.easy => 1,
      SudokuDifficulty.medium => 2,
      SudokuDifficulty.hard => 3,
      SudokuDifficulty.expert => 4,
      SudokuDifficulty.nightmare => 5,
    };
  }

  static SudokuDifficulty difficultyFromNumeric(int num) {
    return switch (num) {
      1 => SudokuDifficulty.easy,
      2 => SudokuDifficulty.medium,
      3 => SudokuDifficulty.hard,
      4 => SudokuDifficulty.expert,
      5 => SudokuDifficulty.nightmare,
      _ => SudokuDifficulty.medium,
    };
  }

  void startNewGame({
    SudokuDifficulty? difficulty,
    int? seed,
    bool autoStartTimer = true,
  }) {
    currentLearningLevel = null;
    if (difficulty != null) this.difficulty = difficulty;
    _currentSeed = seed ?? (Random().nextInt(899999) + 100000);

    final puzzleData = SudokuGenerator.generate(
      difficulty: this.difficulty,
      seed: _currentSeed,
    );

    if (autoStartTimer) {
      SudokuStatsManager.instance.recordGameStarted(difficultyNumeric);
    }

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
    movesCount = 0;
    hintsUsed = 0;
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
    if (status == SudokuStatus.playing) {
      status = SudokuStatus.paused;
      stopTimer();
      notifyListeners();
    }
  }

  void resumeTimer() {
    if (status == SudokuStatus.paused) {
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
    if (status == SudokuStatus.paused) {
      resumeTimer();
    }
    if (status != SudokuStatus.playing) return;
    selectedRow = r;
    selectedCol = c;
    notifyListeners();
  }

  void toggleNotesMode() {
    isNotesMode = !isNotesMode;
    notifyListeners();
  }

  void inputNumber(int number) {
    if (status != SudokuStatus.playing) return;
    if (selectedRow == null || selectedCol == null) return;

    final cell = board[selectedRow!][selectedCol!];
    if (cell.isGiven) return;

    movesCount++;

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

    if (cell.value == number) return;

    final oldValue = cell.value;
    final oldNotes = Set<int>.from(cell.notes);
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
          SudokuLearningManager.instance.recordWin(
            currentLearningLevel!,
            elapsedSeconds,
            mistakes: mistakes,
          );
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
    cell.isError = (cell.value != 0 && cell.value != cell.solution);

    selectedRow = lastMove.row;
    selectedCol = lastMove.col;
    notifyListeners();
  }

  void hint() {
    if (status != SudokuStatus.playing) return;
    if (selectedRow == null || selectedCol == null) return;

    final cell = board[selectedRow!][selectedCol!];
    if (cell.isGiven || cell.value == cell.solution) return;

    hintsUsed++;
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

  // ==========================================
  // SERIALIZE & DATABASE RESUME
  // ==========================================

  String serializeBoardCurrent() {
    final buffer = StringBuffer();
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        buffer.write(board[r][c].value);
      }
    }
    return buffer.toString();
  }

  String? serializeNotesData() {
    final map = <String, List<int>>{};
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (board[r][c].notes.isNotEmpty) {
          map['${r}_$c'] = board[r][c].notes.toList();
        }
      }
    }
    if (map.isEmpty) return null;
    return jsonEncode(map);
  }

  void restoreFromSavedGame(SudokuSavedGame saved) {
    currentLearningLevel = saved.level;
    difficulty = difficultyFromNumeric(saved.difficulty);
    _currentSeed = saved.seed;

    final puzzleData = isLearningMode
        ? SudokuGenerator.generate(
            customClues: SudokuLearningManager.getCluesForLevel(currentLearningLevel!),
            seed: _currentSeed,
          )
        : SudokuGenerator.generate(
            difficulty: difficulty,
            seed: _currentSeed,
          );

    _initBoardWithPuzzle(puzzleData, autoStartTimer: false);

    // Điền lại trạng thái các ô đã chơi
    if (saved.boardCurrent.length == 81) {
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          final charVal = int.tryParse(saved.boardCurrent[r * 9 + c]) ?? 0;
          if (!board[r][c].isGiven) {
            board[r][c].value = charVal;
            board[r][c].isError = (charVal != 0 && charVal != board[r][c].solution);
          }
        }
      }
    }

    // Khôi phục ghi chú bút chì
    if (saved.notesData != null && saved.notesData!.isNotEmpty) {
      try {
        final decoded = jsonDecode(saved.notesData!) as Map<String, dynamic>;
        decoded.forEach((key, val) {
          final parts = key.split('_');
          if (parts.length == 2) {
            final r = int.tryParse(parts[0]);
            final c = int.tryParse(parts[1]);
            if (r != null && c != null && r >= 0 && r < 9 && c >= 0 && c < 9) {
              if (val is List) {
                board[r][c].notes = val.cast<int>().toSet();
              }
            }
          }
        });
      } catch (_) {}
    }

    mistakes = saved.mistakes;
    elapsedSeconds = saved.elapsedSeconds;
    status = SudokuStatus.paused;
    notifyListeners();
  }

  /// Lưu trạng thái ván cờ hiện tại lên Database
  Future<void> saveGameToServer(ApiClient api) async {
    if (board.isEmpty || status == SudokuStatus.won || status == SudokuStatus.lost) {
      return;
    }
    try {
      await api.saveSudokuGame(
        gameMode: isLearningMode ? 'LEARNING' : 'CLASSIC',
        level: currentLearningLevel,
        difficulty: difficultyNumeric,
        seed: _currentSeed ?? 12345,
        boardCurrent: serializeBoardCurrent(),
        notesData: serializeNotesData(),
        mistakes: mistakes,
        elapsedSeconds: elapsedSeconds,
      );
    } catch (e) {
      debugPrint('Lỗi lưu ván Sudoku lên Database: $e');
    }
  }

  /// Xóa ván cờ dở dang trên Database khi hoàn thành hoặc bắt đầu lại
  Future<void> deleteGameFromServer(ApiClient api) async {
    try {
      await api.deleteSudokuSavedGame(
        mode: isLearningMode ? 'LEARNING' : 'CLASSIC',
      );
    } catch (e) {
      debugPrint('Lỗi xóa ván Sudoku trên Database: $e');
    }
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
