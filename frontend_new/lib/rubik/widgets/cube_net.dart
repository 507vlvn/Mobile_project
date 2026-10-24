import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_tokens.dart';
import '../model/cube_model.dart';

const Map<String, String> kFaceLabels = {
  'top': 'Trên',
  'left': 'Trái',
  'front': 'Trước',
  'right': 'Phải',
  'back': 'Sau',
  'bottom': 'Dưới',
};

/// Sơ đồ trải phẳng hình chữ thập:
///          [Trên]
///   [Trái][Trước][Phải][Sau]
///          [Dưới]
/// Chạm vào một mặt → [onFaceTap]. Ô lỗi được viền màu lỗi + dấu chấm than.
class CubeNet extends StatelessWidget {
  final Cube3DState state;
  final Set<StickerRef> highlighted;
  final ValueChanged<String>? onFaceTap;

  const CubeNet({
    super.key,
    required this.state,
    this.highlighted = const {},
    this.onFaceTap,
  });

  static const _layout = {
    'top': (1, 0),
    'left': (0, 1),
    'front': (1, 1),
    'right': (2, 1),
    'back': (3, 1),
    'bottom': (1, 2),
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 6.0;
      final faceSize = ((c.maxWidth - gap * 3) / 4).clamp(48.0, 120.0);
      final width = faceSize * 4 + gap * 3;
      final height = faceSize * 3 + gap * 2;
      return Center(
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              for (final e in _layout.entries)
                Positioned(
                  left: e.value.$1 * (faceSize + gap),
                  top: e.value.$2 * (faceSize + gap),
                  width: faceSize,
                  height: faceSize,
                  child: _NetFace(
                    face: e.key,
                    colors: state.faces[e.key]!,
                    highlighted: highlighted,
                    onTap: onFaceTap == null ? null : () => onFaceTap!(e.key),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _NetFace extends StatelessWidget {
  final String face;
  final List<Color> colors;
  final Set<StickerRef> highlighted;
  final VoidCallback? onTap;

  const _NetFace({
    required this.face,
    required this.colors,
    required this.highlighted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final errors = [
      for (var i = 0; i < 9; i++) highlighted.contains(StickerRef(face, i))
    ];
    final hasError = errors.contains(true);

    return Semantics(
      button: onTap != null,
      label:
          'Mặt ${kFaceLabels[face]}${hasError ? ', có ô cần kiểm tra' : ''}. Chạm để sửa.',
      excludeSemantics: true,
      child: Material(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < 9; i++)
                  Container(
                    decoration: BoxDecoration(
                      color: colors[i],
                      borderRadius: BorderRadius.circular(3),
                      border: errors[i]
                          ? Border.all(color: scheme.error, width: 2.5)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: errors[i]
                        ? Icon(Icons.priority_high_rounded,
                            size: 14, color: scheme.error)
                        : (i == 4
                            ? Text(
                                kFaceLabels[face]![0],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _onSticker(colors[i]),
                                ),
                              )
                            : null),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _onSticker(Color c) =>
    c.computeLuminance() > 0.45 ? Colors.black87 : Colors.white;

/// Bottom sheet sửa một mặt với ô lớn (≥ 56dp), bảng màu và nút xoay lưới.
/// Trả về 9 màu mới, hoặc null nếu huỷ.
Future<List<Color>?> showFaceEditor(
  BuildContext context, {
  required String face,
  required List<Color> colors,
}) {
  return showModalBottomSheet<List<Color>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FaceEditor(face: face, initial: colors),
  );
}

class _FaceEditor extends StatefulWidget {
  final String face;
  final List<Color> initial;
  const _FaceEditor({required this.face, required this.initial});

  @override
  State<_FaceEditor> createState() => _FaceEditorState();
}

class _FaceEditorState extends State<_FaceEditor> {
  late List<Color> _colors = List.of(widget.initial);
  late Color _pen = RubikColors.all.firstWhere(
    (c) => c != widget.initial[4],
    orElse: () => RubikColors.white,
  );

  void _rotate(List<int> order) {
    setState(() => _colors = [for (final i in order) _colors[i]]);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final grid = (size.width - AppSpacing.xl * 2).clamp(200.0, 300.0);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sửa mặt ${kFaceLabels[widget.face]}', style: text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Chọn màu bên dưới rồi chạm vào ô cần sửa. Ô tâm được khoá.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Container(
                width: grid,
                height: grid,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF151515),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < 9; i++)
                      Semantics(
                        button: i != 4,
                        label:
                            'Ô ${i + 1}, màu ${RubikColors.nameOf(_colors[i])}'
                            '${i == 4 ? ', ô tâm, đã khoá' : ''}',
                        excludeSemantics: true,
                        child: Material(
                          color: _colors[i],
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            onTap: i == 4
                                ? null
                                : () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _colors[i] = _pen);
                                  },
                            child: i == 4
                                ? Icon(Icons.lock_rounded,
                                    color: _onSticker(_colors[i]))
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final c in RubikColors.all)
                  _PenButton(
                    color: c,
                    selected: c == _pen,
                    onTap: () => setState(() => _pen = c),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _RotateButton(
                  icon: Icons.rotate_left_rounded,
                  label: 'Trái',
                  tooltip: 'Xoay mặt sang trái 90°',
                  onTap: () => _rotate(const [2, 5, 8, 1, 4, 7, 0, 3, 6]),
                ),
                _RotateButton(
                  icon: Icons.sync_rounded,
                  label: '180°',
                  tooltip: 'Xoay mặt 180°',
                  onTap: () => _rotate(const [8, 7, 6, 5, 4, 3, 2, 1, 0]),
                ),
                _RotateButton(
                  icon: Icons.rotate_right_rounded,
                  label: 'Phải',
                  tooltip: 'Xoay mặt sang phải 90°',
                  onTap: () => _rotate(const [6, 3, 0, 7, 4, 1, 8, 5, 2]),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.pop(context, _colors),
              child: const Text('Lưu mặt này'),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huỷ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PenButton extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _PenButton(
      {required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Bút màu ${RubikColors.nameOf(color)}',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: SizedBox.square(
          dimension: kMinTouchTarget,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.fast),
              width: selected ? 44 : 38,
              height: selected ? 44 : 38,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outline,
                  width: selected ? 3 : 1,
                ),
              ),
              child: selected
                  ? Icon(Icons.check_rounded,
                      size: 20, color: _onSticker(color))
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _RotateButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  const _RotateButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Tooltip(
          message: tooltip,
          child: OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}
