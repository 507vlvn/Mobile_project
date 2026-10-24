import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/features/rubik/model/cube_model.dart';
import 'package:mobile_rubik/features/rubik/render/cube_geometry.dart';
import 'package:mobile_rubik/features/rubik/render/turn_gesture.dart';

CubeCamera _cam({double pitch = 0, double yaw = 0}) =>
    CubeCamera(size: const Size.square(300), pitch: pitch, yaw: yaw);

/// Toạ độ màn hình của tâm sticker sau khi tầng của nó quay [turn].
Offset _stickerScreen(CubeCamera cam, StickerRef s, LayerTurn? turn) {
  final u = cam.cubieSize;
  final p = s.position, n = s.normal;
  var w = [
    (p[0] + n[0] * 0.5) * u,
    (p[1] + n[1] * 0.5) * u,
    (p[2] + n[2] * 0.5) * u,
  ];
  if (turn != null && turn.contains(p[0], p[1], p[2])) {
    w = rotateAxis(w, turn.axis, turn.angle);
  }
  return cam.projectWorld(w);
}

String? _moveFor(CubeCamera cam, StickerRef s, Offset drag) {
  final plan = TurnGesturePlan.resolve(camera: cam, sticker: s, drag: drag);
  final q = plan.angleFor(drag) > 0 ? 1 : -1;
  return CubeMove.fromRotation(axis: plan.axis, layer: plan.layer, quarterTurns: q)
      ?.notation;
}

void main() {
  group('Nhìn thẳng mặt Trước (Đỏ)', () {
    final cam = _cam();
    const up = Offset(0, -80), down = Offset(0, 80);
    const left = Offset(-80, 0), right = Offset(80, 0);

    test('vuốt cột phải lên = R, xuống = R\'', () {
      expect(_moveFor(cam, const StickerRef('front', 5), up), 'R');
      expect(_moveFor(cam, const StickerRef('front', 8), down), "R'");
    });

    test('vuốt cột trái xuống = L, lên = L\'', () {
      expect(_moveFor(cam, const StickerRef('front', 3), down), 'L');
      expect(_moveFor(cam, const StickerRef('front', 0), up), "L'");
    });

    test('vuốt hàng trên sang trái = U, sang phải = U\'', () {
      expect(_moveFor(cam, const StickerRef('front', 1), left), 'U');
      expect(_moveFor(cam, const StickerRef('front', 2), right), "U'");
    });

    test('vuốt hàng dưới sang phải = D', () {
      expect(_moveFor(cam, const StickerRef('front', 7), right), 'D');
    });

    test('vuốt hàng giữa / cột giữa = E / M', () {
      expect(_moveFor(cam, const StickerRef('front', 4), right), 'E');
      expect(_moveFor(cam, const StickerRef('front', 4), down), 'M');
    });
  });

  test('Mọi góc nhìn, mọi ô, mọi hướng: sticker đi theo hướng ngón tay', () {
    final rnd = math.Random(3);
    var checked = 0;
    for (var trial = 0; trial < 400; trial++) {
      final cam = _cam(
        pitch: (rnd.nextDouble() - 0.5) * 2.6,
        yaw: (rnd.nextDouble() - 0.5) * 2 * math.pi,
      );
      final face = kFaceKeys[rnd.nextInt(6)];
      final s = StickerRef(face, rnd.nextInt(9));

      // Bỏ qua mặt đang quay lưng lại (người dùng không chạm được)
      final normalCam = cam.toCamera(s.normal.map((e) => e.toDouble()).toList());
      if (normalCam[2] < 0.25) continue;

      final ang = rnd.nextDouble() * 2 * math.pi;
      final drag = Offset(math.cos(ang), math.sin(ang)) * 40;
      final plan = TurnGesturePlan.resolve(camera: cam, sticker: s, drag: drag);
      final small = plan.toLayerTurn(plan.angleFor(drag) * 0.1);

      final before = _stickerScreen(cam, s, null);
      final after = _stickerScreen(cam, s, small);
      final moved = after - before;
      if (moved.distance < 1e-3) continue;
      final cos = (moved.dx * drag.dx + moved.dy * drag.dy) /
          (moved.distance * drag.distance);
      // Sticker phải chuyển động cùng phía với ngón tay (cos > 0).
      // Không đòi cos lớn: ô chỉ đi được theo 2 hướng, vuốt chéo hẳn thì lệch góc là tất yếu.
      expect(cos, greaterThan(0.0),
          reason: 'face=$face idx=${s.index} drag=$drag cos=$cos');
      checked++;
    }
    expect(checked, greaterThan(100));
  });

  group('resolveQuarterTurns', () {
    const q = math.pi / 2;
    test('kéo chậm: làm tròn về nấc gần nhất', () {
      expect(resolveQuarterTurns(angle: q * 0.4, angularVelocity: 0), 0);
      expect(resolveQuarterTurns(angle: q * 0.6, angularVelocity: 0), 1);
      expect(resolveQuarterTurns(angle: -q * 1.6, angularVelocity: 0), -2);
    });
    test('vuốt nhanh: xoay theo hướng vuốt', () {
      expect(resolveQuarterTurns(angle: q * 0.2, angularVelocity: 8), 1);
      expect(resolveQuarterTurns(angle: 0, angularVelocity: -8), -1);
    });
    test('đang kéo dở rồi vuốt ngược lại: huỷ về 0', () {
      expect(resolveQuarterTurns(angle: q * 0.4, angularVelocity: -8), 0);
    });
  });
}
