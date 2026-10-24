import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';

/// Bảng trượt ô số: ô là thẻ bo góc, trượt mượt bằng [AnimatedPositioned].
///
/// - Chạm một ô → [onTileTap] (ô cùng hàng/cột với ô trống sẽ trượt cả đoạn).
/// - Vuốt theo một hướng → trượt ô kề ô trống ở phía đối diện hướng vuốt vào ô trống.
/// - Ô không trượt được rung nhẹ qua [PuzzleBoardViewState.shake].
class PuzzleBoardView extends StatefulWidget {
  final List<int> board;
  final int n;
  final double side;
  final int? hintIndex;
  final bool interactive;
  final bool showCorrect;
  final ValueChanged<int>? onTileTap;

  const PuzzleBoardView({
    super.key,
    required this.board,
    required this.n,
    required this.side,
    this.hintIndex,
    this.interactive = true,
    this.showCorrect = true,
    this.onTileTap,
  });

  @override
  State<PuzzleBoardView> createState() => PuzzleBoardViewState();
}

class PuzzleBoardViewState extends State<PuzzleBoardView> with TickerProviderStateMixin {
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: AppMotion.slow);
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  int? _shakeTile;
  Offset? _panStart;
  bool _panDone = false;

  double get _pad => math.max(6, widget.side * 0.02);
  double get _cell => (widget.side - _pad * 2) / widget.n;

  @override
  void didUpdateWidget(covariant PuzzleBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  void _syncPulse() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.hintIndex != null && !reduce) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = widget.hintIndex != null ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Rung nhẹ ô đang ở vị trí [index] (bỏ qua khi người dùng giảm chuyển động).
  void shake(int index) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    _shakeTile = widget.board[index];
    _shake.forward(from: 0);
  }

  int? _indexAt(Offset p) {
    final x = p.dx - _pad, y = p.dy - _pad;
    if (x < 0 || y < 0) return null;
    final c = x ~/ _cell, r = y ~/ _cell;
    if (c >= widget.n || r >= widget.n) return null;
    return r * widget.n + c;
  }

  void _onSwipe(Offset d) {
    final n = widget.n;
    final blank = widget.board.indexOf(0);
    final r = blank ~/ n, c = blank % n;
    int? src;
    if (d.dx.abs() > d.dy.abs()) {
      // Vuốt sang phải → ô bên trái ô trống trượt sang phải.
      final nc = d.dx > 0 ? c - 1 : c + 1;
      if (nc >= 0 && nc < n) src = r * n + nc;
    } else {
      final nr = d.dy > 0 ? r - 1 : r + 1;
      if (nr >= 0 && nr < n) src = nr * n + c;
    }
    if (src != null) widget.onTileTap?.call(src);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final n = widget.n;
    final cell = _cell;
    final gap = cell * 0.04 + 1.5;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final slideDur = AppMotion.of(context, AppMotion.normal);
    final blank = widget.board.indexOf(0);
    final correct = widget.showCorrect
        ? [for (var i = 0; i < widget.board.length; i++) widget.board[i] != 0 && widget.board[i] == i + 1]
        : const <bool>[];
    final correctTotal = correct.where((e) => e).length;

    Offset posOf(int i) => Offset(_pad + (i % n) * cell, _pad + (i ~/ n) * cell);

    final slotColor = Color.alphaBlend(scheme.shadow.withValues(alpha: 0.10), palette.stage);

    final children = <Widget>[
      // Ô nền (ô trống là một khe lõm)
      for (var i = 0; i < n * n; i++)
        Positioned(
          left: posOf(i).dx + gap,
          top: posOf(i).dy + gap,
          width: cell - gap * 2,
          height: cell - gap * 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: slotColor,
              borderRadius: BorderRadius.circular(cell * 0.16),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
          ),
        ),
      for (var t = 1; t < n * n; t++)
        _buildTile(context, t, widget.board.indexOf(t), cell, gap, blank, slideDur, reduce,
            correct.isNotEmpty && correct[widget.board.indexOf(t)]),
    ];

    final board = Container(
      width: widget.side,
      height: widget.side,
      decoration: BoxDecoration(
        color: palette.stage,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Stack(children: children),
    );

    return Semantics(
      container: true,
      label: 'Bảng xếp hình $n nhân $n'
          '${widget.showCorrect ? ', $correctTotal ô đúng vị trí' : ''}',
      child: widget.interactive
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                final i = _indexAt(d.localPosition);
                if (i != null && widget.board[i] != 0) widget.onTileTap?.call(i);
              },
              onPanDown: (d) {
                _panStart = d.localPosition;
                _panDone = false;
              },
              onPanUpdate: (d) {
                if (_panDone || _panStart == null) return;
                final delta = d.localPosition - _panStart!;
                if (delta.distance > math.min(cell * 0.35, 28)) {
                  _panDone = true;
                  _onSwipe(delta);
                }
              },
              child: board,
            )
          : board,
    );
  }

  Widget _buildTile(BuildContext context, int tile, int index, double cell, double gap, int blank,
      Duration slideDur, bool reduce, bool isCorrect) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final n = widget.n;
    final row = index ~/ n, col = index % n;
    final movable = widget.interactive && (row == blank ~/ n || col == blank % n);
    final isHint = widget.hintIndex == index;
    final size = cell - gap * 2;
    final fontSize = math.max(18.0, size * 0.42);

    Widget face = Container(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(cell * 0.16),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.22),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              '$tile',
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: scheme.onPrimary,
                fontFeatures: kTabularFigures,
                height: 1.1,
              ),
            ),
          ),
          if (isCorrect)
            Positioned(
              top: size * 0.07,
              right: size * 0.07,
              child: Icon(
                Icons.check_circle_rounded,
                size: math.max(12, size * 0.2),
                color: scheme.onPrimary.withValues(alpha: 0.85),
              ),
            ),
        ],
      ),
    );

    if (isHint) {
      final arrow = _arrowFor(index, blank);
      face = AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_pulse.value);
          return Transform.scale(
            scale: 1 + 0.05 * t,
            child: Stack(
              fit: StackFit.expand,
              children: [
                child!,
                // Viền kép: vòng ngoài màu cảnh báo, vòng trong màu chữ để nổi trên nền tím.
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(cell * 0.16),
                    border: Border.all(
                      color: Color.lerp(palette.warning.withValues(alpha: 0.6), palette.warning, t)!,
                      width: 3 + 1.5 * t,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(4.5 + 1.5 * t),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(cell * 0.12),
                      border: Border.all(color: scheme.onPrimary, width: 2),
                    ),
                  ),
                ),
                Positioned(
                  left: size * 0.06,
                  bottom: size * 0.06,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: palette.warning, shape: BoxShape.circle),
                    child: Icon(arrow, size: math.max(14, size * 0.24), color: scheme.surface),
                  ),
                ),
              ],
            ),
          );
        },
        child: face,
      );
    }

    final label = 'Ô số $tile, hàng ${row + 1} cột ${col + 1}'
        '${isCorrect ? ', đúng vị trí' : ''}'
        '${isHint ? ', gợi ý: nên trượt ô này' : ''}'
        '${widget.interactive ? (movable ? ', chạm để trượt' : ', chưa trượt được') : ''}';

    return AnimatedPositioned(
      key: ValueKey(tile),
      duration: slideDur,
      curve: AppMotion.standard,
      left: _pad + col * cell + gap,
      top: _pad + row * cell + gap,
      width: size,
      height: size,
      child: Semantics(
        label: label,
        button: widget.interactive,
        onTap: widget.interactive ? () => widget.onTileTap?.call(index) : null,
        excludeSemantics: true,
        child: AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final active = _shakeTile == tile && _shake.isAnimating;
            final dx = active ? math.sin(_shake.value * math.pi * 4) * (1 - _shake.value) * cell * 0.07 : 0.0;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: face,
        ),
      ),
    );
  }

  IconData _arrowFor(int index, int blank) {
    final n = widget.n;
    if (blank == index - 1) return Icons.arrow_back_rounded;
    if (blank == index + 1) return Icons.arrow_forward_rounded;
    if (blank == index - n) return Icons.arrow_upward_rounded;
    return Icons.arrow_downward_rounded;
  }
}
