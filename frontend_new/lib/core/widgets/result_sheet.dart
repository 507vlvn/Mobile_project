import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'game_timer.dart';
import 'primary_button.dart';

/// Kết quả một ván chơi để hiển thị.
class GameResultData {
  final bool success;
  final String title;
  final Duration time;
  final int mistakes;
  final String mistakesLabel;
  final int? moves;
  final int? score;
  final bool isPersonalBest;

  const GameResultData({
    required this.success,
    required this.title,
    required this.time,
    required this.mistakes,
    this.mistakesLabel = 'Lỗi',
    this.moves,
    this.score,
    this.isPersonalBest = false,
  });
}

enum ResultAction { playAgain, home }

/// Bottom sheet kết quả ván chơi. Trả về hành động người dùng chọn.
Future<ResultAction?> showResultSheet(
  BuildContext context,
  GameResultData data,
) {
  return showModalBottomSheet<ResultAction>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    builder: (context) => _ResultSheet(data: data),
  );
}

class _ResultSheet extends StatelessWidget {
  final GameResultData data;
  const _ResultSheet({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final tint = data.success ? palette.success : scheme.error;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                data.success ? Icons.emoji_events_rounded : Icons.flag_rounded,
                size: 38,
                color: tint,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(data.title, style: text.headlineSmall, textAlign: TextAlign.center),
            if (data.isPersonalBest) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 18, color: palette.accent),
                    const SizedBox(width: 4),
                    Text(
                      'Kỷ lục cá nhân mới',
                      style: text.labelLarge?.copyWith(color: palette.accent),
                    ),
                  ],
                ),
              ),
            ],
            if (data.score != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                '${data.score}',
                style: text.displaySmall?.copyWith(
                  // Tím đậm trên nền tối không đủ tương phản → dùng tím sáng
                  color: scheme.brightness == Brightness.dark
                      ? scheme.secondary
                      : scheme.primary,
                  fontFeatures: kTabularFigures,
                ),
              ),
              Text('điểm', style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                _StatTile(
                  icon: Icons.timer_outlined,
                  label: 'Thời gian',
                  value: formatDuration(data.time),
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatTile(
                  icon: Icons.error_outline_rounded,
                  label: data.mistakesLabel,
                  value: '${data.mistakes}',
                ),
                if (data.moves != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _StatTile(
                    icon: Icons.swipe_rounded,
                    label: 'Nước đi',
                    value: '${data.moves}',
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Chơi ván mới',
              icon: Icons.replay_rounded,
              onPressed: () => Navigator.pop(context, ResultAction.playAgain),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, ResultAction.home),
                child: const Text('Về màn chọn game'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(
              value,
              style: text.titleMedium?.copyWith(fontFeatures: kTabularFigures),
            ),
            Text(label, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
