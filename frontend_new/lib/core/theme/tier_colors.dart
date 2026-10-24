import 'package:flutter/material.dart';

import '../models/rank.dart';

/// Màu 5 bậc rank — nơi DUY NHẤT được phép dùng mã màu thô cho rank.
/// Mỗi bậc có biến thể sáng/tối, chọn để đọc rõ trên nền surface của giao
/// diện tương ứng. Rank luôn đi kèm icon + tên nên màu không phải là kênh
/// thông tin duy nhất.
abstract final class TierColors {
  static const _light = {
    Tier.bronze: Color(0xFF9A4F1C),
    Tier.silver: Color(0xFF52606D),
    Tier.gold: Color(0xFF946200),
    Tier.platinum: Color(0xFF0F7490),
    Tier.diamond: Color(0xFF2F5BE0),
  };

  static const _dark = {
    Tier.bronze: Color(0xFFE08B52),
    Tier.silver: Color(0xFFB4BFCC),
    Tier.gold: Color(0xFFF2BE3A),
    Tier.platinum: Color(0xFF4FD1E8),
    Tier.diamond: Color(0xFF8FB0FF),
  };

  static Color of(Tier tier, Brightness brightness) =>
      (brightness == Brightness.dark ? _dark : _light)[tier]!;
}

extension TierColorX on BuildContext {
  Color tierColor(Tier tier) => TierColors.of(tier, Theme.of(this).brightness);
}
