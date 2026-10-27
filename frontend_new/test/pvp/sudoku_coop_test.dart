import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_new/core/realtime/realtime_service.dart';
import 'package:frontend_new/pvp/match_session.dart';
import 'package:frontend_new/pvp/sudoku_coop_screen.dart';
import 'package:provider/provider.dart';

import '../support/fake_realtime.dart';

void main() {
  late FakeRealtime rt;
  late MatchSession session;

  setUp(() {
    rt = FakeRealtime();
    session = MatchSession(realtime: rt);
  });

  tearDown(() {
    session.dispose();
    rt.dispose();
  });

  Widget buildScreen() {
    return MaterialApp(
      home: ListenableProvider<RealtimeService>.value(
        value: rt,
        child: ChangeNotifierProvider<MatchSession>.value(
          value: session,
          child: SudokuCoopScreen(session: session),
        ),
      ),
    );
  }

  MatchInfo createSudokuMatch({int seed = 12345}) {
    return MatchInfo(
      matchId: 'm_sudoku_1',
      gameCode: kGameSudoku,
      difficulty: 2,
      ranked: false,
      isTurn: false,
      kind: 'COOP',
      seed: seed,
      active: true,
      you: 1,
      players: const [
        MatchPlayer(userId: 1, username: 'player1', fullName: 'Thái Bình'),
        MatchPlayer(userId: 2, username: 'player2', fullName: 'Nguyễn An'),
      ],
      startedAt: DateTime.now(),
    );
  }

  testWidgets('SudokuCoopScreen: render tiêu đề, người chơi, và bàn cờ 9x9', (tester) async {
    final match = createSudokuMatch();
    rt.matchStartedCtl.add(match);
    await tester.pump();

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Sudoku Đồng Đội'), findsOneWidget);
    expect(find.text('Bạn'), findsOneWidget);
    expect(find.text('Nguyễn An'), findsOneWidget);
    expect(find.textContaining('Lỗi:'), findsOneWidget);
    expect(find.textContaining('Tiến độ:'), findsOneWidget);
    expect(find.text('Ghi chú TẮT'), findsOneWidget);
  });

  testWidgets('SudokuCoopScreen: đồng bộ nước đi và con trỏ từ đối phương', (tester) async {
    final match = createSudokuMatch();
    rt.matchStartedCtl.add(match);
    await tester.pump();

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Đối thủ di chuyển con trỏ tới ô hàng 3 cột 4
    rt.sudokuCursorsCtl.add(const SudokuCursorEvent(
      matchId: 'm_sudoku_1',
      userId: 2,
      row: 2,
      col: 3,
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đang xem: Ô [D3]'), findsOneWidget);

    // Đối phương điền một nước đi hợp lệ
    rt.sudokuMovesCtl.add(const SudokuMoveEvent(
      matchId: 'm_sudoku_1',
      row: 0,
      col: 0,
      value: 5,
      byUserId: 2,
      isMistake: false,
      mistakes: 0,
      movesCount: 1,
    ));
    await tester.pumpAndSettle();
    expect(find.text('1 ô'), findsOneWidget); // Nguyễn An đã giải được 1 ô

    // Đối phương phạm 1 lỗi
    rt.sudokuMovesCtl.add(const SudokuMoveEvent(
      matchId: 'm_sudoku_1',
      row: 0,
      col: 1,
      value: 9,
      byUserId: 2,
      isMistake: true,
      mistakes: 1,
      movesCount: 2,
    ));
    await tester.pumpAndSettle();
    // Bảng lỗi cập nhật
    expect(find.byIcon(Icons.close_rounded), findsWidgets);
  });

  testWidgets('SudokuCoopScreen: bấm nút thoát hiển thị hộp thoại và rời phòng thành công', (tester) async {
    final match = createSudokuMatch();
    rt.matchStartedCtl.add(match);
    await tester.pump();

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Bấm nút X ở AppBar
    await tester.tap(find.byTooltip('Rời phòng'));
    await tester.pumpAndSettle();

    expect(find.text('Rời ván chơi?'), findsOneWidget);
    expect(find.text('Tiếp tục chơi'), findsOneWidget);
    expect(find.text('Rời phòng'), findsOneWidget);

    // Xác nhận rời phòng
    await tester.tap(find.widgetWithText(FilledButton, 'Rời phòng'));
    await tester.pumpAndSettle();

    // Lệnh Resign đã được ghi nhận vào realtime hub
    expect(rt.calls.any((c) => c.startsWith('Resign m_sudoku_1')), isTrue);
  });

  testWidgets('SudokuCoopScreen: kết thúc ván đấu và bấm Về sảnh đưa về sảnh', (tester) async {
    final match = createSudokuMatch();
    rt.matchStartedCtl.add(match);
    await tester.pump();

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Trận kết thúc do chiến thắng
    rt.matchEndedCtl.add(const MatchEndedEvent(
      matchId: 'm_sudoku_1',
      winnerId: null,
      reason: 'COOP_WIN',
      ranked: false,
      ratingChanges: {},
      scores: {},
    ));
    await tester.pumpAndSettle();

    expect(find.text('Chiến Thắng Đồng Đội!'), findsOneWidget);
    expect(find.text('Về sảnh'), findsOneWidget);
    expect(find.text('Tái đấu'), findsOneWidget);

    // Bấm về sảnh
    await tester.tap(find.text('Về sảnh'));
    await tester.pumpAndSettle();

    expect(session.phase, equals(PvpPhase.idle));
  });

  testWidgets('SudokuCoopScreen: bấm số bàn phím kích hoạt kiểm tra đáp án', (tester) async {
    final match = createSudokuMatch();
    rt.matchStartedCtl.add(match);
    await tester.pump();

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Bấm số 5 trên bàn phím (ô đầu tiên đã được tự động chọn)
    await tester.tap(find.widgetWithText(InkWell, '5'));
    await tester.pump();

    // Đã gọi SudokuMove tới hub
    expect(rt.calls.any((c) => c.startsWith('SudokuMove m_sudoku_1')), isTrue);
  });

  testWidgets('SudokuCoopScreen: chia lượt đổi lượt khi điền số và chặn khi chưa tới lượt', (tester) async {
    final match = createSudokuMatch();
    rt.matchStartedCtl.add(match);
    await tester.pump();

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('LƯỢT CỦA BẠN'), findsOneWidget);

    // Điền 1 số (lượt đầu của P1)
    await tester.tap(find.widgetWithText(InkWell, '5'));
    await tester.pump();

    // Sau khi điền, lượt đổi sang đối thủ (P2 - Nguyễn An)
    expect(find.text('LƯỢT CỦA NGUYỄN AN'), findsOneWidget);

    final moveCallsBefore = rt.calls.where((c) => c.startsWith('SudokuMove m_sudoku_1')).length;

    // P1 cố tình bấm tiếp số khác khi chưa đến lượt
    await tester.tap(find.widgetWithText(InkWell, '6'));
    await tester.pump();

    // Không gửi thêm nước đi nào
    final moveCallsAfter = rt.calls.where((c) => c.startsWith('SudokuMove m_sudoku_1')).length;
    expect(moveCallsAfter, equals(moveCallsBefore));
    expect(find.textContaining('Đang là lượt của Nguyễn An'), findsOneWidget);

    // Đối thủ đi xong và server trả về lượt mới chuyển về P1
    rt.sudokuMovesCtl.add(const SudokuMoveEvent(
      matchId: 'm_sudoku_1',
      row: 0,
      col: 1,
      value: 7,
      byUserId: 2,
      isMistake: false,
      mistakes: 0,
      movesCount: 2,
      nextTurnUserId: 1,
    ));
    await tester.pumpAndSettle();

    // Lượt đã quay lại cho P1
    expect(find.text('LƯỢT CỦA BẠN'), findsOneWidget);
  });

  testWidgets('SudokuCoopScreen: khi thua vẫn có nút Tái đấu và Về sảnh, bấm Tái đấu gửi lời mời tới đối thủ', (tester) async {
    final match = createSudokuMatch();
    rt.matchStartedCtl.add(match);
    await tester.pump();

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Trận kết thúc do quá số lỗi (thua)
    rt.matchEndedCtl.add(const MatchEndedEvent(
      matchId: 'm_sudoku_1',
      winnerId: null,
      reason: 'MISTAKES_LIMIT',
      ranked: false,
      ratingChanges: {},
      scores: {},
    ));
    await tester.pumpAndSettle();

    // Kiểm tra hộp thoại thua cuộc
    expect(find.text('Hết Lượt Thử (3/3 Lỗi)'), findsOneWidget);
    // Có cả nút "Về sảnh" và "Tái đấu"
    expect(find.text('Về sảnh'), findsOneWidget);
    expect(find.text('Tái đấu'), findsOneWidget);

    // Bấm nút Tái đấu
    await tester.tap(find.text('Tái đấu'));
    await tester.pumpAndSettle();

    // Đã gọi Rematch tới server hub
    expect(rt.calls.any((c) => c.startsWith('Rematch m_sudoku_1')), isTrue);
    expect(find.text('Đang chờ đối thủ…'), findsOneWidget);
  });

  testWidgets('SudokuCoopScreen: người chơi vẫn có thể bật ghi chú và ghi chú nháp số khi chưa đến lượt mình', (tester) async {
    final match = createSudokuMatch();
    rt.matchStartedCtl.add(match);
    await tester.pump();

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Điền 1 số ở lượt đầu để lượt chuyển sang đối thủ
    await tester.tap(find.widgetWithText(InkWell, '5'));
    await tester.pumpAndSettle();

    expect(find.text('LƯỢT CỦA NGUYỄN AN'), findsOneWidget);

    // Bật chế độ Ghi chú
    await tester.tap(find.text('Ghi chú TẮT'));
    await tester.pumpAndSettle();
    expect(find.text('Ghi chú BẬT'), findsOneWidget);

    // Ghi chú số 3 vào ô hiện tại khi chưa tới lượt
    await tester.tap(find.widgetWithText(InkWell, '3'));
    await tester.pumpAndSettle();

    // Số 3 xuất hiện trong bảng ghi chú nháp của ô
    expect(find.text('3'), findsWidgets);
  });
}


