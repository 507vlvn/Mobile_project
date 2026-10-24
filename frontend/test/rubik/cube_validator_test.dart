import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/features/rubik/model/cube_model.dart';
import 'package:mobile_rubik/features/rubik/services/cube_validator.dart';

void _swap(Cube3DState s, StickerRef a, StickerRef b) {
  final ca = s.faces[a.face]![a.index];
  s.faces[a.face]![a.index] = s.faces[b.face]![b.index];
  s.faces[b.face]![b.index] = ca;
}

Cube3DState _scrambled() => Cube3DState()
  ..applyMoves(["R", "U'", 'F2', 'L', "D'", 'B', 'R2', "U", "F'", 'L2']);

void main() {
  test('khối đã giải và khối xáo hợp lệ → không có lỗi', () {
    expect(validateCube(Cube3DState()), isEmpty);
    expect(validateCube(_scrambled()), isEmpty);
  });

  test('tô sai một ô → báo số lượng màu và chỉ ra ô thừa', () {
    final s = _scrambled();
    final wrong = s.faces['front']![0] == RubikColors.red ? RubikColors.orange : RubikColors.red;
    s.faces['front']![0] = wrong;
    final issues = validateCube(s);
    expect(issues.first.type, CubeIssueType.colorCount);
    expect(issues.any((i) => i.stickers.contains(const StickerRef('front', 0))), isTrue);
  });

  test('lật một viên cạnh → twistedEdge', () {
    final s = _scrambled();
    // Viên cạnh trên-trước: top#7 và front#1
    _swap(s, const StickerRef('top', 7), const StickerRef('front', 1));
    expect(validateCube(s).single.type, CubeIssueType.twistedEdge);
  });

  test('xoay một viên góc → twistedCorner', () {
    final s = _scrambled();
    // Góc trên-trước-phải: top#8, front#2, right#0 → xoay vòng 3 màu
    final a = s.faces['top']![8], b = s.faces['front']![2], c = s.faces['right']![0];
    s.faces['top']![8] = b;
    s.faces['front']![2] = c;
    s.faces['right']![0] = a;
    expect(validateCube(s).single.type, CubeIssueType.twistedCorner);
  });

  test('đổi chỗ hai viên cạnh → parity', () {
    final s = Cube3DState();
    // Đổi viên UF (top#7/front#1) với viên UR (top#5/right#1)
    _swap(s, const StickerRef('top', 7), const StickerRef('top', 5));
    _swap(s, const StickerRef('front', 1), const StickerRef('right', 1));
    expect(validateCube(s).single.type, CubeIssueType.parity);
  });

  test('viên cạnh không tồn tại (trùng màu) → badEdge, chỉ đúng 2 ô', () {
    final s = Cube3DState();
    // Đổi Đỏ của viên UF với Vàng của viên UR → UF = (Vàng, Vàng), số lượng màu vẫn đủ 9
    _swap(s, const StickerRef('front', 1), const StickerRef('top', 5));
    final issues = validateCube(s);
    expect(issues.first.type, CubeIssueType.badEdge);
    expect(issues.first.stickers.length, 2);
  });

  test('màu đối diện được suy ra từ tâm (không giả định bảng màu)', () {
    final s = Cube3DState()..applyMoves(['x', 'y']); // đổi hướng cả khối
    expect(validateCube(s), isEmpty);
    expect(s.faces['top']![4], isNot(RubikColors.yellow));
  });

  test('Color dùng trong RubikColors.all đủ 6 màu', () {
    expect(RubikColors.all.toSet().length, 6);
    expect(RubikColors.all, contains(const Color(0xFFFFD500)));
  });
}
