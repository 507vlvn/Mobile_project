import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/realtime/match_models.dart';
import 'match_session.dart';

/// Caro không có độ khó trong trận online; mọi người cùng vào một hàng chờ
/// (server ghép theo cặp game + độ khó, nên cố định một giá trị).
const kCaroOnlineDifficulty = 2;

String pvpGameName(String gameCode) => switch (gameCode) {
      kGameCaro => 'Caro',
      kGamePuzzle => 'Xếp số',
      'SUDOKU' => 'Sudoku',
      'RUBIK' => 'Rubik',
      _ => gameCode,
    };

IconData pvpGameIcon(String gameCode) => switch (gameCode) {
      kGameCaro => Icons.grid_on_rounded,
      kGamePuzzle => Icons.apps_rounded,
      _ => Icons.sports_esports_rounded,
    };

/// Nhãn độ khó Xếp số: 1/2/3 = lưới 3×3 / 4×4 / 5×5.
String puzzleSizeLabel(int difficulty) {
  final n = difficulty.clamp(1, 3) + 2;
  return '$n×$n';
}

/// Mô tả ngắn một ván: "Caro" hoặc "Xếp số 4×4".
String pvpGameLabel(String gameCode, int difficulty) =>
    gameCode == kGamePuzzle ? 'Xếp số ${puzzleSizeLabel(difficulty)}' : pvpGameName(gameCode);

/// [MatchSession] nếu app có cung cấp (test / ảnh chụp có thể không có).
MatchSession? maybeMatchSessionOf(BuildContext context, {bool listen = false}) {
  try {
    return listen ? context.watch<MatchSession>() : context.read<MatchSession>();
  } on ProviderNotFoundException {
    return null;
  }
}

/// "mm:ss"
String formatMmSs(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(s ~/ 60)}:${two(s % 60)}';
}
