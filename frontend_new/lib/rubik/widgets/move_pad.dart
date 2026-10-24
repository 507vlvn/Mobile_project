import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../model/cube_model.dart';

/// Bảng nút xoay 6 mặt — phương án thay thế cho cử chỉ vuốt (accessibility).
/// Mỗi nút có chấm màu tâm hiện tại của mặt đó để người mới không cần thuộc ký hiệu.
class MovePad extends StatefulWidget {
  final Cube3DState state;
  final bool enabled;
  final ValueChanged<String> onMove;

  const MovePad({
    super.key,
    required this.state,
    required this.onMove,
    this.enabled = true,
  });

  @override
  State<MovePad> createState() => _MovePadState();
}

class _MovePadState extends State<MovePad> {
  bool _prime = false;

  static const _faces = [
    ('U', 'top', 'Trên'),
    ('L', 'left', 'Trái'),
    ('F', 'front', 'Trước'),
    ('R', 'right', 'Phải'),
    ('B', 'back', 'Sau'),
    ('D', 'bottom', 'Dưới'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final (letter, key, label) in _faces) ...[
              Expanded(
                child: _FaceButton(
                  notation: _prime ? "$letter'" : letter,
                  label: label,
                  center: widget.state.faces[key]![4],
                  enabled: widget.enabled,
                  onTap: () => widget.onMove(_prime ? "$letter'" : letter),
                ),
              ),
              if (letter != 'D') const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Công tắc chiều quay — có nhãn chữ rõ ràng, không chỉ dùng ký hiệu
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => setState(() => _prime = !_prime),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kMinTouchTarget),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _prime
                        ? Icons.rotate_left_rounded
                        : Icons.rotate_right_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _prime
                        ? 'Đang chọn: ngược chiều (\')'
                        : 'Đang chọn: thuận chiều',
                    style: text.labelLarge,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Switch(
                    value: _prime,
                    onChanged: (v) => setState(() => _prime = v),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FaceButton extends StatelessWidget {
  final String notation;
  final String label;
  final Color center;
  final bool enabled;
  final VoidCallback onTap;

  const _FaceButton({
    required this.notation,
    required this.label,
    required this.center,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Xoay mặt $label, ký hiệu $notation',
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: center,
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.outline, width: 1),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(notation, style: text.titleSmall),
                    ],
                  ),
                  Text(
                    label,
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
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
