import 'dart:async';
import 'package:flutter/material.dart';
import 'models/material.dart';
import 'engine/physics_engine.dart';
import 'engine/reaction_engine.dart';
import 'services/phaseshift_score_service.dart';
import 'widgets/game_board.dart';
import 'widgets/control_panel.dart';
import 'widgets/phaseshift_rules.dart';
import '../shared/models/difficulty.dart';
import '../shared/services/timer_service.dart';

class PhaseShiftScreen extends StatefulWidget {
  final GameDifficulty difficulty;
  final bool enableTimeLimit;
  final int timeLimitSeconds;

  const PhaseShiftScreen({
    super.key,
    this.difficulty = GameDifficulty.easy,
    this.enableTimeLimit = false,
    this.timeLimitSeconds = 180,
  });

  @override
  State<PhaseShiftScreen> createState() => _PhaseShiftScreenState();
}

class _PhaseShiftScreenState extends State<PhaseShiftScreen> {
  late int _rows;
  late int _cols;
  late List<List<ElementBlock?>> _board;

  ElementBlock? _activeBlock;
  Position? _activePosition;
  late ElementBlock _nextBlock;

  /// Cột của khối vừa đặt xuống — khối kế tiếp xuất hiện ở cột này.
  int? _lastDropCol;

  int _score = 0;
  int _highScore = 0;
  int _comboCount = 0;
  String? _lastReactionLog;

  bool _isGameOver = false;
  bool _isPaused = false;

  Timer? _gameLoopTimer;
  late TimerService _timerService;

  @override
  void initState() {
    super.initState();
    _rows = PhysicsEngine.getRows(widget.difficulty);
    _cols = PhysicsEngine.getCols(widget.difficulty);
    _timerService = TimerService();

    _loadHighScore();
    _initBoard();
    _startTimers();
  }

  Future<void> _loadHighScore() async {
    final high = await PhaseShiftScoreService.getHighScore(widget.difficulty);
    if (mounted) {
      setState(() {
        _highScore = high;
      });
    }
  }

  void _initBoard() {
    _board = List.generate(
      _rows,
      (_) => List.generate(_cols, (_) => null),
    );
    _score = 0;
    _comboCount = 0;
    _isGameOver = false;
    _isPaused = false;
    _lastReactionLog = null;
    _lastDropCol = null;

    _nextBlock = PhysicsEngine.generateRandomBlock(widget.difficulty);
    _spawnNewBlock();
  }

  void _spawnNewBlock() {
    _activeBlock = _nextBlock;
    _nextBlock = PhysicsEngine.generateRandomBlock(widget.difficulty);

    // Khối mới ra ở cột vừa đặt khối trước (đỡ phải dời lại), nếu cột đó còn
    // ít nhất 2 ô trống phía trên (tránh vừa ra đã chạm hàng trên cùng và thua oan);
    // không thì ra ở cột giữa như cũ — cột giữa cũng bị chiếm thì thua.
    final center = _cols ~/ 2;
    bool free(int row, int col) =>
        PhysicsEngine.isValidMove(board: _board, position: Position(row, col), rows: _rows, cols: _cols);
    final last = _lastDropCol;
    if (last != null && last != center && free(0, last) && free(1, last)) {
      _activePosition = Position(0, last);
      return;
    }
    _activePosition = Position(0, center);
    if (!free(0, center)) _triggerGameOver();
  }

  void _startTimers() {
    _gameLoopTimer?.cancel();
    final interval = PhysicsEngine.getDropInterval(widget.difficulty);
    _gameLoopTimer = Timer.periodic(interval, (_) => _onGameTick());
    _timerService.startTimer();
  }

  void _stopTimers() {
    _gameLoopTimer?.cancel();
    _timerService.pauseTimer();
  }

  void _onGameTick() {
    if (_isGameOver || _isPaused) return;

    if (_activePosition != null && _activeBlock != null) {
      final nextPos = _activePosition!.copyWith(row: _activePosition!.row + 1);

      if (PhysicsEngine.isValidMove(
        board: _board,
        position: nextPos,
        rows: _rows,
        cols: _cols,
      )) {
        setState(() {
          _activePosition = nextPos;
        });
      } else {
        _lockActiveBlock();
      }
    }

    if (widget.enableTimeLimit) {
      final remaining = widget.timeLimitSeconds - _timerService.secondsElapsed;
      if (remaining <= 0 && !_isGameOver) {
        _triggerGameOver(reason: 'Hết giờ!');
      }
    }
  }

  void _lockActiveBlock() {
    if (_activeBlock == null || _activePosition == null) return;

    _board[_activePosition!.row][_activePosition!.col] = _activeBlock;

    if (_activePosition!.row == 0) {
      _triggerGameOver();
      return;
    }

    _lastDropCol = _activePosition!.col;
    _activeBlock = null;
    _activePosition = null;

    // Nước vừa đặt lên mép một khối thì chảy xuống chỗ thấp hơn trước khi xét phản ứng.
    ReactionEngine.applyPhysicsTick(_board, _rows, _cols);

    final result = ReactionEngine.processReactions(
      grid: _board,
      rows: _rows,
      cols: _cols,
      initialCombo: _comboCount,
    );

    setState(() {
      _board = result.board;
      _score += result.scoreEarned;
      _comboCount = result.comboCount;
      if (result.reactionLogs.isNotEmpty) {
        _lastReactionLog = result.reactionLogs.last;
      }
    });

    _updateHighScore();
    _spawnNewBlock();
  }

  void _updateHighScore() {
    if (_score > _highScore) {
      setState(() {
        _highScore = _score;
      });
      PhaseShiftScoreService.saveHighScore(widget.difficulty, _score);
    }
  }

  void _moveLeft() {
    if (_isGameOver || _isPaused || _activePosition == null) return;
    final nextPos = _activePosition!.copyWith(col: _activePosition!.col - 1);
    if (PhysicsEngine.isValidMove(
      board: _board,
      position: nextPos,
      rows: _rows,
      cols: _cols,
    )) {
      setState(() {
        _activePosition = nextPos;
      });
    }
  }

  void _moveRight() {
    if (_isGameOver || _isPaused || _activePosition == null) return;
    final nextPos = _activePosition!.copyWith(col: _activePosition!.col + 1);
    if (PhysicsEngine.isValidMove(
      board: _board,
      position: nextPos,
      rows: _rows,
      cols: _cols,
    )) {
      setState(() {
        _activePosition = nextPos;
      });
    }
  }

  void _softDrop() {
    if (_isGameOver || _isPaused || _activePosition == null) return;
    final nextPos = _activePosition!.copyWith(row: _activePosition!.row + 1);
    if (PhysicsEngine.isValidMove(
      board: _board,
      position: nextPos,
      rows: _rows,
      cols: _cols,
    )) {
      setState(() {
        _activePosition = nextPos;
        _score += 1;
      });
      _updateHighScore();
    } else {
      _lockActiveBlock();
    }
  }

  void _hardDrop() {
    if (_isGameOver || _isPaused || _activePosition == null) return;
    final dropPos = PhysicsEngine.calculateHardDropPosition(
      board: _board,
      currentPos: _activePosition!,
      rows: _rows,
      cols: _cols,
    );

    final droppedDistance = dropPos.row - _activePosition!.row;
    setState(() {
      _activePosition = dropPos;
      _score += droppedDistance * 2;
    });
    _updateHighScore();
    _lockActiveBlock();
  }

  void _togglePause() {
    if (_isGameOver) return;
    setState(() {
      _isPaused = !_isPaused;
    });

    if (_isPaused) {
      _stopTimers();
      _showPauseDialog();
    } else {
      _startTimers();
    }
  }

  /// Xem luật: tạm dừng trong lúc đọc, đóng bảng thì chơi tiếp
  /// (nếu trước đó đã tự tạm dừng thì vẫn giữ trạng thái dừng).
  Future<void> _showRules() async {
    final wasRunning = !_isGameOver && !_isPaused;
    if (wasRunning) {
      setState(() => _isPaused = true);
      _stopTimers();
    }
    await showPhaseShiftRules(context);
    if (wasRunning && mounted && !_isGameOver) {
      setState(() => _isPaused = false);
      _startTimers();
    }
  }

  void _showPauseDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252A34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.pause_circle_filled_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('Tạm Dừng Game', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Game đang tạm dừng. Đồng hồ thời gian đã ngưng.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              'Điểm hiện tại: $_score',
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.home_rounded, color: Colors.redAccent),
            label: const Text('Menu Chính', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetGame();
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.cyanAccent),
            label: const Text('Chơi Lại', style: TextStyle(color: Colors.cyanAccent)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _isPaused = false;
              });
              _startTimers();
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Tiếp Tục'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _triggerGameOver({String reason = 'Các khối đã đầy bảng!'}) {
    _stopTimers();
    setState(() {
      _isGameOver = true;
    });

    final isNewRecord = _score >= _highScore && _score > 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252A34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isNewRecord ? Icons.stars_rounded : Icons.sentiment_very_dissatisfied_rounded,
              color: isNewRecord ? Colors.amber : Colors.deepOrange,
              size: 32,
            ),
            const SizedBox(width: 8),
            Text(
              isNewRecord ? 'Kỷ Lục Mới! 🎉' : 'Kết Thúc Game',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reason, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Text('Thời gian chơi: ${_timerService.formattedTime}',
                style: const TextStyle(color: Colors.white)),
            Text('Điểm số: $_score',
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                )),
            Text('Kỷ lục hiện tại: $_highScore',
                style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Về Menu', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetGame();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text('Chơi Lại', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _resetGame() {
    _stopTimers();
    _timerService.resetTimer();
    setState(() {
      _initBoard();
    });
    _startTimers();
  }

  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    _timerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remainingTimeStr = widget.enableTimeLimit
        ? _getRemainingTimeStr()
        : _timerService.formattedTime;

    return Scaffold(
      backgroundColor: const Color(0xFF14171D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222A),
        foregroundColor: Colors.white,
        title: Text('PhaseShift - ${widget.difficulty.displayName}'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: _showRules,
            tooltip: 'Luật chơi',
          ),
          IconButton(
            icon: const Icon(Icons.pause_circle_outline_rounded),
            onPressed: _togglePause,
            tooltip: 'Tạm dừng',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                color: const Color(0xFF1E222A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Điểm: $_score',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '🏆 Kỷ lục: $_highScore',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '⏱ $remainingTimeStr',
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_comboCount > 1)
                            Text(
                              'Combo x$_comboCount 🔥',
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      Column(
                        children: [
                          const Text(
                            'Khối tiếp',
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _nextBlock.color.withAlpha(51),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _nextBlock.color),
                            ),
                            child: Row(
                              children: [
                                Icon(_nextBlock.icon, color: _nextBlock.color, size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  _nextBlock.symbol,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_lastReactionLog != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withAlpha(77),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigoAccent),
                  ),
                  child: Text(
                    _lastReactionLog!,
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: PhaseShiftGameBoard(
                    board: _board,
                    activeBlock: _activeBlock,
                    activePosition: _activePosition,
                    rows: _rows,
                    cols: _cols,
                  ),
                ),
              ),
            ),

            PhaseShiftControlPanel(
              onMoveLeft: _moveLeft,
              onMoveRight: _moveRight,
              onSoftDrop: _softDrop,
              onHardDrop: _hardDrop,
            ),
          ],
        ),
      ),
    );
  }

  String _getRemainingTimeStr() {
    final remaining = widget.timeLimitSeconds - _timerService.secondsElapsed;
    final display = remaining > 0 ? remaining : 0;
    final mins = (display ~/ 60).toString().padLeft(2, '0');
    final secs = (display % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}
