import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter/material.dart';

import '../model/cube_model.dart';

enum CubeIssueType {
  colorCount,
  centers,
  badEdge,
  badCorner,
  duplicatePiece,
  twistedEdge,
  twistedCorner,
  parity,
}

/// Một lỗi khi kiểm tra trạng thái khối đã quét, kèm các ô cần tô sáng.
class CubeIssue {
  final CubeIssueType type;
  final String message;
  final String hint;
  final Set<StickerRef> stickers;

  const CubeIssue({
    required this.type,
    required this.message,
    required this.hint,
    this.stickers = const {},
  });
}

/// Kiểm tra khối đã quét/tô theo thứ tự từ dễ hiểu tới khó hiểu:
/// 1. Mỗi màu đúng 9 ô  2. 6 tâm hợp lệ  3. Từng viên cạnh/góc tồn tại
/// 4. Kiểm tra cấu trúc của Kociemba (lật cạnh, xoay góc, hoán vị).
/// Trả về danh sách rỗng nếu khối giải được.
List<CubeIssue> validateCube(Cube3DState state) {
  final issues = <CubeIssue>[];

  // ---- 1. Số lượng màu ----------------------------------------------------
  final counts = state.colorCounts();
  for (final color in RubikColors.all) {
    final n = counts[color] ?? 0;
    if (n == 9) continue;
    final name = RubikColors.nameOf(color);
    issues.add(CubeIssue(
      type: CubeIssueType.colorCount,
      message: 'Màu $name có $n/9 ô',
      hint: n > 9
          ? 'Có ô màu khác bị nhận nhầm thành $name. ${_confusionHint(color)}'
          : 'Thiếu ô $name — có ô $name bị nhận nhầm sang màu khác. ${_confusionHint(color)}',
      stickers: n > 9 ? _stickersOf(state, color) : const {},
    ));
  }
  if (issues.isNotEmpty) return issues;

  // ---- 2. Tâm ---------------------------------------------------------------
  final centers = {for (final f in kFaceKeys) f: state.faces[f]![4]};
  if (centers.values.toSet().length != 6) {
    return [
      CubeIssue(
        type: CubeIssueType.centers,
        message: '6 ô tâm phải có 6 màu khác nhau',
        hint: 'Quét lại từng mặt theo đúng màu tâm được yêu cầu.',
        stickers: {for (final f in kFaceKeys) StickerRef(f, 4)},
      ),
    ];
  }
  const oppositeFace = {
    'top': 'bottom',
    'bottom': 'top',
    'front': 'back',
    'back': 'front',
    'left': 'right',
    'right': 'left',
  };
  Color opposite(Color c) {
    final face = centers.entries.firstWhere((e) => e.value == c).key;
    return centers[oppositeFace[face]]!;
  }

  // ---- 3. Từng viên cạnh / góc ------------------------------------------------
  final seenEdges = <String, Set<StickerRef>>{};
  final seenCorners = <String, Set<StickerRef>>{};
  for (var x = -1; x <= 1; x++) {
    for (var y = -1; y <= 1; y++) {
      for (var z = -1; z <= 1; z++) {
        final pos = [x, y, z];
        final nonZero = pos.where((v) => v != 0).length;
        if (nonZero < 2) continue;

        final stickers = <StickerRef>{};
        for (var axis = 0; axis < 3; axis++) {
          if (pos[axis] == 0) continue;
          final normal = [0, 0, 0]..[axis] = pos[axis];
          stickers.add(StickerRef.fromGeometry(pos, normal));
        }
        final colors = [
          for (final s in stickers) state.faces[s.face]![s.index]
        ];

        var valid = colors.toSet().length == colors.length;
        for (var i = 0; i < colors.length && valid; i++) {
          for (var j = i + 1; j < colors.length; j++) {
            if (opposite(colors[i]) == colors[j]) valid = false;
          }
        }
        final names = colors.map(RubikColors.nameOf).join(' – ');
        final isEdge = nonZero == 2;

        if (!valid) {
          issues.add(CubeIssue(
            type: isEdge ? CubeIssueType.badEdge : CubeIssueType.badCorner,
            message: isEdge
                ? 'Viên cạnh $names không có trên khối thật'
                : 'Viên góc $names không có trên khối thật',
            hint:
                'Hai màu đối diện (hoặc trùng màu) không thể nằm chung một viên. '
                'Kiểm tra lại các ô được tô sáng.',
            stickers: stickers,
          ));
          continue;
        }

        final key =
            (colors.map((c) => c.toARGB32()).toList()..sort()).join('-');
        final seen = isEdge ? seenEdges : seenCorners;
        if (seen.containsKey(key)) {
          issues.add(CubeIssue(
            type: CubeIssueType.duplicatePiece,
            message: isEdge
                ? 'Viên cạnh $names xuất hiện 2 lần'
                : 'Viên góc $names xuất hiện 2 lần',
            hint: 'Một trong hai viên được tô sáng bị quét nhầm màu.',
            stickers: {...seen[key]!, ...stickers},
          ));
        } else {
          seen[key] = stickers;
        }
      }
    }
  }
  if (issues.isNotEmpty) return issues;

  // ---- 4. Kiểm tra cấu trúc (lật / xoay / hoán vị) ------------------------
  final status = _kociembaStatus(state);
  const turnHint =
      'Thường do một mặt bị quét sai hướng: mở lại màn quét và dùng '
      'nút xoay lưới 90°/180° cho mặt đó. Nếu khối từng bị tháo lắp thì có thể khối không giải được.';
  switch (status) {
    case cuber.CubeStatus.twistedEdge:
      issues.add(const CubeIssue(
        type: CubeIssueType.twistedEdge,
        message: 'Có một viên cạnh bị lật ngược',
        hint: turnHint,
      ));
    case cuber.CubeStatus.twistedCorner:
      issues.add(const CubeIssue(
        type: CubeIssueType.twistedCorner,
        message: 'Có một viên góc bị xoay lệch',
        hint: turnHint,
      ));
    case cuber.CubeStatus.parityError:
      issues.add(const CubeIssue(
        type: CubeIssueType.parity,
        message: 'Có hai viên bị đổi chỗ cho nhau',
        hint: turnHint,
      ));
    case cuber.CubeStatus.missingEdge:
    case cuber.CubeStatus.missingCorner:
      issues.add(const CubeIssue(
        type: CubeIssueType.duplicatePiece,
        message: 'Thiếu một viên của khối',
        hint: 'Kiểm tra lại màu các ô góc và cạnh.',
      ));
    default:
      break;
  }
  return issues;
}

cuber.CubeStatus _kociembaStatus(Cube3DState state) {
  final codes = state.toSideColorCode();
  final centerToFace = {
    codes['top']![4]: 'U',
    codes['right']![4]: 'R',
    codes['front']![4]: 'F',
    codes['bottom']![4]: 'D',
    codes['left']![4]: 'L',
    codes['back']![4]: 'B',
  };
  String map(String s) => s.split('').map((c) => centerToFace[c] ?? c).join();
  final definition = [
    'top',
    'right',
    'front',
    'bottom',
    'left',
    'back',
  ].map((k) => map(codes[k]!)).join();
  try {
    return cuber.Cube.from(definition).verify();
  } catch (_) {
    return cuber.CubeStatus.missingEdge;
  }
}

Set<StickerRef> _stickersOf(Cube3DState state, Color color) => {
      for (final f in kFaceKeys)
        for (var i = 0; i < 9; i++)
          if (i != 4 && state.faces[f]![i] == color) StickerRef(f, i),
    };

String _confusionHint(Color c) {
  if (c == RubikColors.red || c == RubikColors.orange) {
    return 'Đỏ và Cam rất dễ nhầm dưới đèn vàng.';
  }
  if (c == RubikColors.white || c == RubikColors.yellow) {
    return 'Trắng và Vàng dễ nhầm khi ánh sáng ấm.';
  }
  if (c == RubikColors.blue || c == RubikColors.green) {
    return 'Xanh dương và Xanh lá dễ nhầm trong bóng tối.';
  }
  return '';
}
