import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/difficulty.dart';
import '../../core/network/api_client.dart';
import '../../core/services/score_reporter.dart';
import '../logic/sudoku_controller.dart';
import '../models/sudoku_models.dart';
import '../logic/sudoku_stats_manager.dart';
import '../widgets/sudoku_board.dart';
import '../widgets/sudoku_keypad.dart';

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
  bool _hasReportedOutcome = false;

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
    // Tự động dừng thời gian và lưu lại ván cờ khi ẩn app hoặc chuyển ứng dụng
    if (state != AppLifecycleState.resumed) {
      _controller.pauseTimer();
      _saveCurrentGame();
    }
  }

  void _saveCurrentGame() {
    if (!mounted) return;
    if (_controller.hasOngoingGame && !_hasReportedOutcome) {
      final api = context.read<ApiClient>();
      unawaited(_controller.saveGameToServer(api));
    }
  }

  void _onGameStateChanged() {
    if (!mounted) return;
    setState(() {});

    if (_controller.status == SudokuStatus.won) {
      if (!_hasReportedOutcome) {
        _hasReportedOutcome = true;
        _reportOutcome(isWin: true);
      }
      _showEndGameDialog(
        title: '🎉 Chúc Mừng Chiến Thắng!',
        message: 'Bạn đã hoàn thành bảng Sudoku xuất sắc!',
        isWin: true,
      );
    } else if (_controller.status == SudokuStatus.lost) {
      if (!_hasReportedOutcome) {
        _hasReportedOutcome = true;
        _reportOutcome(isWin: false);
      }
      _showEndGameDialog(
        title: '💔 Thua Cuộc',
        message: 'Bạn đã phạm quá ${_controller.maxMistakes} lỗi.',
        isWin: false,
      );
    }
  }

  void _reportOutcome({required bool isWin}) {
    if (isWin) {
      SudokuStatsManager.instance.recordGameWon(
        _controller.difficultyNumeric,
        _controller.elapsedSeconds,
        mistakes: _controller.mistakes,
      );
    }
    final reporter = context.read<ScoreReporter>();
    final api = context.read<ApiClient>();
    reporter.submit(GameRecord(
      gameCode: 'SUDOKU',
      // Mức chung chỉ có 1–3; Chuyên gia (4), Ác mộng (5) gửi qua level
      difficulty: Difficulty.fromValue(_controller.difficultyNumeric),
      level: _controller.difficultyNumeric > 3 ? _controller.difficultyNumeric : null,
      timeSeconds: _controller.elapsedSeconds,
      mistakes: _controller.mistakes,
      moves: _controller.movesCount,
      hints: _controller.hintsUsed,
      outcome: isWin ? GameOutcome.completed : GameOutcome.lose,
    ));
    _controller.deleteGameFromServer(api);
  }

  void _showEndGameDialog({
    required String title,
    required String message,
    required bool isWin,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isWin
                ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))
                : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('Thời gian', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      _controller.elapsedFormatted,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text('Số lỗi', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      '${_controller.mistakes}/${_controller.maxMistakes}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text('Độ khó', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      _controller.displayTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          if (!isWin)
            ElevatedButton.icon(
              icon: const Icon(Icons.exit_to_app_rounded),
              label: const Text('Thoát trò chơi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted) Navigator.pop(context);
              },
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _hasReportedOutcome = false;
              _controller.restartCurrentGame();
            },
            child: Text('Chơi lại', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ),
          if (isWin)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _hasReportedOutcome = false;
                _controller.startNewGame();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: const Text('Ván mới'),
            ),
        ],
      ),
    );
  }

  void _showNewGameConfirm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        title: Text(
          'Tạo ván mới?',
          style: TextStyle(
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Tiến trình ván hiện tại sẽ bị đặt lại.',
          style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _hasReportedOutcome = false;
              final api = context.read<ApiClient>();
              _controller.deleteGameFromServer(api);
              _controller.startNewGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Bắt đầu'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.pauseTimer();
    _saveCurrentGame();
    _controller.removeListener(_onGameStateChanged);
    if (!_isExternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _controller.progressPercent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        _controller.pauseTimer();
        _saveCurrentGame();
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
            ),
            onPressed: () {
              _controller.pauseTimer();
              Navigator.maybePop(context);
            },
            tooltip: 'Trang chủ',
          ),
          title: Text(
            'Sudoku Cổ điển',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
            ),
          ),
          centerTitle: true,
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          elevation: isDark ? 0 : 0.5,
          actions: [
            IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
              ),
              tooltip: 'Ván mới',
              onPressed: _showNewGameConfirm,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Thanh thông số trên cùng (Độ khó, Lỗi, Đồng hồ)
              _buildStatusBar(isDark),

              // Thanh tiến độ giải đề
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress / 100.0,
                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? const Color(0xFF38BDF8) : const Color(0xFF4F46E5),
                    ),
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
                                color: isDark
                                    ? const Color(0xFF0F172A).withValues(alpha: 0.95)
                                    : Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.pause_circle_outline,
                                    size: 64,
                                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4F46E5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Đang tạm dừng',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _controller.togglePause,
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: const Text('Tiếp tục'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
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

  Widget _buildStatusBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Bộ chọn độ khó
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SudokuDifficulty>(
                value: _controller.difficulty,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                iconEnabledColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
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
                  color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600,
                ),
              ),
              Text(
                '${_controller.mistakes}/${_controller.maxMistakes}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _controller.mistakes > 0
                      ? const Color(0xFFEF4444)
                      : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B)),
                ),
              ),
            ],
          ),

          // Đồng hồ bấm giờ & Nút tạm dừng
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 18,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Text(
                _controller.elapsedFormatted,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                iconSize: 22,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(
                  _controller.status == SudokuStatus.paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF4F46E5),
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
