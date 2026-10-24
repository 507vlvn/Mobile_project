import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/challenge_context.dart';
import '../../core/models/difficulty.dart';
import '../../core/widgets/game_timer.dart';
import 'logic/sudoku_board.dart';
import 'logic/sudoku_generator.dart';

enum SudokuPhase { setup, generating, playing, paused, solved }

/// Kết quả một lần nhập số.
enum PlaceResult { ignored, note, correct, wrong, solved }

/// Sự kiện nhấp nháy khi hoàn thành hàng/cột/khối (mỗi sự kiện có id riêng).
class SudokuFlash {
  final int id;
  final Set<int> cells;
  const SudokuFlash(this.id, this.cells);
}

class _Snapshot {
  final List<int> values;
  final List<Set<int>> notes;
  _Snapshot(SudokuBoard b)
      : values = List<int>.of(b.values),
        notes = [for (final s in b.notes) Set<int>.of(s)];
}

typedef PuzzleGenerator = Future<SudokuPuzzle> Function(Difficulty difficulty);

/// Trạng thái một ván Sudoku.
class SudokuController extends ChangeNotifier {
  SudokuController({
    PuzzleGenerator? generator,
    this.saveDelay = const Duration(milliseconds: 400),
    this.challenge,
  })  : _generator = generator ??
            (challenge == null
                ? generatePuzzleInIsolate
                : ((d) => generatePuzzleInIsolate(d, seed: challenge.seed))),
        _hintRandom = challenge == null ? null : Random(challenge.seed);

  /// Khác null = ván thách đấu: đề sinh từ seed, không lưu/khôi phục.
  final ChallengeContext? challenge;
  final Random? _hintRandom;

  static const saveKey = 'sudoku_save';
  static const _maxUndo = 300;

  final PuzzleGenerator _generator;
  final Duration saveDelay;
  final GameClock clock = GameClock();

  SudokuPhase _phase = SudokuPhase.setup;
  SudokuPhase get phase => _phase;

  Difficulty difficulty = Difficulty.medium;
  SudokuBoard? board;

  int? _selected;
  int? get selected => _selected;

  bool _notesMode = false;
  bool get notesMode => _notesMode;

  int _wrongEntries = 0;
  int get wrongEntries => _wrongEntries;

  int _hints = 0;
  int get hints => _hints;

  int _entries = 0;
  int get entries => _entries;

  /// Lỗi = số lần điền sai + số gợi ý đã dùng.
  int get mistakes => _wrongEntries + _hints;

  SudokuFlash? _flash;
  SudokuFlash? get flash => _flash;
  int _flashId = 0;

  final List<_Snapshot> _undo = [];
  bool get canUndo => _undo.isNotEmpty && _phase == SudokuPhase.playing;
  bool get isPlaying => _phase == SudokuPhase.playing;

  int _genToken = 0;
  Timer? _saveTimer;
  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Ván mới
  // ---------------------------------------------------------------------------

  /// Sinh đề (trong isolate) rồi bắt đầu. Trong lúc chờ phase = generating.
  Future<void> startNewGame(Difficulty d) async {
    final token = ++_genToken;
    difficulty = d;
    board = null;
    _resetCounters();
    _phase = SudokuPhase.generating;
    notifyListeners();
    final puzzle = await _generator(d);
    if (_disposed || token != _genToken) {
      return;
    }
    loadPuzzle(puzzle, d);
  }

  /// Nạp đề có sẵn (dùng cho test / sau khi sinh xong).
  void loadPuzzle(SudokuPuzzle p, Difficulty d) {
    difficulty = d;
    board = SudokuBoard(
      givens: List<int>.of(p.puzzle),
      solution: List<int>.of(p.solution),
    );
    _resetCounters();
    _phase = SudokuPhase.playing;
    notifyListeners();
    _scheduleSave();
  }

  void _resetCounters() {
    _selected = null;
    _notesMode = false;
    _wrongEntries = 0;
    _hints = 0;
    _entries = 0;
    _flash = null;
    _undo.clear();
    clock.reset();
  }

  /// Huỷ ván đang chơi, quay về màn chọn độ khó.
  void abandon() {
    _genToken++;
    _saveTimer?.cancel();
    clock.pause();
    board = null;
    _selected = null;
    _phase = SudokuPhase.setup;
    if (challenge == null) clearSave();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Thao tác
  // ---------------------------------------------------------------------------

  void select(int? index) {
    if (_phase != SudokuPhase.playing) {
      return;
    }
    _selected = index;
    notifyListeners();
  }

  void toggleNotes() {
    if (_phase != SudokuPhase.playing) {
      return;
    }
    _notesMode = !_notesMode;
    notifyListeners();
  }

  void _startClock() {
    if (_phase == SudokuPhase.playing && !clock.isRunning) {
      clock.start();
    }
  }

  void _pushUndo() {
    _undo.add(_Snapshot(board!));
    if (_undo.length > _maxUndo) {
      _undo.removeAt(0);
    }
  }

  /// Nhập chữ số [d] (1–9) vào ô đang chọn (hoặc bật/tắt ghi chú ở chế độ nháp).
  PlaceResult input(int d) {
    final b = board;
    final i = _selected;
    if (b == null || i == null || _phase != SudokuPhase.playing) {
      return PlaceResult.ignored;
    }
    if (d < 1 || d > 9 || b.isGiven(i) || b.isCorrect(i)) {
      return PlaceResult.ignored;
    }

    if (_notesMode) {
      if (!b.isEmpty(i)) {
        return PlaceResult.ignored;
      }
      _startClock();
      _pushUndo();
      if (!b.notes[i].add(d)) {
        b.notes[i].remove(d);
      }
      notifyListeners();
      _scheduleSave();
      return PlaceResult.note;
    }

    if (b.values[i] == d) {
      return PlaceResult.ignored;
    }
    _startClock();
    _pushUndo();
    b.values[i] = d;
    b.notes[i].clear();
    _entries++;

    if (d != b.solution[i]) {
      _wrongEntries++;
      notifyListeners();
      _scheduleSave();
      return PlaceResult.wrong;
    }
    return _afterCorrect(i, d);
  }

  PlaceResult _afterCorrect(int i, int d) {
    final b = board!;
    b.clearNotesOfPeers(i, d);

    if (b.isComplete) {
      _finish();
      return PlaceResult.solved;
    }
    final flash = <int>{};
    for (final unit in [
      SudokuBoard.rowCells(SudokuBoard.rowOf(i)),
      SudokuBoard.colCells(SudokuBoard.colOf(i)),
      SudokuBoard.boxCells(SudokuBoard.boxOf(i)),
    ]) {
      if (b.unitCorrect(unit)) {
        flash.addAll(unit);
      }
    }
    if (flash.isNotEmpty) {
      _flash = SudokuFlash(++_flashId, flash);
    }
    notifyListeners();
    _scheduleSave();
    return PlaceResult.correct;
  }

  void _finish() {
    clock.pause();
    _phase = SudokuPhase.solved;
    _flash = SudokuFlash(++_flashId, {for (var k = 0; k < 81; k++) k});
    _selected = null;
    _saveTimer?.cancel();
    if (challenge == null) clearSave();
    notifyListeners();
  }

  /// Xoá số / ghi chú ở ô đang chọn.
  bool erase() {
    final b = board;
    final i = _selected;
    if (b == null || i == null || _phase != SudokuPhase.playing) {
      return false;
    }
    if (b.isGiven(i) || b.isCorrect(i)) {
      return false;
    }
    if (b.isEmpty(i) && b.notes[i].isEmpty) {
      return false;
    }
    _startClock();
    _pushUndo();
    b.values[i] = 0;
    b.notes[i].clear();
    notifyListeners();
    _scheduleSave();
    return true;
  }

  bool undo() {
    final b = board;
    if (b == null || !canUndo) {
      return false;
    }
    final s = _undo.removeLast();
    for (var k = 0; k < 81; k++) {
      b.values[k] = s.values[k];
      b.notes[k]
        ..clear()
        ..addAll(s.notes[k]);
    }
    notifyListeners();
    _scheduleSave();
    return true;
  }

  /// Gợi ý: điền đúng ô đang chọn (nếu chưa đúng), nếu không thì một ô sai/trống.
  /// Mỗi gợi ý tính 1 lỗi. Trả về chỉ số ô được điền, hoặc -1.
  int hint({Random? random}) {
    final b = board;
    if (b == null || _phase != SudokuPhase.playing) {
      return -1;
    }
    final int target;
    final sel = _selected;
    if (sel != null && !b.isGiven(sel) && !b.isCorrect(sel)) {
      target = sel;
    } else {
      final candidates = [
        for (var k = 0; k < 81; k++)
          if (!b.isCorrect(k)) k,
      ];
      if (candidates.isEmpty) {
        return -1;
      }
      target = candidates[(random ?? _hintRandom ?? Random()).nextInt(candidates.length)];
    }
    _startClock();
    _pushUndo();
    final d = b.solution[target];
    b.values[target] = d;
    b.notes[target].clear();
    _entries++;
    _hints++;
    _selected = target;
    _afterCorrect(target, d);
    return target;
  }

  // ---------------------------------------------------------------------------
  // Tạm dừng
  // ---------------------------------------------------------------------------

  void pause() {
    if (_phase != SudokuPhase.playing) {
      return;
    }
    clock.pause();
    _phase = SudokuPhase.paused;
    notifyListeners();
    saveNow();
  }

  void resume() {
    if (_phase != SudokuPhase.paused) {
      return;
    }
    _phase = SudokuPhase.playing;
    if (_entries > 0 || _hints > 0 || clock.elapsed > Duration.zero) {
      clock.start();
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Lưu / khôi phục
  // ---------------------------------------------------------------------------

  void _scheduleSave() {
    if (challenge != null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, saveNow);
  }

  Future<void> saveNow() async {
    _saveTimer?.cancel();
    if (challenge != null) return;
    final b = board;
    if (b == null ||
        (_phase != SudokuPhase.playing && _phase != SudokuPhase.paused)) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        saveKey,
        jsonEncode({
          'difficulty': difficulty.value,
          'board': b.toJson(),
          'elapsedMs': clock.elapsed.inMilliseconds,
          'wrong': _wrongEntries,
          'hints': _hints,
          'entries': _entries,
        }),
      );
    } catch (_) {}
  }

  Future<void> clearSave() async {
    if (challenge != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(saveKey);
    } catch (_) {}
  }

  static Future<bool> hasSavedGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(saveKey);
    } catch (_) {
      return false;
    }
  }

  /// Khôi phục ván dở; ván ở trạng thái tạm dừng.
  Future<bool> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(saveKey);
      if (raw == null) {
        return false;
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final restored =
          SudokuBoard.fromJson(data['board'] as Map<String, dynamic>);
      _genToken++;
      board = restored;
      difficulty = Difficulty.fromValue(data['difficulty'] as int?);
      _wrongEntries = data['wrong'] as int? ?? 0;
      _hints = data['hints'] as int? ?? 0;
      _entries = data['entries'] as int? ?? 0;
      _selected = null;
      _notesMode = false;
      _flash = null;
      _undo.clear();
      clock.reset(
        startAt: Duration(milliseconds: data['elapsedMs'] as int? ?? 0),
      );
      _phase = SudokuPhase.paused;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Không khôi phục được ván Sudoku: $e');
      await clearSave();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    clock.dispose();
    super.dispose();
  }
}
