import 'package:flutter/material.dart';

/// Thông tin hiển thị của từng game (khớp mã game phía server).
class GameMeta {
  final String code;
  final String name;
  final IconData icon;
  const GameMeta(this.code, this.name, this.icon);

  static const all = <GameMeta>[
    GameMeta('RUBIK', 'Rubik 3D', Icons.view_in_ar_rounded),
    GameMeta('SUDOKU', 'Sudoku', Icons.grid_3x3_rounded),
    GameMeta('PUZZLE', 'Xếp hình', Icons.apps_rounded),
    GameMeta('CARO', 'Caro', Icons.grid_on_rounded),
  ];

  static GameMeta of(String code) => all.firstWhere(
        (g) => g.code == code,
        orElse: () => GameMeta(code, code, Icons.sports_esports_rounded),
      );
}

/// Thời gian tương đối bằng tiếng Việt.
String relativeTimeVi(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = n.difference(t);
  if (d.isNegative || d.inSeconds < 60) return 'Vừa xong';
  if (d.inMinutes < 60) return '${d.inMinutes} phút trước';
  if (d.inHours < 24) return '${d.inHours} giờ trước';
  final days = DateTime(n.year, n.month, n.day)
      .difference(DateTime(t.year, t.month, t.day))
      .inDays;
  if (days == 1) return 'Hôm qua';
  if (days < 7) return '$days ngày trước';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year}';
}
