import 'package:flutter/material.dart';

/// Nút hành động chính: rộng hết chiều ngang, có trạng thái đang tải.
/// Khi [loading] = true nút bị vô hiệu để chống bấm lặp.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: scheme.onPrimary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    // Khi đang tải: giữ nguyên màu nút (không xám như disabled) nhưng chặn chạm,
    // để người dùng thấy rõ hành động đang được xử lý.
    final button = IgnorePointer(
      ignoring: loading,
      child: FilledButton(
        onPressed: loading ? () {} : onPressed,
        child: Semantics(
          label: loading ? '$label, đang xử lý' : null,
          child: child,
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
