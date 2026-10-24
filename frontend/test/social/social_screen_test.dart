import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/network/api_client.dart';
import 'package:mobile_rubik/core/network/models.dart';
import 'package:mobile_rubik/core/theme/app_theme.dart';
import 'package:mobile_rubik/features/auth/auth_controller.dart';
import 'package:mobile_rubik/features/social/social_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/fakes.dart';
import 'helpers.dart';

Widget _host(FakeApiClient api, AuthController auth) => MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<AuthController>.value(value: auth),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const SocialScreen()),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('khách: hiện lời mời đăng nhập, không gọi API', (tester) async {
    final api = FakeApiClient();
    final auth = AuthController(api: api, tokens: FakeTokenStorage());
    await tester.runAsync(auth.restore);
    await tester.pumpWidget(_host(api, auth));
    await tester.pump();
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Tìm người chơi'), findsNothing);
  });

  testWidgets('tìm kiếm: debounce 400ms và cần ít nhất 2 ký tự', (tester) async {
    final api = FakeApiClient();
    api.onLogin = () async => const AuthResult(token: 't', user: testUser);
    final queries = <String>[];
    api.onSearchUsers = (q) async {
      queries.add(q);
      return const [UserSummary(userId: 12, username: 'lan_pham')];
    };
    final auth = AuthController(api: api, tokens: FakeTokenStorage());
    await tester.runAsync(() => auth.login('an', 'x'));
    await tester.pumpWidget(_host(api, auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'l');
    await tester.pump(const Duration(seconds: 1));
    expect(queries, isEmpty);

    await tester.enterText(find.byType(TextField), 'la');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField), 'lan');
    await tester.pump(const Duration(milliseconds: 399));
    expect(queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 5));
    await tester.pumpAndSettle();
    expect(queries, ['lan']); // chỉ một lần, với từ khoá cuối
    expect(find.text('@lan_pham'), findsOneWidget);
  });

  testWidgets('đăng nhập: tải thách đấu một lần và chia nhóm', (tester) async {
    final api = FakeApiClient();
    api.onLogin = () async => const AuthResult(token: 't', user: testUser);
    var calls = 0;
    api.onChallenges = (box) async {
      calls++;
      return [
        challenge(1, challengerId: 2, opponentId: 7),
        challenge(2, status: ChallengeStatus.accepted),
      ];
    };
    final auth = AuthController(api: api, tokens: FakeTokenStorage());
    await tester.runAsync(() => auth.login('an', 'x'));
    await tester.pumpWidget(_host(api, auth));
    await tester.pumpAndSettle();
    expect(calls, 0); // tab Thách đấu chỉ dựng khi được mở
    await tester.tap(find.text('Thách đấu'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Lời mời đến (1)'), findsOneWidget);
    expect(find.text('Đang diễn ra (1)'), findsOneWidget);
    expect(find.text('Chấp nhận'), findsOneWidget);
    expect(find.text('Chơi ngay'), findsOneWidget);
  });
}
