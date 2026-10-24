import 'package:flutter/material.dart';
import '../logic/sudoku_controller.dart';
import '../logic/sudoku_models.dart';
import 'sudoku_board.dart';
import 'sudoku_keypad.dart';

class SudokuScreen extends StatefulWidget {
  final SudokuDifficulty initialDifficulty;
  final int? seed;
  final SudokuController? controller;

  const SudokuScreen({
    super.key,
    this.initialDifficulty = SudokuDifficulty.medium,
    this.seed,
    this.controller,
  });

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> with WidgetsBindingObserver {
  late final SudokuController _controller;
  late final bool _isExternalController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isExternalController = widget.controller != null;
    _controller = widget.controller ??
        SudokuController(
          initialDifficulty: widget.initialDifficulty,
          seed: widget.seed,
        );

    // Bắt đầu game nếu chưa có bàn cờ
    if (_controller.board.isEmpty) {
      _controller.startNewGame(
        difficulty: widget.initialDifficulty,
        seed: widget.seed,
      );
    } else if (_controller.status == SudokuStatus.paused) {
      _controller.resumeTimer();
    }

    _controller.addListener(_onGameStateChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tự động dừng thời gian khi ẩn app, tắt màn hình hoặc chuyển ứng dụng khác
    if (state != AppLifecycleState.resumed) {
      _controller.pauseTimer();
    }
  }

  void _onGameStateChanged() {
    if (!mounted) return;
    setState(() {});

    if (_controller.status == SudokuStatus.won) {
      _showEndGameDialog(
        title: '🎉 Chúc Mừng Chiến Thắng!',
        message: 'Bạn đã hoàn thành bảng Sudoku xuất sắc!',
        isWin: true,
      );
    } else if (_controller.status == SudokuStatus.lost) {
      _showEndGameDialog(
        title: '💔 Thua Cuộc',
        message: 'Bạn đã phạm quá ${_controller.maxMistakes} lỗi.',
        isWin: false,
      );
    }
  }

  void _showEndGameDialog({
    required String title,
    required String message,
    required bool isWin,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isWin ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Thời gian', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      _controller.elapsedFormatted,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('Số lỗi', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      '${_controller.mistakes}/${_controller.maxMistakes}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('Độ khó', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      _controller.displayTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _controller.restartCurrentGame();
            },
            child: const Text('Chơi lại'),
          ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _controller.startNewGame();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
              ),
              child: const Text('Ván mới'),
            ),
        ],
      ),
    );
  }

  void _showNewGameConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo ván mới?'),
        content: const Text('Tiến trình ván hiện tại sẽ bị đặt lại.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _controller.startNewGame();
            },
            child: const Text('Bắt đầu'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Dừng thời gian ngay khi thoát khỏi màn hình chơi
    _controller.pauseTimer();
    _controller.removeListener(_onGameStateChanged);
    if (!_isExternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _controller.progressPercent;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        // Dừng thời gian khi nhấn Back cử chỉ hoặc nút Back của thiết bị
        _controller.pauseTimer();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () {
              _controller.pauseTimer();
              Navigator.maybePop(context);
            },
            tooltip: 'Trang chủ',
          ),
          title: const Text(
            'Sudoku Cổ điển',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0.5,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Ván mới',
              onPressed: _showNewGameConfirm,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Thanh thông số trên cùng (Độ khó, Lỗi, Đồng hồ)
              _buildStatusBar(),

              // Thanh tiến độ giải đề
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress / 100.0,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                    minHeight: 5,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Bàn cờ Sudoku 9x9
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SudokuBoard(controller: _controller),

                        // Màn chắn khi tạm dừng
                        if (_controller.status == SudokuStatus.paused)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.pause_circle_outline,
                                      size: 64, color: Color(0xFF4F46E5)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Đang tạm dừng',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _controller.togglePause,
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: const Text('Tiếp tục'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4F46E5),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bàn phím số và công cụ phía dưới
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
                child: SudokuKeypad(controller: _controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Bộ chọn độ khó
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SudokuDifficulty>(
                value: _controller.difficulty,
                isDense: true,
                onChanged: (newDiff) {
                  if (newDiff != null && newDiff != _controller.difficulty) {
                    _controller.startNewGame(difficulty: newDiff);
                  }
                },
                items: SudokuDifficulty.values.map((diff) {
                  return DropdownMenuItem(
                    value: diff,
                    child: Text(
                      diff.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Bộ đếm lỗi
          Row(
            children: [
              Text(
                'Lỗi: ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                '${_controller.mistakes}/${_controller.maxMistakes}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _controller.mistakes > 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),

          // Đồng hồ bấm giờ & Nút tạm dừng
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                _controller.elapsedFormatted,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(
                  _controller.status == SudokuStatus.paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  color: const Color(0xFF4F46E5),
                ),
                onPressed: _controller.togglePause,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
