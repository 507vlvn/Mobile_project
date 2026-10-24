import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_new/caro/models/challenge_context.dart';
import 'package:frontend_new/caro/models/difficulty.dart';
import 'package:frontend_new/caro/services/score_reporter.dart';
import 'package:frontend_new/caro/widgets/game_timer.dart';
import 'logic/caro_ai.dart';
import 'logic/caro_board.dart';

enum CaroPhase { setup, playing, finished }

enum CaroResult { playerWin, aiWin, draw }

/// Hàm tính nước đi cho máy (mặc định chạy trên isolate; test có thể thay thế).
typedef CaroAiRunner = Future<int> Function(CaroAiRequest request);

/// Trạng thái một ván Caro với máy.
class CaroController extends ChangeNotifier {
  CaroController({
    CaroAiRunner? aiRunner,
    this.minThinkTime = const Duration(milliseconds: 350),
    this.indicatorDelay = const Duration(milliseconds: 300),
    this.challenge,
  }) : _runner = aiRunner ?? runCaroAiInIsolate;

  /// Khác null = ván thách đấu: người chơi luôn đi trước, máy dùng seed xác
  /// định từ `challenge.seed` + thế cờ, không lưu/khôi phục ván.
  final ChallengeContext? challenge;

  static const _saveKey = 'caro_save';

  final CaroAiRunner _runner;

  /// Máy luôn "suy nghĩ" ít nhất chừng này để nước đi tự nhiên.
  final Duration minThinkTime;

  /// Chỉ hiện "Máy đang nghĩ…" nếu việc tính toán kéo dài hơn mức này.
  final Duration indicatorDelay;

  CaroPhase _phase = CaroPhase.setup;
  CaroPhase get phase => _phase;

  Difficulty difficulty = Difficulty.medium;
  bool playerFirst = true;

  final Uint8List cells = Uint8List(kCaroCells);
  final GameClock clock = GameClock();

  /// Tăng mỗi khi bàn cờ đổi — dùng cho shouldRepaint.
  int version = 0;

  /// Danh sách ô đã đánh theo thứ tự. Người đi đầu luôn ở chỉ số chẵn.
  final List<int> _history = [];
  List<int> get history => List.unmodifiable(_history);

  int _undos = 0;
  int get undos => _undos;

  CaroResult? _result;
  CaroResult? get result => _result;

  List<int>? _winLine;
  List<int>? get winLine => _winLine;

  bool _thinking = false;
  bool get thinking => _thinking;

  bool _thinkingVisible = false;

  /// true khi tính toán đã kéo dài quá [indicatorDelay] → hiện chỉ báo.
  bool get thinkingVisible => _thinkingVisible;

  int _gen = 0;
  bool _disposed = false;

  int? get lastMove => _history.isEmpty ? null : _history.last;

  int _playerOf(int historyIndex) =>
      ((historyIndex % 2 == 0) == playerFirst) ? kCaroPlayer : kCaroAi;

  int get playerMoves {
    var n = 0;
    for (var i = 0; i < _history.length; i++) {
      if (_playerOf(i) == kCaroPlayer) n++;
    }
    return n;
  }

  bool get isPlaying => _phase == CaroPhase.playing;

  bool get isPlayerTurn => isPlaying && _playerOf(_history.length) == kCaroPlayer;

  bool get canPlayerMove => isPlayerTurn && !_thinking;

  bool get canUndo => isPlaying && !_thinking && playerMoves > 0;

  bool isEmptyCell(int idx) => cells[idx] == kCaroEmpty;

  // -------------------------------------------------------------------------
  // Luồng ván chơi
  // -------------------------------------------------------------------------

  void newGame({required Difficulty difficulty, required bool playerFirst}) {
    _gen++;
    final ch = challenge;
    this.difficulty = ch?.difficulty ?? difficulty;
    this.playerFirst = ch != null ? true : playerFirst;
    playerFirst = this.playerFirst;
    cells.fillRange(0, kCaroCells, kCaroEmpty);
    _history.clear();
    _undos = 0;
    _result = null;
    _winLine = null;
    _thinking = false;
    _thinkingVisible = false;
    version++;
    clock.reset();
    _phase = CaroPhase.playing;
    clock.start();
    notifyListeners();
    if (!playerFirst) _aiTurn();
  }

  /// Về màn chọn thiết lập (xoá ván đang dở).
  void toSetup() {
    _gen++;
    _thinking = false;
    _thinkingVisible = false;
    clock.pause();
    _phase = CaroPhase.setup;
    if (challenge == null) clearSave();
    notifyListeners();
  }

  /// Người chơi đặt quân. Trả về true nếu nước đi hợp lệ.
  bool placePlayer(int idx) {
    if (!canPlayerMove || idx < 0 || idx >= kCaroCells || cells[idx] != kCaroEmpty) return false;
    _place(idx, kCaroPlayer);
    if (_phase == CaroPhase.playing) {
      save();
      _aiTurn();
    }
    return true;
  }

  void _place(int idx, int player) {
    cells[idx] = player;
    _history.add(idx);
    version++;
    if (caroMakesWin(cells, idx)) {
      _winLine = caroWinningLine(cells, idx);
      _finish(player == kCaroPlayer ? CaroResult.playerWin : CaroResult.aiWin);
    } else if (_history.length >= kCaroCells) {
      _finish(CaroResult.draw);
    } else {
      notifyListeners();
    }
  }

  void _finish(CaroResult r) {
    _result = r;
    _phase = CaroPhase.finished;
    clock.pause();
    if (challenge == null) clearSave();
    notifyListeners();
  }

  /// Seed cho lượt máy: ngẫu nhiên khi chơi thường; xác định (theo seed thách
  /// đấu và số nước đã đi) khi thách đấu → cùng thế cờ thì máy chọn như nhau.
  int _aiSeed() {
    final ch = challenge;
    if (ch == null) return Random().nextInt(1 << 30);
    return Random(ch.seed * 1000003 + _history.length).nextInt(1 << 30);
  }

  @visibleForTesting
  int debugAiSeed() => _aiSeed();

  Future<void> _aiTurn() async {
    final gen = ++_gen;
    _thinking = true;
    _thinkingVisible = false;
    notifyListeners();

    final timer = Timer(indicatorDelay, () {
      if (gen == _gen && _thinking && !_disposed) {
        _thinkingVisible = true;
        notifyListeners();
      }
    });
    final sw = Stopwatch()..start();
    final request = CaroAiRequest(
      cells: List<int>.of(cells),
      difficulty: difficulty,
      seed: _aiSeed(),
    );
    int move;
    try {
      move = await _runner(request);
    } catch (_) {
      move = chooseCaroMove(CaroAiRequest(cells: request.cells, difficulty: Difficulty.medium));
    }
    timer.cancel();
    final remaining = minThinkTime - sw.elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    if (_disposed || gen != _gen) return;

    _thinking = false;
    _thinkingVisible = false;
    if (move < 0 || move >= kCaroCells || cells[move] != kCaroEmpty) {
      move = cells.indexOf(kCaroEmpty); // phòng thủ: không bao giờ đánh vào ô đã có quân
    }
    if (move < 0) {
      _finish(CaroResult.draw);
      return;
    }
    _place(move, kCaroAi);
    if (_phase == CaroPhase.playing) save();
  }

  /// Đi lại: xoá nước gần nhất của người chơi cùng nước đáp trả của máy. Tính 1 lần đi lại.
  bool undo() {
    if (!canUndo) return false;
    _gen++;
    final lastIsAi = _playerOf(_history.length - 1) == kCaroAi;
    if (lastIsAi) _removeLast();
    _removeLast();
    _undos++;
    version++;
    notifyListeners();
    save();
    // Nếu máy đi trước và vừa bị xoá hết nước người chơi thì máy không cần đi lại:
    // lịch sử còn lại luôn kết thúc bằng nước của máy → đến lượt người chơi.
    return true;
  }

  void _removeLast() {
    final idx = _history.removeLast();
    cells[idx] = kCaroEmpty;
  }

  void pause() {
    if (_phase == CaroPhase.playing) clock.pause();
  }

  void resume() {
    if (_phase == CaroPhase.playing) clock.start();
  }

  /// Bản ghi để nộp điểm. Chỉ hợp lệ khi ván đã kết thúc.
  GameRecord toRecord() {
    final outcome = switch (_result) {
      CaroResult.playerWin => GameOutcome.win,
      CaroResult.aiWin => GameOutcome.lose,
      _ => GameOutcome.draw,
    };
    return GameRecord(
      gameCode: 'CARO',
      difficulty: difficulty,
      timeSeconds: clock.seconds,
      mistakes: _undos,
      moves: playerMoves,
      outcome: outcome,
      challengeId: challenge?.challengeId,
    );
  }

  /// Bản ghi bỏ cuộc giữa ván thách đấu (tính là thua).
  GameRecord toAbandonRecord() => GameRecord(
        gameCode: 'CARO',
        difficulty: difficulty,
        timeSeconds: clock.seconds,
        mistakes: _undos,
        moves: playerMoves,
        outcome: GameOutcome.lose,
        challengeId: challenge?.challengeId,
      );

  // -------------------------------------------------------------------------
  // Lưu / khôi phục
  // -------------------------------------------------------------------------

  Future<void> save() async {
    if (challenge != null) return;
    if (_phase != CaroPhase.playing || _history.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _saveKey,
        jsonEncode({
          'difficulty': difficulty.value,
          'playerFirst': playerFirst,
          'history': _history,
          'undos': _undos,
          'seconds': clock.seconds,
        }),
      );
    } catch (_) {}
  }

  Future<void> clearSave() async {
    if (challenge != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_saveKey);
    } catch (_) {}
  }

  static Future<bool> hasSavedGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_saveKey) != null;
    } catch (_) {
      return false;
    }
  }

  /// Khôi phục ván đang dở. Trả về false nếu dữ liệu hỏng.
  Future<bool> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_saveKey);
      if (raw == null) return false;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final hist = (m['history'] as List).cast<int>();
      final first = m['playerFirst'] as bool;
      final seen = <int>{};
      for (final i in hist) {
        if (i < 0 || i >= kCaroCells || !seen.add(i)) return false;
      }
      _gen++;
      difficulty = Difficulty.fromValue(m['difficulty'] as int?);
      playerFirst = first;
      cells.fillRange(0, kCaroCells, kCaroEmpty);
      _history
        ..clear()
        ..addAll(hist);
      for (var i = 0; i < hist.length; i++) {
        cells[hist[i]] = _playerOf(i);
      }
      for (final i in hist) {
        if (caroMakesWin(cells, i)) {
          await clearSave();
          return false;
        }
      }
      _undos = (m['undos'] as int?) ?? 0;
      _result = null;
      _winLine = null;
      _thinking = false;
      version++;
      clock.reset(startAt: Duration(seconds: (m['seconds'] as int?) ?? 0));
      _phase = CaroPhase.playing;
      clock.start();
      notifyListeners();
      if (_playerOf(_history.length) == kCaroAi) _aiTurn();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _gen++;
    clock.dispose();
    super.dispose();
  }
}
