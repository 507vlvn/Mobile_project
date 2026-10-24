import 'package:flutter/material.dart';

abstract final class AppColors {
  // ----- Giao diện sáng -----
  static const lightPrimary = Color(0xFF7C3AED);
  static const lightSecondary = Color(0xFF6D28D9);
  static const lightAccent = Color(0xFFE11D48);
  static const lightBackground = Color(0xFFF8F7FC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceVariant = Color(0xFFF1EEF9);
  static const lightOnSurface = Color(0xFF0F172A);
  static const lightOnSurfaceMuted = Color(0xFF475569);
  static const lightOutline = Color(0xFFDDD6FE);
  static const lightError = Color(0xFFDC2626);
  static const lightSuccess = Color(0xFF16A34A);
  static const lightWarning = Color(0xFFB45309);

  // ----- Giao diện tối -----
  static const darkPrimary = Color(0xFF7C3AED);
  static const darkSecondary = Color(0xFFA78BFA);
  static const darkAccent = Color(0xFFF43F5E);
  static const darkBackground = Color(0xFF0F0F23);
  static const darkSurface = Color(0xFF1E1C35);
  static const darkSurfaceVariant = Color(0xFF27273B);
  static const darkOnSurface = Color(0xFFE2E8F0);
  static const darkOnSurfaceMuted = Color(0xFF94A3B8);
  static const darkOutline = Color(0xFF4C1D95);
  static const darkError = Color(0xFFEF4444);
  static const darkSuccess = Color(0xFF22C55E);
  static const darkWarning = Color(0xFFF59E0B);
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color success;
  final Color warning;
  final Color accent;
  final Color onSurfaceMuted;
  final Color stage;

  const AppPalette({
    required this.success,
    required this.warning,
    required this.accent,
    required this.onSurfaceMuted,
    required this.stage,
  });

  static const light = AppPalette(
    success: AppColors.lightSuccess,
    warning: AppColors.lightWarning,
    accent: AppColors.lightAccent,
    onSurfaceMuted: AppColors.lightOnSurfaceMuted,
    stage: Color(0xFFECE8F7),
  );

  static const dark = AppPalette(
    success: AppColors.darkSuccess,
    warning: AppColors.darkWarning,
    accent: AppColors.darkAccent,
    onSurfaceMuted: AppColors.darkOnSurfaceMuted,
    stage: Color(0xFF16152B),
  );

  @override
  AppPalette copyWith({
    Color? success,
    Color? warning,
    Color? accent,
    Color? onSurfaceMuted,
    Color? stage,
  }) {
    return AppPalette(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      accent: accent ?? this.accent,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      stage: stage ?? this.stage,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onSurfaceMuted: Color.lerp(onSurfaceMuted, other.onSurfaceMuted, t)!,
      stage: Color.lerp(stage, other.stage, t)!,
    );
  }
}

extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}
