import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_new/rubik/model/cube_model.dart';
import 'package:frontend_new/rubik/render/cube_geometry.dart';
import 'package:frontend_new/rubik/render/rubik_3d_view.dart';

/// Toạ độ (trong widget) của tâm sticker khi nhìn thẳng mặt trước.
Offset _stickerCenter(double size, StickerRef s) {
  final cam = CubeCamera(size: Size.square(size), pitch: 0, yaw: 0);
  final u = cam.cubieSize;
  final p = s.position, n = s.normal;
  return cam.projectWorld([
    (p[0] + n[0] * 0.5) * u,
    (p[1] + n[1] * 0.5) * u,
    (p[2] + n[2] * 0.5) * u,
  ]);
}

void main() {
  const size = 300.0;

  Future<List<String>> pumpAndDrag(
    WidgetTester tester, {
    required StickerRef sticker,
    required Offset drag,
    bool fling = false,
    bool layerTurns = true,
  }) async {
    final moves = <String>[];
    final state = Cube3DState();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Rubik3DView(
            state: state,
            size: size,
            enableLayerTurns: layerTurns,
            initialPitch: 0,
            initialYaw: 0,
            onMove: moves.add,
          ),
        ),
      ),
    ));
    final origin = tester.getTopLeft(find.byType(Rubik3DView));
    final start = origin + _stickerCenter(size, sticker);
    if (fling) {
      await tester.flingFrom(start, drag, 1500);
    } else {
      final g = await tester.startGesture(start);
      // Kéo từ từ qua nhiều bước như ngón tay thật
      for (var i = 1; i <= 10; i++) {
        await g.moveBy(drag / 10);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await g.up();
    }
    await tester.pumpAndSettle();
    return moves;
  }

  testWidgets('kéo cột phải lên đủ xa → R', (tester) async {
    final moves = await pumpAndDrag(
      tester,
      sticker: const StickerRef('front', 5),
      drag: const Offset(0, -150),
    );
    expect(moves, ['R']);
  });

  testWidgets('kéo hàng trên sang trái → U', (tester) async {
    final moves = await pumpAndDrag(
      tester,
      sticker: const StickerRef('front', 1),
      drag: const Offset(-150, 0),
    );
    expect(moves, ['U']);
  });

  testWidgets('kéo quá ngắn rồi thả chậm → bật về, không có nước đi', (tester) async {
    final moves = await pumpAndDrag(
      tester,
      sticker: const StickerRef('front', 5),
      drag: const Offset(0, -25),
    );
    expect(moves, isEmpty);
  });

  testWidgets('vuốt nhanh quãng ngắn → xoay luôn 1 nấc', (tester) async {
    final moves = await pumpAndDrag(
      tester,
      sticker: const StickerRef('front', 7),
      drag: const Offset(60, 0),
      fling: true,
    );
    expect(moves, ['D']);
  });

  testWidgets('khi tắt xoay tầng: vuốt trên ô chỉ xoay góc nhìn', (tester) async {
    final moves = await pumpAndDrag(
      tester,
      sticker: const StickerRef('front', 5),
      drag: const Offset(0, -150),
      layerTurns: false,
    );
    expect(moves, isEmpty);
  });
}
