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
}
