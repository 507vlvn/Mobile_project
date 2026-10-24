import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'XepHinh/xep_hinh_screen.dart';

void main() {
  runApp(const XepHinhApp());
}

class XepHinhApp extends StatelessWidget {
  const XepHinhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xếp Hình Master',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const XepHinhScreen(),
    );
  }
}
