import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/network/token_storage.dart';
import 'core/realtime/notification_overlay.dart';
import 'core/realtime/realtime_lifecycle.dart';
import 'core/realtime/realtime_service.dart';
import 'core/services/api_score_reporter.dart';
import 'core/services/challenge_launcher.dart';
import 'core/services/score_reporter.dart';
import 'core/services/shell_navigation.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/auth_controller.dart';
import 'features/caro/caro_screen.dart';
import 'features/puzzle/puzzle_screen.dart';
import 'features/rubik/practice/practice_screen.dart';
import 'features/shell/main_shell.dart';
import 'features/social/chat_screen.dart';
import 'features/sudoku/sudoku_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerChallengeGames();
  final themeController = ThemeController();
  await themeController.load();

  final tokens = TokenStorage();
  final api = DioApiClient(tokens: tokens);
  final auth = AuthController(api: api, tokens: tokens);
  api.onUnauthorized = auth.handleUnauthorized;
  final reporter =
      ApiScoreReporter(api: api, isLoggedIn: () => auth.isAuthenticated);
  // Sau khi đăng nhập/khôi phục phiên: gửi dần các điểm đang xếp hàng
  auth.onSignedIn = () => unawaited(reporter.flushQueue());

  // Realtime (SignalR): tự kết nối khi đăng nhập, ngắt khi đăng xuất hoặc
  // khi app ở nền quá 2 phút.
  final realtime = SignalRRealtimeService(tokens: tokens);
  RealtimeLifecycle(service: realtime, auth: auth).attach();
  final shellNavigation = ShellNavigation();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeController),
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<AuthController>.value(value: auth),
        Provider<ScoreReporter>.value(value: reporter),
        ListenableProvider<RealtimeService>.value(value: realtime),
        ChangeNotifierProvider<ShellNavigation>.value(value: shellNavigation),
      ],
      child: const GameHubApp(),
    ),
  );

  // Không chặn khung hình đầu tiên: app hiển thị ngay, phiên khôi phục sau.
  unawaited(auth.restore());
}

/// Game nào mở được từ nút "Chơi ngay" của một ván thách đấu.
/// Mọi game sinh đề từ `challenge.seed` nên hai người chơi nhận cùng một đề.
void _registerChallengeGames() {
  ChallengeLauncher.register('RUBIK', (c) => PracticeScreen(challenge: c));
  ChallengeLauncher.register('SUDOKU', (c) => SudokuScreen(challenge: c));
  ChallengeLauncher.register('PUZZLE', (c) => PuzzleScreen(challenge: c));
  ChallengeLauncher.register('CARO', (c) => CaroScreen(challenge: c));
}

/// Khóa Navigator dùng chung để lớp thông báo trong app mở được màn hình.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class GameHubApp extends StatelessWidget {
  const GameHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ThemeController>().mode;
    return MaterialApp(
      title: 'Game Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      themeAnimationDuration: const Duration(milliseconds: 250),
      navigatorKey: appNavigatorKey,
      builder: (context, child) => NotificationOverlay(
        navigatorKey: appNavigatorKey,
        myId: () => context.read<AuthController>().currentUser?.userId,
        onOpenChat: (nav, partner) => nav.push(MaterialPageRoute<void>(
            builder: (_) => ChatScreen(partner: partner))),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const MainShell(),
    );
  }
}
