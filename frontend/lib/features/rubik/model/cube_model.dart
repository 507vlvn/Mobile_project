import 'package:flutter/material.dart';

import 'cube_move.dart';

export 'cube_move.dart';

/// Màu sắc tiêu chuẩn của khối Rubik
class RubikColors {
  static const Color yellow = Color(0xFFFFD500);
  static const Color white = Color(0xFFFFFFFF);
  static const Color red = Color(0xFFDC143C);
  static const Color orange = Color(0xFFFF6A00);
  static const Color green = Color(0xFF009B48);
  static const Color blue = Color(0xFF0046AD);
  static const Color plastic = Color(0xFF1E1E1E);

  static Color fromChar(String char) {
    switch (char.toLowerCase()) {
      case 'y':
        return yellow;
      case 'w':
        return white;
      case 'r':
        return red;
      case 'o':
        return orange;
      case 'g':
        return green;
      case 'b':
        return blue;
      default:
        return Colors.grey.shade400;
    }
  }

  /// Tên màu tiếng Việt (dùng trong mô tả nước đi).
  static String nameOf(Color color) {
    if (color == yellow) return 'Vàng';
    if (color == white) return 'Trắng';
    if (color == red) return 'Đỏ';
    if (color == orange) return 'Cam';
    if (color == green) return 'Xanh lá';
    if (color == blue) return 'Xanh dương';
    return 'Không rõ';
  }

  static const List<Color> all = [white, yellow, red, orange, green, blue];

  static String toChar(Color color) {
    if (color == yellow) return 'y';
    if (color == white) return 'w';
    if (color == red) return 'r';
    if (color == orange) return 'o';
    if (color == green) return 'g';
    if (color == blue) return 'b';
    return 'w';
  }
}

/// Trạng thái màu 54 mặt của khối Rubik
class Cube3DState {
  // Mỗi mặt là danh sách 9 màu (index 0..8)
  final Map<String, List<Color>> faces;

  Cube3DState({Map<String, List<Color>>? initialFaces})
      : faces = initialFaces ?? _defaultSolved();

  static Map<String, List<Color>> _defaultSolved() {
    return {
      'top': List.filled(9, RubikColors.yellow),
      'bottom': List.filled(9, RubikColors.white),
      'front': List.filled(9, RubikColors.red),
      'back': List.filled(9, RubikColors.orange),
      'right': List.filled(9, RubikColors.green),
      'left': List.filled(9, RubikColors.blue),
    };
  }

  /// Tạo bản sao trạng thái
  Cube3DState clone() {
    final copy = <String, List<Color>>{};
    for (final entry in faces.entries) {
      copy[entry.key] = List.from(entry.value);
    }
    return Cube3DState(initialFaces: copy);
  }

  /// Chuyển đổi từ cấu trúc sideColor / sideColorCode của DataState
  factory Cube3DState.fromSideColorCode(Map<String, String> sideCode) {
    final faces = <String, List<Color>>{};
    for (final key in ['top', 'bottom', 'front', 'back', 'right', 'left']) {
      final code = sideCode[key];
      if (code != null && code.length == 9) {
        faces[key] = code.split('').map(RubikColors.fromChar).toList();
      } else {
        faces[key] = _defaultSolved()[key]!;
      }
    }
    return Cube3DState(initialFaces: faces);
  }

  /// Xuất ra sideColorCode (`Map<String, String>`)
  Map<String, String> toSideColorCode() {
    final result = <String, String>{};
    for (final entry in faces.entries) {
      result[entry.key] = entry.value.map(RubikColors.toChar).join();
    }
    return result;
  }

  /// Cập nhật màu tại 1 ô cụ thể
  void setColor(String face, int index, Color color) {
    if (faces.containsKey(face) && index >= 0 && index < 9) {
      faces[face]![index] = color;
    }
  }

  /// Thực hiện một nước đi (R, U', F2, M, x...). Ký hiệu sai sẽ bị bỏ qua.
  void applyMove(String move) {
    final m = CubeMove.tryParse(move);
    if (m == null) return;
    applyCubeMove(m);
  }

  void applyMoves(Iterable<String> moves) {
    for (final m in moves) {
      applyMove(m);
    }
  }

  /// Xoay hình học: mọi sticker thuộc tầng được quay quanh trục,
  /// nên luôn khớp tuyệt đối với hoạt ảnh của renderer.
  void applyCubeMove(CubeMove move) {
    final q = move.positiveQuarterTurns;
    if (q == 0) return;
    final next = <String, List<Color>>{
      for (final k in kFaceKeys) k: List<Color>.from(faces[k]!),
    };
    for (final face in kFaceKeys) {
      for (var i = 0; i < 9; i++) {
        final st = StickerRef(face, i);
        final pos = st.position;
        final c = pos[move.axis];
        if (!move.layers.contains(c)) continue;
        final newPos = rotateIntVector(pos, move.axis, q);
        final newNormal = rotateIntVector(st.normal, move.axis, q);
        final target = StickerRef.fromGeometry(newPos, newNormal);
        next[target.face]![target.index] = faces[face]![i];
      }
    }
    for (final k in kFaceKeys) {
      faces[k] = next[k]!;
    }
  }

  /// Khối đã giải: mỗi mặt chỉ có một màu.
  bool get isSolved =>
      kFaceKeys.every((k) => faces[k]!.every((c) => c == faces[k]![0]));

  /// Đếm số ô của từng màu (dùng để kiểm tra khi quét).
  Map<Color, int> colorCounts() {
    final counts = <Color, int>{};
    for (final k in kFaceKeys) {
      for (final c in faces[k]!) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Màu tâm của mặt chứa ký hiệu [faceLetter] (U/D/F/B/R/L) ở hướng hiện tại.
  Color centerColorOf(String faceLetter) =>
      faces[faceKeyOf(faceLetter)]![4];

  bool sameAs(Cube3DState other) => kFaceKeys.every((k) {
        final a = faces[k]!, b = other.faces[k]!;
        for (var i = 0; i < 9; i++) {
          if (a[i] != b[i]) return false;
        }
        return true;
      });
}

const List<String> kFaceKeys = ['top', 'bottom', 'front', 'back', 'right', 'left'];

String faceKeyOf(String letter) {
  switch (letter.toUpperCase()) {
    case 'U':
      return 'top';
    case 'D':
      return 'bottom';
    case 'R':
      return 'right';
    case 'L':
      return 'left';
    case 'B':
      return 'back';
    default:
      return 'front';
  }
}

/// Tham chiếu tới 1 sticker (mặt + chỉ số 0..8) và hình học của nó.
///
/// Quy ước chỉ số (nhìn thẳng vào mặt, hàng trên → dưới, trái → phải),
/// khớp với chuẩn facelet của Kociemba:
///   top    : i = (z+1)*3 + (x+1)   (hàng trên giáp mặt Sau)
///   bottom : i = (1-z)*3 + (x+1)   (hàng trên giáp mặt Trước)
///   front  : i = (y+1)*3 + (x+1)
///   back   : i = (y+1)*3 + (1-x)
///   right  : i = (y+1)*3 + (1-z)
///   left   : i = (y+1)*3 + (z+1)
class StickerRef {
  final String face;
  final int index;
  const StickerRef(this.face, this.index);

  int get _row => index ~/ 3;
  int get _col => index % 3;

  /// Toạ độ viên lập phương nhỏ chứa sticker (mỗi thành phần ∈ {-1,0,1}).
  List<int> get position {
    final r = _row, c = _col;
    switch (face) {
      case 'top':
        return [c - 1, -1, r - 1];
      case 'bottom':
        return [c - 1, 1, 1 - r];
      case 'front':
        return [c - 1, r - 1, 1];
      case 'back':
        return [1 - c, r - 1, -1];
      case 'right':
        return [1, r - 1, 1 - c];
      default: // left
        return [-1, r - 1, c - 1];
    }
  }

  /// Pháp tuyến hướng ra ngoài của mặt.
  List<int> get normal => faceNormal(face);

  static List<int> faceNormal(String face) {
    switch (face) {
      case 'top':
        return const [0, -1, 0];
      case 'bottom':
        return const [0, 1, 0];
      case 'front':
        return const [0, 0, 1];
      case 'back':
        return const [0, 0, -1];
      case 'right':
        return const [1, 0, 0];
      default:
        return const [-1, 0, 0];
    }
  }

  static StickerRef fromGeometry(List<int> pos, List<int> normal) {
    final x = pos[0], y = pos[1], z = pos[2];
    if (normal[1] == -1) return StickerRef('top', (z + 1) * 3 + (x + 1));
    if (normal[1] == 1) return StickerRef('bottom', (1 - z) * 3 + (x + 1));
    if (normal[2] == 1) return StickerRef('front', (y + 1) * 3 + (x + 1));
    if (normal[2] == -1) return StickerRef('back', (y + 1) * 3 + (1 - x));
    if (normal[0] == 1) return StickerRef('right', (y + 1) * 3 + (1 - z));
    return StickerRef('left', (y + 1) * 3 + (z + 1));
  }

  @override
  bool operator ==(Object other) =>
      other is StickerRef && other.face == face && other.index == index;

  @override
  int get hashCode => Object.hash(face, index);
}
