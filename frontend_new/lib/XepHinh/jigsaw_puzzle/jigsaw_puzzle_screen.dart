import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/models/difficulty.dart';
import '../shared/services/timer_service.dart';
import '../shared/services/score_service.dart';
import '../shared/widgets/game_header_widget.dart';
import '../../core/models/difficulty.dart' as core;
import '../../core/services/score_reporter.dart';
import 'jigsaw_puzzle_logic.dart';
import 'models/jigsaw_picture.dart';
import 'widgets/jigsaw_piece_image.dart';

class JigsawPuzzleScreen extends StatefulWidget {
  final GameDifficulty difficulty;

  /// Hình để ghép (mặc định: tranh có sẵn đầu tiên).
  final JigsawPicture? picture;

  const JigsawPuzzleScreen({
    super.key,
    this.difficulty = GameDifficulty.easy,
    this.picture,
  });

  @override
  State<JigsawPuzzleScreen> createState() => _JigsawPuzzleScreenState();
}

class _JigsawPuzzleScreenState extends State<JigsawPuzzleScreen> {
  late JigsawPuzzleLogic _logic;
  late TimerService _timerService;
  late final JigsawPicture _picture = widget.picture ?? JigsawPicture.builtIns.first;

  /// Hiện số thứ tự đúng của từng mảnh (gợi ý).
  bool _showNumbers = false;

  @override
  void initState() {
    super.initState();
    _logic = JigsawPuzzleLogic(difficulty: widget.difficulty);
    _timerService = TimerService();
    _logic.addListener(_onLogicUpdate);
    _timerService.startTimer();
  }

  void _onLogicUpdate() {
    if (_logic.isCompleted) {
      _timerService.pauseTimer();
      _showWinDialog();
    }
  }

  @override
  void dispose() {
    _logic.removeListener(_onLogicUpdate);
    _logic.dispose();
    _timerService.dispose();
    super.dispose();
  }

  void _resetGame() {
    _logic.initBoard();
    _timerService.resetTimer();
    _timerService.startTimer();
  }

  void _togglePause() {
    if (_timerService.isRunning) {
      _timerService.pauseTimer();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Đã tạm dừng'),
          content: const Text('Nhấn tiếp tục để chơi tiếp.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _timerService.startTimer();
              },
              child: const Text('Tiếp tục'),
            ),
          ],
        ),
      );
    }
  }

  void _showOriginal() {
    showDialog(
      context: context,
      builder: (ctx) {
        // Ảnh vuông vừa màn hình cả khi điện thoại xoay ngang.
        final screen = MediaQuery.sizeOf(ctx);
        final side = [screen.width * 0.85, screen.height * 0.65, 480.0]
            .reduce((a, b) => a < b ? a : b);
        return Dialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: side,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: side, height: side, child: _picture.build()),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Expanded(child: Text('Ảnh gốc: ${_picture.name}')),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Đóng'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  core.Difficulty _coreDifficulty() {
    switch (widget.difficulty) {
      case GameDifficulty.easy:
        return core.Difficulty.easy;
      case GameDifficulty.medium:
        return core.Difficulty.medium;
      case GameDifficulty.hard:
        return core.Difficulty.hard;
    }
  }

  void _showWinDialog() {
    final int finalScore = ScoreService.calculateScore(
      moves: _logic.moves,
      timeInSeconds: _timerService.secondsElapsed,
      difficulty: widget.difficulty,
    );

    // Nộp điểm lên server
    final reporter = context.read<ScoreReporter>();
    final record = GameRecord(
      gameCode: 'PUZZLE',
      difficulty: _coreDifficulty(),
      timeSeconds: _timerService.secondsElapsed,
      mistakes: 0,
      moves: _logic.moves,
      outcome: GameOutcome.completed,
    );
    reporter.submit(record).then((outcome) {
      if (!mounted) return;
      if (outcome.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(outcome.message!),
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (outcome.isPersonalBest) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🏆 Kỷ lục cá nhân mới!'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('🧩 Hoàn thành Mảnh ghép! 🧩'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chúc mừng bạn đã ghép hoàn chỉnh các mảnh ghép!'),
            const SizedBox(height: 12),
            Text('Thời gian: ${_timerService.formattedTime}'),
            Text('Số bước: ${_logic.moves}'),
            Text(
              'Điểm số: $finalScore',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetGame();
            },
            child: const Text('Chơi lại'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Jigsaw Puzzle - ${widget.difficulty.displayName}'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _showNumbers ? 'Ẩn số gợi ý' : 'Hiện số gợi ý',
            icon: Icon(_showNumbers ? Icons.pin_rounded : Icons.pin_outlined),
            onPressed: () => setState(() => _showNumbers = !_showNumbers),
          ),
          IconButton(
            tooltip: 'Xem ảnh gốc',
            icon: const Icon(Icons.image_outlined),
            onPressed: _showOriginal,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_logic, _timerService]),
        builder: (context, _) {
          return Column(
            children: [
              GameHeaderWidget(
                title: 'Ghép Hình Jigsaw',
                formattedTime: _timerService.formattedTime,
                moves: _logic.moves,
                onReset: _resetGame,
                onPause: _togglePause,
              ),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300, width: 1),
                      ),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _logic.gridSize,
                          // Ghép xong: các mảnh khít lại thành tranh liền
                          crossAxisSpacing: _logic.isCompleted ? 0 : 1.5,
                          mainAxisSpacing: _logic.isCompleted ? 0 : 1.5,
                        ),
                        itemCount: _logic.pieces.length,
                        itemBuilder: (context, index) {
                          final piece = _logic.pieces[index];
                          final isSelected = _logic.selectedPieceIndex == index;
                          final done = _logic.isCompleted;

                          return GestureDetector(
                            onTap: () => _logic.selectOrSwapPiece(index),
                            child: Container(
                              foregroundDecoration: done
                                  ? null
                                  : BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.red
                                            : (piece.isCorrect
                                                ? Colors.lightGreenAccent.shade400
                                                : Colors.white38),
                                        width: isSelected ? 2 : (piece.isCorrect ? 1.5 : 0.5),
                                      ),
                                    ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(done ? 0 : 4),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    JigsawPieceImage(
                                      picture: _picture,
                                      row: piece.correctRow,
                                      col: piece.correctCol,
                                      gridSize: _logic.gridSize,
                                    ),
                                    if (isSelected)
                                      const ColoredBox(color: Color(0x33FF5252)),
                                    if (_showNumbers && !done)
                                      Positioned(
                                        left: 4,
                                        top: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${piece.id}',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
