import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'caro/services/score_reporter.dart';
import 'core/theme/app_theme.dart';
import 'shell/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ScoreReporter>(
          create: (_) => LocalScoreReporter(),
        ),
      ],
      child: MaterialApp(
        title: 'GameHub',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const MainShell(),
      ),
    );
  }
}
