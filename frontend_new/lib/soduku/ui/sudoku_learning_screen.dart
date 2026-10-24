import 'package:flutter/material.dart';
import '../logic/sudoku_learning_manager.dart';
import 'crossmath_screen.dart';

class SudokuLearningScreen extends StatefulWidget {
  const SudokuLearningScreen({super.key});

  @override
  State<SudokuLearningScreen> createState() => _SudokuLearningScreenState();
}

class _SudokuLearningScreenState extends State<SudokuLearningScreen> {
  final SudokuLearningManager _learningManager = SudokuLearningManager.instance;

  @override
  void initState() {
    super.initState();
    _learningManager.init().then((_) {
      if (mounted) setState(() {});
    });
    _learningManager.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _learningManager.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  void _playLevel(int level) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CrossMathScreen(level: level),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final levels = _learningManager.getLevels();
    final completed = _learningManager.completedCount;
    final total = SudokuLearningManager.totalLevels;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Toán Chéo (CrossMath)',
          style: TextStyle(
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thông số tiến trình (ví dụ: 2/30)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$completed/$total Đã hoàn thành',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                    ),
                  ),
                  Text(
                    'Độ khó tăng dần từ 1 đến $total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Lưới 5 cột x 6 hàng = 30 level
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.86,
                ),
                itemCount: levels.length,
                itemBuilder: (context, index) {
                  final info = levels[index];
                  return _buildLevelCard(info, isDark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(LearningLevelInfo info, bool isDark) {
    final isCompleted = info.isCompleted;
    final isUnlocked = info.isUnlocked;
    final isCurrent = isUnlocked && !isCompleted;

    // 1. Level đã hoàn thành: Nền xanh biển đậm, số trắng, thời gian hoàn thành
    if (isCompleted) {
      return Material(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(14),
        elevation: 2,
        child: InkWell(
          onTap: () => _playLevel(info.level),
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${info.level}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                info.timeFormatted,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFDBEAFE),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Level đang mở khóa (hiện tại)
    if (isCurrent) {
      return Material(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 1,
        child: InkWell(
          onTap: () => _playLevel(info.level),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                width: 2.2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${info.level}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '--:--',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. Level bị khóa
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.5)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.lock_rounded,
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                size: 26,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '${info.level}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
