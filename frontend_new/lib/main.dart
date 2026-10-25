import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_controller.dart';
import 'core/network/api_client.dart';
import 'core/network/token_storage.dart';
import 'core/realtime/realtime_lifecycle.dart';
import 'core/realtime/realtime_service.dart';
import 'core/services/api_score_reporter.dart';
import 'core/services/score_reporter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'pvp/match_session.dart';
import 'shell/main_shell.dart';
import 'soduku/logic/sudoku_controller.dart';
import 'soduku/logic/sudoku_learning_manager.dart';
import 'soduku/logic/sudoku_stats_manager.dart';

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
  // Kết nối API cho tiến trình và thống kê Sudoku
  SudokuLearningManager.instance.attachApi(api);
  SudokuStatsManager.instance.attachApi(api);
  unawaited(SudokuLearningManager.instance.init(api: api));
  unawaited(SudokuStatsManager.instance.init(api: api));

  // Tự động chuyển đổi tiến trình và làm mới ván cờ theo từng tài khoản (hoặc khi đăng xuất)
  auth.addListener(() {
    final uid = auth.currentUser?.userId;
    unawaited(SudokuLearningManager.instance.switchUser(uid));
    SudokuController.instance.onUserChanged(uid);
    unawaited(SudokuStatsManager.instance.switchUser(uid));
  });

  // Sau khi đăng nhập/khôi phục phiên: gửi dần các điểm đang xếp hàng và đồng bộ Sudoku
  auth.onSignedIn = () {
    unawaited(reporter.flushQueue());
    unawaited(SudokuLearningManager.instance.syncWithServer());
    unawaited(SudokuStatsManager.instance.syncWithServer());
  };

  // Realtime (SignalR): tự kết nối khi đăng nhập, ngắt khi đăng xuất hoặc khi
  // app ở nền quá 2 phút. Còn kết nối thì server mới báo mình "online" với bạn bè.
  final realtime = SignalRRealtimeService(tokens: tokens);
  RealtimeLifecycle(service: realtime, auth: auth).attach();

  // Đối kháng: trạng thái hàng chờ / lời mời / trận đấu dùng chung cho cả app.
  final matchSession = MatchSession(realtime: realtime);
  auth.addListener(() {
    if (!auth.isAuthenticated) matchSession.reset();
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeController),
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<AuthController>.value(value: auth),
        Provider<ScoreReporter>.value(value: reporter),
        ListenableProvider<RealtimeService>.value(value: realtime),
        ChangeNotifierProvider<MatchSession>.value(value: matchSession),
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
