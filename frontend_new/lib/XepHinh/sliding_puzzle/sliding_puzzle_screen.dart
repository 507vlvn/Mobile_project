import 'package:flutter/material.dart';
import '../shared/models/difficulty.dart';
import '../shared/services/timer_service.dart';
import '../shared/services/score_service.dart';
import '../shared/widgets/game_header_widget.dart';
import 'sliding_puzzle_logic.dart';

class SlidingPuzzleScreen extends StatefulWidget {
  final GameDifficulty difficulty;

  const SlidingPuzzleScreen({
    super.key,
    this.difficulty = GameDifficulty.easy,
  });

  @override
  State<SlidingPuzzleScreen> createState() => _SlidingPuzzleScreenState();
}

class _SlidingPuzzleScreenState extends State<SlidingPuzzleScreen> {
  late SlidingPuzzleLogic _logic;
  late TimerService _timerService;

  @override
  void initState() {
    super.initState();
    _logic = SlidingPuzzleLogic(difficulty: widget.difficulty);
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
        title: const Text('🎉 Chúc mừng! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bạn đã hoàn thành Trò chơi Xếp số!'),
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
        title: Text('Xếp hình trượt - ${widget.difficulty.displayName}'),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_logic, _timerService]),
        builder: (context, _) {
          return Column(
            children: [
              GameHeaderWidget(
                title: 'Sliding Puzzle',
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
                        color: Colors.blueGrey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _logic.gridSize,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        ),
                        itemCount: _logic.tiles.length,
                        itemBuilder: (context, index) {
                          final tile = _logic.tiles[index];
                          if (tile.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return GestureDetector(
                            onTap: () => _logic.moveTile(index),
                            child: Container(
                              decoration: BoxDecoration(
                                color: tile.isCorrect
                                    ? Colors.teal.shade400
                                    : Colors.indigo.shade400,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 3,
                                    offset: Offset(2, 2),
                                  )
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${tile.id}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
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
