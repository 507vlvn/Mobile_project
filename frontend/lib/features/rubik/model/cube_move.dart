import 'dart:math' as math;

/// Hệ toạ độ dùng chung cho mô hình, renderer và cử chỉ:
///   x: sang phải (+1 = mặt Phải)
///   y: hướng XUỐNG (-1 = mặt Trên, +1 = mặt Dưới)
///   z: hướng về người xem (+1 = mặt Trước)
/// Góc quay dương = quay theo quy tắc bàn tay phải quanh trục dương.

/// Mô tả một tầng đang xoay với góc bất kỳ (dùng cho hoạt ảnh / kéo tay).
class LayerTurn {
  /// 0 = trục X, 1 = trục Y, 2 = trục Z
  final int axis;

  /// Các tầng bị xoay theo toạ độ trên [axis] (ví dụ {1} cho R, {-1,0,1} cho x)
  final Set<int> layers;

  /// Góc quay (radian) quanh chiều dương của [axis]
  final double angle;

  const LayerTurn({
    required this.axis,
    required this.layers,
    required this.angle,
  });

  LayerTurn withAngle(double a) =>
      LayerTurn(axis: axis, layers: layers, angle: a);

  bool contains(int x, int y, int z) {
    final c = axis == 0 ? x : (axis == 1 ? y : z);
    return layers.contains(c);
  }
}

/// Định nghĩa gốc của từng ký hiệu nước đi:
/// trục, tầng và hướng quay của một lần xoay 90° "theo chiều kim đồng hồ".
class _MoveBase {
  final int axis;
  final Set<int> layers;
  final int sign; // +1: quay dương quanh trục, -1: quay âm
  const _MoveBase(this.axis, this.layers, this.sign);
}

const Map<String, _MoveBase> _bases = {
  'R': _MoveBase(0, {1}, 1),
  'L': _MoveBase(0, {-1}, -1),
  'M': _MoveBase(0, {0}, -1), // theo chiều L
  'U': _MoveBase(1, {-1}, -1),
  'D': _MoveBase(1, {1}, 1),
  'E': _MoveBase(1, {0}, 1), // theo chiều D
  'F': _MoveBase(2, {1}, 1),
  'B': _MoveBase(2, {-1}, -1),
  'S': _MoveBase(2, {0}, 1), // theo chiều F
  // Xoay nguyên khối
  'X': _MoveBase(0, {-1, 0, 1}, 1), // theo chiều R
  'Y': _MoveBase(1, {-1, 0, 1}, -1), // theo chiều U
  'Z': _MoveBase(2, {-1, 0, 1}, 1), // theo chiều F
};

/// Một nước đi đã được phân tích.
class CubeMove {
  final String face; // R L U D F B M E S X Y Z (viết hoa)
  final int turns; // 1, 2 hoặc 3 (3 = ngược chiều)

  const CubeMove(this.face, this.turns);

  /// Phân tích ký hiệu như "R", "U'", "F2", "x", "M'". Trả về null nếu sai.
  static CubeMove? tryParse(String notation) {
    final s = notation.trim();
    if (s.isEmpty) return null;
    final face = s[0].toUpperCase();
    if (!_bases.containsKey(face)) return null;
    final suffix = s.substring(1);
    switch (suffix) {
      case '':
      case '1':
        return CubeMove(face, 1);
      case '2':
      case "2'":
        return CubeMove(face, 2);
      case "'":
      case '3':
        return CubeMove(face, 3);
      default:
        return null;
    }
  }

  int get axis => _bases[face]!.axis;
  Set<int> get layers => _bases[face]!.layers;

  /// Góc quay quanh chiều dương của trục, trong khoảng (-π, π].
  double get angle {
    final base = _bases[face]!.sign;
    final q = turns == 3 ? -1 : turns; // R' = -90°, R2 = 180°
    return base * q * math.pi / 2;
  }

  /// Số lần quay +90° quanh chiều dương của trục (0..3).
  int get positiveQuarterTurns {
    final base = _bases[face]!.sign;
    return ((base * turns) % 4 + 4) % 4;
  }

  bool get isWholeCube => layers.length == 3;

  CubeMove get inverse => CubeMove(face, turns == 2 ? 2 : 4 - turns);

  LayerTurn toLayerTurn({double progress = 1}) =>
      LayerTurn(axis: axis, layers: layers, angle: angle * progress);

  /// Ký hiệu chuẩn. Xoay nguyên khối viết thường (x, y, z).
  String get notation {
    final f = isWholeCube ? face.toLowerCase() : face;
    switch (turns) {
      case 2:
        return '${f}2';
      case 3:
        return "$f'";
      default:
        return f;
    }
  }

  /// Tìm nước đi tương ứng với việc xoay [layer] trên [axis]
  /// [quarterTurns] lần +90° quanh chiều dương của trục.
  /// Trả về null nếu quarterTurns ≡ 0 (không đổi gì).
  static CubeMove? fromRotation({
    required int axis,
    required int layer,
    required int quarterTurns,
  }) {
    final q = ((quarterTurns % 4) + 4) % 4;
    if (q == 0) return null;
    for (final entry in _bases.entries) {
      final b = entry.value;
      if (b.axis != axis || b.layers.length != 1 || !b.layers.contains(layer)) {
        continue;
      }
      // turns * sign ≡ q (mod 4)  →  turns ≡ q * sign (vì sign = ±1)
      final turns = ((q * b.sign) % 4 + 4) % 4;
      return CubeMove(entry.key, turns);
    }
    return null;
  }

  @override
  String toString() => notation;

  @override
  bool operator ==(Object other) =>
      other is CubeMove && other.face == face && other.turns == turns;

  @override
  int get hashCode => Object.hash(face, turns);
}

/// Các nước đi 6 mặt dùng để xáo / cho bảng nút.
const List<String> kFaceMoves = [
  'R', "R'", 'R2', 'L', "L'", 'L2', 'U', "U'", 'U2',
  'D', "D'", 'D2', 'F', "F'", 'F2', 'B', "B'", 'B2',
];

/// Quay vector nguyên [v] quanh [axis] đúng [quarterTurns] lần +90°.
List<int> rotateIntVector(List<int> v, int axis, int quarterTurns) {
  var x = v[0], y = v[1], z = v[2];
  final q = ((quarterTurns % 4) + 4) % 4;
  for (var i = 0; i < q; i++) {
    switch (axis) {
      case 0: // Rx(+90): y' = -z, z' = y
        final ny = -z;
        z = y;
        y = ny;
        break;
      case 1: // Ry(+90): x' = z, z' = -x
        final nx = z;
        z = -x;
        x = nx;
        break;
      default: // Rz(+90): x' = -y, y' = x
        final nx = -y;
        y = x;
        x = nx;
    }
  }
  return [x, y, z];
}
