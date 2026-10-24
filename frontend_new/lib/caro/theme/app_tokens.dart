import 'package:flutter/widgets.dart';

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const double screen = 16;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

const double kMinTouchTarget = 48;

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 350);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const standard = Curves.easeInOutCubic;

  static Duration of(BuildContext context, Duration d) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false
        ? const Duration(milliseconds: 1)
        : d;
  }
}

const List<FontFeature> kTabularFigures = [FontFeature.tabularFigures()];
