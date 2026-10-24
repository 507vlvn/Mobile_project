import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/challenge_context.dart';
import '../../core/models/difficulty.dart';
import '../../core/widgets/game_timer.dart';
import 'logic/ida_star.dart';
import 'logic/puzzle_logic.dart';

enum PuzzlePhase { setup, playing, paused, solved }

enum TapResult { ignored, blocked, moved, solved }

/// Hàm giải 3×3: trả về dãy vị trí ô cần trượt (xem [solveOptimal]).
typedef PuzzleSolveFn = Future<List<int>?> Function(List<int> board, int n);

class _Entry {
  final int tapped;
  final int blankBefore;
  const _Entry(this.tapped, this.blankBefore);
}

/// Thống kê cuối ván.
class PuzzleStats {
  final int reference;
  final int extraMoves;
  final int hints;

  /// Lỗi gửi lên server = bước thừa + số lần gợi ý.
  int get mistakes => extraMoves + hints;
  const PuzzleStats(this.reference, this.extraMoves, this.hints);
}

/// Trạng thái một ván Xếp hình.
class PuzzleController extends ChangeNotifier {
  /// [challenge] != null: ván thách đấu — xáo bằng `Random(challenge.seed)`
  /// (cùng đề cho cả hai người chơi) và không lưu/khôi phục ván.
  PuzzleController({Random? random, PuzzleSolveFn? solver, this.challenge})
      : _random = random ??
            (challenge == null ? Random() : Random(challenge.seed)),
        _solver = solver ?? solveOptimalInIsolate;

  final ChallengeContext? challenge;

  static const saveKey = 'puzzle_save';

  final Random _random;
  final PuzzleSolveFn _solver;
  final GameClock clock = GameClock();

  PuzzlePhase _phase = PuzzlePhase.setup;
  PuzzlePhase get phase => _phase;

  Difficulty difficulty = Difficulty.easy;
  int n = 3;
  List<int> board = PuzzleLogic.solved(3);
  List<int> _initial = PuzzleLogic.solved(3);

  int _moves = 0;
  int get moves => _moves;
  int _hints = 0;
  int get hints => _hints;

  final List<_Entry> _history = [];
  bool get canUndo => _history.isNotEmpty && _phase == PuzzlePhase.playing;

  int? _prevBlank;

  /// Vị trí ô đang được gợi ý (null nếu không có).
  int? _hintIndex;
  int? get hintIndex => _hintIndex;
  bool _hintLoading = false;
  bool get hintLoading => _hintLoading;

  int? _reference;
  Future<int>? _referenceFuture;

  /// Mốc tham chiếu đã tính xong chưa (3×3: tối ưu thật; còn lại: cận trên).
  int? get referenceMoves => _reference;

  bool get isPlaying => _phase == PuzzlePhase.playing;

  // -------------------------------------------------------------------------

  /// Tạo đề mới theo độ khó.
  void newGame(Difficulty d) {
    difficulty = d;
    n = PuzzleLogic.sizeOf(d);
    final s = PuzzleLogic.shuffle(n, _random);
    _initial = List.of(s.board);
    board = List.of(s.board);
    _moves = 0;
    _hints = 0;
    _history.clear();
    _prevBlank = null;
    _hintIndex = null;
    _hintLoading = false;
    clock.reset();
    _startReference(s.referenceMoves);
    _phase = PuzzlePhase.playing;
    notifyListeners();
    save();
  }

  /// 3×3: IDA* chính xác (isolate). 4×4+: cận trên từ đường xáo.
  void _startReference(int fallback, {int? known}) {
    _reference = known;
    if (known != null) {
      _referenceFuture = Future.value(known);
      return;
    }
    if (n == 3) {
      final start = List<int>.of(_initial);
      _referenceFuture = _solver(start, n).then((p) => p?.length ?? fallback, onError: (_) => fallback).then((v) {
        _reference = v;
        return v;
      });
    } else {
      _reference = fallback;
      _referenceFuture = Future.value(fallback);
    }
  }

  /// Chạm vào ô ở [index]: trượt cả đoạn về phía ô trống nếu cùng hàng/cột.
  TapResult tap(int index) {
    if (_phase != PuzzlePhase.playing) return TapResult.ignored;
    final r = PuzzleLogic.slide(board, n, index);
    if (r == null) return TapResult.blocked;
    _apply(r, _Entry(index, r.blankBefore));
    _prevBlank = r.lastStepFrom;
    return _afterMove();
  }

  /// Hoàn tác nước gần nhất. Hoàn tác cũng là một lần trượt nên vẫn cộng bước.
  TapResult undo() {
    if (!canUndo) return TapResult.ignored;
    final e = _history.last;
    final r = PuzzleLogic.slide(board, n, e.blankBefore);
    if (r == null) return TapResult.ignored;
    _history.removeLast();
    board = r.board;
    _moves += r.cost;
    _hintIndex = null;
    _prevBlank = null;
    return _afterMove();
  }

  void _apply(SlideResult r, _Entry e) {
    _history.add(e);
    board = r.board;
    _moves += r.cost;
    _hintIndex = null;
  }

  TapResult _afterMove() {
    if (!clock.isRunning) clock.start();
    if (PuzzleLogic.isSolved(board)) {
      clock.pause();
      _phase = PuzzlePhase.solved;
      clearSave();
      notifyListeners();
      return TapResult.solved;
    }
    notifyListeners();
    save();
    return TapResult.moved;
  }

  /// Gợi ý nước kế tiếp. Mỗi lần dùng tính 1 lỗi. Trả về vị trí ô cần trượt.
  Future<int?> requestHint() async {
    if (_phase != PuzzlePhase.playing || _hintLoading) return null;
    if (_hintIndex != null) return _hintIndex;
    final snapshot = board;
    int? idx;
    if (n == 3) {
      _hintLoading = true;
      notifyListeners();
      try {
        final path = await _solver(List.of(board), n);
        if (path != null && path.isNotEmpty) idx = path.first;
      } catch (_) {}
      _hintLoading = false;
      if (!identical(snapshot, board)) {
        notifyListeners();
        return null;
      }
    }
    idx ??= PuzzleLogic.greedyHint(board, n, avoidBlank: _prevBlank);
    if (idx != null) {
      _hints++;
      _hintIndex = idx;
      save();
    }
    notifyListeners();
    return idx;
  }

  /// Tính thống kê cuối ván (chờ mốc tham chiếu nếu chưa xong).
  Future<PuzzleStats> stats() async {
    final ref = _reference ?? await _referenceFuture ?? 0;
    return PuzzleStats(ref, PuzzleLogic.extraMoves(_moves, ref), _hints);
  }

  void giveUp() {
    clock.pause();
    _phase = PuzzlePhase.setup;
    _hintIndex = null;
    clearSave();
    notifyListeners();
  }

  void pause() {
    if (_phase != PuzzlePhase.playing) return;
    clock.pause();
    _phase = PuzzlePhase.paused;
    notifyListeners();
    save();
  }

  void resume() {
    if (_phase != PuzzlePhase.paused) return;
    _phase = PuzzlePhase.playing;
    if (_moves > 0) clock.start();
    notifyListeners();
  }

  // ----- Lưu / khôi phục ván dở -------------------------------------------

  Future<void> save() async {
    if (challenge != null) return;
    if (_phase != PuzzlePhase.playing && _phase != PuzzlePhase.paused) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        saveKey,
        jsonEncode({
          'difficulty': difficulty.value,
          'board': board,
          'initial': _initial,
          'elapsedMs': clock.elapsed.inMilliseconds,
          'moves': _moves,
          'hints': _hints,
          'reference': _reference,
          'history': [
            for (final e in _history) [e.tapped, e.blankBefore],
          ],
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

  /// Khôi phục ván dở; ván được khôi phục ở trạng thái tạm dừng.
  Future<bool> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(saveKey);
      if (raw == null) return false;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final d = Difficulty.fromValue(data['difficulty'] as int?);
      final size = PuzzleLogic.sizeOf(d);
      final b = (data['board'] as List).cast<int>();
      final init = (data['initial'] as List).cast<int>();
      if (b.length != size * size ||
          init.length != size * size ||
          !PuzzleLogic.isSolvable(b, size) ||
          !PuzzleLogic.isSolvable(init, size)) {
        throw const FormatException('Dữ liệu ván không hợp lệ');
      }
      difficulty = d;
      n = size;
      board = List.of(b);
      _initial = List.of(init);
      _moves = data['moves'] as int? ?? 0;
      _hints = data['hints'] as int? ?? 0;
      _history
        ..clear()
        ..addAll([
          for (final e in (data['history'] as List? ?? []))
            _Entry((e as List)[0] as int, e[1] as int),
        ]);
      _prevBlank = null;
      _hintIndex = null;
      _hintLoading = false;
      clock.reset(startAt: Duration(milliseconds: data['elapsedMs'] as int? ?? 0));
      // Thiếu mốc đã lưu: 3×3 tính lại bằng IDA*; lớn hơn dùng heuristic (cận dưới) làm mốc.
      _startReference(PuzzleLogic.heuristic(_initial, n), known: data['reference'] as int?);
      _phase = PuzzlePhase.paused;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Không khôi phục được ván Xếp hình: $e');
      await clearSave();
      return false;
    }
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }
}
