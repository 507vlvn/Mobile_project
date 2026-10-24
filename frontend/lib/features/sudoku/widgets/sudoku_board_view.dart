import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../logic/sudoku_board.dart';

/// Lưới Sudoku 9×9: đường mảnh giữa ô, đường đậm giữa các khối 3×3.
/// [board] = null vẽ lưới trống (màn chọn độ khó / đang sinh đề).
class SudokuBoardView extends StatelessWidget {
  final SudokuBoard? board;
  final int? selected;
  final ValueChanged<int> onTap;

  /// 0→1 trong lúc nhấp nháy khi hoàn thành hàng/cột/khối
  final Animation<double> flash;
  final Set<int> flashCells;

  const SudokuBoardView({
    super.key,
    required this.board,
    required this.selected,
    required this.onTap,
    required this.flash,
    this.flashCells = const {},
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thin = scheme.outline.withValues(alpha: 0.55);
    final thick = Color.alphaBlend(
        scheme.onSurface.withValues(alpha: 0.55), scheme.outline);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: flash,
              builder: (context, _) {
                final pulse = math.sin(flash.value * math.pi);
                return Column(
                  children: [
                    for (var r = 0; r < 9; r++)
                      Expanded(
                        child: Row(
                          children: [
                            for (var c = 0; c < 9; c++)
                              Expanded(
                                child: _Cell(
                                  index: r * 9 + c,
                                  board: board,
                                  selected: selected,
                                  flash: flashCells.contains(r * 9 + c)
                                      ? pulse
                                      : 0,
                                  onTap: onTap,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            IgnorePointer(
              child:
                  CustomPaint(painter: _GridPainter(thin: thin, thick: thick)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color thin;
  final Color thick;
  const _GridPainter({required this.thin, required this.thick});

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 9;
    final thinPaint = Paint()
      ..color = thin
      ..strokeWidth = 1;
    final thickPaint = Paint()
      ..color = thick
      ..strokeWidth = 2.5;
    for (var i = 1; i < 9; i++) {
      if (i % 3 == 0) continue;
      final p = cell * i;
      canvas.drawLine(Offset(p, 0), Offset(p, size.height), thinPaint);
      canvas.drawLine(Offset(0, p), Offset(size.width, p), thinPaint);
    }
    for (var i = 0; i <= 3; i++) {
      final p = cell * 3 * i;
      canvas.drawLine(Offset(p, 0), Offset(p, size.height), thickPaint);
      canvas.drawLine(Offset(0, p), Offset(size.width, p), thickPaint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.thin != thin || old.thick != thick;
}

class _Cell extends StatelessWidget {
  final int index;
  final SudokuBoard? board;
  final int? selected;
  final double flash;
  final ValueChanged<int> onTap;

  const _Cell({
    required this.index,
    required this.board,
    required this.selected,
    required this.flash,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final success = context.palette.success;
    final b = board;
    final r = SudokuBoard.rowOf(index), c = SudokuBoard.colOf(index);

    final value = b?.values[index] ?? 0;
    final given = b?.isGiven(index) ?? false;
    final wrong = b?.isWrong(index) ?? false;
    final notes = b?.notes[index] ?? const <int>{};
    final sel = selected;
    final selValue = (sel != null && b != null) ? b.values[sel] : 0;

    final isSelected = sel == index;
    final isPeer = sel != null && SudokuBoard.arePeers(sel, index);
    final isSame = selValue != 0 && value == selValue && !isSelected;

    // Lớp màu nền: peer rất nhạt < cùng số < ô sai < ô đang chọn
    var bg = scheme.surface;
    if (isPeer) {
      bg = Color.alphaBlend(
          scheme.primary.withValues(alpha: isDark ? 0.14 : 0.07), bg);
    }
    if (isSame) {
      bg = Color.alphaBlend(
          scheme.primary.withValues(alpha: isDark ? 0.34 : 0.22), bg);
    }
    if (wrong) {
      bg = Color.alphaBlend(
          scheme.error.withValues(alpha: isDark ? 0.22 : 0.13), bg);
    }
    if (isSelected) {
      bg = Color.alphaBlend(
        scheme.primary.withValues(alpha: isDark ? 0.55 : 0.3),
        scheme.surface,
      );
    }
    if (flash > 0) {
      bg = Color.alphaBlend(success.withValues(alpha: 0.5 * flash), bg);
    }

    final userColor = isDark ? scheme.secondary : scheme.primary;
    final digitColor = wrong
        ? scheme.error
        : given
            ? scheme.onSurface
            : userColor;

    final String label;
    if (value != 0) {
      label = 'Hàng ${r + 1} cột ${c + 1}, số $value, '
          '${given ? 'ô đề bài' : wrong ? 'ô điền sai' : 'ô đã điền'}';
    } else if (notes.isNotEmpty) {
      label =
          'Hàng ${r + 1} cột ${c + 1}, trống, ghi chú ${(notes.toList()..sort()).join(', ')}';
    } else {
      label = 'Hàng ${r + 1} cột ${c + 1}, trống';
    }

    return Semantics(
      label: label,
      button: true,
      selected: isSelected,
      excludeSemantics: true,
      onTap: b == null ? null : () => onTap(index),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: b == null ? null : (_) => onTap(index),
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.maxWidth;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: bg,
                border: isSelected
                    ? Border.all(color: scheme.primary, width: 2.5)
                    : null,
              ),
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  if (value != 0)
                    Center(
                      child: Text(
                        '$value',
                        style: TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: size * 0.58,
                          height: 1.1,
                          fontWeight: given ? FontWeight.w700 : FontWeight.w500,
                          color: digitColor,
                          fontFeatures: kTabularFigures,
                          decoration: wrong ? TextDecoration.underline : null,
                          decorationStyle: TextDecorationStyle.wavy,
                          decorationColor: scheme.error,
                        ),
                      ),
                    )
                  else if (notes.isNotEmpty)
                    _Notes(
                        notes: notes,
                        size: size,
                        highlight: selValue,
                        highlightColor: userColor),
                  if (wrong)
                    Positioned(
                      top: 1.5,
                      right: 1.5,
                      child: Icon(Icons.error_rounded,
                          size: math.max(10, size * 0.27), color: scheme.error),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Notes extends StatelessWidget {
  final Set<int> notes;
  final double size;
  final int highlight;
  final Color highlightColor;
  const _Notes({
    required this.notes,
    required this.size,
    required this.highlight,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fontSize = math.max(10.0, size * 0.27);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Column(
        children: [
          for (var r = 0; r < 3; r++)
            Expanded(
              child: Row(
                children: [
                  for (var c = 0; c < 3; c++)
                    Expanded(
                      child: Center(
                        child: notes.contains(r * 3 + c + 1)
                            ? Text(
                                '${r * 3 + c + 1}',
                                style: TextStyle(
                                  fontFamily: kFontFamily,
                                  fontSize: fontSize,
                                  height: 1,
                                  fontWeight: highlight == r * 3 + c + 1
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: highlight == r * 3 + c + 1
                                      ? highlightColor
                                      : scheme.onSurfaceVariant,
                                ),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
