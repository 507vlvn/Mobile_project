import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/models/difficulty.dart';
import 'package:mobile_rubik/features/puzzle/logic/ida_star.dart';
import 'package:mobile_rubik/features/puzzle/logic/puzzle_logic.dart';
import 'package:mobile_rubik/features/puzzle/puzzle_controller.dart';

List<int> _applyPath(List<int> board, int n, List<int> path) {
  var b = board;
  for (final idx in path) {
    final r = PuzzleLogic.slide(b, n, idx)!;
    expect(r.cost, 1, reason: 'mỗi bước IDA* là một ô đơn lẻ');
    b = r.board;
  }
  return b;
}

void main() {
  group('Kích thước & xáo', () {
    test('kích thước theo độ khó', () {
      expect(PuzzleLogic.sizeOf(Difficulty.easy), 3);
      expect(PuzzleLogic.sizeOf(Difficulty.medium), 4);
      expect(PuzzleLogic.sizeOf(Difficulty.hard), 5);
    });

    test('xáo luôn giải được và không trùng trạng thái đã giải', () {
      for (final n in [3, 4, 5]) {
        for (var seed = 0; seed < 40; seed++) {
          final s = PuzzleLogic.shuffle(n, Random(seed));
          expect(PuzzleLogic.isSolvable(s.board, n), isTrue, reason: 'n=$n seed=$seed');
          expect(PuzzleLogic.isSolved(s.board), isFalse);
          expect(s.board.toSet().length, n * n);
          expect(s.blankPath.length, PuzzleLogic.shuffleSteps(n) + 1);
        }
      }
    });

    test('isSolvable từ chối hoán vị lẻ', () {
      final b = PuzzleLogic.solved(3);
      final t = b[0];
      b[0] = b[1];
      b[1] = t;
      expect(PuzzleLogic.isSolvable(b, 3), isFalse);
      final c = PuzzleLogic.solved(4);
      final u = c[0];
      c[0] = c[1];
      c[1] = u;
      expect(PuzzleLogic.isSolvable(c, 4), isFalse);
    });

    test('cùng seed cho cùng đề', () {
      final a = PuzzleLogic.shuffle(4, Random(7));
      final b = PuzzleLogic.shuffle(4, Random(7));
      expect(a.board, b.board);
    });

    test('đường xáo không có nước đi ngược ngay lập tức', () {
      final s = PuzzleLogic.shuffle(4, Random(3));
      for (var i = 2; i < s.blankPath.length; i++) {
        expect(s.blankPath[i], isNot(s.blankPath[i - 2]));
      }
      expect(s.referenceMoves, s.blankPath.length - 1);
    });

    test('cancelBacktracking triệt tiêu đi-rồi-quay-lại', () {
      expect(PuzzleLogic.cancelBacktracking([8, 7, 8, 5]), [8, 5]);
      expect(PuzzleLogic.cancelBacktracking([8, 7, 6]), [8, 7, 6]);
      expect(PuzzleLogic.cancelBacktracking([8, 7, 8, 7, 8]), [8]);
    });
  });

  group('Di chuyển', () {
    test('trượt một ô kề', () {
      final b = PuzzleLogic.solved(3); // ô trống ở 8
      final r = PuzzleLogic.slide(b, 3, 7)!;
      expect(r.board, [1, 2, 3, 4, 5, 6, 7, 0, 8]);
      expect(r.cost, 1);
      expect(r.blankBefore, 8);
      expect(r.blankAfter, 7);
    });

    test('trượt cả đoạn trong hàng: tính k bước', () {
      final b = PuzzleLogic.solved(3);
      final r = PuzzleLogic.slide(b, 3, 6)!; // ô 7 ở đầu hàng cuối
      expect(r.board.sublist(6), [0, 7, 8]);
      expect(r.cost, 2);
    });

    test('trượt cả đoạn trong cột', () {
      final b = PuzzleLogic.solved(3);
      final r = PuzzleLogic.slide(b, 3, 2)!; // ô 3 ở đầu cột cuối
      expect([r.board[2], r.board[5], r.board[8]], [0, 3, 6]);
      expect(r.cost, 2);
      expect(PuzzleLogic.isSolvable(r.board, 3), isTrue);
    });

    test('ô không cùng hàng/cột hoặc ô trống: không trượt', () {
      final b = PuzzleLogic.solved(3);
      expect(PuzzleLogic.slide(b, 3, 0), isNull);
      expect(PuzzleLogic.slide(b, 3, 8), isNull);
    });

    test('trượt đoạn rồi trượt lại giữ nguyên số ô và tính giải được', () {
      final s = PuzzleLogic.shuffle(5, Random(1));
      var b = s.board;
      final rnd = Random(2);
      for (var i = 0; i < 200; i++) {
        final blank = b.indexOf(0);
        final row = blank ~/ 5, col = blank % 5;
        final idx = rnd.nextBool() ? row * 5 + rnd.nextInt(5) : rnd.nextInt(5) * 5 + col;
        final r = PuzzleLogic.slide(b, 5, idx);
        if (r != null) b = r.board;
      }
      expect(b.toSet().length, 25);
      expect(PuzzleLogic.isSolvable(b, 5), isTrue);
    });
  });

  group('Heuristic & IDA*', () {
    test('đã giải: heuristic 0, lời giải rỗng', () {
      expect(PuzzleLogic.heuristic(PuzzleLogic.solved(3), 3), 0);
      expect(solveOptimal(PuzzleLogic.solved(3), 3), isEmpty);
    });

    test('cách đích 1 nước = 1', () {
      final b = [1, 2, 3, 4, 5, 6, 7, 0, 8];
      final p = solveOptimal(b, 3)!;
      expect(p.length, 1);
      expect(_applyPath(b, 3, p), PuzzleLogic.solved(3));
    });

    test('cách đích 2 và 3 nước', () {
      expect(solveOptimal([1, 2, 3, 4, 0, 6, 7, 5, 8], 3)!.length, 2);
      expect(solveOptimal([1, 2, 3, 0, 4, 6, 7, 5, 8], 3)!.length, 3);
    });

    test('bảng không giải được trả về null', () {
      expect(solveOptimal([1, 2, 3, 4, 5, 6, 8, 7, 0], 3), isNull);
    });

    test('lời giải hợp lệ, tối ưu <= đường xáo, cùng tính chẵn lẻ', () {
      for (var seed = 0; seed < 25; seed++) {
        final s = PuzzleLogic.shuffle(3, Random(seed));
        final p = solveOptimal(s.board, 3)!;
        expect(_applyPath(s.board, 3, p), PuzzleLogic.solved(3));
        expect(p.length, lessThanOrEqualTo(s.referenceMoves));
        expect((p.length - s.referenceMoves).isEven, isTrue);
      }
    });

    test('tối ưu bằng BFS trên các đề nhỏ', () {
      // BFS từ trạng thái đã giải để so khớp với IDA*.
      final dist = <String, int>{};
      final start = PuzzleLogic.solved(3);
      dist[start.join(',')] = 0;
      var frontier = [start];
      for (var d = 1; d <= 12; d++) {
        final next = <List<int>>[];
        for (final b in frontier) {
          final blank = b.indexOf(0);
          for (final nb in PuzzleLogic.neighbors(blank, 3)) {
            final c = List<int>.of(b);
            c[blank] = c[nb];
            c[nb] = 0;
            if (dist.putIfAbsent(c.join(','), () => d) == d) next.add(c);
          }
        }
        frontier = next;
      }
      final rnd = Random(5);
      final keys = dist.keys.toList();
      for (var i = 0; i < 40; i++) {
        final k = keys[rnd.nextInt(keys.length)];
        final b = k.split(',').map(int.parse).toList();
        expect(solveOptimal(b, 3)!.length, dist[k], reason: k);
      }
    });

    test('đề khó 3x3 giải nhanh', () {
      // Đề khó (31 nước theo đích 1..8,0): thử bằng đảo ngược đề đã biết.
      final b = [8, 6, 7, 2, 5, 4, 3, 1, 0];
      final sw = Stopwatch()..start();
      final p = solveOptimal(b, 3);
      if (p != null) expect(_applyPath(b, 3, p), PuzzleLogic.solved(3));
      expect(sw.elapsedMilliseconds, lessThan(8000));
    });

    test('chạy được trên isolate', () async {
      final s = PuzzleLogic.shuffle(3, Random(11));
      final p = await solveOptimalInIsolate(s.board, 3);
      expect(_applyPath(s.board, 3, p!), PuzzleLogic.solved(3));
    });
  });

  group('Gợi ý', () {
    test('3×3: bước đầu của IDA* là nước hợp lệ', () {
      final s = PuzzleLogic.shuffle(3, Random(4));
      final first = solveOptimal(s.board, 3)!.first;
      expect(PuzzleLogic.slide(s.board, 3, first)!.cost, 1);
    });

    test('4×4 và 5×5: gợi ý tham lam là ô kề ô trống, không đi ngược', () {
      for (final n in [4, 5]) {
        for (var seed = 0; seed < 20; seed++) {
          final s = PuzzleLogic.shuffle(n, Random(seed));
          final blank = s.board.indexOf(0);
          final avoid = s.blankPath[s.blankPath.length - 2];
          final h = PuzzleLogic.greedyHint(s.board, n, avoidBlank: avoid)!;
          expect(PuzzleLogic.neighbors(blank, n), contains(h));
          expect(h, isNot(avoid));
          expect(PuzzleLogic.slide(s.board, n, h)!.cost, 1);
        }
      }
    });

    test('đã giải: không có gợi ý', () {
      expect(PuzzleLogic.greedyHint(PuzzleLogic.solved(4), 4), isNull);
    });
  });

  test('bước thừa = max(0, bước đi - mốc)', () {
    expect(PuzzleLogic.extraMoves(30, 22), 8);
    expect(PuzzleLogic.extraMoves(22, 22), 0);
    expect(PuzzleLogic.extraMoves(10, 22), 0);
  });

  group('Controller', () {
    PuzzleController make({int seed = 1}) => PuzzleController(
          random: Random(seed),
          solver: (b, n) async => solveOptimal(b, n),
        );

    test('chơi theo lời giải tối ưu: 0 bước thừa, đồng hồ chạy từ bước đầu', () async {
      final c = make();
      c.newGame(Difficulty.easy);
      expect(c.clock.isRunning, isFalse);
      final path = solveOptimal(c.board, 3)!;
      TapResult last = TapResult.ignored;
      for (final idx in path) {
        last = c.tap(idx);
        if (last != TapResult.solved) expect(c.clock.isRunning, isTrue);
      }
      expect(c.clock.isRunning, isFalse);
      expect(last, TapResult.solved);
      expect(c.phase, PuzzlePhase.solved);
      final st = await c.stats();
      expect(st.reference, path.length);
      expect(c.moves, path.length);
      expect(st.extraMoves, 0);
      c.dispose();
    });

    test('bước thừa và gợi ý được cộng vào lỗi', () async {
      final c = make(seed: 2);
      c.newGame(Difficulty.easy);
      final ref = solveOptimal(c.board, 3)!.length;
      // Đi một bước rồi hoàn tác: +2 bước (hoàn tác cũng là một lần trượt).
      final blank = c.board.indexOf(0);
      c.tap(PuzzleLogic.neighbors(blank, 3).first);
      expect(c.undo(), TapResult.moved);
      await c.requestHint();
      expect(c.hints, 1);
      expect(c.moves, 2);
      // Giải nốt theo đường tối ưu.
      for (final idx in solveOptimal(c.board, 3)!) {
        c.tap(idx);
      }
      final st = await c.stats();
      expect(st.reference, ref);
      expect(st.extraMoves, 2);
      expect(st.mistakes, 3);
      c.dispose();
    });

    test('chạm ô không trượt được → blocked, không tính bước', () {
      final c = make();
      c.newGame(Difficulty.easy);
      final blank = c.board.indexOf(0);
      final bad = List.generate(9, (i) => i).firstWhere(
          (i) => i != blank && i ~/ 3 != blank ~/ 3 && i % 3 != blank % 3);
      expect(c.tap(bad), TapResult.blocked);
      expect(c.moves, 0);
      c.dispose();
    });

    test('4×4 dùng mốc từ đường xáo; gợi ý tham lam là nước hợp lệ', () async {
      final c = make();
      c.newGame(Difficulty.medium);
      expect(c.n, 4);
      expect(c.referenceMoves, isNotNull);
      final idx = await c.requestHint();
      expect(PuzzleLogic.neighbors(c.board.indexOf(0), 4), contains(idx));
      c.tap(idx!);
      expect(c.hintIndex, isNull);
      c.dispose();
    });
  });
}
