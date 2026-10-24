import 'package:flutter/material.dart';

import 'cube_geometry.dart';

/// Vẽ khối Rubik từ [CubeGeometry] đã tính sẵn cho khung hình hiện tại.
class Cube3DPainter extends CustomPainter {
  final CubeGeometry geometry;

  /// 0..1 — độ sáng của viền tô sáng (gợi ý), nhấp nháy theo thời gian
  final double highlightPulse;
  final Color highlightColor;

  Cube3DPainter({
    required this.geometry,
    this.highlightPulse = 0,
    this.highlightColor = Colors.white,
  });

  static final _plasticPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  static final _stickerPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  static final _borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = const Color(0xFF0B0B0B)
    ..strokeWidth = 1.2
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  static final _highlightPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    for (final face in geometry.faces) {
      final path = face.toPath();
      _plasticPaint.color = _shade(const Color(0xFF181818), face.lighting);
      canvas.drawPath(path, _plasticPaint);
      canvas.drawPath(path, _borderPaint);

      if (face.sticker == null) continue;

      // Sticker thụt vào trong một chút để lộ viền nhựa đen
      final c = _center(face.points);
      final inset = [
        for (final p in face.points)
          Offset(p.dx + (c.dx - p.dx) * 0.12, p.dy + (c.dy - p.dy) * 0.12),
      ];
      final stickerPath = Path()..addPolygon(inset, true);
      _stickerPaint.color = _shade(face.color, face.lighting);
      canvas.drawPath(stickerPath, _stickerPaint);

      if (face.highlighted && highlightPulse > 0) {
        _highlightPaint
          ..color = highlightColor.withValues(alpha: 0.35 + 0.6 * highlightPulse)
          ..strokeWidth = 2 + 2.5 * highlightPulse;
        canvas.drawPath(stickerPath, _highlightPaint);
      }
    }
  }

  static Offset _center(List<Offset> pts) {
    var x = 0.0, y = 0.0;
    for (final p in pts) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / pts.length, y / pts.length);
  }

  static Color _shade(Color color, double f) => Color.from(
        alpha: color.a,
        red: (color.r * f).clamp(0.0, 1.0),
        green: (color.g * f).clamp(0.0, 1.0),
        blue: (color.b * f).clamp(0.0, 1.0),
      );

  @override
  bool shouldRepaint(covariant Cube3DPainter old) =>
      !identical(old.geometry, geometry) ||
      old.highlightPulse != highlightPulse ||
      old.highlightColor != highlightColor;
}
