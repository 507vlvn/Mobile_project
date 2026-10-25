import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_new/XepHinh/phaseshift/engine/reaction_engine.dart';
import 'package:frontend_new/XepHinh/phaseshift/models/material.dart';

const rows = 8;
const cols = 4;

List<List<ElementBlock?>> emptyBoard() =>
    List.generate(rows, (_) => List<ElementBlock?>.filled(cols, null));

ElementBlock b(ElementType t) => ElementBlock(type: t, id: '${t.name}_${DateTime.now().microsecondsSinceEpoch}');

String? at(List<List<ElementBlock?>> board, int r, int c) => board[r][c]?.name;

void main() {
  test('khối bên dưới bị hòa tan thì cả chồng phía trên rơi hẳn xuống đáy, không lơ lửng', () {
    // Cột 3 (từ dưới lên): Đá, Axit, Đá, Nước. Axit hòa tan Đá bên dưới.
    final board = emptyBoard();
    board[7][3] = b(ElementType.stone);
    board[6][3] = b(ElementType.acid);
    board[5][3] = b(ElementType.stone);
    board[4][3] = b(ElementType.water);
    // Nước cạnh tường trái là Đá để khỏi chảy ngang
    board[7][2] = b(ElementType.stone);
    board[6][2] = b(ElementType.stone);
    board[5][2] = b(ElementType.stone);
    board[4][2] = b(ElementType.stone);

    final r = ReactionEngine.processReactions(grid: board, rows: rows, cols: cols);

    expect(r.scoreEarned, greaterThan(0), reason: 'Axit + Đá phải phản ứng');
    expect(at(r.board, 7, 3), 'Đá', reason: 'Đá phía trên rơi xuống đáy');
    expect(at(r.board, 6, 3), 'Nước', reason: 'Nước rơi theo, nằm trên Đá');
    for (var row = 0; row < 6; row++) {
      expect(r.board[row][3], isNull, reason: 'không còn khối lơ lửng ở hàng $row');
    }
  });

  test('applyPhysicsTick cho khối rơi hết quãng trống trong một lần', () {
    final board = emptyBoard();
    board[1][0] = b(ElementType.stone);
    ReactionEngine.applyPhysicsTick(board, rows, cols);
    expect(at(board, 7, 0), 'Đá');
    expect(board[1][0], isNull);
  });

  test('Nước nằm trên đáy phẳng thì đứng yên, không trôi qua lại', () {
    final board = emptyBoard();
    board[7][1] = b(ElementType.water);
    final moved = ReactionEngine.applyPhysicsTick(board, rows, cols);
    expect(moved, isFalse);
    expect(at(board, 7, 1), 'Nước');
  });

  test('Nước trên mép một khối thì chảy xuống chỗ trống bên cạnh', () {
    final board = emptyBoard();
    board[7][1] = b(ElementType.stone);
    board[6][1] = b(ElementType.water);
    // Bên phải (cột 2) trống tới đáy; bên trái (cột 0) bị chặn ở đáy
    board[7][0] = b(ElementType.stone);
    board[6][0] = b(ElementType.stone);
    ReactionEngine.applyPhysicsTick(board, rows, cols);
    expect(board[6][1], isNull);
    expect(at(board, 7, 2), 'Nước');
  });
}
