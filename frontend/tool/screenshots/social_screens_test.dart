// ignore_for_file: invalid_use_of_visible_for_testing_member
// Chụp ảnh các màn Bạn bè: thách đấu, tin nhắn, chat (giao diện sáng + tối).
// Chạy: flutter test tool/screenshots/social_screens_test.dart --dart-define=OUT=<thư mục>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/network/api_client.dart';
import 'package:mobile_rubik/core/network/api_exception.dart';
import 'package:mobile_rubik/core/network/models.dart';
import 'package:mobile_rubik/core/theme/app_theme.dart';
import 'package:mobile_rubik/core/theme/theme_controller.dart';
import 'package:mobile_rubik/features/auth/auth_controller.dart';
import 'package:mobile_rubik/features/social/chat_screen.dart';
import 'package:mobile_rubik/features/social/player_sheet.dart';
import 'package:mobile_rubik/features/social/social_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/core/fakes.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/screenshots');
final _boundary = GlobalKey();

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      final bytes = File(p).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load(kFontFamily, [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/BeVietnamPro-$w.ttf',
  ]);
  final flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final iconFont = '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf';
  if (File(iconFont).existsSync()) {
    await load('MaterialIcons', [iconFont]);
  }
}

Widget _app(Widget home, ThemeMode mode, FakeApiClient api, AuthController auth) {
  final controller = ThemeController()..setMode(mode);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: controller),
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider<AuthController>.value(value: auth),
    ],
    child: RepaintBoundary(
      key: _boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: home,
      ),
    ),
  );
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 50));
  final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_out/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

const _me = 7; // testUser

ChallengeUser _u(int id, String username, [String? name]) =>
    ChallengeUser(userId: id, username: username, fullName: name);

Challenge _c(
  int id,
  ChallengeStatus status,
  String game,
  int diff,
  ChallengeUser challenger,
  ChallengeUser opponent,
  Duration ago, {
  ChallengeResult? mine,
  ChallengeResult? theirs,
  int? winner,
}) {
  final t = DateTime.now().subtract(ago);
  return Challenge(
    id: id,
    gameCode: game,
    gameName: game,
    difficulty: diff,
    status: status,
    createdAt: t,
    acceptedAt: status == ChallengeStatus.pending ? null : t,
    completedAt: status == ChallengeStatus.completed ? t : null,
    challenger: challenger,
    opponent: opponent,
    myResult: mine,
    theirResult: theirs,
    winnerId: winner,
  );
}

FakeApiClient _api() {
  final me = _u(_me, 'an_nguyen', 'Nguyễn Văn An');
  final lan = _u(12, 'lan_pham', 'Phạm Thị Lan');
  final minh = _u(11, 'minh_tran', 'Trần Quang Minh');
  final hoang = _u(13, 'hoang99');
  final bao = _u(14, 'bao_le', 'Lê Gia Bảo');
  const win = ChallengeResult(score: 1720, timeSeconds: 230, mistakes: 1);
  const lose = ChallengeResult(score: 1488, timeSeconds: 412, mistakes: 2);

  final api = FakeApiClient();
  api.onLogin = () async => const AuthResult(token: 't', user: testUser);
  api.onChallenges = (box) async => [
        _c(1, ChallengeStatus.pending, 'CARO', 3, lan, me, const Duration(minutes: 20)),
        _c(2, ChallengeStatus.pending, 'SUDOKU', 2, minh, me, const Duration(hours: 5)),
        _c(3, ChallengeStatus.pending, 'RUBIK', 1, me, hoang, const Duration(hours: 2)),
        _c(4, ChallengeStatus.accepted, 'PUZZLE', 2, me, bao, const Duration(hours: 8)),
        _c(5, ChallengeStatus.accepted, 'SUDOKU', 3, lan, me, const Duration(days: 1),
            mine: const ChallengeResult(score: 2105, timeSeconds: 640)),
        _c(6, ChallengeStatus.completed, 'SUDOKU', 2, me, minh, const Duration(days: 2),
            mine: win, theirs: lose, winner: _me),
        _c(7, ChallengeStatus.completed, 'CARO', 3, bao, me, const Duration(days: 3),
            mine: lose, theirs: win, winner: 14),
        _c(8, ChallengeStatus.completed, 'PUZZLE', 1, me, lan, const Duration(days: 4),
            mine: const ChallengeResult(score: 900, timeSeconds: 80),
            theirs: const ChallengeResult(score: 900, timeSeconds: 80)),
        _c(9, ChallengeStatus.declined, 'RUBIK', 2, hoang, me, const Duration(days: 5)),
      ];
  api.onSearchUsers = (q) async => const [
        UserSummary(userId: 12, username: 'lan_pham', fullName: 'Phạm Thị Lan'),
        UserSummary(userId: 14, username: 'lan_anh_2k', fullName: 'Đỗ Lan Anh'),
        UserSummary(userId: 15, username: 'planet'),
      ];
  api.onConversations = () async => [
        Conversation(
          userId: 12,
          username: 'lan_pham',
          fullName: 'Phạm Thị Lan',
          lastMessage: 'Mai mình đấu Sudoku mức Khó nhé, nhớ chơi hết sức đấy!',
          lastMessageAt: DateTime.now().subtract(const Duration(minutes: 4)),
          unreadCount: 3,
        ),
        Conversation(
          userId: 11,
          username: 'minh_tran',
          fullName: 'Trần Quang Minh',
          lastMessage: 'Ván hôm qua hay quá',
          lastMessageAt: DateTime.now().subtract(const Duration(hours: 3)),
          lastFromMe: true,
        ),
        Conversation(
          userId: 13,
          username: 'hoang99',
          lastMessage: 'ok',
          lastMessageAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        Conversation(
          userId: 14,
          username: 'bao_le',
          fullName: 'Lê Gia Bảo',
          lastMessage: 'Cảm ơn bạn đã chấp nhận lời thách đấu',
          lastMessageAt: DateTime.now().subtract(const Duration(days: 9)),
          unreadCount: 120,
        ),
      ];
  return api;
}

void main() {
  setUpAll(_loadFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 2, 851 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Future<AuthController> loggedIn(WidgetTester tester, FakeApiClient api) async {
    final auth = AuthController(api: api, tokens: FakeTokenStorage());
    await tester.runAsync(() => auth.login('an', 'x'));
    return auth;
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final tag = mode.name;

    testWidgets('social guest $tag', (tester) async {
      await phone(tester);
      final api = _api();
      final auth = AuthController(api: api, tokens: FakeTokenStorage());
      await tester.runAsync(auth.restore);
      await tester.pumpWidget(_app(const SocialScreen(), mode, api, auth));
      await tester.pumpAndSettle();
      await _shot(tester, '01_social_guest_$tag');
    });

    testWidgets('challenges $tag', (tester) async {
      await phone(tester);
      final api = _api();
      final auth = await loggedIn(tester, api);
      await tester.pumpWidget(_app(const SocialScreen(), mode, api, auth));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thách đấu'));
      await tester.pumpAndSettle();
      await _shot(tester, '02_challenges_top_$tag');
      await tester.drag(find.byType(ListView).first, const Offset(0, -520));
      await tester.pumpAndSettle();
      await _shot(tester, '03_challenges_mid_$tag');
      await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
      await tester.pumpAndSettle();
      await _shot(tester, '04_challenges_done_$tag');
    });

    testWidgets('player sheet $tag', (tester) async {
      await phone(tester);
      final api = _api();
      final auth = await loggedIn(tester, api);
      await tester.pumpWidget(_app(const SocialScreen(), mode, api, auth));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'lan');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      await _shot(tester, '05_search_$tag');
      // Thách đấu không đồng thời nay mở từ menu của bạn bè: chụp thẳng bảng chọn.
      const lan = UserSummary(
          userId: 12, username: 'lan_pham', fullName: 'Phạm Thị Lan');
      await tester.pumpWidget(_app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  useSafeArea: true,
                  builder: (_) =>
                      const PlayerSheet(player: lan, startInPicker: true),
                ),
                child: const Text('mở'),
              ),
            ),
          ),
        ),
        mode,
        api,
        auth,
      ));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      await _shot(tester, '07_player_picker_$tag');
    });

    testWidgets('conversations $tag', (tester) async {
      await phone(tester);
      final api = _api();
      final auth = await loggedIn(tester, api);
      await tester.pumpWidget(_app(const SocialScreen(), mode, api, auth));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tin nhắn'));
      await tester.pumpAndSettle();
      await _shot(tester, '08_conversations_$tag');
    });

    testWidgets('chat $tag', (tester) async {
      await phone(tester);
      final api = _api();
      final auth = await loggedIn(tester, api);
      final now = DateTime.now();
      ChatMessage m(int id, bool mine, String text, Duration ago) => ChatMessage(
            messageId: id,
            senderId: mine ? _me : 12,
            receiverId: mine ? 12 : _me,
            content: text,
            sentAt: now.subtract(ago),
          );
      api.onMessages = (uid, after, before, limit) async => after != null
          ? <ChatMessage>[]
          : [
              m(1, false, 'Chào An, hôm qua bạn thắng mình ván Caro đấy', const Duration(days: 1, hours: 2)),
              m(2, true, 'Haha may mắn thôi', const Duration(days: 1, hours: 2)),
              m(3, false, 'Mai mình đấu Sudoku mức Khó nhé, nhớ chơi hết sức đấy! Mình luyện cả tuần rồi.', const Duration(minutes: 12)),
              m(4, true, 'Ok, mình gửi lời thách ngay bây giờ', const Duration(minutes: 10)),
              m(5, false, 'Đã nhận', const Duration(minutes: 9)),
            ];
      api.onSendMessage = (uid, text) async =>
          throw const ApiException(ApiException.networkMessage, isNetwork: true);

      const partner = UserSummary(
          userId: 12, username: 'lan_pham', fullName: 'Phạm Thị Lan');
      await tester.pumpWidget(_app(const ChatScreen(partner: partner), mode, api, auth));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Vậy mình chơi lúc 8 giờ tối nhé');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      await _shot(tester, '09_chat_failed_$tag');

      // Gỡ màn chat để huỷ hẹn giờ hỏi tin mới trước khi kết thúc test
      await tester.pumpWidget(const SizedBox());
    });
  }
}
