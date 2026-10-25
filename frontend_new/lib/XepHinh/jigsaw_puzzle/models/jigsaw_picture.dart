import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

/// Hình dùng để ghép: tranh có sẵn (vẽ bằng code, không cần file ảnh)
/// hoặc ảnh người chơi chọn từ thư viện máy.
class JigsawPicture {
  final String name;

  /// Dựng hình vuông lấp đầy khung được cấp.
  final Widget Function() build;

  /// Đường dẫn ảnh nếu là ảnh của người chơi (null với tranh có sẵn).
  final String? filePath;

  const JigsawPicture._(this.name, this.build, {this.filePath});

  static final builtIns = <JigsawPicture>[
    JigsawPicture._('Hoàng hôn', () => const CustomPaint(painter: _SunsetPainter(), size: Size.infinite)),
    JigsawPicture._('Biển đảo', () => const CustomPaint(painter: _OceanPainter(), size: Size.infinite)),
    JigsawPicture._('Thành phố đêm', () => const CustomPaint(painter: _NightCityPainter(), size: Size.infinite)),
  ];

  factory JigsawPicture.file(String path) => JigsawPicture._(
        'Ảnh của bạn',
        () => Image.file(File(path), fit: BoxFit.cover),
        filePath: path,
      );
}

// ------------------------------------------------------------ tranh có sẵn
// Mỗi tranh có nhiều vùng màu/hình khác nhau để các mảnh dễ phân biệt.

class _SunsetPainter extends CustomPainter {
  const _SunsetPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final horizon = h * 0.62;

    // Bầu trời
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizon),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B1055), Color(0xFF7B2C8F), Color(0xFFF46B45), Color(0xFFFFC371)],
          stops: [0, 0.35, 0.75, 1],
        ).createShader(Rect.fromLTWH(0, 0, w, horizon)),
    );
    // Mặt trời
    canvas.drawCircle(Offset(w * 0.68, horizon * 0.78), w * 0.13, Paint()..color = const Color(0xFFFFE29A));
    // Chim
    final bird = Paint()
      ..color = const Color(0xFF3A1F4F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.008;
    for (final p in [Offset(w * 0.2, h * 0.16), Offset(w * 0.28, h * 0.12), Offset(w * 0.35, h * 0.2)]) {
      final path = Path()
        ..moveTo(p.dx - w * 0.03, p.dy)
        ..quadraticBezierTo(p.dx - w * 0.015, p.dy - w * 0.02, p.dx, p.dy)
        ..quadraticBezierTo(p.dx + w * 0.015, p.dy - w * 0.02, p.dx + w * 0.03, p.dy);
      canvas.drawPath(path, bird);
    }
    // Núi xa
    canvas.drawPath(
      Path()
        ..moveTo(0, horizon)
        ..lineTo(0, h * 0.42)
        ..lineTo(w * 0.22, h * 0.3)
        ..lineTo(w * 0.42, h * 0.45)
        ..lineTo(w * 0.6, h * 0.34)
        ..lineTo(w * 0.85, h * 0.5)
        ..lineTo(w, h * 0.4)
        ..lineTo(w, horizon)
        ..close(),
      Paint()..color = const Color(0xFF5B2A6E),
    );
    // Núi gần
    canvas.drawPath(
      Path()
        ..moveTo(0, horizon)
        ..lineTo(0, h * 0.52)
        ..lineTo(w * 0.15, h * 0.47)
        ..lineTo(w * 0.33, h * 0.58)
        ..lineTo(w * 0.5, h * 0.5)
        ..lineTo(w * 0.7, horizon)
        ..close(),
      Paint()..color = const Color(0xFF2E1640),
    );
    // Hồ
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, w, h - horizon),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9806E), Color(0xFF6A3093), Color(0xFF1F1C4D)],
        ).createShader(Rect.fromLTWH(0, horizon, w, h - horizon)),
    );
    // Bóng mặt trời trên mặt hồ
    final glow = Paint()..color = const Color(0xCCFFE29A);
    for (var i = 0; i < 6; i++) {
      final y = horizon + (h - horizon) * (0.1 + i * 0.14);
      final half = w * (0.12 - i * 0.015);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(w * 0.68, y), width: half * 2, height: h * 0.012),
            const Radius.circular(4)),
        glow,
      );
    }
    // Thuyền
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.2, h * 0.8)
        ..lineTo(w * 0.36, h * 0.8)
        ..lineTo(w * 0.33, h * 0.84)
        ..lineTo(w * 0.23, h * 0.84)
        ..close(),
      Paint()..color = const Color(0xFF1A0E26),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.28, h * 0.79)
        ..lineTo(w * 0.28, h * 0.68)
        ..lineTo(w * 0.35, h * 0.79)
        ..close(),
      Paint()..color = const Color(0xFFFFF1D6),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OceanPainter extends CustomPainter {
  const _OceanPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final horizon = h * 0.48;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizon),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4FACFE), Color(0xFFB3E5FC)],
        ).createShader(Rect.fromLTWH(0, 0, w, horizon)),
    );
    // Mặt trời + mây
    canvas.drawCircle(Offset(w * 0.15, h * 0.13), w * 0.08, Paint()..color = const Color(0xFFFFEB3B));
    final cloud = Paint()..color = Colors.white;
    void puff(double x, double y, double r) {
      canvas.drawCircle(Offset(x, y), r, cloud);
      canvas.drawCircle(Offset(x + r * 0.9, y + r * 0.2), r * 0.8, cloud);
      canvas.drawCircle(Offset(x - r * 0.9, y + r * 0.25), r * 0.7, cloud);
    }
    puff(w * 0.55, h * 0.12, w * 0.06);
    puff(w * 0.82, h * 0.25, w * 0.045);

    // Biển
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, w, h - horizon),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0288D1), Color(0xFF01579B), Color(0xFF002F6C)],
        ).createShader(Rect.fromLTWH(0, horizon, w, h - horizon)),
    );
    // Sóng
    final wave = Paint()
      ..color = const Color(0x99FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.008
      ..strokeCap = StrokeCap.round;
    for (var row = 0; row < 5; row++) {
      final y = horizon + (h - horizon) * (0.18 + row * 0.18);
      for (var i = 0; i < 4; i++) {
        final x = w * (0.1 + i * 0.25 + (row.isOdd ? 0.12 : 0));
        canvas.drawArc(Rect.fromCenter(center: Offset(x, y), width: w * 0.1, height: h * 0.03), pi, pi, false, wave);
      }
    }
    // Đảo + cây dừa
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.72, horizon + h * 0.03), width: w * 0.42, height: h * 0.1),
        Paint()..color = const Color(0xFFF4D58D));
    final trunk = Paint()
      ..color = const Color(0xFF8D6E63)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.72, horizon + h * 0.01)
        ..quadraticBezierTo(w * 0.69, horizon - h * 0.12, w * 0.75, horizon - h * 0.22),
      trunk,
    );
    final leaf = Paint()..color = const Color(0xFF2E7D32);
    final top = Offset(w * 0.75, horizon - h * 0.22);
    for (final a in [-2.6, -1.9, -1.2, -0.5, 0.2]) {
      canvas.save();
      canvas.translate(top.dx, top.dy);
      canvas.rotate(a);
      canvas.drawOval(Rect.fromLTWH(0, -h * 0.02, w * 0.15, h * 0.04), leaf);
      canvas.restore();
    }
    // Thuyền buồm
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.12, h * 0.72)
        ..lineTo(w * 0.36, h * 0.72)
        ..lineTo(w * 0.31, h * 0.77)
        ..lineTo(w * 0.17, h * 0.77)
        ..close(),
      Paint()..color = const Color(0xFFD84315),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.24, h * 0.71)
        ..lineTo(w * 0.24, h * 0.55)
        ..lineTo(w * 0.34, h * 0.71)
        ..close(),
      Paint()..color = Colors.white,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.23, h * 0.71)
        ..lineTo(w * 0.23, h * 0.58)
        ..lineTo(w * 0.15, h * 0.71)
        ..close(),
      Paint()..color = const Color(0xFFFFCC80),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NightCityPainter extends CustomPainter {
  const _NightCityPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0F2B), Color(0xFF1B2A6B), Color(0xFF6A3D9A)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    // Sao (vị trí cố định nhờ seed)
    final rnd = Random(7);
    final star = Paint()..color = Colors.white;
    for (var i = 0; i < 60; i++) {
      canvas.drawCircle(Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.55),
          w * (0.002 + rnd.nextDouble() * 0.004), star);
    }
    // Trăng khuyết
    canvas.drawCircle(Offset(w * 0.78, h * 0.18), w * 0.09, Paint()..color = const Color(0xFFFFF59D));
    canvas.drawCircle(Offset(w * 0.82, h * 0.15), w * 0.08, Paint()..color = const Color(0xFF111A44));
    // Nhà cao tầng
    final buildings = [
      [0.0, 0.62, 0.14], [0.13, 0.48, 0.12], [0.24, 0.56, 0.1], [0.33, 0.38, 0.13],
      [0.45, 0.6, 0.09], [0.53, 0.44, 0.14], [0.66, 0.54, 0.11], [0.76, 0.4, 0.12], [0.87, 0.58, 0.13],
    ];
    final colors = [const Color(0xFF1C1F3B), const Color(0xFF252A52), const Color(0xFF2F2A5C)];
    final window = Paint()..color = const Color(0xFFFFD54F);
    final wr = Random(3);
    for (var i = 0; i < buildings.length; i++) {
      final x = buildings[i][0] * w, top = buildings[i][1] * h, bw = buildings[i][2] * w;
      canvas.drawRect(Rect.fromLTWH(x, top, bw, h - top), Paint()..color = colors[i % colors.length]);
      for (var y = top + h * 0.03; y < h - h * 0.05; y += h * 0.05) {
        for (var wx = x + bw * 0.15; wx < x + bw - bw * 0.2; wx += bw * 0.3) {
          if (wr.nextDouble() < 0.55) {
            canvas.drawRect(Rect.fromLTWH(wx, y, bw * 0.16, h * 0.022), window);
          }
        }
      }
    }
    // Ăng-ten có đèn đỏ
    canvas.drawLine(Offset(w * 0.395, h * 0.38), Offset(w * 0.395, h * 0.3),
        Paint()
          ..color = const Color(0xFF9E9E9E)
          ..strokeWidth = w * 0.006);
    canvas.drawCircle(Offset(w * 0.395, h * 0.3), w * 0.012, Paint()..color = const Color(0xFFFF5252));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
