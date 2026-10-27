import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_new/caro/models/caro_mode.dart';
import 'package:frontend_new/caro/models/challenge_context.dart';
import 'package:frontend_new/caro/models/difficulty.dart';
import 'package:frontend_new/core/network/api_client.dart';
import 'package:frontend_new/core/network/models.dart';
import 'package:frontend_new/caro/services/score_reporter.dart';
import 'package:frontend_new/caro/widgets/game_timer.dart';
import 'logic/caro_ai.dart';
import 'logic/caro_board.dart';

enum CaroPhase { setup, playing, finished }

enum CaroResult { playerWin, aiWin, draw }

/// Hàm tính nước đi cho máy (mặc định chạy trên isolate; test có thể thay thế).
typedef CaroAiRunner = Future<int> Function(CaroAiRequest request);

/// Trạng thái một ván Caro (hỗ trợ PvE, Local PvP 2 người, và Cờ sinh tồn).
class CaroController extends ChangeNotifier {
  CaroController({
    CaroAiRunner? aiRunner,
    this.minThinkTime = const Duration(milliseconds: 350),
    this.indicatorDelay = const Duration(milliseconds: 300),
    this.challenge,
    this.userId,
  }) : _runner = aiRunner ?? runCaroAiInIsolate;

  /// ID tài khoản đang chơi (null nếu là khách/chưa đăng nhập).
  int? userId;

  void switchUser(int? newUserId) {
    if (userId != newUserId) {
      userId = newUserId;
    }
  }

  /// Giới hạn số quân tối đa trên bàn cho mỗi bên trong chế độ Cờ sinh tồn.
  static const int kFadingStoneLimit = 6;

  /// Khác null = ván thách đấu: người chơi luôn đi trước, máy dùng seed xác
  /// định từ `challenge.seed` + thế cờ, không lưu/khôi phục ván.
  final ChallengeContext? challenge;

  static const _legacySaveKey = 'caro_save';

  static String saveKeyFor(int? userId) =>
      userId != null ? 'caro_save_user_$userId' : 'caro_save_guest';

  String get currentSaveKey => saveKeyFor(userId);

  final CaroAiRunner _runner;

  /// Máy luôn "suy nghĩ" ít nhất chừng này để nước đi tự nhiên.
  final Duration minThinkTime;

  /// Chỉ hiện "Máy đang nghĩ…" nếu việc tính toán kéo dài hơn mức này.
  final Duration indicatorDelay;

  CaroPhase _phase = CaroPhase.setup;
  CaroPhase get phase => _phase;

  CaroGameMode gameMode = CaroGameMode.pve;
  Difficulty difficulty = Difficulty.medium;
  bool playerFirst = true;

  final Uint8List cells = Uint8List(kCaroCells);
  final GameClock clock = GameClock();

  /// Tăng mỗi khi bàn cờ đổi — dùng cho shouldRepaint.
  int version = 0;

  /// Danh sách ô đã đánh theo thứ tự. Người đi đầu luôn ở chỉ số chẵn.
  final List<int> _history = [];
  List<int> get history => List.unmodifiable(_history);

  /// Danh sách các ô cờ hiện đang sống của từng bên (dành cho chế độ Fading).
  final List<int> _playerXStones = [];
  final List<int> _playerOStones = [];
  List<int> get playerXStones => List.unmodifiable(_playerXStones);
  List<int> get playerOStones => List.unmodifiable(_playerOStones);

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

  /// Nước gợi ý hiện tại (null nếu không có).
  int? _hintCell;
  int? get hintCell => _hintCell;

  /// Số lần gợi ý còn lại trong ván (mặc định 3 lần).
  int _hintsRemaining = 3;
  int get hintsRemaining => _hintsRemaining;

  int? get lastMove => _history.isEmpty ? null : _history.last;

  int _playerOf(int historyIndex) =>
      ((historyIndex % 2 == 0) == playerFirst) ? kCaroPlayer : kCaroAi;

  /// Người chơi đang đến lượt (kCaroPlayer hoặc kCaroAi).
  int get currentTurnPlayer => _playerOf(_history.length);

  bool get isPvP => gameMode == CaroGameMode.pvpLocal;
  bool get isFading => gameMode == CaroGameMode.fading;

  int get playerMoves {
    var n = 0;
    for (var i = 0; i < _history.length; i++) {
      if (_playerOf(i) == kCaroPlayer) n++;
    }
    return n;
  }

  int get opponentMoves {
    var n = 0;
    for (var i = 0; i < _history.length; i++) {
      if (_playerOf(i) == kCaroAi) n++;
    }
    return n;
  }

  /// Cảnh báo quân sắp biến mất ở nước đi tiếp theo (trong chế độ Fading).
  int? get fadingWarningX =>
      (isFading && _playerXStones.length >= kFadingStoneLimit) ? _playerXStones.first : null;

  int? get fadingWarningO =>
      (isFading && _playerOStones.length >= kFadingStoneLimit) ? _playerOStones.first : null;

  bool get isPlaying => _phase == CaroPhase.playing;

  bool get isPlayerTurn =>
      isPlaying && (isPvP || _playerOf(_history.length) == kCaroPlayer);

  bool get canPlayerMove =>
      isPlaying && !_thinking && (isPvP || _playerOf(_history.length) == kCaroPlayer);

  bool get canUndo {
    if (!isPlaying || _thinking) return false;
    if (isPvP) return _history.isNotEmpty;
    return playerMoves > 0;
  }

  bool isEmptyCell(int idx) => cells[idx] == kCaroEmpty;

  // -------------------------------------------------------------------------
  // Luồng ván chơi
  // -------------------------------------------------------------------------

  void newGame({
    required Difficulty difficulty,
    required bool playerFirst,
    CaroGameMode mode = CaroGameMode.pve,
  }) {
    _gen++;
    final ch = challenge;
    gameMode = ch != null ? CaroGameMode.pve : mode;
    this.difficulty = ch?.difficulty ?? difficulty;
    this.playerFirst = ch != null ? true : playerFirst;
    cells.fillRange(0, kCaroCells, kCaroEmpty);
    _history.clear();
    _playerXStones.clear();
    _playerOStones.clear();
    _undos = 0;
    _result = null;
    _winLine = null;
    _thinking = false;
    _thinkingVisible = false;
    _hintCell = null;
    _hintsRemaining = 3;
    version++;
    clock.reset();
    _phase = CaroPhase.playing;
    clock.start();
    notifyListeners();
    if (!this.playerFirst && !isPvP) _aiTurn();
  }

  /// Về màn chọn thiết lập (xoá ván đang dở).
  void toSetup() {
    _gen++;
    _thinking = false;
    _thinkingVisible = false;
    _hintCell = null;
    clock.pause();
    _phase = CaroPhase.setup;
    if (challenge == null) clearSave();
    notifyListeners();
  }

  /// Người chơi đặt quân. Trả về true nếu nước đi hợp lệ.
  bool placePlayer(int idx) {
    if (!canPlayerMove || idx < 0 || idx >= kCaroCells || cells[idx] != kCaroEmpty) return false;
    _hintCell = null;
    final movingPlayer = isPvP ? currentTurnPlayer : kCaroPlayer;
    _place(idx, movingPlayer);
    if (_phase == CaroPhase.playing) {
      save();
      if (!isPvP) _aiTurn();
    }
    return true;
  }

  void _place(int idx, int player) {
    // Nếu là chế độ cờ sinh tồn: nếu bên đó đã đạt tối đa 6 quân thì quân cũ nhất biến mất
    if (isFading) {
      final stones = player == kCaroPlayer ? _playerXStones : _playerOStones;
      if (stones.length >= kFadingStoneLimit) {
        final oldest = stones.removeAt(0);
        cells[oldest] = kCaroEmpty;
      }
      stones.add(idx);
    }

    cells[idx] = player;
    _history.add(idx);
    version++;

    if (caroMakesWin(cells, idx)) {
      _winLine = caroWinningLine(cells, idx);
      _finish(player == kCaroPlayer ? CaroResult.playerWin : CaroResult.aiWin);
    } else if (_history.length >= kCaroCells && !isFading) {
      _finish(CaroResult.draw);
    } else {
      notifyListeners();
    }
  }

  void _finish(CaroResult r) {
    _result = r;
    _phase = CaroPhase.finished;
    _hintCell = null;
    clock.pause();
    if (challenge == null) clearSave();
    notifyListeners();
  }

  /// Yêu cầu gợi ý nước đi tốt nhất từ AI.
  Future<int?> requestHint() async {
    if (!canPlayerMove || _hintsRemaining <= 0 || _phase != CaroPhase.playing) return null;
    _gen++;
    final currentGen = _gen;
    final targetPlayer = currentTurnPlayer;
    final request = CaroAiRequest(
      cells: List<int>.of(cells),
      difficulty: Difficulty.hard,
      aiPlayer: targetPlayer,
      budgetMs: 500,
    );
    int move;
    try {
      move = await _runner(request);
    } catch (_) {
      move = chooseCaroMove(request);
    }
    if (_disposed || currentGen != _gen) return null;
    if (move >= 0 && move < kCaroCells && cells[move] == kCaroEmpty) {
      _hintCell = move;
      _hintsRemaining--;
      notifyListeners();
      return move;
    }
    return null;
  }

  void clearHint() {
    if (_hintCell != null) {
      _hintCell = null;
      notifyListeners();
    }
  }

  /// Seed cho lượt máy.
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
      move = cells.indexOf(kCaroEmpty);
    }
    if (move < 0) {
      _finish(CaroResult.draw);
      return;
    }
    _place(move, kCaroAi);
    if (_phase == CaroPhase.playing) save();
  }

  /// Đi lại nước cờ.
  bool undo() {
    if (!canUndo) return false;
    _gen++;
    _hintCell = null;

    if (isPvP) {
      // Trong PvP cục bộ, chỉ huỷ nước đi vừa rồi
      _history.removeLast();
    } else {
      // Trong PvE, huỷ nước của máy và nước của người chơi
      final lastIsAi = _playerOf(_history.length - 1) == kCaroAi;
      if (lastIsAi) _history.removeLast();
      if (_history.isNotEmpty) _history.removeLast();
    }

    _undos++;
    _rebuildBoardFromHistory();
    version++;
    notifyListeners();
    save();
    return true;
  }

  /// Tái thiết lập bàn cờ và danh sách quân cờ Fading dựa trên lịch sử nước đi.
  void _rebuildBoardFromHistory() {
    cells.fillRange(0, kCaroCells, kCaroEmpty);
    _playerXStones.clear();
    _playerOStones.clear();

    for (var i = 0; i < _history.length; i++) {
      final idx = _history[i];
      final p = _playerOf(i);
      if (isFading) {
        final stones = p == kCaroPlayer ? _playerXStones : _playerOStones;
        if (stones.length >= kFadingStoneLimit) {
          final oldest = stones.removeAt(0);
          cells[oldest] = kCaroEmpty;
        }
        stones.add(idx);
      }
      cells[idx] = p;
    }
  }

  void pause() {
    if (_phase == CaroPhase.playing) clock.pause();
  }

  void resume() {
    if (_phase == CaroPhase.playing) clock.start();
  }

  /// Bản ghi để nộp điểm (chỉ áp dụng khi đánh với máy trong PvE).
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
      hints: 3 - _hintsRemaining,
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
  // Lưu / khôi phục theo tài khoản
  // -------------------------------------------------------------------------

  Future<void> save({int? customUserId}) async {
    if (challenge != null) return;
    if (_phase != CaroPhase.playing || _history.isEmpty) return;
    try {
      final targetUser = customUserId ?? userId;
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'difficulty': difficulty.value,
        'playerFirst': playerFirst,
        'gameMode': gameMode.name,
        'hintsRemaining': _hintsRemaining,
        'history': _history,
        'undos': _undos,
        'seconds': clock.seconds,
      });
      await prefs.setString(saveKeyFor(targetUser), payload);
      if (targetUser == null) {
        await prefs.setString(_legacySaveKey, payload);
      }
    } catch (_) {}
  }

  Future<void> clearSave({int? customUserId}) async {
    if (challenge != null) return;
    try {
      final targetUser = customUserId ?? userId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(saveKeyFor(targetUser));
      if (targetUser == null) {
        await prefs.remove(_legacySaveKey);
      }
    } catch (_) {}
  }

  static Future<bool> hasSavedGame({int? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = saveKeyFor(userId);
      if (prefs.getString(key) != null) return true;
      if (userId == null && prefs.getString(_legacySaveKey) != null) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Khôi phục ván đang dở theo tài khoản. Trả về false nếu dữ liệu hỏng.
  Future<bool> restore({int? customUserId}) async {
    try {
      final targetUser = customUserId ?? userId;
      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString(saveKeyFor(targetUser));
      if (raw == null && targetUser == null) {
        raw = prefs.getString(_legacySaveKey);
      }
      if (raw == null) return false;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final hist = (m['history'] as List).cast<int>();
      final first = m['playerFirst'] as bool;
      final savedMode = CaroGameMode.fromName(m['gameMode'] as String?);

      if (savedMode != CaroGameMode.fading) {
        final seen = <int>{};
        for (final i in hist) {
          if (i < 0 || i >= kCaroCells || !seen.add(i)) return false;
        }
      }

      _gen++;
      gameMode = savedMode;
      difficulty = Difficulty.fromValue(m['difficulty'] as int?);
      playerFirst = first;
      _hintsRemaining = (m['hintsRemaining'] as int?) ?? 3;
      _hintCell = null;
      _history
        ..clear()
        ..addAll(hist);

      _rebuildBoardFromHistory();

      // Kiểm tra xem ván đã thắng chưa
      for (final i in _history) {
        if (caroMakesWin(cells, i)) {
          await clearSave(customUserId: targetUser);
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
      if (!isPvP && _playerOf(_history.length) == kCaroAi) _aiTurn();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Lưu trạng thái ván cờ hiện tại lên Database
  Future<void> saveGameToServer(ApiClient api) async {
    if (challenge != null || _phase != CaroPhase.playing || _history.isEmpty) return;
    try {
      await api.saveCaroGame(
        gameMode: gameMode.name,
        difficulty: difficulty.value,
        playerFirst: playerFirst,
        history: _history,
        undos: _undos,
        elapsedSeconds: clock.seconds,
        hintsRemaining: _hintsRemaining,
      );
    } catch (_) {}
  }

  /// Xóa ván cờ dở dang trên Database khi hoàn thành hoặc bắt đầu lại
  Future<void> deleteGameFromServer(ApiClient api) async {
    if (challenge != null) return;
    try {
      await api.deleteCaroSavedGame(mode: gameMode.name);
    } catch (_) {}
  }

  /// Khôi phục ván cờ từ CaroSavedGame tải từ Server
  bool restoreFromSavedGame(CaroSavedGame saved) {
    try {
      final hist = saved.history;
      final savedMode = CaroGameMode.fromName(saved.gameMode);

      if (savedMode != CaroGameMode.fading) {
        final seen = <int>{};
        for (final i in hist) {
          if (i < 0 || i >= kCaroCells || !seen.add(i)) return false;
        }
      }

      _gen++;
      gameMode = savedMode;
      difficulty = Difficulty.fromValue(saved.difficulty);
      playerFirst = saved.playerFirst;
      _hintsRemaining = saved.hintsRemaining;
      _hintCell = null;
      _history
        ..clear()
        ..addAll(hist);

      _rebuildBoardFromHistory();

      for (final i in _history) {
        if (caroMakesWin(cells, i)) {
          clearSave();
          return false;
        }
      }
      _undos = saved.undos;
      _result = null;
      _winLine = null;
      _thinking = false;
      version++;
      clock.reset(startAt: Duration(seconds: saved.elapsedSeconds));
      _phase = CaroPhase.playing;
      clock.start();
      notifyListeners();
      if (!isPvP && _playerOf(_history.length) == kCaroAi) _aiTurn();
      save();
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
