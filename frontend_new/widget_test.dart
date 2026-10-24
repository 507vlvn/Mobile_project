<<<<<<< HEAD
import 'package:flutter_test/flutter_test.dart';
=======
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_new/auth/auth_controller.dart';
import 'package:frontend_new/core/models/presence.dart';
import 'package:frontend_new/core/network/api_client.dart';
import 'package:frontend_new/core/network/models.dart';
import 'package:frontend_new/core/network/token_storage.dart';
import 'package:frontend_new/core/theme/theme_controller.dart';
>>>>>>> origin/main
import 'package:frontend_new/main.dart';
import 'package:frontend_new/soduku/logic/sudoku_controller.dart';
import 'package:frontend_new/soduku/ui/sudoku_home_screen.dart';

const _me = AppUser(userId: 7, username: 'binh', email: 'binh@example.com', fullName: 'Thái Bình');
const _an = UserSummary(userId: 9, username: 'an', fullName: 'Nguyễn An');
const _cuong = UserSummary(userId: 11, username: 'cuong', fullName: 'Lê Cường');
const _dung = UserSummary(userId: 12, username: 'dung', fullName: 'Phạm Dũng');

/// Server giả trong bộ nhớ: An là bạn, Cường đã gửi lời mời, Dũng chưa quen.
class _FakeApi implements ApiClient {
  @override
  VoidCallback? onUnauthorized;

  String? updatedName;
  final friendIds = <int>{_an.userId};
  final incomingIds = <int>{_cuong.userId};
  final outgoingIds = <int>{};
  final sentMessages = <String>[];
  final _users = {for (final u in [_an, _cuong, _dung]) u.userId: u};
  final _messages = <ChatMessage>[
    ChatMessage(
        messageId: 1,
        senderId: 9,
        receiverId: 7,
        content: 'Chào Bình!',
        isRead: false,
        sentAt: DateTime.now().subtract(const Duration(minutes: 3))),
  ];

  @override
  Future<List<UserSummary>> searchUsers(String q) async => [
        for (final u in _users.values)
          if (u.username.contains(q) || (u.fullName ?? '').toLowerCase().contains(q.toLowerCase())) u,
      ];

  @override
  Future<PlayerProfile> userProfile(int userId) async => PlayerProfile(
        user: _users[userId] ?? const UserSummary(userId: 7, username: 'binh', fullName: 'Thái Bình'),
        relationship: userId == 7
            ? Relationship.self
            : friendIds.contains(userId)
                ? Relationship.friends
                : incomingIds.contains(userId)
                    ? Relationship.pendingIn
                    : outgoingIds.contains(userId)
                        ? Relationship.pendingOut
                        : Relationship.none,
        requestId: incomingIds.contains(userId) ? 100 + userId : null,
        stats: const [
          GameStats(gameCode: 'SUDOKU', rating: 1300, games: 10, wins: 7, losses: 3, bestScore: 950),
        ],
      );

  @override
  Future<List<FriendInfo>> friends() async => [
        for (final id in friendIds)
          FriendInfo(
            userId: id,
            username: _users[id]!.username,
            fullName: _users[id]!.fullName,
            presence: PresenceStatus.online,
          ),
      ];

  @override
  Future<FriendRequests> friendRequests() async => FriendRequests(
        incoming: [for (final id in incomingIds) FriendRequestItem(requestId: 100 + id, user: _users[id]!)],
        outgoing: [for (final id in outgoingIds) FriendRequestItem(requestId: 200 + id, user: _users[id]!)],
      );

  @override
  Future<void> sendFriendRequest(int userId) async => outgoingIds.add(userId);

  @override
  Future<void> acceptFriendRequest(int requestId) async {
    final id = requestId - 100;
    incomingIds.remove(id);
    friendIds.add(id);
  }

  @override
  Future<void> declineFriendRequest(int requestId) async => incomingIds.remove(requestId - 100);

  @override
  Future<void> removeFriend(int userId) async {
    friendIds.remove(userId);
    outgoingIds.remove(userId);
  }

  @override
  Future<List<Conversation>> conversations() async => [
        Conversation(
          user: _an,
          lastMessage: _messages.last.content,
          lastMessageAt: _messages.last.sentAt,
          lastFromMe: _messages.last.senderId == 7,
          unreadCount: _messages.where((m) => m.senderId == 9 && !m.isRead).length,
        ),
      ];

  @override
  Future<List<ChatMessage>> messagesWith(int userId, {int? afterId, int? beforeId, int limit = 30}) async => [
        for (final m in _messages)
          if ((afterId == null || m.messageId > afterId) && (beforeId == null || m.messageId < beforeId)) m,
      ];

  @override
  Future<ChatMessage> sendMessage(int userId, String content) async {
    sentMessages.add(content);
    final m = ChatMessage(
        messageId: _messages.length + 1,
        senderId: 7,
        receiverId: userId,
        content: content,
        isRead: false,
        sentAt: DateTime.now());
    _messages.add(m);
    return m;
  }

  @override
  Future<void> markRead(int userId) async {}

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
  Future<PagedResult<MatchHistoryItem>> matches({int page = 1, int pageSize = 20}) async =>
      PagedResult(
        items: [
          MatchHistoryItem(
            matchId: 1,
            gameCode: 'SUDOKU',
            ranked: true,
            opponent: _an,
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

Future<AuthController> _pumpApp(WidgetTester tester, {bool loggedIn = false, _FakeApi? fake}) async {
  SharedPreferences.setMockInitialValues(loggedIn ? {'auth_token': 't'} : {});
  final api = fake ?? _FakeApi();
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

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
      of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

Future<void> _openProfile(WidgetTester tester) => _openTab(tester, 'Hồ sơ');

/// Nút/chữ trong vùng nội dung (không tính thanh điều hướng dưới).
Finder _inBody(String text) => find.descendant(
    of: find.byType(IndexedStack).first, matching: find.text(text));

void main() {
<<<<<<< HEAD
  testWidgets('Sudoku home screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
=======
  testWidgets('Home hiển thị danh sách trò chơi', (WidgetTester tester) async {
    await _pumpApp(tester);

    expect(find.text('Chọn trò chơi'), findsOneWidget);
    for (final name in ['Rubik 3D', 'Sudoku', 'Xếp hình', 'Caro']) {
      expect(find.text(name), findsOneWidget);
    }

    // Chưa có chức năng: bấm vào game chỉ hiện thông báo.
    await tester.tap(find.text('Sudoku'));
>>>>>>> origin/main
    await tester.pump();
    expect(find.text('Sudoku đang được phát triển, sắp ra mắt!'), findsOneWidget);
  });

<<<<<<< HEAD
    expect(find.byType(SudokuHomeScreen), findsOneWidget);
    expect(find.text('Sudoku Classic'), findsOneWidget);
    expect(find.text('Tiếp tục Trò chơi'), findsOneWidget);
    expect(find.text('Trò chơi Mới'), findsOneWidget);

    SudokuController.instance.stopTimer();
=======
  testWidgets('Thanh điều hướng dưới chuyển được tab', (WidgetTester tester) async {
    await _pumpApp(tester);

    for (final label in ['Trò chơi', 'Đối kháng', 'Xếp hạng', 'Bạn bè', 'Hồ sơ']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Xếp hạng'));
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

  // ------------------------------------------------------------ bạn bè

  testWidgets('Bạn bè khi chưa đăng nhập: mời đăng nhập', (WidgetTester tester) async {
    await _pumpApp(tester);
    await _openTab(tester, 'Bạn bè');

    expect(find.text('Đăng nhập để kết bạn'), findsOneWidget);
  });

  testWidgets('Danh sách bạn bè: hiện bạn, trạng thái, không có thách đấu', (WidgetTester tester) async {
    await _pumpApp(tester, loggedIn: true);
    await _openTab(tester, 'Bạn bè');

    expect(find.text('Nguyễn An'), findsOneWidget);
    expect(find.text('Đang online'), findsOneWidget);
    expect(find.text('1 đang online · 1 bạn bè'), findsOneWidget);
    expect(find.text('Thách đấu'), findsNothing);
    expect(find.byIcon(Icons.sports_esports_rounded), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Xem hồ sơ'), findsOneWidget);
    expect(find.text('Hủy kết bạn'), findsOneWidget);
    expect(find.text('Thách đấu không đồng thời'), findsNothing);
  });

  testWidgets('Lời mời: chấp nhận thì thành bạn bè', (WidgetTester tester) async {
    final fake = _FakeApi();
    await _pumpApp(tester, loggedIn: true, fake: fake);
    await _openTab(tester, 'Bạn bè');

    await tester.tap(find.text('Lời mời'));
    await tester.pumpAndSettle();
    expect(find.text('Lời mời đến (1)'), findsOneWidget);
    expect(find.text('Lê Cường'), findsOneWidget);

    await tester.tap(find.text('Chấp nhận'));
    await tester.pumpAndSettle();
    expect(fake.friendIds, contains(_cuong.userId));
    expect(find.text('Đã kết bạn với Lê Cường'), findsOneWidget);
    expect(find.text('Chưa có lời mời nào'), findsOneWidget);
  });

  testWidgets('Tìm người chơi và gửi lời mời kết bạn', (WidgetTester tester) async {
    final fake = _FakeApi();
    await _pumpApp(tester, loggedIn: true, fake: fake);
    await _openTab(tester, 'Bạn bè');

    await tester.enterText(find.byType(TextField), 'dung');
    await tester.pump(const Duration(milliseconds: 500)); // debounce
    await tester.pumpAndSettle();
    expect(find.text('Phạm Dũng'), findsOneWidget);

    await tester.tap(find.text('Kết bạn'));
    await tester.pumpAndSettle();
    expect(fake.outgoingIds, contains(_dung.userId));
    expect(find.text('Đã gửi · Hủy'), findsOneWidget);
  });

  testWidgets('Thẻ hồ sơ người lạ có nút Kết bạn, không có Mời đấu', (WidgetTester tester) async {
    await _pumpApp(tester, loggedIn: true);
    await _openTab(tester, 'Bạn bè');

    await tester.enterText(find.byType(TextField), 'dung');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phạm Dũng'));
    await tester.pumpAndSettle();

    expect(find.text('Thống kê đối kháng'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Kết bạn'), findsWidgets);
    expect(find.text('Mời đấu'), findsNothing);
  });

  testWidgets('Tin nhắn: mở hội thoại và gửi tin', (WidgetTester tester) async {
    final fake = _FakeApi();
    await _pumpApp(tester, loggedIn: true, fake: fake);
    await _openTab(tester, 'Bạn bè');

    await tester.tap(_inBody('Tin nhắn'));
    await tester.pumpAndSettle();
    expect(find.text('Chào Bình!'), findsOneWidget);

    await tester.tap(find.text('Nguyễn An'));
    await tester.pumpAndSettle();
    expect(find.text('Chào Bình!'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Nhập tin nhắn'), 'Đấu không?');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(fake.sentMessages, ['Đấu không?']);
    expect(find.text('Đấu không?'), findsOneWidget);

    // Rời màn chat để dừng hỏi tin định kỳ.
    await tester.pageBack();
    await tester.pumpAndSettle();
>>>>>>> origin/main
  });
}
