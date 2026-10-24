import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';

/// Bàn phím số 1–9: mỗi nút ≥ 48dp, kèm số lượng còn thiếu của chữ số đó.
class SudokuNumberPad extends StatelessWidget {
  /// remaining[d-1] = số ô còn thiếu của chữ số d (0 = đã đủ → nút mờ)
  final List<int> remaining;
  final bool notesMode;
  final bool enabled;
  final ValueChanged<int> onDigit;

  const SudokuNumberPad({
    super.key,
    required this.remaining,
    required this.notesMode,
    required this.enabled,
    required this.onDigit,
  });

  @override
  Widget build(BuildContext context) {
    Widget button(int d, double w) => SizedBox(
          width: w,
          child: _DigitButton(
            digit: d,
            remaining: remaining[d - 1],
            notesMode: notesMode,
            enabled: enabled && remaining[d - 1] > 0,
            onTap: () => onDigit(d),
          ),
        );
    return LayoutBuilder(builder: (context, c) {
      const gap = AppSpacing.sm;
      final w = (c.maxWidth - gap * 4) / 5;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (var d = 1; d <= 5; d++) button(d, w)],
          ),
          const SizedBox(height: gap),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var d = 6; d <= 9; d++) ...[
                if (d > 6) const SizedBox(width: gap),
                button(d, w),
              ],
            ],
          ),
        ],
      );
    });
  }
}

class _DigitButton extends StatelessWidget {
  final int digit;
  final int remaining;
  final bool notesMode;
  final bool enabled;
  final VoidCallback onTap;

  const _DigitButton({
    required this.digit,
    required this.remaining,
    required this.notesMode,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final done = remaining == 0;
    final bg = notesMode ? scheme.secondaryContainer : scheme.primaryContainer;
    final fg =
        notesMode ? scheme.onSecondaryContainer : scheme.onPrimaryContainer;

    return Semantics(
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      label: done ? 'Số $digit, đã đủ' : 'Số $digit, còn $remaining ô',
      child: Opacity(
        opacity: enabled ? 1 : (done ? 0.38 : 0.6),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              height: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$digit',
                    style: text.headlineSmall?.copyWith(
                      color: fg,
                      height: 1.05,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                  Text(
                    done ? 'đủ' : 'còn $remaining',
                    style: text.bodySmall?.copyWith(color: fg, height: 1.1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút công cụ có nhãn: Hoàn tác / Xoá / Ghi chú / Gợi ý.
class SudokuToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Không null = nút bật/tắt; hiện huy hiệu Bật / Tắt
  final bool? toggled;

  const SudokuToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.toggled,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final on = toggled ?? false;
    final color = enabled
        ? (on ? scheme.onPrimary : scheme.onSurface)
        : scheme.onSurface.withValues(alpha: 0.38);

    Widget iconWidget = Icon(icon, color: color);
    if (toggled != null) {
      iconWidget = Badge(
        label: Text(on ? 'Bật' : 'Tắt'),
        backgroundColor: on ? scheme.tertiary : scheme.surfaceContainerHighest,
        textColor: on ? scheme.onTertiary : scheme.onSurfaceVariant,
        alignment: AlignmentDirectional.topEnd,
        offset: const Offset(14, -8),
        child: iconWidget,
      );
    }

    return Semantics(
      button: true,
      enabled: enabled,
      toggled: toggled,
      excludeSemantics: true,
      label:
          toggled == null ? label : '$label, ${on ? 'đang bật' : 'đang tắt'}',
      child: Material(
        color: on ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                iconWidget,
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
