import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'package:frontend_new/caro/theme/app_tokens.dart';
import 'package:frontend_new/caro/theme/caro_theme.dart';
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
    this.hintCell,
    this.fadingWarningX,
    this.fadingWarningO,
    this.theme = CaroBoardTheme.wood,
    this.interactive = true,
  });

  final Uint8List cells;
  final int version;
  final int? lastMove;
  final int? preview;
  final List<int>? winLine;
  final int? hintCell;
  final int? fadingWarningX;
  final int? fadingWarningO;
  final CaroBoardTheme theme;
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
  late final AnimationController _pulse;
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
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);

    _stoneCount = _count(widget.cells);
    if (widget.winLine != null) _win.value = 1;
  }

  @override
  void dispose() {
    _zoomAnim.dispose();
    _pop.dispose();
    _win.dispose();
    _pulse.dispose();
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
    // Chạm đúp nhanh tại cùng chỗ → zoom
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeData = CaroThemeData.fromTheme(widget.theme, isDark: isDark);

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
                      hintCell: widget.hintCell,
                      fadingWarningX: widget.fadingWarningX,
                      fadingWarningO: widget.fadingWarningO,
                      popCell: _popCell,
                      pop: _pop,
                      win: _win,
                      pulse: _pulse,
                      themeData: themeData,
                      interactive: widget.interactive,
                      onCellTap: widget.onCellTap,
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

/// Vẽ bàn cờ với đa dạng chủ đề và hiệu ứng sinh tồn / gợi ý
class CaroBoardPainter extends CustomPainter {
  CaroBoardPainter({
    required this.cells,
    required this.version,
    required this.lastMove,
    required this.preview,
    required this.winLine,
    required this.hintCell,
    required this.fadingWarningX,
    required this.fadingWarningO,
    required this.popCell,
    required this.pop,
    required this.win,
    required this.pulse,
    required this.themeData,
    required this.interactive,
    required this.onCellTap,
  }) : super(repaint: Listenable.merge([pop, win, pulse]));

  final Uint8List cells;
  final int version;
  final int? lastMove;
  final int? preview;
  final List<int>? winLine;
  final int? hintCell;
  final int? fadingWarningX;
  final int? fadingWarningO;
  final int? popCell;
  final Animation<double> pop;
  final Animation<double> win;
  final Animation<double> pulse;
  final CaroThemeData themeData;
  final bool interactive;
  final ValueChanged<int> onCellTap;

  Color _color(int p) => p == kCaroPlayer ? themeData.xColor : themeData.oColor;

  void _drawSakuraStone(
    Canvas canvas,
    Offset c,
    double cell,
    int p,
    Color col, {
    double scale = 1,
    double alpha = 1,
  }) {
    if (p == kCaroPlayer) {
      final a = cell * 0.26 * scale;
      final petalPaint = Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = cell * 0.15;
      canvas.drawLine(c + Offset(-a, -a), c + Offset(a, a), petalPaint);
      canvas.drawLine(c + Offset(-a, a), c + Offset(a, -a), petalPaint);
      final pistil = Paint()..color = const Color(0xFFFB7185).withValues(alpha: 0.9 * alpha);
      canvas.drawCircle(c, cell * 0.07 * scale, pistil);
    } else {
      final r = cell * 0.26 * scale;
      final rimPaint = Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = cell * 0.13;
      canvas.drawCircle(c, r, rimPaint);
      final innerPaint = Paint()
        ..color = col.withValues(alpha: 0.3 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(c, r * 0.62, innerPaint);
    }
  }

  void _drawGalaxyStone(
    Canvas canvas,
    Offset c,
    double cell,
    int p,
    Color col, {
    double scale = 1,
    double alpha = 1,
  }) {
    if (p == kCaroPlayer) {
      final a = cell * 0.28 * scale;
      final glow = Paint()
        ..color = col.withValues(alpha: 0.4 * alpha)
        ..strokeWidth = cell * 0.16
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      final core = Paint()
        ..color = col
        ..strokeWidth = cell * 0.12
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(c + Offset(-a, -a), c + Offset(a, a), glow);
      canvas.drawLine(c + Offset(-a, a), c + Offset(a, -a), glow);
      canvas.drawLine(c + Offset(-a, -a), c + Offset(a, a), core);
      canvas.drawLine(c + Offset(-a, a), c + Offset(a, -a), core);
      final whiteCore = Paint()..color = Colors.white.withValues(alpha: 0.9 * alpha);
      canvas.drawCircle(c, cell * 0.08 * scale, whiteCore);
    } else {
      final r = cell * 0.22 * scale;
      final planetPaint = Paint()..color = col;
      canvas.drawCircle(c, r, planetPaint);
      final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.25 * alpha);
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 4, math.pi, true, shadowPaint);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-math.pi / 6);
      final ringPaint = Paint()
        ..color = const Color(0xFFFEF08A).withValues(alpha: 0.9 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.06;
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2.8, height: r * 0.9), ringPaint);
      canvas.restore();
    }
  }

  void _drawCalligraphyStone(
    Canvas canvas,
    Offset c,
    double cell,
    int p,
    Color col, {
    double scale = 1,
    double alpha = 1,
  }) {
    if (p == kCaroPlayer) {
      final a = cell * 0.26 * scale;
      final brushPaint = Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = cell * 0.15;
      final p1 = Path()
        ..moveTo(c.dx - a, c.dy - a * 0.85)
        ..quadraticBezierTo(c.dx - a * 0.15, c.dy - a * 0.05, c.dx + a, c.dy + a * 0.95);
      final p2 = Path()
        ..moveTo(c.dx - a * 0.85, c.dy + a)
        ..quadraticBezierTo(c.dx + a * 0.05, c.dy - a * 0.15, c.dx + a * 0.95, c.dy - a * 0.85);
      canvas.drawPath(p1, brushPaint);
      canvas.drawPath(p2, brushPaint);
    } else {
      final r = cell * 0.26 * scale;
      final sealRect = Rect.fromCenter(center: c, width: r * 2, height: r * 2);
      final sealPaint = Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.13;
      canvas.drawRRect(RRect.fromRectAndRadius(sealRect, Radius.circular(r * 0.3)), sealPaint);
      final innerPaint = Paint()..color = col;
      canvas.drawCircle(c, cell * 0.08 * scale, innerPaint);
    }
  }

  void _drawPixelStone(
    Canvas canvas,
    Offset c,
    double cell,
    int p,
    Color col, {
    double scale = 1,
    double alpha = 1,
  }) {
    final px = (cell * 0.075 * scale).clamp(1.5, 4.0);
    final paint = Paint()..color = col;
    if (p == kCaroPlayer) {
      const coords = [
        [-3, -3], [-2, -2], [-1, -1], [0, 0], [1, 1], [2, 2], [3, 3],
        [-3, 3], [-2, 2], [-1, 1], [1, -1], [2, -2], [3, -3],
        [-3, -2], [-2, -3], [2, 3], [3, 2],
        [-3, 2], [-2, 3], [2, -3], [3, -2],
      ];
      for (final pt in coords) {
        canvas.drawRect(Rect.fromLTWH(c.dx + pt[0] * px - px / 2, c.dy + pt[1] * px - px / 2, px, px), paint);
      }
    } else {
      const coords = [
        [-1, -3], [0, -3], [1, -3],
        [-1, 3], [0, 3], [1, 3],
        [-3, -1], [-3, 0], [-3, 1],
        [3, -1], [3, 0], [3, 1],
        [-2, -2], [2, -2],
        [-2, 2], [2, 2],
        [-2, -3], [2, -3], [-2, 3], [2, 3],
        [-3, -2], [-3, 2], [3, -2], [3, 2],
      ];
      for (final pt in coords) {
        canvas.drawRect(Rect.fromLTWH(c.dx + pt[0] * px - px / 2, c.dy + pt[1] * px - px / 2, px, px), paint);
      }
    }
  }

  void _stone(
    Canvas canvas,
    Offset c,
    double cell,
    int p, {
    double scale = 1,
    double alpha = 1,
  }) {
    final col = _color(p).withValues(alpha: alpha);

    // 1. Hoa anh đào
    if (themeData.isSakura) {
      _drawSakuraStone(canvas, c, cell, p, col, scale: scale, alpha: alpha);
      return;
    }

    // 2. Thiên hà
    if (themeData.isGalaxy) {
      _drawGalaxyStone(canvas, c, cell, p, col, scale: scale, alpha: alpha);
      return;
    }

    // 3. Thư pháp
    if (themeData.isCalligraphy) {
      _drawCalligraphyStone(canvas, c, cell, p, col, scale: scale, alpha: alpha);
      return;
    }

    // 4. Pixel 8-bit
    if (themeData.isPixel) {
      _drawPixelStone(canvas, c, cell, p, col, scale: scale, alpha: alpha);
      return;
    }

    // 5. Cờ vây đá 3D
    if (themeData.isGoStones) {
      final r = cell * 0.38 * scale;
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.25 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(c + const Offset(1.2, 2.0), r, shadowPaint);

      if (p == kCaroPlayer) {
        // Quân đen
        final blackPaint = Paint()..color = const Color(0xFF1F2428).withValues(alpha: alpha);
        canvas.drawCircle(c, r, blackPaint);
        // Vệt sáng highlight
        final highlight = Paint()..color = Colors.white.withValues(alpha: 0.25 * alpha);
        canvas.drawCircle(c + Offset(-r * 0.3, -r * 0.3), r * 0.32, highlight);
      } else {
        // Quân trắng
        final whitePaint = Paint()..color = const Color(0xFFF8FAFC).withValues(alpha: alpha);
        canvas.drawCircle(c, r, whitePaint);
        final rimPaint = Paint()
          ..color = const Color(0xFFCBD5E1).withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        canvas.drawCircle(c, r, rimPaint);
        final highlight = Paint()..color = Colors.white.withValues(alpha: 0.6 * alpha);
        canvas.drawCircle(c + Offset(-r * 0.28, -r * 0.28), r * 0.35, highlight);
      }
      return;
    }

    // 6. Cyberpunk Neon
    if (themeData.isNeonGlow) {
      final glowPaint = Paint()
        ..color = col.withValues(alpha: 0.45 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = cell * 0.18
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);

      final linePaint = Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = cell * 0.12;

      if (p == kCaroPlayer) {
        final a = cell * 0.25 * scale;
        // Lớp phát sáng
        canvas.drawLine(c + Offset(-a, -a), c + Offset(a, a), glowPaint);
        canvas.drawLine(c + Offset(-a, a), c + Offset(a, -a), glowPaint);
        // Lớp nét chính
        canvas.drawLine(c + Offset(-a, -a), c + Offset(a, a), linePaint);
        canvas.drawLine(c + Offset(-a, a), c + Offset(a, -a), linePaint);
      } else {
        canvas.drawCircle(c, cell * 0.28 * scale, glowPaint);
        canvas.drawCircle(c, cell * 0.28 * scale, linePaint);
      }
      return;
    }

    // 7. Kiểu Vở ô ly hoặc Gỗ cổ điển
    final paint = Paint()
      ..color = col
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

    // 1. Mặt bàn
    canvas.drawRRect(
      RRect.fromRectAndRadius(gridRect.inflate(6), const Radius.circular(AppRadius.md)),
      Paint()..color = themeData.surfaceColor,
    );

    // Viền mép vở nếu là notebook theme
    if (themeData.isPaperGrid) {
      final marginPaint = Paint()
        ..color = const Color(0xFFFCA5A5).withValues(alpha: 0.6)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(g + cell * 0.8, g), Offset(g + cell * 0.8, g + cell * kCaroSize), marginPaint);
    }

    // 2. Lưới ô vuông
    final line = Paint()
      ..color = themeData.gridColor
      ..strokeWidth = themeData.isPaperGrid ? 0.8 : 1.0;
    for (var i = 0; i <= kCaroSize; i++) {
      final o = g + i * cell;
      canvas.drawLine(Offset(g, o), Offset(g + cell * kCaroSize, o), line);
      canvas.drawLine(Offset(o, g), Offset(o, g + cell * kCaroSize), line);
    }

    // 3. Điểm mốc (tâm và 4 góc phụ)
    final dot = Paint()..color = themeData.markColor.withValues(alpha: 0.45);
    for (final rc in const [
      [7, 7],
      [3, 3],
      [3, 11],
      [11, 3],
      [11, 11],
    ]) {
      final pt = geo.center(rc[0] * kCaroSize + rc[1]);
      if (themeData.isPixel) {
        canvas.drawRect(Rect.fromCenter(center: pt, width: cell * 0.16, height: cell * 0.16), dot);
      } else if (themeData.isGalaxy) {
        final starPaint = Paint()
          ..color = themeData.markColor.withValues(alpha: 0.8)
          ..strokeWidth = 1.4;
        canvas.drawLine(pt + const Offset(-4, 0), pt + const Offset(4, 0), starPaint);
        canvas.drawLine(pt + const Offset(0, -4), pt + const Offset(0, 4), starPaint);
        canvas.drawCircle(pt, 1.2, Paint()..color = Colors.white);
      } else if (themeData.isSakura) {
        final petalPaint = Paint()..color = themeData.markColor.withValues(alpha: 0.45);
        canvas.drawCircle(pt, cell * 0.08, petalPaint);
        canvas.drawCircle(pt + const Offset(0, -1.5), cell * 0.04, Paint()..color = const Color(0xFFFDA4AF));
      } else {
        canvas.drawCircle(pt, cell * 0.09, dot);
      }
    }

    // 4. Đường thắng: dải sáng bên dưới quân
    final wl = winLine;
    final wt = Curves.easeOutCubic.transform(win.value);
    if (wl != null && wl.length >= 2) {
      final a = geo.center(wl.first), b = geo.center(wl.last);
      final end = Offset.lerp(a, b, wt)!;
      canvas.drawLine(
        a,
        end,
        Paint()
          ..color = themeData.accentColor.withValues(alpha: 0.32)
          ..strokeWidth = cell * 0.9
          ..strokeCap = StrokeCap.round,
      );
    }

    // 5. Nước gợi ý (Hint): Vòng hào quang vàng amber nhấp nháy
    final hc = hintCell;
    if (hc != null && cells[hc] == kCaroEmpty) {
      final center = geo.center(hc);
      final pulseVal = Curves.easeInOut.transform(pulse.value);
      final hintRadius = cell * (0.35 + 0.12 * pulseVal);
      final glowPaint = Paint()
        ..color = themeData.hintColor.withValues(alpha: 0.28 + 0.2 * pulseVal)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, hintRadius, glowPaint);

      final ringPaint = Paint()
        ..color = themeData.hintColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, cell * 0.32, ringPaint);

      final dotPaint = Paint()
        ..color = themeData.hintColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, cell * 0.08, dotPaint);
    }

    // 6. Nước đi cuối
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

    // 7. Quân cờ (có hiệu ứng nhấp nháy cho quân sắp biến mất trong Fading)
    final pulseAlpha = 0.35 + 0.35 * pulse.value;
    for (var i = 0; i < kCaroCells; i++) {
      final p = cells[i];
      if (p == kCaroEmpty) continue;
      var scale = 1.0;
      if (i == popCell) scale = 0.4 + 0.6 * Curves.easeOutBack.transform(pop.value);

      // Cảnh báo quân sắp biến mất
      final isFadingWarning = (p == kCaroPlayer && i == fadingWarningX) ||
          (p == kCaroAi && i == fadingWarningO);
      final alpha = isFadingWarning ? pulseAlpha : 1.0;

      if (isFadingWarning) {
        // Vẽ viền cảnh báo quanh ô cờ sắp biến mất
        final warningRect = geo.cellRect(i).deflate(3);
        canvas.drawRRect(
          RRect.fromRectAndRadius(warningRect, Radius.circular(cell * 0.2)),
          Paint()
            ..color = Colors.amber.withValues(alpha: 0.4 * pulse.value)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }

      _stone(canvas, geo.center(i), cell, p, scale: scale, alpha: alpha);
    }

    // 8. Xem trước (ghost)
    final pv = preview;
    if (pv != null && cells[pv] == kCaroEmpty) {
      final rect = geo.cellRect(pv).deflate(1);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.2));
      canvas.drawRRect(rr, Paint()..color = themeData.xColor.withValues(alpha: 0.18));
      canvas.drawRRect(
        rr,
        Paint()
          ..color = themeData.xColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      _stone(canvas, geo.center(pv), cell, kCaroPlayer, alpha: 0.5);
    }

    // 9. Đường thắng: nét đậm phía trên
    if (wl != null && wl.length >= 2) {
      final a = geo.center(wl.first), b = geo.center(wl.last);
      canvas.drawLine(
        a,
        Offset.lerp(a, b, wt)!,
        Paint()
          ..color = themeData.accentColor
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
      oldDelegate.hintCell != hintCell ||
      oldDelegate.fadingWarningX != fadingWarningX ||
      oldDelegate.fadingWarningO != fadingWarningO ||
      oldDelegate.popCell != popCell ||
      oldDelegate.themeData.type != themeData.type;

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
                    '${cells[i] == kCaroEmpty ? 'trống' : cells[i] == kCaroPlayer ? 'quân X' : 'quân O'}'
                    '${i == preview ? ', đang chọn' : ''}'
                    '${i == lastMove ? ', nước vừa đi' : ''}'
                    '${i == hintCell ? ', nước gợi ý' : ''}',
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
      oldDelegate.hintCell != hintCell ||
      oldDelegate.interactive != interactive;
}
