import 'package:flutter/material.dart';

/// Các chủ đề giao diện bàn cờ Caro (8 phong cách đa dạng)
enum CaroBoardTheme {
  wood('Gỗ cổ điển', Icons.table_restaurant_rounded),
  notebook('Vở ô ly', Icons.menu_book_rounded),
  go('Cờ vây đá', Icons.lens_rounded),
  cyber('Cyberpunk', Icons.blur_on_rounded),
  sakura('Hoa anh đào', Icons.filter_vintage_rounded),
  galaxy('Thiên hà', Icons.auto_awesome_rounded),
  calligraphy('Thư pháp', Icons.brush_rounded),
  retro('Pixel 8-bit', Icons.videogame_asset_rounded);

  const CaroBoardTheme(this.label, this.icon);

  final String label;
  final IconData icon;

  static CaroBoardTheme fromName(String? name) {
    return CaroBoardTheme.values.firstWhere(
      (t) => t.name == name,
      orElse: () => CaroBoardTheme.wood,
    );
  }
}

/// Bảng màu và thông số hiển thị chi tiết cho từng theme
class CaroThemeData {
  final CaroBoardTheme type;
  final Color surfaceColor;
  final Color gridColor;
  final Color markColor;
  final Color xColor;
  final Color oColor;
  final Color accentColor;
  final Color hintColor;
  final bool isGoStones;
  final bool isPaperGrid;
  final bool isNeonGlow;
  final bool isSakura;
  final bool isGalaxy;
  final bool isCalligraphy;
  final bool isPixel;

  const CaroThemeData({
    required this.type,
    required this.surfaceColor,
    required this.gridColor,
    required this.markColor,
    required this.xColor,
    required this.oColor,
    required this.accentColor,
    required this.hintColor,
    this.isGoStones = false,
    this.isPaperGrid = false,
    this.isNeonGlow = false,
    this.isSakura = false,
    this.isGalaxy = false,
    this.isCalligraphy = false,
    this.isPixel = false,
  });

  factory CaroThemeData.fromTheme(CaroBoardTheme theme, {bool isDark = false}) {
    switch (theme) {
      case CaroBoardTheme.wood:
        return CaroThemeData(
          type: theme,
          surfaceColor: isDark ? const Color(0xFF2C241E) : const Color(0xFFF0E5D8),
          gridColor: isDark ? const Color(0xFF6B5848) : const Color(0xFFC7B6A3),
          markColor: isDark ? const Color(0xFFB59A7E) : const Color(0xFF8B6F52),
          xColor: const Color(0xFF2563EB),
          oColor: const Color(0xFFEA580C),
          accentColor: const Color(0xFF10B981),
          hintColor: const Color(0xFFF59E0B),
        );

      case CaroBoardTheme.notebook:
        return const CaroThemeData(
          type: CaroBoardTheme.notebook,
          surfaceColor: Color(0xFFFAF7F2), // Màu giấy tập học sinh
          gridColor: Color(0xFFC4D5EB), // Đường kẻ caro xanh nhạt vở học sinh
          markColor: Color(0xFF93B3DC),
          xColor: Color(0xFF1D4ED8), // Bút bi xanh
          oColor: Color(0xFFDC2626), // Bút bi đỏ
          accentColor: Color(0xFF16A34A),
          hintColor: Color(0xFFD97706),
          isPaperGrid: true,
        );

      case CaroBoardTheme.go:
        return const CaroThemeData(
          type: CaroBoardTheme.go,
          surfaceColor: Color(0xFFDEB887), // Gỗ bàn cờ vây sồi Kaya
          gridColor: Color(0xFF5C4033),
          markColor: Color(0xFF3E2723),
          xColor: Color(0xFF1A1A1A), // Quân đá đen
          oColor: Color(0xFFF8FAFC), // Quân ngọc trắng sáng
          accentColor: Color(0xFFD97706),
          hintColor: Color(0xFFF59E0B),
          isGoStones: true,
        );

      case CaroBoardTheme.cyber:
        return const CaroThemeData(
          type: CaroBoardTheme.cyber,
          surfaceColor: Color(0xFF0B0F19), // Nền không gian số tối đậm
          gridColor: Color(0xFF1E293B),
          markColor: Color(0xFF38BDF8),
          xColor: Color(0xFFF43F5E), // Neon Rose
          oColor: Color(0xFF06B6D4), // Neon Cyan
          accentColor: Color(0xFFA855F7), // Neon Purple
          hintColor: Color(0xFFEAB308),
          isNeonGlow: true,
        );

      case CaroBoardTheme.sakura:
        return const CaroThemeData(
          type: CaroBoardTheme.sakura,
          surfaceColor: Color(0xFFFFF1F2), // Hồng phấn pastel thanh nhã
          gridColor: Color(0xFFFECDD3), // Lưới hồng phấn mờ
          markColor: Color(0xFFF43F5E),
          xColor: Color(0xFFE11D48), // Hồng cánh đào
          oColor: Color(0xFF0284C7), // Xanh ngọc lam bầu trời
          accentColor: Color(0xFFEC4899),
          hintColor: Color(0xFFF59E0B),
          isSakura: true,
        );

      case CaroBoardTheme.galaxy:
        return const CaroThemeData(
          type: CaroBoardTheme.galaxy,
          surfaceColor: Color(0xFF100C2A), // Vũ trụ tím thẫm
          gridColor: Color(0xFF2E2360), // Lưới ánh tím sao
          markColor: Color(0xFFFDE047),
          xColor: Color(0xFF38BDF8), // Sao xanh điện tử
          oColor: Color(0xFFFACC15), // Hành tinh vàng kim
          accentColor: Color(0xFF818CF8),
          hintColor: Color(0xFFF43F5E),
          isGalaxy: true,
        );

      case CaroBoardTheme.calligraphy:
        return const CaroThemeData(
          type: CaroBoardTheme.calligraphy,
          surfaceColor: Color(0xFFF5EEDC), // Giấy xuyến chỉ cổ kính
          gridColor: Color(0xFFD7CCC8), // Mực tàu nhạt
          markColor: Color(0xFF8D6E63),
          xColor: Color(0xFF1C1917), // Nét mực tàu đen tuyền
          oColor: Color(0xFFB91C1C), // Dấu ấn triện son đỏ
          accentColor: Color(0xFFB45309),
          hintColor: Color(0xFFD97706),
          isCalligraphy: true,
        );

      case CaroBoardTheme.retro:
        return const CaroThemeData(
          type: CaroBoardTheme.retro,
          surfaceColor: Color(0xFF8BAC0F), // Xanh màn hình máy Game Boy cổ điển
          gridColor: Color(0xFF306230), // Lưới xanh pixel
          markColor: Color(0xFF0F380F),
          xColor: Color(0xFF0F380F), // Nét pixel đen xanh đậm
          oColor: Color(0xFF1F4E1F), // Nét viền pixel
          accentColor: Color(0xFF306230),
          hintColor: Color(0xFF0F380F),
          isPixel: true,
        );
    }
  }
}
