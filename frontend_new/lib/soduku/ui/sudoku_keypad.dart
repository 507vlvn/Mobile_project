import 'package:flutter/material.dart';
import '../logic/sudoku_controller.dart';

class SudokuKeypad extends StatelessWidget {
  final SudokuController controller;

  const SudokuKeypad({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final counts = controller.numberCounts;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Thanh công cụ hành động (Hoàn tác, Xóa, Ghi chú, Gợi ý)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.undo_rounded,
                label: 'Hoàn tác',
                onTap: controller.undo,
                isDark: isDark,
              ),
              _buildActionButton(
                icon: Icons.backspace_outlined,
                label: 'Xóa',
                onTap: controller.erase,
                isDark: isDark,
              ),
              _buildActionButton(
                icon: Icons.edit_note_rounded,
                label: controller.isNotesMode ? 'Ghi chú (Bật)' : 'Ghi chú',
                isActive: controller.isNotesMode,
                onTap: controller.toggleNotesMode,
                isDark: isDark,
              ),
              _buildActionButton(
                icon: Icons.lightbulb_outline_rounded,
                label: 'Gợi ý',
                onTap: controller.hint,
                isDark: isDark,
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Hàng bàn phím số 1 đến 9
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final buttonWidth = (constraints.maxWidth - (8 * 6)) / 9;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (int i = 1; i <= 9; i++) ...[
                    _buildNumberButton(
                      number: i,
                      placedCount: counts[i] ?? 0,
                      width: buttonWidth,
                      isDark: isDark,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? const Color(0xFF3B82F6)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive
                  ? Colors.white
                  : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? Colors.white
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberButton({
    required int number,
    required int placedCount,
    required double width,
    required bool isDark,
  }) {
    final isCompleted = placedCount >= 9;

    Color bgColor;
    BorderSide borderSide;
    Color numColor;
    Color countColor;

    if (isCompleted) {
      bgColor = isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF1F5F9);
      borderSide = BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1));
      numColor = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);
      countColor = const Color(0xFF10B981);
    } else {
      bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF);
      borderSide = BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFC7D2FE));
      numColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E1B4B);
      countColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF6366F1);
    }

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
      elevation: isCompleted ? 0 : (isDark ? 2 : 1),
      child: InkWell(
        onTap: isCompleted ? null : () => controller.inputNumber(number),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: width,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.fromBorderSide(borderSide),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$number',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: numColor,
                ),
              ),
              Text(
                isCompleted ? '✓' : '${9 - placedCount}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: countColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
