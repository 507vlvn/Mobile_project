import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

const String kFontFamily = 'BeVietnamPro';

abstract final class AppTheme {
  static ThemeData light() => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme(
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
        ),
        background: AppColors.lightBackground,
        palette: AppPalette.light,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme(
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
        ),
        background: AppColors.darkBackground,
        palette: AppPalette.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color background,
    required AppPalette palette,
  }) {
    final textTheme = _textTheme(scheme.onSurface);
    final roundedMd = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: kFontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: brightness == Brightness.light ? 1 : 0,
        shadowColor: scheme.shadow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: brightness == Brightness.dark
              ? BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))
              : BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(kMinTouchTarget, 52),
          shape: roundedMd,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
          shape: roundedMd,
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
          shape: roundedMd,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
          textStyle: textTheme.labelLarge,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: brightness == Brightness.light ? 3 : 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: roundedMd,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        labelStyle: textTheme.labelMedium,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Thang chữ 12 / 14 / 16 / 18 / 22 / 28 / 32 — chữ nhỏ nhất 12.
  static TextTheme _textTheme(Color color) {
    TextStyle s(double size, FontWeight w, double height) => TextStyle(
          fontFamily: kFontFamily,
          fontSize: size,
          fontWeight: w,
          height: height,
          color: color,
        );
    return TextTheme(
      displaySmall: s(32, FontWeight.w700, 1.25),
      headlineMedium: s(28, FontWeight.w700, 1.25),
      headlineSmall: s(22, FontWeight.w700, 1.3),
      titleLarge: s(20, FontWeight.w600, 1.3),
      titleMedium: s(18, FontWeight.w600, 1.35),
      titleSmall: s(16, FontWeight.w600, 1.4),
      bodyLarge: s(16, FontWeight.w400, 1.5),
      bodyMedium: s(14, FontWeight.w400, 1.5),
      bodySmall: s(12, FontWeight.w400, 1.45),
      labelLarge: s(14, FontWeight.w600, 1.3),
      labelMedium: s(12, FontWeight.w600, 1.3),
      labelSmall: s(12, FontWeight.w500, 1.3),
    );
  }
}

/// Chữ số đều độ rộng cho đồng hồ, điểm, số bước — tránh con số "nhảy".
const List<FontFeature> kTabularFigures = [FontFeature.tabularFigures()];
