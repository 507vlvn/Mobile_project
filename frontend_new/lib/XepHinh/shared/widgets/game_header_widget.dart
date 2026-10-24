import 'package:flutter/material.dart';

class GameHeaderWidget extends StatelessWidget {
  final String title;
  final String formattedTime;
  final int moves;
  final VoidCallback onReset;
  final VoidCallback onPause;

  const GameHeaderWidget({
    super.key,
    required this.title,
    required this.formattedTime,
    required this.moves,
    required this.onReset,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '⏱ $formattedTime  |  👣 $moves bước',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.pause_circle_outline),
                  onPressed: onPause,
                  tooltip: 'Tạm dừng',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_outlined),
                  onPressed: onReset,
                  tooltip: 'Chơi lại',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
