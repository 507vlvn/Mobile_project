import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'package:frontend_new/caro/theme/app_colors.dart';
import 'package:frontend_new/caro/theme/app_tokens.dart';
import '../logic/caro_board.dart';

/// Hình học bàn cờ vuông [side] × [side]: lưới 15×15 ô, chừa lề.
class CaroGeometry {
  const CaroGeometry(this.side);

  final double side;

  /// 16dp lề màn hình + 6dp đệm của mặt bàn.
  static const double gutter = 22;

  double get cell => (side - 2 * gutter) / kCaroSize;

  Rect cellRect(int idx) {
    final r = idx ~/ kCaroSize, c = idx % kCaroSize;
    return Rect.fromLTWH(gutter + c * cell, gutter + r * cell, cell, cell);
  }

  Offset center(int idx) => cellRect(idx).center;

  /// Ô tại [p] (toạ độ cục bộ của bàn), hoặc null nếu ngoài lưới.
  int? hit(Offset p) {
    final c = ((p.dx - gutter) / cell).floor();
    final r = ((p.dy - gutter) / cell).floor();
    if (r < 0 || c < 0 || r >= kCaroSize || c >= kCaroSize) return null;
    return r * kCaroSize + c;
  }
}

/// Bàn cờ Caro: zoom/kéo bằng InteractiveViewer, chạm một ô để chọn.
class CaroBoardView extends StatefulWidget {
  const CaroBoardView({
    super.key,
    required this.cells,
    required this.version,
    required this.onCellTap,
    this.lastMove,
    this.preview,
    this.winLine,
    this.interactive = true,
  });

  final Uint8List cells;
  final int version;
  final int? lastMove;
  final int? preview;
  final List<int>? winLine;
  final bool interactive;
  final ValueChanged<int> onCellTap;

  @override
  State<CaroBoardView> createState() => CaroBoardViewState();
}

class CaroBoardViewState extends State<CaroBoardView> with TickerProviderStateMixin {
  static const double _zoomedScale = 2.0;
  static const Duration _doubleTapWindow = Duration(milliseconds: 280);

  final _tc = TransformationController();
  late final AnimationController _zoomAnim;
  late final AnimationController _pop;
  late final AnimationController _win;
  Animation<Matrix4>? _zoomTween;

  Size _viewport = Size.zero;
  int _stoneCount = 0;
  int? _popCell;
  DateTime? _lastTapAt;
  Offset? _lastTapGlobal;

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Đang phóng to (so với vừa khung)?
  bool get isZoomed => _tc.value.getMaxScaleOnAxis() > 1.05;

  @override
  void initState() {
    super.initState();
    _zoomAnim = AnimationController(vsync: this, duration: AppMotion.normal)
      ..addListener(() {
        final t = _zoomTween;
        if (t != null) _tc.value = t.value;
      });
    _pop = AnimationController(vsync: this, duration: AppMotion.normal, value: 1);
    _win = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _stoneCount = _count(widget.cells);
    if (widget.winLine != null) _win.value = 1;
  }

  @override
  void dispose() {
    _zoomAnim.dispose();
    _pop.dispose();
    _win.dispose();
    _tc.dispose();
    super.dispose();
  }

  static int _count(Uint8List cells) {
    var n = 0;
    for (final v in cells) {
      if (v != kCaroEmpty) n++;
    }
    return n;
  }

  @override
  void didUpdateWidget(CaroBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.version != oldWidget.version) {
      final n = _count(widget.cells);
      if (n == _stoneCount + 1 && widget.lastMove != null) {
        _popCell = widget.lastMove;
        if (_reduceMotion) {
          _pop.value = 1;
        } else {
          _pop.forward(from: 0);
        }
        HapticFeedback.selectionClick();
      } else {
        _popCell = null;
      }
      _stoneCount = n;
    }
    if (widget.winLine != null && oldWidget.winLine == null) {
      if (_reduceMotion) {
        _win.value = 1;
      } else {
        _win.forward(from: 0);
      }
    } else if (widget.winLine == null) {
      _win.value = 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Zoom
  // ---------------------------------------------------------------------------

  Matrix4 _matrixFor(double scale, Offset scenePoint) {
    final vw = _viewport.width, vh = _viewport.height;
    final tx = (vw / 2 - scale * scenePoint.dx).clamp(vw - scale * vw, 0.0);
    final ty = (vh / 2 - scale * scenePoint.dy).clamp(vh - scale * vh, 0.0);
    return Matrix4.diagonal3Values(scale, scale, 1)..setTranslationRaw(tx, ty, 0);
  }

  Offset get _boardOrigin {
    final s = math.min(_viewport.width, _viewport.height);
    return Offset((_viewport.width - s) / 2, (_viewport.height - s) / 2);
  }

  /// Chuyển giữa vừa khung và phóng 2×, tâm tại [focalCell] (mặc định nước đi cuối).
  void toggleZoom({int? focalCell, Offset? focalBoardPoint}) {
    if (_viewport.isEmpty) return;
    final side = math.min(_viewport.width, _viewport.height);
    final Matrix4 target;
    if (isZoomed) {
      target = Matrix4.identity();
    } else {
      final geo = CaroGeometry(side);
      final cell = focalCell ?? widget.lastMove;
      final Offset local = focalBoardPoint ??
          (cell != null ? geo.center(cell) : Offset(side / 2, side / 2));
      target = _matrixFor(_zoomedScale, local + _boardOrigin);
    }
    if (_reduceMotion) {
      _tc.value = target;
      return;
    }
    _zoomTween = Matrix4Tween(begin: _tc.value.clone(), end: target).animate(
      CurvedAnimation(parent: _zoomAnim, curve: AppMotion.standard),
    );
    _zoomAnim.forward(from: 0);
  }

  // ---------------------------------------------------------------------------
  // Chạm
  // ---------------------------------------------------------------------------

  void _onTapUp(TapUpDetails d, double side) {
    final now = DateTime.now();
    final lastAt = _lastTapAt, lastPos = _lastTapGlobal;
    _lastTapAt = now;
    _lastTapGlobal = d.globalPosition;
    // Chạm đúp nhanh tại cùng chỗ → zoom (nước đi vẫn do lần chạm đầu xử lý, không trễ).
    if (lastAt != null &&
        lastPos != null &&
        now.difference(lastAt) < _doubleTapWindow &&
        (d.globalPosition - lastPos).distance < 36) {
      _lastTapAt = null;
      toggleZoom(focalBoardPoint: d.localPosition);
      return;
    }
    if (!widget.interactive) return;
    final idx = CaroGeometry(side).hit(d.localPosition);
    if (idx != null) widget.onCellTap(idx);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    return LayoutBuilder(
      builder: (context, c) {
        final vp = Size(c.maxWidth, c.maxHeight);
        if (vp != _viewport) {
          final hadViewport = !_viewport.isEmpty;
          _viewport = vp;
          if (hadViewport) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _tc.value = Matrix4.identity();
            });
          }
        }
        final side = math.min(vp.width, vp.height);
        return InteractiveViewer(
          transformationController: _tc,
          minScale: 1,
          maxScale: 3.5,
          boundaryMargin: EdgeInsets.zero,
          child: SizedBox(
            width: vp.width,
            height: vp.height,
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _onTapUp(d, side),
                child: Semantics(
                  container: true,
                  label: 'Bàn cờ Caro 15 nhân 15',
                  child: CustomPaint(
                    size: Size(side, side),
                    painter: CaroBoardPainter(
                      cells: widget.cells,
                      version: widget.version,
                      lastMove: widget.lastMove,
                      preview: widget.preview,
                      winLine: widget.winLine,
                      popCell: _popCell,
                      pop: _pop,
                      win: _win,
                      interactive: widget.interactive,
                      onCellTap: widget.onCellTap,
                      surface: palette.stage,
                      grid: scheme.brightness == Brightness.dark
                          ? scheme.outlineVariant.withValues(alpha: 0.55)
                          : scheme.outlineVariant,
                      xColor: scheme.primary,
                      oColor: scheme.tertiary,
                      accent: palette.accent,
                      mark: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Vẽ bàn cờ: mặt bàn, lưới, quân X/O (vector), nước cuối, xem trước, đường thắng.
class CaroBoardPainter extends CustomPainter {
  CaroBoardPainter({
    required this.cells,
    required this.version,
    required this.lastMove,
    required this.preview,
    required this.winLine,
    required this.popCell,
    required this.pop,
    required this.win,
    required this.interactive,
    required this.onCellTap,
    required this.surface,
    required this.grid,
    required this.xColor,
    required this.oColor,
    required this.accent,
    required this.mark,
  }) : super(repaint: Listenable.merge([pop, win]));

  final Uint8List cells;
  final int version;
  final int? lastMove;
  final int? preview;
  final List<int>? winLine;
  final int? popCell;
  final Animation<double> pop;
  final Animation<double> win;
  final bool interactive;
  final ValueChanged<int> onCellTap;
  final Color surface, grid, xColor, oColor, accent, mark;

  Color _color(int p) => p == kCaroPlayer ? xColor : oColor;

  void _stone(Canvas canvas, Offset c, double cell, int p, {double scale = 1, double alpha = 1}) {
    final paint = Paint()
      ..color = _color(p).withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = cell * 0.13;
    if (p == kCaroPlayer) {
      final a = cell * 0.25 * scale;
      canvas.drawLine(c + Offset(-a, -a), c + Offset(a, a), paint);
      canvas.drawLine(c + Offset(-a, a), c + Offset(a, -a), paint);
    } else {
      canvas.drawCircle(c, cell * 0.28 * scale, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final geo = CaroGeometry(size.shortestSide);
    final cell = geo.cell;
    final g = CaroGeometry.gutter;
    final gridRect = Rect.fromLTWH(g, g, cell * kCaroSize, cell * kCaroSize);

    // Mặt bàn
    canvas.drawRRect(
      RRect.fromRectAndRadius(gridRect.inflate(6), const Radius.circular(AppRadius.md)),
      Paint()..color = surface,
    );

    // Lưới
    final line = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= kCaroSize; i++) {
      final o = g + i * cell;
      canvas.drawLine(Offset(g, o), Offset(g + cell * kCaroSize, o), line);
      canvas.drawLine(Offset(o, g), Offset(o, g + cell * kCaroSize), line);
    }

    // Điểm mốc (tâm và 4 góc phụ) giúp định hướng khi zoom
    final dot = Paint()..color = mark.withValues(alpha: 0.28);
    for (final rc in const [
      [7, 7],
      [3, 3],
      [3, 11],
      [11, 3],
      [11, 11],
    ]) {
      canvas.drawCircle(geo.center(rc[0] * kCaroSize + rc[1]), cell * 0.09, dot);
    }

    // Đường thắng: dải sáng bên dưới quân
    final wl = winLine;
    final wt = Curves.easeOutCubic.transform(win.value);
    if (wl != null && wl.length >= 2) {
      final a = geo.center(wl.first), b = geo.center(wl.last);
      final end = Offset.lerp(a, b, wt)!;
      canvas.drawLine(
        a,
        end,
        Paint()
          ..color = accent.withValues(alpha: 0.28)
          ..strokeWidth = cell * 0.9
          ..strokeCap = StrokeCap.round,
      );
    }

    // Nước đi cuối
    final lm = lastMove;
    if (lm != null && cells[lm] != kCaroEmpty) {
      final rect = geo.cellRect(lm).deflate(1.5);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.2));
      final col = _color(cells[lm]);
      canvas.drawRRect(rr, Paint()..color = col.withValues(alpha: 0.16));
      canvas.drawRRect(
        rr,
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Quân
    for (var i = 0; i < kCaroCells; i++) {
      final p = cells[i];
      if (p == kCaroEmpty) continue;
      var scale = 1.0;
      if (i == popCell) scale = 0.4 + 0.6 * Curves.easeOutBack.transform(pop.value);
      _stone(canvas, geo.center(i), cell, p, scale: scale);
    }

    // Xem trước (ghost)
    final pv = preview;
    if (pv != null && cells[pv] == kCaroEmpty) {
      final rect = geo.cellRect(pv).deflate(1);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.2));
      canvas.drawRRect(rr, Paint()..color = xColor.withValues(alpha: 0.18));
      canvas.drawRRect(
        rr,
        Paint()
          ..color = xColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      _stone(canvas, geo.center(pv), cell, kCaroPlayer, alpha: 0.5);
    }

    // Đường thắng: nét đậm phía trên
    if (wl != null && wl.length >= 2) {
      final a = geo.center(wl.first), b = geo.center(wl.last);
      canvas.drawLine(
        a,
        Offset.lerp(a, b, wt)!,
        Paint()
          ..color = accent
          ..strokeWidth = cell * 0.15
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(CaroBoardPainter oldDelegate) =>
      oldDelegate.version != version ||
      oldDelegate.lastMove != lastMove ||
      oldDelegate.preview != preview ||
      oldDelegate.winLine != winLine ||
      oldDelegate.popCell != popCell ||
      oldDelegate.surface != surface ||
      oldDelegate.grid != grid ||
      oldDelegate.xColor != xColor ||
      oldDelegate.oColor != oColor ||
      oldDelegate.accent != accent;

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
        final geo = CaroGeometry(size.shortestSide);
        return [
          for (var i = 0; i < kCaroCells; i++)
            CustomPainterSemantics(
              key: ValueKey(i),
              rect: geo.cellRect(i),
              properties: SemanticsProperties(
                textDirection: TextDirection.ltr,
                label: 'Hàng ${i ~/ kCaroSize + 1} cột ${i % kCaroSize + 1}, '
                    '${cells[i] == kCaroEmpty ? 'trống' : cells[i] == kCaroPlayer ? 'quân X của bạn' : 'quân O của máy'}'
                    '${i == preview ? ', đang chọn' : ''}'
                    '${i == lastMove ? ', nước vừa đi' : ''}',
                button: interactive && cells[i] == kCaroEmpty,
                onTap: interactive && cells[i] == kCaroEmpty ? () => onCellTap(i) : null,
              ),
            ),
        ];
      };

  @override
  bool shouldRebuildSemantics(CaroBoardPainter oldDelegate) =>
      oldDelegate.version != version ||
      oldDelegate.preview != preview ||
      oldDelegate.interactive != interactive;
}
