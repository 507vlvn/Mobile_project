// Bản cài đặt nước đi cũ (hoán vị viết tay), giữ lại làm mốc đối chiếu trong test.
import 'package:flutter/material.dart';

class LegacyCube {
  final Map<String, List<Color>> faces;
  LegacyCube(this.faces);

  /// Thực hiện một bước xoay vật lý làm thay đổi trạng thái khối Rubik
  void applyMove(String move) {
    final clean = move.trim();
    if (clean.isEmpty) return;

    final face = clean[0].toUpperCase();
    final isPrime = clean.endsWith("'");
    final isDouble = clean.endsWith("2");

    final turns = isDouble ? 2 : (isPrime ? 3 : 1);
    for (var i = 0; i < turns; i++) {
      _rotateSingleFace(face);
    }
  }

  /// Xoay 1 mặt 90 độ cùng chiều kim đồng hồ
  void _rotateSingleFace(String face) {
    // 1. Xoay 9 ô trên chính mặt đó
    final f = faces[_faceKey(face)]!;
    final oldF = List<Color>.from(f);
    // [0, 1, 2]       [6, 3, 0]
    // [3, 4, 5]  ==>  [7, 4, 1]
    // [6, 7, 8]       [8, 5, 2]
    f[0] = oldF[6];
    f[1] = oldF[3];
    f[2] = oldF[0];
    f[3] = oldF[7];
    f[4] = oldF[4];
    f[5] = oldF[1];
    f[6] = oldF[8];
    f[7] = oldF[5];
    f[8] = oldF[2];

    // 2. Hoán vị 4 cạnh tiếp giáp
    switch (face) {
      case 'U': // Top
        _cycleStickers([
          ('front', 0), ('left', 0), ('back', 0), ('right', 0),
        ]);
        _cycleStickers([
          ('front', 1), ('left', 1), ('back', 1), ('right', 1),
        ]);
        _cycleStickers([
          ('front', 2), ('left', 2), ('back', 2), ('right', 2),
        ]);
        break;
      case 'D': // Bottom
        _cycleStickers([
          ('front', 6), ('right', 6), ('back', 6), ('left', 6),
        ]);
        _cycleStickers([
          ('front', 7), ('right', 7), ('back', 7), ('left', 7),
        ]);
        _cycleStickers([
          ('front', 8), ('right', 8), ('back', 8), ('left', 8),
        ]);
        break;
      case 'R': // Right
        _cycleStickers([
          ('top', 2), ('back', 6), ('bottom', 2), ('front', 2),
        ]);
        _cycleStickers([
          ('top', 5), ('back', 3), ('bottom', 5), ('front', 5),
        ]);
        _cycleStickers([
          ('top', 8), ('back', 0), ('bottom', 8), ('front', 8),
        ]);
        break;
      case 'L': // Left
        _cycleStickers([
          ('top', 0), ('front', 0), ('bottom', 0), ('back', 8),
        ]);
        _cycleStickers([
          ('top', 3), ('front', 3), ('bottom', 3), ('back', 5),
        ]);
        _cycleStickers([
          ('top', 6), ('front', 6), ('bottom', 6), ('back', 2),
        ]);
        break;
      case 'F': // Front
        _cycleStickers([
          ('top', 6), ('right', 0), ('bottom', 2), ('left', 8),
        ]);
        _cycleStickers([
          ('top', 7), ('right', 3), ('bottom', 1), ('left', 5),
        ]);
        _cycleStickers([
          ('top', 8), ('right', 6), ('bottom', 0), ('left', 2),
        ]);
        break;
      case 'B': // Back
        _cycleStickers([
          ('top', 2), ('left', 0), ('bottom', 6), ('right', 8),
        ]);
        _cycleStickers([
          ('top', 1), ('left', 3), ('bottom', 7), ('right', 5),
        ]);
        _cycleStickers([
          ('top', 0), ('left', 6), ('bottom', 8), ('right', 2),
        ]);
        break;
    }
  }

  void _cycleStickers(List<(String, int)> items) {
    final temp = faces[items[3].$1]![items[3].$2];
    faces[items[3].$1]![items[3].$2] = faces[items[2].$1]![items[2].$2];
    faces[items[2].$1]![items[2].$2] = faces[items[1].$1]![items[1].$2];
    faces[items[1].$1]![items[1].$2] = faces[items[0].$1]![items[0].$2];
    faces[items[0].$1]![items[0].$2] = temp;
  }

  static String _faceKey(String face) {
    switch (face.toUpperCase()) {
      case 'U':
        return 'top';
      case 'D':
        return 'bottom';
      case 'R':
        return 'right';
      case 'L':
        return 'left';
      case 'F':
        return 'front';
      case 'B':
        return 'back';
      default:
        return 'front';
    }
  }
}
