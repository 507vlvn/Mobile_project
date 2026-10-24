import 'package:flutter/material.dart';

/// Bậc rank theo rating Elo (TASKS_V2 §2.3).
/// Đồng < 1100 · Bạc < 1250 · Vàng < 1400 · Bạch kim < 1600 · Kim cương >= 1600.
enum Tier {
  bronze('BRONZE', 'Đồng', 0, Icons.shield_rounded),
  silver('SILVER', 'Bạc', 1100, Icons.military_tech_rounded),
  gold('GOLD', 'Vàng', 1250, Icons.workspace_premium_rounded),
  platinum('PLATINUM', 'Bạch kim', 1400, Icons.stars_rounded),
  diamond('DIAMOND', 'Kim cương', 1600, Icons.diamond_rounded);

  const Tier(this.code, this.label, this.minRating, this.icon);

  /// Mã server có thể trả (BRONZE..DIAMOND).
  final String code;

  /// Tên tiếng Việt.
  final String label;

  /// Rating thấp nhất của bậc.
  final int minRating;
  final IconData icon;

  /// Rating khởi điểm của mọi người chơi.
  static const int startRating = 1000;

  static Tier fromRating(int rating) {
    var result = Tier.bronze;
    for (final t in Tier.values) {
      if (rating >= t.minRating) result = t;
    }
    return result;
  }

  /// Đọc mã server (không phân biệt hoa thường); null nếu không nhận ra.
  static Tier? tryParse(String? code) {
    if (code == null) return null;
    final c = code.trim().toUpperCase();
    for (final t in Tier.values) {
      if (t.code == c) return t;
    }
    return null;
  }

  /// Bậc kế tiếp, null nếu đã ở bậc cao nhất.
  Tier? get next =>
      index + 1 < Tier.values.length ? Tier.values[index + 1] : null;
}
