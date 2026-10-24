import 'package:flutter/material.dart';
import '../shared/models/difficulty.dart';
import '../shared/services/timer_service.dart';
import '../shared/services/score_service.dart';
import '../shared/widgets/game_header_widget.dart';
import 'jigsaw_puzzle_logic.dart';

class JigsawPuzzleScreen extends StatefulWidget {
  final GameDifficulty difficulty;

  const JigsawPuzzleScreen({
    super.key,
    this.difficulty = GameDifficulty.easy,
  });

  @override
  State<JigsawPuzzleScreen> createState() => _JigsawPuzzleScreenState();
}

class _JigsawPuzzleScreenState extends State<JigsawPuzzleScreen> {
  late JigsawPuzzleLogic _logic;
  late TimerService _timerService;

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

  void _showWinDialog() {
    final int finalScore = ScoreService.calculateScore(
      moves: _logic.moves,
      timeInSeconds: _timerService.secondsElapsed,
      difficulty: widget.difficulty,
    );

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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.shade300, width: 2),
                      ),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _logic.gridSize,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        ),
                        itemCount: _logic.pieces.length,
                        itemBuilder: (context, index) {
                          final piece = _logic.pieces[index];
                          final isSelected = _logic.selectedPieceIndex == index;

                          return GestureDetector(
                            onTap: () => _logic.selectOrSwapPiece(index),
                            child: Container(
                              decoration: BoxDecoration(
                                color: piece.isCorrect
                                    ? Colors.lightGreen.shade400
                                    : Colors.orange.shade300,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.red
                                      : (piece.isCorrect ? Colors.green : Colors.deepOrange),
                                  width: isSelected ? 3 : 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Piece #${piece.id}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected ? Colors.red.shade900 : Colors.black87,
                                  fontWeight:
                                      isSelected ? FontWeight.bold : FontWeight.normal,
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
