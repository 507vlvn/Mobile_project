import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/difficulty.dart';
import '../../core/widgets/game_timer.dart';
import '../model/cube_model.dart';
import '../services/offline_rubik_solver.dart';
import '../services/scramble.dart';

enum PracticePhase { setup, scrambling, playing, paused, solved }

/// Trạng thái một ván Luyện giải Rubik.
class PracticeController extends ChangeNotifier {
  static const _saveKey = 'rubik_practice_save';

  /// false ở chế độ thách đấu: không ghi đè ván Luyện giải đang lưu.
  final bool persist;

  PracticeController({this.persist = true});

  PracticePhase _phase = PracticePhase.setup;
  PracticePhase get phase => _phase;

  Difficulty difficulty = Difficulty.medium;
  Cube3DState cube = Cube3DState();
  final GameClock clock = GameClock();

  int _moves = 0;
  int get moves => _moves;

  int _hints = 0;
  int get hints => _hints;

  final List<String> _history = [];
  final List<String> _redo = [];
  bool get canUndo => _history.isNotEmpty && _phase == PracticePhase.playing;
  bool get canRedo => _redo.isNotEmpty && _phase == PracticePhase.playing;

  String? _hintMove;
  String? get hintMove => _hintMove;

  bool _hintLoading = false;
  bool get hintLoading => _hintLoading;

  bool get isPlaying => _phase == PracticePhase.playing;

  // -------------------------------------------------------------------------

  /// Tạo đề mới; trả về chuỗi xáo để màn hình diễn hoạt.
  List<String> newGame(Difficulty d, {math.Random? random}) {
    difficulty = d;
    cube = Cube3DState();
    _moves = 0;
    _hints = 0;
    _history.clear();
    _redo.clear();
    _hintMove = null;
    clock.reset();
    _phase = PracticePhase.scrambling;
    notifyListeners();
    return generateScramble(scrambleLength(d), random: random);
  }

  /// Xáo xong (hoặc bỏ qua hoạt ảnh) → bắt đầu chơi. Đồng hồ chạy từ nước đầu tiên.
  void finishScramble() {
    _phase = PracticePhase.playing;
    notifyListeners();
    save();
  }

  /// Người chơi bắt đầu thao tác (kéo tầng / bấm nút) → khởi động đồng hồ.
  void onUserActionStart() {
    if (_phase == PracticePhase.playing && !clock.isRunning) clock.start();
  }

  /// Ghi nhận một nước đi người chơi vừa thực hiện (trạng thái khối đã cập nhật).
  /// Trả về true nếu khối đã được giải.
  bool recordMove(String move, {bool fromUndo = false}) {
    if (_phase != PracticePhase.playing) return false;
    onUserActionStart();
    _moves++;
    if (fromUndo) {
      _redo.add(_history.removeLast());
    } else {
      _history.add(move);
      // Nước mới khác với nước làm lại → xoá nhánh làm lại
      if (_redo.isNotEmpty && _redo.last == move) {
        _redo.removeLast();
      } else {
        _redo.clear();
      }
    }
    _hintMove = null;

    if (cube.isSolved) {
      clock.pause();
      _phase = PracticePhase.solved;
      clearSave();
      notifyListeners();
      return true;
    }
    notifyListeners();
    save();
    return false;
  }

  /// Nước cần thực hiện để hoàn tác (nghịch đảo của nước gần nhất).
  String? get undoMove => _history.isEmpty
      ? null
      : CubeMove.tryParse(_history.last)!.inverse.notation;

  String? get redoMove => _redo.isEmpty ? null : _redo.last;

  /// Lấy gợi ý bằng bộ giải Kociemba từ trạng thái hiện tại. Mỗi lần bị trừ điểm (×0.85).
  Future<String?> requestHint() async {
    if (_phase != PracticePhase.playing || _hintLoading) return null;
    if (_hintMove != null) {
      return _hintMove;
    } // đang hiện gợi ý thì không tính thêm
    _hintLoading = true;
    notifyListeners();
    final result =
        await OfflineRubikSolver.solveFromSideColors(cube.toSideColorCode());
    _hintLoading = false;
    if (result.success && result.moves.isNotEmpty) {
      _hints++;
      _hintMove = result.moves.first;
      onUserActionStart();
      save();
    }
    notifyListeners();
    return _hintMove;
  }

  /// Toàn bộ lời giải từ trạng thái hiện tại (dùng cho "Xem lời giải" = bỏ cuộc).
  Future<List<String>?> fullSolution() async {
    final result =
        await OfflineRubikSolver.solveFromSideColors(cube.toSideColorCode());
    return result.success ? result.moves : null;
  }

  void giveUp() {
    clock.pause();
    _phase = PracticePhase.setup;
    _hintMove = null;
    clearSave();
    notifyListeners();
  }

  void pause() {
    if (_phase != PracticePhase.playing) return;
    clock.pause();
    _phase = PracticePhase.paused;
    notifyListeners();
    save();
  }

  void resume() {
    if (_phase != PracticePhase.paused) return;
    _phase = PracticePhase.playing;
    if (_moves > 0 || _hints > 0) clock.start();
    notifyListeners();
  }

  // ----- Lưu / khôi phục ván dở -------------------------------------------

  Future<void> save() async {
    if (!persist) return;
    if (_phase != PracticePhase.playing && _phase != PracticePhase.paused) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _saveKey,
        jsonEncode({
          'difficulty': difficulty.value,
          'faces': cube.toSideColorCode(),
          'elapsedMs': clock.elapsed.inMilliseconds,
          'moves': _moves,
          'hints': _hints,
          'history': _history,
        }),
      );
    } catch (_) {}
  }

  Future<void> clearSave() async {
    if (!persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_saveKey);
    } catch (_) {}
  }

  static Future<bool> hasSavedGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_saveKey);
    } catch (_) {
      return false;
    }
  }

  /// Khôi phục ván dở; ván được khôi phục ở trạng thái tạm dừng.
  Future<bool> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_saveKey);
      if (raw == null) return false;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      difficulty = Difficulty.fromValue(data['difficulty'] as int?);
      cube = Cube3DState.fromSideColorCode(
        (data['faces'] as Map)
            .map((k, v) => MapEntry(k as String, v as String)),
      );
      _moves = data['moves'] as int? ?? 0;
      _hints = data['hints'] as int? ?? 0;
      _history
        ..clear()
        ..addAll((data['history'] as List? ?? []).cast<String>());
      _redo.clear();
      _hintMove = null;
      clock.reset(
          startAt: Duration(milliseconds: data['elapsedMs'] as int? ?? 0));
      _phase = PracticePhase.paused;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Không khôi phục được ván Rubik: $e');
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
