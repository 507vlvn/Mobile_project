import 'dart:math' as math;
import 'dart:ui';

import '../model/cube_model.dart';
import 'cube_geometry.dart';

/// Kế hoạch xoay tầng suy ra từ một cú vuốt bắt đầu trên sticker.
///
/// Nguyên lý: sticker nằm trên mặt có pháp tuyến n, nên chỉ có thể bị kéo bởi
/// tầng quay quanh một trong 2 trục vuông góc với n. Với mỗi trục, ta tính
/// chính xác hướng sticker di chuyển trên màn hình khi tầng quay một góc rất nhỏ
/// (tuyến tính hoá cục bộ), rồi chọn trục có hướng khớp nhất với ngón tay.
/// Nhờ vậy sticker luôn chạy theo ngón tay ở mọi góc nhìn.
class TurnGesturePlan {
  /// Trục quay (0=X, 1=Y, 2=Z) và tầng bị xoay trên trục đó.
  final int axis;
  final int layer;

  /// Hướng (đơn vị) trên màn hình mà sticker đi khi góc quay tăng.
  final Offset screenDir;

  /// Số pixel sticker đi được trên màn hình cho mỗi radian.
  final double pxPerRadian;

  const TurnGesturePlan({
    required this.axis,
    required this.layer,
    required this.screenDir,
    required this.pxPerRadian,
  });

  /// Góc quay (radian, quanh chiều dương của [axis]) cho tổng quãng vuốt [drag].
  double angleFor(Offset drag) {
    final a = (drag.dx * screenDir.dx + drag.dy * screenDir.dy) / pxPerRadian;
    return a.clamp(-math.pi, math.pi);
  }

  /// Vận tốc góc (rad/s) tương ứng với vận tốc vuốt [v] (px/s).
  /// Không giới hạn như [angleFor] — nếu không vuốt nhanh sẽ không bao giờ vượt ngưỡng.
  double angularVelocity(Offset v) =>
      (v.dx * screenDir.dx + v.dy * screenDir.dy) / pxPerRadian;

  LayerTurn toLayerTurn(double angle) =>
      LayerTurn(axis: axis, layers: {layer}, angle: angle);

  /// Suy ra kế hoạch từ sticker được chạm và quãng vuốt ban đầu.
  static TurnGesturePlan resolve({
    required CubeCamera camera,
    required StickerRef sticker,
    required Offset drag,
  }) {
    final n = sticker.normal;
    final pos = sticker.position;
    final normalAxis = n[0] != 0 ? 0 : (n[1] != 0 ? 1 : 2);
    final unit = camera.cubieSize;

    // Tâm sticker trong không gian thế giới (px)
    final c = [
      (pos[0] + n[0] * 0.5) * unit,
      (pos[1] + n[1] * 0.5) * unit,
      (pos[2] + n[2] * 0.5) * unit,
    ];

    const eps = 0.02;
    var bestAxis = -1;
    var bestScore = -1.0;
    var bestTangent = Offset.zero;
    for (var r = 0; r < 3; r++) {
      if (r == normalAxis) continue;
      final p1 = camera.projectWorld(rotateAxis(c, r, -eps));
      final p2 = camera.projectWorld(rotateAxis(c, r, eps));
      final t = (p2 - p1) / (2 * eps); // px trên mỗi radian
      final len = t.distance;
      if (len < 1e-6) continue;
      final score = (drag.dx * t.dx + drag.dy * t.dy).abs() / len;
      if (score > bestScore) {
        bestScore = score;
        bestAxis = r;
        bestTangent = t;
      }
    }

    // Mặt nhìn quá nghiêng → chặn dưới để góc không tăng vọt
    final len = math.max(bestTangent.distance, unit * 0.5);
    return TurnGesturePlan(
      axis: bestAxis,
      layer: pos[bestAxis],
      screenDir: bestTangent / bestTangent.distance,
      pxPerRadian: len,
    );
  }
}

/// Quyết định góc đích (bội số của 90°) khi người dùng thả tay.
///
/// - Vuốt nhanh (vượt [flingThreshold] rad/s) → xoay tiếp theo hướng vuốt.
/// - Ngược lại làm tròn về nấc gần nhất (có thể là 0 = bật về chỗ cũ).
int resolveQuarterTurns({
  required double angle,
  required double angularVelocity,
  double flingThreshold = 4.0,
}) {
  const q = math.pi / 2;
  final current = angle / q;
  int target;
  if (angularVelocity.abs() > flingThreshold) {
    if (current.abs() < 0.05) {
      // Chưa kéo được bao nhiêu mà đã vuốt nhanh → xoay luôn một nấc
      target = angularVelocity > 0 ? 1 : -1;
    } else {
      // Vuốt nhanh theo chiều nào thì về nấc kế tiếp theo chiều đó
      // (vuốt ngược lại khi đang kéo dở = huỷ, quay về 0)
      target = angularVelocity > 0 ? current.ceil() : current.floor();
    }
  } else {
    target = current.round();
  }
  return target.clamp(-2, 2);
}
