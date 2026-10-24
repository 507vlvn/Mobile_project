import 'dart:math' as math;

import '../../core/models/difficulty.dart';
import '../model/cube_move.dart';

/// Số nước xáo theo độ khó.
int scrambleLength(Difficulty d) => switch (d) {
      Difficulty.easy => 5,
      Difficulty.medium => 11,
      Difficulty.hard => 22,
    };

/// Sinh chuỗi xáo hợp lệ: không có 2 nước liên tiếp cùng mặt (R R'),
/// không có 3 nước liên tiếp cùng trục (R L R) để tránh nước thừa.
List<String> generateScramble(int length, {math.Random? random}) {
  final rnd = random ?? math.Random();
  const faces = ['R', 'L', 'U', 'D', 'F', 'B'];
  const suffixes = ['', "'", '2'];
  final result = <String>[];
  String? lastFace;
  int? lastAxis;
  var sameAxisCount = 0;

  while (result.length < length) {
    final face = faces[rnd.nextInt(faces.length)];
    if (face == lastFace) continue;
    final axis = CubeMove.tryParse(face)!.axis;
    if (axis == lastAxis && sameAxisCount >= 2) continue;

    sameAxisCount = axis == lastAxis ? sameAxisCount + 1 : 1;
    lastAxis = axis;
    lastFace = face;
    result.add('$face${suffixes[rnd.nextInt(suffixes.length)]}');
  }
  return result;
}
