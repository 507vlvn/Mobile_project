import '../model/cube_model.dart';

/// Mô tả nước đi bằng tiếng Việt, lấy màu theo TÂM HIỆN TẠI của khối
/// (không viết cứng "Phải = Xanh lá") và hướng theo góc nhìn cầm khối
/// với mặt Trước hướng về người chơi.
class MoveDescription {
  final String title; // "Mặt Phải (tâm Xanh lá)"
  final String action; // "xoay lên trên 90°"
  const MoveDescription(this.title, this.action);

  String get full => '$title: $action';
}

MoveDescription describeMove(String notation, Cube3DState state) {
  final m = CubeMove.tryParse(notation);
  if (m == null) return MoveDescription(notation, 'thực hiện nước $notation');

  String layerName(String key, String label) =>
      '$label (tâm ${RubikColors.nameOf(state.faces[key]![4])})';

  final (title, cw, ccw) = switch (m.face) {
    'R' => (layerName('right', 'Mặt Phải'), 'lên trên', 'xuống dưới'),
    'L' => (layerName('left', 'Mặt Trái'), 'xuống dưới', 'lên trên'),
    'U' => (layerName('top', 'Mặt Trên'), 'sang trái', 'sang phải'),
    'D' => (layerName('bottom', 'Mặt Dưới'), 'sang phải', 'sang trái'),
    'F' => (
        layerName('front', 'Mặt Trước'),
        'theo chiều kim đồng hồ',
        'ngược chiều kim đồng hồ'
      ),
    'B' => (
        layerName('back', 'Mặt Sau'),
        'ngược chiều kim đồng hồ (nhìn từ phía trước)',
        'theo chiều kim đồng hồ (nhìn từ phía trước)'
      ),
    'M' => ('Tầng giữa dọc', 'xuống dưới', 'lên trên'),
    'E' => ('Tầng giữa ngang', 'sang phải', 'sang trái'),
    'S' => ('Tầng giữa trước-sau', 'theo chiều kim đồng hồ', 'ngược chiều kim đồng hồ'),
    'X' => ('Cả khối', 'lật lên trên', 'lật xuống dưới'),
    'Y' => ('Cả khối', 'xoay sang trái', 'xoay sang phải'),
    _ => ('Cả khối', 'nghiêng theo chiều kim đồng hồ', 'nghiêng ngược chiều kim đồng hồ'),
  };

  final action = switch (m.turns) {
    2 => 'xoay 180° (nửa vòng)',
    3 => '$ccw 90°',
    _ => '$cw 90°',
  };
  return MoveDescription(title, action);
}
