import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.lightPrimary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFEDE4FF),
      onPrimaryContainer: Color(0xFF3B0D91),
      secondary: AppColors.lightSecondary,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE9E3FB),
      onSecondaryContainer: Color(0xFF2E1065),
      tertiary: AppColors.lightAccent,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFFFE4E8),
      onTertiaryContainer: Color(0xFF881337),
      error: AppColors.lightError,
      onError: Colors.white,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF7F1D1D),
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightOnSurface,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFFBFAFE),
      surfaceContainer: AppColors.lightBackground,
      surfaceContainerHigh: AppColors.lightSurfaceVariant,
      surfaceContainerHighest: Color(0xFFE7E2F5),
      onSurfaceVariant: AppColors.lightOnSurfaceMuted,
      outline: Color(0xFFC4B5FD),
      outlineVariant: AppColors.lightOutline,
      shadow: Color(0x1A1E1B4B),
      inverseSurface: Color(0xFF1E1C35),
      onInverseSurface: Color(0xFFF1F5F9),
      inversePrimary: Color(0xFFC4B5FD),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      extensions: const [AppPalette.light],
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.darkPrimary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF3B1F7A),
      onPrimaryContainer: Color(0xFFEDE4FF),
      secondary: AppColors.darkSecondary,
      onSecondary: Color(0xFF0F172A),
      secondaryContainer: Color(0xFF2E2950),
      onSecondaryContainer: Color(0xFFE9E3FB),
      tertiary: AppColors.darkAccent,
      onTertiary: Colors.black,
      tertiaryContainer: Color(0xFF4C0519),
      onTertiaryContainer: Color(0xFFFFE4E8),
      error: AppColors.darkError,
      onError: Colors.black,
      errorContainer: Color(0xFF451A1A),
      onErrorContainer: Color(0xFFFECACA),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkOnSurface,
      surfaceContainerLowest: Color(0xFF0B0B1A),
      surfaceContainerLow: Color(0xFF16152B),
      surfaceContainer: AppColors.darkSurface,
      surfaceContainerHigh: AppColors.darkSurfaceVariant,
      surfaceContainerHighest: Color(0xFF312F4A),
      onSurfaceVariant: AppColors.darkOnSurfaceMuted,
      outline: Color(0xFF6D4BC4),
      outlineVariant: AppColors.darkOutline,
      shadow: Colors.black,
      inverseSurface: Color(0xFFE2E8F0),
      onInverseSurface: Color(0xFF0F172A),
      inversePrimary: AppColors.lightPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      extensions: const [AppPalette.dark],
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}
