import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String? label;
  final Color? color;

  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = color ?? scheme.onSurface;
    return Semantics(
      label: label != null ? '$label: $value' : value,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontFeatures: kTabularFigures,
                  ),
            ),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
