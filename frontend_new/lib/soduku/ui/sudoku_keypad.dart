import 'package:flutter/material.dart';
import '../logic/sudoku_controller.dart';

class SudokuKeypad extends StatelessWidget {
  final SudokuController controller;

  const SudokuKeypad({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final counts = controller.numberCounts;

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
              ),
              _buildActionButton(
                icon: Icons.backspace_outlined,
                label: 'Xóa',
                onTap: controller.erase,
              ),
              _buildActionButton(
                icon: Icons.edit_note_rounded,
                label: controller.isNotesMode ? 'Ghi chú (Bật)' : 'Ghi chú',
                isActive: controller.isNotesMode,
                onTap: controller.toggleNotesMode,
              ),
              _buildActionButton(
                icon: Icons.lightbulb_outline_rounded,
                label: 'Gợi ý',
                onTap: controller.hint,
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? const Color(0xFF4338CA) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? Colors.white : const Color(0xFF334155),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF475569),
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
  }) {
    final isCompleted = placedCount >= 9;

    return Material(
      color: isCompleted ? const Color(0xFFF1F5F9) : const Color(0xFFEEF2FF),
      borderRadius: BorderRadius.circular(10),
      elevation: isCompleted ? 0 : 1,
      child: InkWell(
        onTap: isCompleted ? null : () => controller.inputNumber(number),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: width,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCompleted ? const Color(0xFFCBD5E1) : const Color(0xFFC7D2FE),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$number',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isCompleted
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF1E1B4B),
                ),
              ),
              Text(
                isCompleted ? '✓' : '${9 - placedCount}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isCompleted
                      ? const Color(0xFF10B981)
                      : const Color(0xFF6366F1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
