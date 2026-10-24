import 'dart:async';
import 'package:flutter/material.dart';
import '../logic/crossmath_models.dart';
import '../logic/crossmath_levels.dart';
import '../logic/sudoku_learning_manager.dart';

class CrossMathScreen extends StatefulWidget {
  final int level;

  const CrossMathScreen({
    super.key,
    required this.level,
  });

  @override
  State<CrossMathScreen> createState() => _CrossMathScreenState();
}

class _CrossMathScreenState extends State<CrossMathScreen> with WidgetsBindingObserver {
  late int _currentLevel;
  late CrossMathLevelData _levelData;
  CrossMathCell? _selectedCell;

  int _seconds = 0;
  Timer? _timer;
  bool _isPaused = false;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentLevel = widget.level;
    _initLevel(_currentLevel);
  }

  void _initLevel(int level) {
    _timer?.cancel();
    _currentLevel = level;
    _levelData = CrossMathLevelProvider.getLevel(level);
    _seconds = 0;
    _isPaused = false;
    _isCompleted = false;

    // Tự động chọn ô trống đầu tiên để người chơi dễ tương tác
    final firstBlank = _levelData.cells.where((c) => c.isBlank).firstOrNull;
    _selectedCell = firstBlank;

    _startTimer();
    setState(() {});
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isPaused && mounted) {
        setState(() {
          _seconds++;
        });
      }
    });
  }

  void _pauseTimer() {
    setState(() {
      _isPaused = true;
    });
  }

  void _resumeTimer() {
    setState(() {
      _isPaused = false;
    });
  }

  void _togglePause() {
    if (_isPaused) {
      _resumeTimer();
    } else {
      _pauseTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _pauseTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  String get _timeFormatted {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _onCellTap(CrossMathCell cell) {
    if (!cell.isBlank) return;
    setState(() {
      if (_selectedCell == cell && cell.userText != null) {
        // Chạm lần nữa vào ô đã điền -> xóa giá trị để điền lại
        cell.userText = null;
      } else {
        _selectedCell = cell;
      }
    });
  }

  /// Đếm số lần mỗi thẻ đã được điền lên bảng
  Map<String, int> _getUsedCounts() {
    final counts = <String, int>{};
    for (final cell in _levelData.cells) {
      if (cell.isBlank && cell.userText != null) {
        counts[cell.userText!] = (counts[cell.userText!] ?? 0) + 1;
      }
    }
    return counts;
  }

  void _onNumberTap(String value) {
    if (_selectedCell == null || !_selectedCell!.isBlank) return;

    setState(() {
      _selectedCell!.userText = value;

      // Tìm ô trống tiếp theo chưa điền để tự động focus
      final nextBlank = _levelData.cells.firstWhere(
        (c) => c.isBlank && c.userText == null,
        orElse: () => _selectedCell!,
      );
      _selectedCell = nextBlank;

      _checkCompletion();
    });
  }

  void _checkCompletion() {
    final blankCells = _levelData.cells.where((c) => c.isBlank).toList();
    final allFilled = blankCells.every((c) => c.userText != null);

    if (allFilled) {
      final allCorrect = blankCells.every((c) => c.userText == c.targetText);
      if (allCorrect && !_isCompleted) {
        _isCompleted = true;
        _timer?.cancel();

        // Lưu kỷ lục chiến thắng
        SudokuLearningManager.instance.recordWin(_currentLevel, _seconds);

        _showWinDialog();
      } else if (!allCorrect) {
        // Báo lỗi nhẹ nếu điền hết nhưng chưa đúng
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Có một số ô chưa chính xác, hãy kiểm tra lại nhé!'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _skipLevel() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Bỏ qua màn này?'),
        content: const Text('Bạn có muốn mở khóa và chuyển sang màn tiếp theo không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ở lại'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              SudokuLearningManager.instance.recordWin(_currentLevel, _seconds > 0 ? _seconds : 60);
              if (_currentLevel < SudokuLearningManager.totalLevels) {
                _initLevel(_currentLevel + 1);
              } else {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Bỏ qua'),
          ),
        ],
      ),
    );
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                size: 56,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'XUẤT SẮC!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn đã giải thành công Toán Chéo Màn $_currentLevel',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text(
                    'Thời gian: $_timeFormatted',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _initLevel(_currentLevel);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Chơi lại'),
                  ),
                ),
                const SizedBox(width: 12),
                if (_currentLevel < SudokuLearningManager.totalLevels)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _initLevel(_currentLevel + 1);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Màn tiếp theo'),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Hoàn tất'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _timer?.cancel();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: SafeArea(
          child: Column(
            children: [
              // 1. THANH TIÊU ĐỀ MÀU XANH GIỐNG ẢNH MẪU
              Container(
                color: const Color(0xFF1E88E5),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Nút Back
                    InkWell(
                      onTap: () {
                        _timer?.cancel();
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          size: 20,
                          color: Color(0xFF1E88E5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Tiêu đề hướng dẫn
                    Expanded(
                      child: Text(
                        _selectedCell == null
                            ? 'Nhấn để chọn một ô trống'
                            : 'Màn $_currentLevel: Điền vào ô đang chọn',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // Nút BỎ QUA tròn ở góc phải
                    InkWell(
                      onTap: _skipLevel,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          'BỎ QUA',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. KHUNG CHÍNH CHỨA BÀI TOÁN
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    children: [
                      // Card bàn cờ phép tính
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Timer góc phải: "00:01 ||" giống ảnh mẫu
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  _timeFormatted,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: _togglePause,
                                  child: Icon(
                                    _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                    size: 22,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Lưới phương trình (Grid)
                            _buildCrossMathGrid(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // 3. KHAY SỐ ĐỂ CHỌN BÊN DƯỚI (GIỐNG ẢNH MẪU)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _buildNumberPool(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCrossMathGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = _levelData.cols;
        final rows = _levelData.rows;

        // Tính toán kích thước mỗi ô sao cho hiển thị vừa khít bề ngang
        final availableWidth = constraints.maxWidth - (cols * 3.5);
        final calculatedSize = (availableWidth / cols).clamp(24.0, 42.0);

        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(rows, (r) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: List.generate(cols, (c) {
                  final cell = _levelData.cells.firstWhere(
                    (item) => item.row == r && item.col == c,
                    orElse: () => CrossMathCell(
                      row: r,
                      col: c,
                      type: CrossMathCellType.none,
                    ),
                  );
                  return _buildCellWidget(cell, calculatedSize);
                }),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildCellWidget(CrossMathCell cell, double size) {
    if (cell.type == CrossMathCellType.none) {
      return SizedBox(width: size + 3, height: size + 3);
    }

    final isSelected = _selectedCell == cell;
    final isBlank = cell.isBlank;

    // Màu nền chuẩn theo ảnh mẫu:
    // - Ô số có sẵn & toán tử cố định: màu vàng kem/be (#FFF9E6)
    // - Ô trống chưa điền: màu be rất nhạt/trắng ngà (#FDFCF7)
    // - Ô trống đã điền: màu xanh nhạt (#F0FDF4)
    final bgColor = isBlank
        ? (cell.userText != null ? const Color(0xFFF0FDF4) : const Color(0xFFFDFCF7))
        : const Color(0xFFFFF9E6);

    final borderColor = isSelected
        ? const Color(0xFF1E88E5)
        : (isBlank ? const Color(0xFFCBD5E1) : const Color(0xFF333333));

    final borderWidth = isSelected ? 2.5 : (isBlank ? 1.0 : 1.2);

    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.all(1.5),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: () => _onCellTap(cell),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: borderColor, width: borderWidth),
              ),
              child: Center(
                child: Text(
                  isBlank ? (cell.userText ?? '') : cell.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: size * 0.44,
                    fontWeight: FontWeight.bold,
                    color: isBlank
                        ? (cell.userText != null
                            ? const Color(0xFF0F172A)
                            : Colors.transparent)
                        : Colors.black,
                  ),
                ),
              ),
            ),
          ),

          // Hiển thị bàn tay chỉ điểm hướng dẫn ở ô đang được chọn giống ảnh mẫu
          if (isSelected && cell.userText == null)
            Positioned(
              right: -14,
              bottom: -14,
              child: IgnorePointer(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Image.asset(
                    'assets/images/hand_pointer.png',
                    errorBuilder: (context, error, stackTrace) => const Text('👆', style: TextStyle(fontSize: 24)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNumberPool() {
    final pool = _levelData.numberPool;
    final usedCounts = _getUsedCounts();

    // Để xác định thẻ nào trong pool đã dùng:
    // Theo dõi tiến trình tiêu thụ các giá trị
    final runningUsage = <String, int>{};

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: pool.map((item) {
        final currentUsed = runningUsage[item] ?? 0;
        final totalUsed = usedCounts[item] ?? 0;
        final isItemUsed = currentUsed < totalUsed;
        runningUsage[item] = currentUsed + 1;

        return Opacity(
          opacity: isItemUsed ? 0.35 : 1.0,
          child: InkWell(
            onTap: isItemUsed ? null : () => _onNumberTap(item),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF4FBF7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isItemUsed ? const Color(0xFFCBD5E1) : const Color(0xFF86EFAC),
                  width: 1.5,
                ),
                boxShadow: isItemUsed
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Center(
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isItemUsed ? const Color(0xFF94A3B8) : const Color(0xFF15803D),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
