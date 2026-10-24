import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_new/rubik/model/cube_model.dart';
import 'package:frontend_new/rubik/services/offline_rubik_solver.dart';

import 'legacy_cube_moves.dart';

/// Trạng thái mà mỗi sticker có một "màu" riêng biệt → so sánh được hoán vị đầy đủ.
Map<String, List<Color>> _uniqueFaces() {
  var n = 0;
  return {
    for (final k in kFaceKeys) k: List.generate(9, (_) => Color(0xFF000000 + n++)),
  };
}

Map<String, List<Color>> _copy(Map<String, List<Color>> f) =>
    {for (final e in f.entries) e.key: List<Color>.from(e.value)};

bool _sameFaces(Map<String, List<Color>> a, Map<String, List<Color>> b) {
  for (final k in kFaceKeys) {
    for (var i = 0; i < 9; i++) {
      if (a[k]![i] != b[k]![i]) return false;
    }
  }
  return true;
}

const _allMoves = [
  ...kFaceMoves,
  'M', "M'", 'M2', 'E', "E'", 'E2', 'S', "S'", 'S2',
  'x', "x'", 'x2', 'y', "y'", 'y2', 'z', "z'", 'z2',
];

void main() {
  group('StickerRef', () {
    test('position/normal ↔ fromGeometry là song ánh', () {
      for (final f in kFaceKeys) {
        for (var i = 0; i < 9; i++) {
          final s = StickerRef(f, i);
          expect(StickerRef.fromGeometry(s.position, s.normal), s);
        }
      }
    });
  });

  group('Nước đi hình học', () {
    test('khớp hoàn toàn với bản hoán vị viết tay cũ cho 18 nước 6 mặt', () {
      for (final m in kFaceMoves) {
        final start = _uniqueFaces();
        final cube = Cube3DState(initialFaces: _copy(start))..applyMove(m);
        final legacy = LegacyCube(_copy(start))..applyMove(m);
        expect(_sameFaces(cube.faces, legacy.faces), isTrue, reason: 'Nước $m');
      }
    });

    test('khớp với bản cũ trên chuỗi xáo ngẫu nhiên dài', () {
      final rnd = math.Random(7);
      final start = _uniqueFaces();
      final cube = Cube3DState(initialFaces: _copy(start));
      final legacy = LegacyCube(_copy(start));
      for (var i = 0; i < 200; i++) {
        final m = kFaceMoves[rnd.nextInt(kFaceMoves.length)];
        cube.applyMove(m);
        legacy.applyMove(m);
      }
      expect(_sameFaces(cube.faces, legacy.faces), isTrue);
    });

    test('nước đi rồi nước ngược = trạng thái ban đầu; 4 lần = ban đầu', () {
      for (final m in _allMoves) {
        final start = _uniqueFaces();
        final parsed = CubeMove.tryParse(m)!;
        final c1 = Cube3DState(initialFaces: _copy(start))
          ..applyMove(m)
          ..applyCubeMove(parsed.inverse);
        expect(_sameFaces(c1.faces, start), isTrue, reason: '$m + ngược');

        final c2 = Cube3DState(initialFaces: _copy(start));
        for (var i = 0; i < 4; i++) {
          c2.applyMove(parsed.turns == 2 ? m : m); // 4 lần cùng một nước
        }
        expect(_sameFaces(c2.faces, start), isTrue, reason: '4 × $m');
      }
    });

    test('M = L\' R x\' (định nghĩa chuẩn của tầng giữa)', () {
      final start = _uniqueFaces();
      final a = Cube3DState(initialFaces: _copy(start))..applyMove('M');
      final b = Cube3DState(initialFaces: _copy(start))
        ..applyMoves(["L'", 'R', "x'"]);
      expect(_sameFaces(a.faces, b.faces), isTrue);
    });

    test('isSolved', () {
      final c = Cube3DState();
      expect(c.isSolved, isTrue);
      c.applyMove('R');
      expect(c.isSolved, isFalse);
      c.applyMove("R'");
      expect(c.isSolved, isTrue);
      // Xoay nguyên khối vẫn là đã giải
      c.applyMoves(['x', 'y2']);
      expect(c.isSolved, isTrue);
    });
  });

  group('CubeMove', () {
    test('fromRotation là nghịch đảo của (axis, layer, positiveQuarterTurns)', () {
      for (final m in _allMoves) {
        final parsed = CubeMove.tryParse(m)!;
        if (parsed.isWholeCube) continue;
        final back = CubeMove.fromRotation(
          axis: parsed.axis,
          layer: parsed.layers.single,
          quarterTurns: parsed.positiveQuarterTurns,
        );
        expect(back, parsed, reason: m);
      }
    });

    test('ký hiệu sai trả về null', () {
      expect(CubeMove.tryParse('Q'), isNull);
      expect(CubeMove.tryParse("R''"), isNull);
      expect(CubeMove.tryParse(''), isNull);
    });
  });

  group('Tương thích bộ giải Kociemba', () {
    Future<void> roundTrip(List<String> scramble) async {
      final cube = Cube3DState()..applyMoves(scramble);
      final result =
          await OfflineRubikSolver.solveFromSideColors(cube.toSideColorCode());
      expect(result.success, isTrue, reason: result.errorMessage);
      cube.applyMoves(result.moves);
      expect(cube.isSolved, isTrue, reason: 'Xáo: ${scramble.join(' ')}');
    }

    test('xáo 6 mặt ngẫu nhiên → giải → về trạng thái đã giải', () async {
      final rnd = math.Random(42);
      for (var t = 0; t < 3; t++) {
        await roundTrip([
          for (var i = 0; i < 20; i++) kFaceMoves[rnd.nextInt(kFaceMoves.length)],
        ]);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('xáo có cả tầng giữa M/E/S (tâm bị dịch chuyển) vẫn giải được', () async {
      await roundTrip(['M', 'U', 'E', "R'", 'S2', 'F', "M'", 'D2', 'S', 'L']);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
