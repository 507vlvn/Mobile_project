import 'dart:math' as math;
import 'dart:ui';

import '../model/cube_model.dart';

/// Camera nhìn khối Rubik: xoay yaw (quanh Y) rồi pitch (quanh X), chiếu phối cảnh.
class CubeCamera {
  final Size size;
  final double pitch;
  final double yaw;
  final double zoom;

  /// Khoảng cách mắt tới tâm khối (px). Mắt nằm tại (0, 0, +distance) trong hệ camera.
  static const double distance = 900;

  CubeCamera({
    required this.size,
    required this.pitch,
    required this.yaw,
    this.zoom = 1,
  });

  Offset get center => Offset(size.width / 2, size.height / 2);

  /// Khoảng cách giữa tâm hai viên lập phương nhỏ liền kề (px).
  double get cubieSize => math.min(size.width, size.height) * 0.205 * zoom;

  List<double> toCamera(List<double> p) =>
      rotateAxis(rotateAxis(p, 1, yaw), 0, pitch);

  Offset project(List<double> camPoint) {
    final f = distance / (distance - camPoint[2]);
    return Offset(center.dx + camPoint[0] * f, center.dy + camPoint[1] * f);
  }

  Offset projectWorld(List<double> worldPoint) => project(toCamera(worldPoint));
}

/// Quay điểm [p] quanh trục [axis] (0=X, 1=Y, 2=Z) một góc [angle] (quy tắc bàn tay phải).
List<double> rotateAxis(List<double> p, int axis, double angle) {
  if (angle == 0) return p;
  final c = math.cos(angle), s = math.sin(angle);
  switch (axis) {
    case 0:
      return [p[0], p[1] * c - p[2] * s, p[1] * s + p[2] * c];
    case 1:
      return [p[0] * c + p[2] * s, p[1], -p[0] * s + p[2] * c];
    default:
      return [p[0] * c - p[1] * s, p[0] * s + p[1] * c, p[2]];
  }
}

/// Một mặt (tứ giác) đã chiếu lên màn hình.
class RenderFace {
  final List<Offset> points;
  final StickerRef? sticker; // null = mặt nhựa bên trong
  final Color color;
  final double lighting;
  final bool highlighted;

  const RenderFace({
    required this.points,
    required this.sticker,
    required this.color,
    required this.lighting,
    required this.highlighted,
  });

  Path toPath() => Path()..addPolygon(points, true);
}

/// Danh sách mặt đã sắp xếp theo thứ tự vẽ (xa → gần) cho một khung hình.
/// Dùng chung cho việc vẽ và xác định ô được chạm.
class CubeGeometry {
  final List<RenderFace> faces;
  final CubeCamera camera;

  const CubeGeometry._(this.faces, this.camera);

  static const _cubieHalf = 0.48; // nửa cạnh viên nhỏ (đơn vị = khoảng cách tâm)
  static const _plastic = Color(0xFF151515);
  static final _light = _normalize([0.4, -0.6, 0.7]);

  // 6 hướng mặt của một viên lập phương nhỏ
  static const _dirs = [
    [1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1],
  ];

  factory CubeGeometry.build({
    required Cube3DState state,
    required CubeCamera camera,
    LayerTurn? turn,
    LayerTurn? highlight,
  }) {
    final unit = camera.cubieSize;
    final eye = [0.0, 0.0, CubeCamera.distance];
    final cubies = <_CubieDraw>[];

    for (var x = -1; x <= 1; x++) {
      for (var y = -1; y <= 1; y++) {
        for (var z = -1; z <= 1; z++) {
          if (x == 0 && y == 0 && z == 0) continue;

          final inTurn = turn != null && turn.contains(x, y, z);
          List<double> toCam(List<double> world) {
            final p = inTurn ? rotateAxis(world, turn.axis, turn.angle) : world;
            return camera.toCamera(p);
          }

          final centerCam = toCam([x * unit, y * unit, z * unit]);
          final faceDraws = <RenderFace>[];
          final highlighted = highlight != null && highlight.contains(x, y, z);

          for (final d in _dirs) {
            // Mặt bên trong chỉ cần vẽ khi có tầng đang xoay (lộ khe hở)
            final exterior = (d[0] != 0 && d[0] == x) ||
                (d[1] != 0 && d[1] == y) ||
                (d[2] != 0 && d[2] == z);
            if (!exterior && turn == null) continue;

            // toCam chỉ gồm các phép quay quanh gốc nên áp dụng được cho cả pháp tuyến
            final normalCam = toCam([d[0].toDouble(), d[1].toDouble(), d[2].toDouble()]);
            final faceCenterCam = toCam([
              (x + d[0] * _cubieHalf) * unit,
              (y + d[1] * _cubieHalf) * unit,
              (z + d[2] * _cubieHalf) * unit,
            ]);
            // Back-face culling theo phối cảnh: mặt phải hướng về phía mắt
            final toEye = [
              eye[0] - faceCenterCam[0],
              eye[1] - faceCenterCam[1],
              eye[2] - faceCenterCam[2],
            ];
            if (_dot(normalCam, toEye) <= 0) continue;

            final corners = _faceCorners(d).map((c) {
              return camera.project(toCam([
                (x + c[0]) * unit,
                (y + c[1]) * unit,
                (z + c[2]) * unit,
              ]));
            }).toList();

            StickerRef? sticker;
            var color = _plastic;
            if (exterior) {
              sticker = StickerRef.fromGeometry([x, y, z], d);
              color = state.faces[sticker.face]![sticker.index];
            }

            final lambert = math.max(0.0, _dot(normalCam, _light));
            faceDraws.add(RenderFace(
              points: corners,
              sticker: sticker,
              color: color,
              lighting: 0.72 + 0.28 * lambert,
              highlighted: highlighted && sticker != null,
            ));
          }

          if (faceDraws.isNotEmpty) {
            final dist = _dist2(centerCam, eye);
            cubies.add(_CubieDraw(dist, faceDraws));
          }
        }
      }
    }

    // Painter's algorithm theo viên: viên xa vẽ trước
    cubies.sort((a, b) => b.dist2.compareTo(a.dist2));
    return CubeGeometry._(
      [for (final c in cubies) ...c.faces],
      camera,
    );
  }

  /// Ô sticker trên cùng tại điểm chạm (null nếu chạm vào nền hoặc nhựa).
  StickerRef? hitTest(Offset point) {
    for (var i = faces.length - 1; i >= 0; i--) {
      final f = faces[i];
      if (f.toPath().contains(point)) return f.sticker;
    }
    return null;
  }

  /// Có chạm trúng khối (kể cả phần nhựa) hay không.
  bool hitsCube(Offset point) {
    for (final f in faces) {
      if (f.toPath().contains(point)) return true;
    }
    return false;
  }

  /// 4 góc của mặt có pháp tuyến [d] (theo thứ tự vòng quanh).
  static List<List<double>> _faceCorners(List<int> d) {
    const h = _cubieHalf;
    final axis = d[0] != 0 ? 0 : (d[1] != 0 ? 1 : 2);
    final s = (d[axis]).toDouble() * h;
    final u = (axis + 1) % 3, v = (axis + 2) % 3;
    final pts = <List<double>>[];
    for (final (a, b) in const [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)]) {
      final p = [0.0, 0.0, 0.0];
      p[axis] = s;
      p[u] = a * h;
      p[v] = b * h;
      pts.add(p);
    }
    return pts;
  }

  static double _dot(List<double> a, List<double> b) =>
      a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

  static double _dist2(List<double> a, List<double> b) {
    final dx = a[0] - b[0], dy = a[1] - b[1], dz = a[2] - b[2];
    return dx * dx + dy * dy + dz * dz;
  }

  static List<double> _normalize(List<double> v) {
    final l = math.sqrt(_dot(v, v));
    return [v[0] / l, v[1] / l, v[2] / l];
  }
}

class _CubieDraw {
  final double dist2;
  final List<RenderFace> faces;
  _CubieDraw(this.dist2, this.faces);
}
