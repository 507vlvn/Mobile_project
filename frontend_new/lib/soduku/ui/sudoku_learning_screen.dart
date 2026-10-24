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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 24),
          color: const Color(0xFF1E293B),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Toán Chéo (CrossMath)',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thông số tiến trình (ví dụ: 2/30)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$completed/$total',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  Text(
                    'Độ khó tăng dần từ 1 đến $total',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
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
                  return _buildLevelCard(info);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(LearningLevelInfo info) {
    final isCompleted = info.isCompleted;
    final isUnlocked = info.isUnlocked;
    final isCurrent = isUnlocked && !isCompleted;

    // 1. Level đã hoàn thành: Nền xanh biển đậm, số trắng, thời gian hoàn thành
    if (isCompleted) {
      return Material(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(14),
        elevation: 1,
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

    // 2. Level đang mở khóa (hiện tại): Nền trắng, viền xanh biển đậm, --:--
    if (isCurrent) {
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _playLevel(info.level),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2563EB), width: 2.2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${info.level}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '--:--',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. Level bị khóa: Nền xám nhạt, icon ổ khóa và số level mờ
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.lock_rounded,
                color: Color(0xFFCBD5E1),
                size: 28,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '${info.level}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
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
