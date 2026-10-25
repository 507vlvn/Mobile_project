import 'package:flutter/material.dart';
import '../logic/sudoku_stats_manager.dart';

class SudokuStatsView extends StatefulWidget {
  final VoidCallback? onBack;
  final bool showBackButton;
  final bool embedded;

  const SudokuStatsView({
    super.key,
    this.onBack,
    this.showBackButton = true,
    this.embedded = false,
  });

  @override
  State<SudokuStatsView> createState() => _SudokuStatsViewState();
}

class _SudokuStatsViewState extends State<SudokuStatsView> {
  final SudokuStatsManager _statsManager = SudokuStatsManager.instance;
  int _selectedDifficulty = 1; // 1: Dễ, 2: Trung bình, 3: Khó, 4: Chuyên gia

  final List<String> _difficultyLabels = [
    'Dễ',
    'Trung bình',
    'Khó',
    'Chuyên gia',
  ];

  @override
  void initState() {
    super.initState();
    _statsManager.addListener(_onStatsChanged);
    _statsManager.init();
    _statsManager.syncWithServer();
  }

  @override
  void dispose() {
    _statsManager.removeListener(_onStatsChanged);
    super.dispose();
  }

  void _onStatsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats = _statsManager.getStats(_selectedDifficulty);

    final content = Column(
          children: [
            // 1. Thanh tiêu đề trên cùng (Thống kê - icon bộ lọc)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.showBackButton)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                      tooltip: 'Quay lại',
                      onPressed: () {
                        if (widget.onBack != null) {
                          widget.onBack!();
                        } else if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                    )
                  else
                    const SizedBox(width: 48, height: 48),
                  Text(
                    'Thống kê',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, size: 26),
                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                    tooltip: 'Bộ lọc',
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // 2. Tab chọn mức độ khó (Dễ, Trung bình, Khó, Chuyên gia)
            Container(
              height: 44,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _difficultyLabels.length,
                separatorBuilder: (_, _) => const SizedBox(width: 24),
                itemBuilder: (context, index) {
                  final diffValue = index + 1;
                  final isSelected = _selectedDifficulty == diffValue;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedDifficulty = diffValue);
                    },
                    child: Center(
                      child: Text(
                        _difficultyLabels[index],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected
                              ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 6),

            // 3. Nội dung thống kê chi tiết
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  // Mục 1: Trò chơi
                  Text(
                    'Trò chơi',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Thẻ 1: Trò chơi Đã bắt đầu
                  _buildStatCard(
                    icon: Icons.grid_view_rounded,
                    title: 'Trò chơi Đã bắt đầu',
                    value: '${stats.gamesStarted}',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),

                  // Thẻ 2: Trò chơi Đã thắng
                  _buildStatCard(
                    icon: Icons.military_tech_outlined,
                    title: 'Trò chơi Đã thắng',
                    value: '${stats.gamesWon}',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),

                  // Thẻ 3: Tỉ lệ Thắng
                  _buildStatCard(
                    icon: Icons.outlined_flag_rounded,
                    title: 'Tỉ lệ Thắng',
                    value: stats.winRateFormatted,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),

                  // Thẻ 4: Thắng Không Lỗi
                  _buildStatCard(
                    icon: Icons.flag_circle_outlined,
                    title: 'Thắng Không Lỗi',
                    value: '${stats.winWithoutMistakes}',
                    isDark: isDark,
                  ),

                  const SizedBox(height: 24),

                  // Mục 2: Thời gian
                  Text(
                    'Thời gian',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Thẻ 5: Thời gian Tốt nhất
                  _buildStatCard(
                    icon: Icons.timer_outlined,
                    title: 'Thời gian Tốt nhất',
                    value: stats.bestTimeFormatted,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FBFE),
      body: SafeArea(child: content),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F4F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0).withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 26,
                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
