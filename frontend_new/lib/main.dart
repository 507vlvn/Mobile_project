import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'caro/caro_screen.dart';
import 'caro/services/score_reporter.dart';
import 'caro/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        Provider<ScoreReporter>(
          create: (_) => LocalScoreReporter(),
        ),
      ],
      child: const CaroApp(),
    ),
  );
}

class CaroApp extends StatelessWidget {
  const CaroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Caro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const CaroScreen(),
    );
  }
}
