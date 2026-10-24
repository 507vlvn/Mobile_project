import 'package:flutter/material.dart';

class PhaseShiftControlPanel extends StatelessWidget {
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;
  final VoidCallback onSoftDrop;
  final VoidCallback onHardDrop;

  const PhaseShiftControlPanel({
    super.key,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onSoftDrop,
    required this.onHardDrop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.arrow_back_rounded,
            label: 'Trái',
            color: Colors.indigo,
            onPressed: onMoveLeft,
          ),
          _buildControlButton(
            icon: Icons.arrow_downward_rounded,
            label: 'Xuống',
            color: Colors.blue.shade700,
            onPressed: onSoftDrop,
          ),
          _buildControlButton(
            icon: Icons.keyboard_double_arrow_down_rounded,
            label: 'Thả ngay',
            color: Colors.deepOrange.shade700,
            onPressed: onHardDrop,
          ),
          _buildControlButton(
            icon: Icons.arrow_forward_rounded,
            label: 'Phải',
            color: Colors.indigo,
            onPressed: onMoveRight,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
