import 'package:flutter/widgets.dart';

/// Khoảng cách theo nhịp 4/8dp.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Lề hai bên màn hình
  static const double screen = 16;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// Kích thước tối thiểu của vùng chạm (Material: 48dp).
const double kMinTouchTarget = 48;

/// Token chuyển động dùng chung — mọi hiệu ứng phải lấy từ đây.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 350);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const standard = Curves.easeInOutCubic;

  /// Trả về [d] hoặc gần như 0 nếu người dùng bật "giảm chuyển động".
  static Duration of(BuildContext context, Duration d) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false
        ? const Duration(milliseconds: 1)
        : d;
  }
}
