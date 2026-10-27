import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_new/auth/auth_controller.dart';
import 'package:frontend_new/core/models/presence.dart';
import 'package:frontend_new/core/network/api_client.dart';
import 'package:frontend_new/core/network/api_exception.dart';
import 'package:frontend_new/core/network/models.dart';
import 'package:frontend_new/core/network/token_storage.dart';
import 'package:frontend_new/core/services/score_reporter.dart';
import 'package:frontend_new/core/theme/theme_controller.dart';
import 'package:frontend_new/main.dart';
import 'package:frontend_new/profile/profile_screen.dart';
import 'package:frontend_new/rubik/screens/rubik_home_screen.dart';
import 'package:frontend_new/sudoku/screens/sudoku_home_screen.dart';
import 'package:frontend_new/XepHinh/xep_hinh_screen.dart';

const _me = AppUser(userId: 7, username: 'binh', email: 'binh@example.com', fullName: 'Thái Bình');
const _an = UserSummary(userId: 9, username: 'an', fullName: 'Nguyễn An');
const _cuong = UserSummary(userId: 11, username: 'cuong', fullName: 'Lê Cường');
const _dung = UserSummary(userId: 12, username: 'dung', fullName: 'Phạm Dũng');

/// Server giả trong bộ nhớ: An là bạn, Cường đã gửi lời mời, Dũng chưa quen.
class _FakeApi implements ApiClient {
  @override
  VoidCallback? onUnauthorized;

  String? updatedName;
  int matchCount = 1;
  String password = 'cu123456';
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
  Future<SubmitResult> submitHistory(GameRecord record) async =>
      SubmitResult(score: record.localScore);

  final leaderboardQueries = <String>[];

  /// Ghi đè bảng kỷ lục / hạng kỷ lục của mình cho từng test.
  List<LeaderboardEntry> recordEntries = const [
    LeaderboardEntry(rank: 1, user: _an, bestScore: 2840, bestTimeSeconds: 312),
    LeaderboardEntry(rank: 2, user: _cuong, bestScore: 1990, bestTimeSeconds: 455),
  ];
  MyRank recordMe = const MyRank();

  @override
  Future<List<LeaderboardEntry>> leaderboard(LeaderboardQuery query, {int top = 50}) async {
    leaderboardQueries.add(query.key);
    return query.ranked
        ? const [
            LeaderboardEntry(rank: 1, user: _an, bestScore: 1350, rating: 1350, games: 12, wins: 9),
            LeaderboardEntry(rank: 2, user: UserSummary(userId: 7, username: 'binh', fullName: 'Thái Bình'),
                bestScore: 1210, rating: 1210, games: 5, wins: 3),
          ]
        : recordEntries;
  }

  @override
  Future<MyRank> myRank(LeaderboardQuery query) async =>
      query.ranked ? const MyRank(rank: 2, rating: 1210, games: 5, wins: 3) : recordMe;

  @override
  Future<SeasonInfo> season() async => SeasonInfo(
        start: DateTime.now().subtract(const Duration(days: 2)),
        end: DateTime.now().add(const Duration(days: 4, hours: 3)),
      );

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
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    if (currentPassword != password) {
      throw const ApiException('Mật khẩu hiện tại không đúng', statusCode: 400);
    }
    password = newPassword;
  }

  @override
  Future<List<GameStats>> myRatings() async => const [
        GameStats(gameCode: 'SUDOKU', rating: 1300, games: 10, wins: 7, losses: 3),
      ];

  @override
  Future<PagedResult<MatchHistoryItem>> matches({int page = 1, int pageSize = 20}) async =>
      PagedResult(
        items: [
          for (var id = (page - 1) * pageSize + 1; id <= matchCount && id <= page * pageSize; id++)
            id == 1
                ? MatchHistoryItem(
                    matchId: 1,
                    gameCode: 'SUDOKU',
                    ranked: true,
                    opponent: _an,
                    result: MatchResult.win,
                    ratingDelta: 16,
                    endedAt: DateTime.now().subtract(const Duration(hours: 2)),
                  )
                : MatchHistoryItem(
                    matchId: id,
                    gameCode: 'CARO',
                    ranked: false,
                    opponent: _cuong,
                    result: MatchResult.lose,
                    endedAt: DateTime.now().subtract(Duration(days: id)),
                  ),
        ],
        page: page,
        pageSize: pageSize,
        total: matchCount,
      );

  @override
  Future<List<DifficultyStats>> getSudokuDifficultyStats() async => [];

  @override
  Future<DifficultyStats> recordSudokuDifficultyStat({
    required int difficulty,
    bool isGameStarted = false,
    bool isWin = false,
    int elapsedSeconds = 0,
    int mistakes = 0,
  }) async =>
      DifficultyStats(difficulty: difficulty);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

/// Cuộn mục [finder] lên đầu vùng nhìn thấy (để thanh điều hướng dưới không che) rồi bấm.
Future<void> _scrollAndTap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Nút/chữ trong vùng nội dung (không tính thanh điều hướng dưới).
Finder _inBody(String text) => find.descendant(
    of: find.byType(IndexedStack).first, matching: find.text(text));

void main() {
  testWidgets('Home hiển thị danh sách trò chơi và mở Sudoku', (WidgetTester tester) async {
    await _pumpApp(tester);

    expect(find.text('Chọn trò chơi'), findsOneWidget);
    for (final name in ['Rubik 3D', 'Sudoku', 'Xếp hình & PhaseShift', 'Caro']) {
      expect(find.text(name), findsOneWidget);
    }

    // Bấm vào Sudoku mở thẳng SudokuHomeScreen
    await tester.tap(find.text('Sudoku'));
    await tester.pumpAndSettle();
    expect(find.byType(SudokuHomeScreen), findsOneWidget);
  });

  testWidgets('Home mở được Rubik', (WidgetTester tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Rubik 3D'));
    await tester.pumpAndSettle();
    expect(find.byType(RubikHomeScreen), findsOneWidget);
  });

  testWidgets('Home mở được Xếp hình', (WidgetTester tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Xếp hình & PhaseShift'));
    await tester.pumpAndSettle();
    expect(find.byType(XepHinhScreen), findsOneWidget);
  });

  testWidgets('Thanh điều hướng dưới chuyển được tab', (WidgetTester tester) async {
    await _pumpApp(tester);

    for (final label in ['Trò chơi', 'Đối kháng', 'Xếp hạng', 'Bạn bè', 'Hồ sơ']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Xếp hạng'));
    await tester.pumpAndSettle();
    expect(find.text('Kỷ lục'), findsOneWidget);
  });

  // ------------------------------------------------------------ xếp hạng

  testWidgets('Xếp hạng: bảng kỷ lục, đổi sang đối kháng thấy hạng của mình', (WidgetTester tester) async {
    final fake = _FakeApi();
    await _pumpApp(tester, loggedIn: true, fake: fake);
    await _openTab(tester, 'Xếp hạng');

    expect(find.text('Nguyễn An'), findsOneWidget);
    expect(find.text('2840'), findsOneWidget);
    expect(find.text('05:12'), findsOneWidget);
    expect(find.text('🥇'), findsOneWidget);
    expect(find.textContaining('Mùa tuần này kết thúc sau 4 ngày'), findsOneWidget);
    expect(find.text('Bạn chưa có thành tích trong bảng này'), findsOneWidget);
    expect(fake.leaderboardQueries.first, contains('board=record'));
    expect(find.text('Mọi độ khó'), findsNothing, reason: 'không còn lựa chọn gộp mọi độ khó');
    expect(fake.leaderboardQueries.first, contains('difficulty=1'), reason: 'mặc định Dễ');

    await tester.tap(find.text('Dễ'));
    await tester.pumpAndSettle();
    expect(find.text('Mọi độ khó'), findsNothing);
    expect(find.text('Chuyên gia'), findsOneWidget, reason: 'Sudoku có đủ 5 mức');
    await tester.tap(find.text('Ác mộng'));
    await tester.pumpAndSettle();
    expect(fake.leaderboardQueries.last, contains('difficulty=5'));

    // Sang game chỉ có 3 mức: tự về Khó
    await tester.tap(find.widgetWithText(ChoiceChip, 'Caro'));
    await tester.pumpAndSettle();
    expect(fake.leaderboardQueries.last, contains('gameCode=CARO'));
    expect(fake.leaderboardQueries.last, contains('difficulty=3'));
    await tester.tap(find.text('Khó'));
    await tester.pumpAndSettle();
    expect(find.text('Ác mộng'), findsNothing, reason: 'Caro chỉ có 3 mức');
    await tester.tapAt(const Offset(10, 10)); // đóng menu
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(SegmentedButton<bool>).first, matching: find.text('Đối kháng')));
    await tester.pumpAndSettle();
    expect(fake.leaderboardQueries.last, contains('board=ranked'));
    expect(fake.leaderboardQueries.last, contains('gameCode=CARO'), reason: 'bảng đối kháng chỉ có Caro / Xếp số');
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('Thái Bình (bạn)'), findsOneWidget);
    expect(find.text('12 trận · thắng 75%'), findsOneWidget);
    expect(find.text('Còn 40 điểm để lên Vàng'), findsOneWidget, reason: '1210 (Bạc) -> Vàng từ 1250');
  });

  testWidgets('Xếp hạng: bảng bạn bè khi chưa đăng nhập thì mời đăng nhập', (WidgetTester tester) async {
    final fake = _FakeApi();
    await _pumpApp(tester, fake: fake);
    await _openTab(tester, 'Xếp hạng');
    expect(find.text('Nguyễn An'), findsOneWidget, reason: 'bảng toàn server xem được khi chưa đăng nhập');
    expect(find.text('Đăng nhập để có tên trên bảng xếp hạng'), findsOneWidget);

    await tester.tap(find.text('Toàn server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bạn bè').last); // mục trong menu (nằm trên thanh điều hướng)
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập để xem bảng bạn bè'), findsOneWidget);
    expect(fake.leaderboardQueries.where((q) => q.contains('scope=friends')), isEmpty);
  });

  testWidgets('Xếp hạng: hạng 4 trở đi là danh sách; thanh của bạn gợi ý số điểm để vượt người phía trên',
      (WidgetTester tester) async {
    const em = UserSummary(userId: 13, username: 'em', fullName: 'Võ Em');
    final fake = _FakeApi()
      ..recordEntries = const [
        LeaderboardEntry(rank: 1, user: _an, bestScore: 2840, bestTimeSeconds: 312),
        LeaderboardEntry(rank: 2, user: _cuong, bestScore: 1990, bestTimeSeconds: 455),
        LeaderboardEntry(rank: 3, user: _dung, bestScore: 1500, bestTimeSeconds: 500),
        LeaderboardEntry(rank: 4, user: em, bestScore: 1200, bestTimeSeconds: 520),
        LeaderboardEntry(rank: 5, user: UserSummary(userId: 7, username: 'binh', fullName: 'Thái Bình'),
            bestScore: 1100, bestTimeSeconds: 600),
      ]
      ..recordMe = const MyRank(rank: 5, bestScore: 1100, bestTimeSeconds: 600);
    await _pumpApp(tester, loggedIn: true, fake: fake);
    await _openTab(tester, 'Xếp hạng');

    expect(find.text('🥉'), findsOneWidget);
    expect(find.text('08:20'), findsOneWidget, reason: 'bục hạng 3 vẫn hiện thời gian');
    expect(find.text('@em'), findsOneWidget, reason: 'hạng 4 là một dòng trong danh sách');
    expect(find.text('#5'), findsOneWidget);
    expect(find.text('Thêm 101 điểm để vượt Võ Em'), findsOneWidget);

    await tester.tap(find.text('Thêm 101 điểm để vượt Võ Em'));
    await tester.pumpAndSettle();
    final y = tester.getCenter(find.text('Thái Bình (bạn)')).dy;
    expect(y, inInclusiveRange(0, 450), reason: 'bấm thanh của bạn thì cuộn dòng của mình vào vùng nhìn thấy');
  });

  testWidgets('Xếp hạng: nhớ bộ lọc lần trước và xem được cách tính xếp hạng', (WidgetTester tester) async {
    final fake = _FakeApi();
    await _pumpApp(tester, loggedIn: true, fake: fake);
    (await SharedPreferences.getInstance()).setString('leaderboard_query',
        '{"gameCode":"CARO","ranked":true,"difficulty":null,"friendsOnly":false,"season":false}');
    await _openTab(tester, 'Xếp hạng');

    expect(fake.leaderboardQueries.first, contains('board=ranked'), reason: 'mở lại đúng bảng đã chọn lần trước');
    expect(fake.leaderboardQueries.first, contains('period=all'));
    expect(find.text('Mọi lúc'), findsOneWidget);

    await tester.tap(find.text('Mọi lúc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tuần này').last);
    await tester.pumpAndSettle();
    final saved = (await SharedPreferences.getInstance()).getString('leaderboard_query');
    expect(saved, contains('"season":true'));

    await tester.tap(find.byTooltip('Cách tính xếp hạng'));
    await tester.pumpAndSettle();
    expect(find.text('Cách tính xếp hạng'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Kim cương'), 100,
        scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)));
    expect(find.text('Kim cương'), findsOneWidget);
  });

  testWidgets('Xếp hạng: màn hình điện thoại nhỏ, tên dài không bị tràn', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3; // 360×740
    addTearDown(tester.view.reset);
    const long = UserSummary(userId: 21, username: 'nguoichoi_ten_rat_dai', fullName: 'Nguyễn Hoàng Phúc Thịnh Vượng');
    final fake = _FakeApi()
      ..recordEntries = const [
        LeaderboardEntry(rank: 1, user: long, bestScore: 123456, bestTimeSeconds: 3725),
        LeaderboardEntry(rank: 2, user: long, bestScore: 99999, bestTimeSeconds: 455),
        LeaderboardEntry(rank: 2, user: long, bestScore: 99999, bestTimeSeconds: 455),
        LeaderboardEntry(rank: 4, user: long, bestScore: 88888, bestTimeSeconds: 520),
      ]
      ..recordMe = const MyRank(rank: 40, bestScore: 1100, bestTimeSeconds: 600);
    await _pumpApp(tester, loggedIn: true, fake: fake);
    await _openTab(tester, 'Xếp hạng');

    expect(tester.takeException(), isNull);
    expect(find.text('#40'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(SegmentedButton<bool>), matching: find.text('Đối kháng')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Còn 40 điểm để lên Vàng'), findsOneWidget);
  });

  testWidgets('Xếp hạng: khách bấm vào người chơi thì được mời đăng nhập', (WidgetTester tester) async {
    await _pumpApp(tester);
    await _openTab(tester, 'Xếp hạng');

    await tester.tap(find.text('Nguyễn An'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập để xem hồ sơ và kết bạn với người chơi'), findsOneWidget);
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
    expect(find.textContaining('Xem tất cả'), findsNothing, reason: 'chỉ 1 trận thì không cần trang riêng');
  });

  testWidgets('Hồ sơ chỉ hiện 3 trận gần đây; Xem tất cả mở danh sách tải thêm khi cuộn',
      (WidgetTester tester) async {
    final fake = _FakeApi()..matchCount = 45;
    await _pumpApp(tester, loggedIn: true, fake: fake);
    await _openProfile(tester);

    await tester.scrollUntilVisible(find.text('Đăng xuất'), 200);
    expect(find.byType(MatchHistoryTile), findsNWidgets(3));

    await tester.ensureVisible(find.text('Xem tất cả (45)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem tất cả (45)'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử trận đấu'), findsOneWidget);
    expect(find.text('Đã tải 20 / 45 trận'), findsOneWidget);

    // Cuộn tới cuối: tự tải các trang tiếp cho tới hết.
    for (var i = 0; i < 3; i++) {
      await tester.fling(find.byType(ListView).last, const Offset(0, -4000), 4000);
      await tester.pumpAndSettle();
    }
    expect(find.text('Đã hiện hết lịch sử'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, 20000));
    await tester.pumpAndSettle();
    expect(find.text('Đã tải 45 / 45 trận'), findsOneWidget);
  });

  testWidgets('Đổi mật khẩu: báo lỗi tại chỗ khi sai mật khẩu hiện tại, rồi đổi thành công',
      (WidgetTester tester) async {
    final fake = _FakeApi();
    await _pumpApp(tester, loggedIn: true, fake: fake);
    await _openProfile(tester);

    await _scrollAndTap(tester, find.text('Đổi mật khẩu'));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'sai-mat-khau');
    await tester.enterText(fields.at(1), 'moi123456');
    await tester.enterText(fields.at(2), 'khac123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Đổi mật khẩu'));
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);

    await tester.enterText(fields.at(2), 'moi123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Đổi mật khẩu'));
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu hiện tại không đúng'), findsOneWidget);
    expect(fake.password, 'cu123456');

    await tester.enterText(fields.at(0), 'cu123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Đổi mật khẩu'));
    await tester.pumpAndSettle();
    expect(fake.password, 'moi123456');
    expect(find.text('Đã đổi mật khẩu'), findsOneWidget);
  });

  testWidgets('Sửa tên hiển thị và đăng xuất', (WidgetTester tester) async {
    final auth = await _pumpApp(tester, loggedIn: true);
    await _openProfile(tester);

    await _scrollAndTap(tester, find.text('Sửa tên hiển thị'));
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
  });
}
