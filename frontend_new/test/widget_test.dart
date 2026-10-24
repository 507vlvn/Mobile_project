import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_new/auth/auth_controller.dart';
import 'package:frontend_new/core/network/api_client.dart';
import 'package:frontend_new/core/network/models.dart';
import 'package:frontend_new/core/network/token_storage.dart';
import 'package:frontend_new/core/theme/theme_controller.dart';
import 'package:frontend_new/main.dart';

const _me = AppUser(userId: 7, username: 'binh', email: 'binh@example.com', fullName: 'Thái Bình');

class _FakeApi implements ApiClient {
  @override
  VoidCallback? onUnauthorized;

  String? updatedName;

  @override
  Future<AuthResult> login({required String usernameOrEmail, required String password}) async =>
      const AuthResult(token: 't', user: _me);

  @override
  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
  }) async =>
      const AuthResult(token: 't', user: _me);

  @override
  Future<AppUser> me() async => _me;

  @override
  Future<AppUser> updateMe({String? fullName}) async {
    updatedName = fullName;
    return AppUser(userId: 7, username: 'binh', email: _me.email, fullName: fullName);
  }

  @override
  Future<List<GameStats>> myRatings() async => const [
        GameStats(gameCode: 'SUDOKU', rating: 1300, games: 10, wins: 7, losses: 3),
      ];

  @override
  Future<List<GameStats>> profileStats(int userId) async => const [
        GameStats(gameCode: 'SUDOKU', rating: 1300, games: 10, wins: 7, losses: 3, bestScore: 950),
      ];

  @override
  Future<PagedResult<MatchHistoryItem>> matches({int page = 1, int pageSize = 20}) async =>
      PagedResult(
        items: [
          MatchHistoryItem(
            matchId: 1,
            gameCode: 'SUDOKU',
            ranked: true,
            opponent: const UserSummary(userId: 9, username: 'an', fullName: 'Nguyễn An'),
            result: MatchResult.win,
            ratingDelta: 16,
            endedAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
        ],
        page: 1,
        pageSize: 20,
        total: 1,
      );
}

Future<AuthController> _pumpApp(WidgetTester tester, {bool loggedIn = false}) async {
  SharedPreferences.setMockInitialValues(loggedIn ? {'auth_token': 't'} : {});
  final api = _FakeApi();
  final tokens = TokenStorage();
  final auth = AuthController(api: api, tokens: tokens);
  await auth.restore();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeController()),
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider<AuthController>.value(value: auth),
    ],
    child: const MyApp(),
  ));
  return auth;
}

Future<void> _openProfile(WidgetTester tester) async {
  await tester.tap(find.descendant(
      of: find.byType(NavigationBar), matching: find.text('Hồ sơ')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Home hiển thị danh sách trò chơi', (WidgetTester tester) async {
    await _pumpApp(tester);

    expect(find.text('Chọn trò chơi'), findsOneWidget);
    for (final name in ['Rubik 3D', 'Sudoku', 'Xếp hình', 'Caro']) {
      expect(find.text(name), findsOneWidget);
    }

    // Chưa có chức năng: bấm vào game chỉ hiện thông báo.
    await tester.tap(find.text('Sudoku'));
    await tester.pump();
    expect(find.text('Sudoku đang được phát triển, sắp ra mắt!'), findsOneWidget);
  });

  testWidgets('Thanh điều hướng dưới chuyển được tab', (WidgetTester tester) async {
    await _pumpApp(tester);

    for (final label in ['Trò chơi', 'Đối kháng', 'Xếp hạng', 'Bạn bè', 'Hồ sơ']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Bạn bè'));
    await tester.pumpAndSettle();
    expect(find.text('Đang được phát triển'), findsOneWidget);
  });

  testWidgets('Hồ sơ khi chưa đăng nhập: hiện thẻ Khách và mở được màn đăng nhập',
      (WidgetTester tester) async {
    await _pumpApp(tester);
    await _openProfile(tester);

    expect(find.text('Khách'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsNothing);

    await tester.tap(find.text('Đăng nhập / Đăng ký'));
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng trở lại'), findsOneWidget);
  });

  testWidgets('Hồ sơ khi đã đăng nhập: tên, thống kê, lịch sử trận', (WidgetTester tester) async {
    await _pumpApp(tester, loggedIn: true);
    await _openProfile(tester);

    expect(find.text('Thái Bình'), findsOneWidget);
    expect(find.text('@binh'), findsOneWidget);
    expect(find.text('1300 điểm'), findsOneWidget);
    expect(find.text('10 trận · thắng 70%'), findsOneWidget);
    expect(find.text('Kỷ lục 950'), findsOneWidget);
    expect(find.text('Cao nhất · Sudoku'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('vs Nguyễn An'), 200);
    expect(find.text('vs Nguyễn An'), findsOneWidget);
    expect(find.text('+16'), findsOneWidget);
  });

  testWidgets('Sửa tên hiển thị và đăng xuất', (WidgetTester tester) async {
    final auth = await _pumpApp(tester, loggedIn: true);
    await _openProfile(tester);

    await tester.scrollUntilVisible(find.text('Sửa tên hiển thị'), 200);
    await tester.tap(find.text('Sửa tên hiển thị'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Bình Mới');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(auth.currentUser?.fullName, 'Bình Mới');
    expect(find.text('Đã cập nhật tên hiển thị'), findsOneWidget);
    // Đợi SnackBar tự ẩn để không che nút Đăng xuất.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Đăng xuất'), 200);
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
    await tester.pumpAndSettle();
    expect(auth.isAuthenticated, isFalse);
    expect(find.text('Khách'), findsOneWidget);
  });
}
