import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_controller.dart';
import 'core/network/api_client.dart';
import 'core/network/token_storage.dart';
import 'core/services/api_score_reporter.dart';
import 'core/services/score_reporter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'shell/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = ThemeController();
  await themeController.load();

  final tokens = TokenStorage();
  final api = HttpApiClient(tokens: tokens);
  final auth = AuthController(api: api, tokens: tokens);
  api.onUnauthorized = auth.handleUnauthorized;
  final reporter =
      ApiScoreReporter(api: api, isLoggedIn: () => auth.isAuthenticated);
  // Sau khi đăng nhập/khôi phục phiên: gửi dần các điểm đang xếp hàng
  auth.onSignedIn = () => unawaited(reporter.flushQueue());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeController),
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<AuthController>.value(value: auth),
        Provider<ScoreReporter>.value(value: reporter),
      ],
      child: const MyApp(),
    ),
  );

  // Không chặn khung hình đầu tiên: app hiển thị ngay, phiên khôi phục sau.
  unawaited(auth.restore());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GameHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: context.watch<ThemeController>().mode,
      home: const MainShell(),
    );
  }
}
