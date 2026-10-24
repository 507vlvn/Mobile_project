import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/difficulty.dart';

/// Chọn độ khó Dễ / Vừa / Khó dạng SegmentedButton.
class DifficultySelector extends StatelessWidget {
  final Difficulty value;
  final ValueChanged<Difficulty> onChanged;

  const DifficultySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<Difficulty>(
      showSelectedIcon: false,
      segments: [
        for (final d in Difficulty.values)
          ButtonSegment(value: d, label: Text(d.label)),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Ghi nhớ độ khó đã chọn gần nhất cho từng game.
abstract final class DifficultyMemory {
  static String _key(String gameCode) => 'difficulty_$gameCode';

  static Future<Difficulty> load(String gameCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return Difficulty.fromValue(prefs.getInt(_key(gameCode)));
    } catch (_) {
      return Difficulty.medium;
    }
  }

  static Future<void> save(String gameCode, Difficulty d) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key(gameCode), d.value);
    } catch (_) {}
  }
}
