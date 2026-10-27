import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_new/caro/models/difficulty.dart';
import 'package:frontend_new/caro/logic/caro_ai.dart';
import 'package:frontend_new/caro/logic/caro_board.dart';

const x = kCaroPlayer;
const o = kCaroAi;

Uint8List board(Map<(int, int), int> stones) {
  final b = Uint8List(kCaroCells);
  stones.forEach((rc, v) => b[caroIndex(rc.$1, rc.$2)] = v);
  return b;
}

Map<(int, int), int> run(int r, int c, int dr, int dc, int n, int who) =>
    {for (var i = 0; i < n; i++) (r + dr * i, c + dc * i): who};

int move(Difficulty d, Uint8List b, {int seed = 1, int budgetMs = 1200}) =>
    chooseCaroMove(CaroAiRequest(cells: b, difficulty: d, seed: seed, budgetMs: budgetMs));

void main() {
  group('Nhận diện thắng', () {
    final dirs = {
      'ngang': [0, 1],
      'dọc': [1, 0],
      'chéo xuống': [1, 1],
      'chéo lên': [1, -1],
    };
    for (final e in dirs.entries) {
      test('5 quân ${e.key} ở giữa bàn', () {
        final dr = e.value[0], dc = e.value[1];
        final r0 = 5, c0 = dc < 0 ? 9 : 5;
        final b = board(run(r0, c0, dr, dc, 5, x));
        for (var i = 0; i < 5; i++) {
          expect(caroMakesWin(b, caroIndex(r0 + dr * i, c0 + dc * i)), isTrue);
        }
        final line = caroWinningLine(b, caroIndex(r0 + dr * 2, c0 + dc * 2))!;
        expect(line.length, 5);
        expect(line.first, caroIndex(r0, c0));
        expect(line.last, caroIndex(r0 + dr * 4, c0 + dc * 4));
      });
      test('4 quân ${e.key} chưa thắng', () {
        final dr = e.value[0], dc = e.value[1];
        final c0 = dc < 0 ? 9 : 5;
        final b = board(run(5, c0, dr, dc, 4, x));
        expect(caroMakesWin(b, caroIndex(5, c0)), isFalse);
        expect(caroWinningLine(b, caroIndex(5, c0)), isNull);
      });
    }

    test('thắng sát mép bàn (các góc)', () {
      expect(caroMakesWin(board(run(0, 0, 0, 1, 5, o)), 0), isTrue);
      expect(caroMakesWin(board(run(14, 10, 0, 1, 5, o)), caroIndex(14, 14)), isTrue);
      expect(caroMakesWin(board(run(0, 14, 1, 0, 5, x)), caroIndex(0, 14)), isTrue);
      expect(caroMakesWin(board(run(10, 14, 1, 0, 5, x)), caroIndex(14, 14)), isTrue);
      expect(caroMakesWin(board(run(0, 0, 1, 1, 5, x)), 0), isTrue);
      expect(caroMakesWin(board(run(10, 10, 1, 1, 5, x)), caroIndex(14, 14)), isTrue);
      expect(caroMakesWin(board(run(0, 14, 1, -1, 5, o)), caroIndex(0, 14)), isTrue);
      expect(caroMakesWin(board(run(10, 4, 1, -1, 5, o)), caroIndex(14, 0)), isTrue);
    });

    test('6 quân liên tiếp vẫn thắng và đường thắng gồm cả 6 quân', () {
      final b = board(run(7, 2, 0, 1, 6, x));
      expect(caroMakesWin(b, caroIndex(7, 4)), isTrue);
      expect(caroWinningLine(b, caroIndex(7, 4))!.length, 6);
    });

    test('dãy bị quân đối phương cắt ngang thì không thắng', () {
      final stones = run(3, 3, 0, 1, 5, x)..[(3, 5)] = o;
      expect(caroMakesWin(board(stones), caroIndex(3, 3)), isFalse);
    });
  });

  test('hoà: bàn đầy mà không ai có 5 quân', () {
    final b = Uint8List(kCaroCells);
    for (var r = 0; r < kCaroSize; r++) {
      for (var c = 0; c < kCaroSize; c++) {
        b[caroIndex(r, c)] = ((c ~/ 2) + r) % 2 == 0 ? x : o;
      }
    }
    expect(caroIsFull(b), isTrue);
    for (var i = 0; i < kCaroCells; i++) {
      expect(caroMakesWin(b, i), isFalse, reason: 'ô $i');
    }
    b[40] = kCaroEmpty;
    expect(caroIsFull(b), isFalse);
  });

  for (final d in [Difficulty.medium, Difficulty.hard]) {
    group('AI ${d.label}', () {
      test('thắng ngay khi có thể (4 quân hai đầu mở)', () {
        final b = board({...run(7, 4, 0, 1, 4, o), (9, 9): x, (9, 10): x, (10, 9): x});
        final m = move(d, b);
        expect([caroIndex(7, 3), caroIndex(7, 8)], contains(m));
      });

      test('thắng ngay khi có 4 quân có một khe hở', () {
        final b = board({
          (5, 5): o, (5, 6): o, (5, 8): o, (5, 9): o,
          (8, 8): x, (8, 9): x, (9, 9): x, (10, 4): x,
        });
        expect(move(d, b), caroIndex(5, 7));
      });

      test('ưu tiên thắng hơn chặn', () {
        final b = board({
          ...run(2, 2, 1, 0, 4, o), // máy có 4 dọc
          ...run(9, 5, 0, 1, 4, x), // người cũng có 4 ngang
        });
        final m = move(d, b);
        expect([caroIndex(1, 2), caroIndex(6, 2)], contains(m));
      });

      test('chặn 4 quân bị chặn một đầu', () {
        final b = board({...run(7, 4, 0, 1, 4, x), (7, 3): o, (3, 3): o});
        expect(move(d, b), caroIndex(7, 8));
      });

      test('chặn 4 quân có một khe hở (X X _ X X)', () {
        final b = board({
          (6, 3): x, (6, 4): x, (6, 6): x, (6, 7): x, (10, 10): o, (10, 11): o,
        });
        expect(move(d, b), caroIndex(6, 5));
      });

      test('chặn 4 quân chéo', () {
        final b = board({...run(4, 4, 1, 1, 4, x), (3, 3): o, (11, 2): o});
        expect(move(d, b), caroIndex(8, 8));
      });

      test('chặn 4 quân sát mép bàn (chỉ còn một đầu)', () {
        final b = board({...run(0, 0, 0, 1, 4, x), (10, 10): o});
        expect(move(d, b), caroIndex(0, 4));
      });

      test('chặn ba mở trước khi thành bốn mở', () {
        final b = board({...run(7, 5, 0, 1, 3, x), (12, 12): o});
        final m = move(d, b);
        expect([caroIndex(7, 4), caroIndex(7, 8), caroIndex(7, 3), caroIndex(7, 9)], contains(m));
      });
    });
  }

  test('AI đi nước đầu vào giữa bàn khi bàn trống', () {
    for (final d in Difficulty.values) {
      expect(move(d, Uint8List(kCaroCells)), caroIndex(7, 7));
    }
  });

  test('AI không bao giờ đánh vào ô đã có quân (mọi mức)', () {
    for (final d in Difficulty.values) {
      final rng = Random(7);
      final b = Uint8List(kCaroCells);
      var side = x;
      for (var t = 0; t < 40; t++) {
        int m;
        if (side == x) {
          do {
            m = caroIndex(3 + rng.nextInt(9), 3 + rng.nextInt(9));
          } while (b[m] != 0);
        } else {
          m = move(d, b, seed: t, budgetMs: 150);
          expect(b[m], kCaroEmpty, reason: '${d.label} lượt $t');
        }
        b[m] = side;
        if (caroMakesWin(b, m)) break;
        side = 3 - side;
      }
    }
  });

  test('AI Khó trả về trong ngân sách thời gian (+ biên)', () {
    final b = board({
      (7, 7): x, (7, 8): o, (8, 8): x, (6, 6): o, (8, 7): x, (6, 7): o,
      (9, 9): x, (5, 5): o, (7, 9): x, (7, 6): o, (6, 8): x, (8, 6): o,
      (9, 7): x, (5, 7): o, (10, 8): x,
    });
    final sw = Stopwatch()..start();
    final m = move(Difficulty.hard, b, budgetMs: 1200);
    sw.stop();
    expect(b[m], kCaroEmpty);
    expect(sw.elapsedMilliseconds, lessThan(1200 + 400));
  });

  test('AI Khó chạy được qua Isolate.run', () async {
    final b = board(run(7, 4, 0, 1, 4, o));
    final m = await runCaroAiInIsolate(
      CaroAiRequest(cells: b, difficulty: Difficulty.hard, budgetMs: 300),
    );
    expect([caroIndex(7, 3), caroIndex(7, 8)], contains(m));
  });
  test('AI Kho khi di truoc: khai cuoc sat thu Hoa Nguyet', () {
    final b = board({(7, 7): o, (8, 8): x});
    final m = move(Difficulty.hard, b);
    expect([caroIndex(7, 8), caroIndex(8, 7)], contains(m));
  });

  test('AI Kho VCF: phat hien va danh nuoc don ep 4 thang ngay', () {
    final b = board({
      (7, 5): o, (7, 6): o, (7, 7): o, (7, 8): o,
      (8, 5): x, (8, 6): x, (8, 7): x,
    });
    final m = move(Difficulty.hard, b);
    expect([caroIndex(7, 4), caroIndex(7, 9)], contains(m));
  });

  test('AI Kho: uu tien chan nguoi choi 4 quan thay vi tao 4 mo cho minh', () {
    final b = board({
      (8, 5): x, (8, 6): x, (8, 7): x, (8, 8): x,
      (7, 5): o, (7, 6): o, (7, 7): o,
    });
    final m = move(Difficulty.hard, b);
    expect([caroIndex(8, 4), caroIndex(8, 9)], contains(m));
  });

  test('AI Kho: chan 3 mo cua nguoi choi truoc khi tao don doi 3-3 cho minh', () {
    final b = board({
      (8, 5): x, (8, 6): x, (8, 7): x,
      (4, 6): o, (5, 6): o, (6, 4): o, (6, 5): o,
    });
    final m = move(Difficulty.hard, b);
    expect([caroIndex(8, 4), caroIndex(8, 8)], contains(m));
  });

  test('AI Kho: chan don doi 3-3 cua nguoi choi', () {
    final b = board({
      (4, 6): x, (5, 6): x, (6, 4): x, (6, 5): x,
      (10, 10): o, (10, 11): o,
    });
    final m = move(Difficulty.hard, b);
    expect(m, caroIndex(6, 6));
  });

  test('AI Kho: chan don 4-3 cua nguoi choi', () {
    // x có đường dọc (5,6), (7,6), (8,6) chặn ở (9,6) (nếu đánh (6,6) sẽ tạo 4 kín)
    // và đường ngang (6,4), (6,5) mở (nếu đánh (6,6) sẽ tạo 3 mở)
    final b = board({
      (5, 6): x, (7, 6): x, (8, 6): x, (9, 6): o,
      (6, 4): x, (6, 5): x,
      (11, 11): o,
    });
    final m = move(Difficulty.hard, b);
    expect(m, caroIndex(6, 6));
  });

  test('AI Kho: khong VCF tan cong khi nguoi choi dang co 4 quan thang ngay', () {
    final b = board({
      (8, 5): x, (8, 6): x, (8, 7): x, (8, 8): x,
      (3, 3): o, (3, 4): o, (3, 5): o,
    });
    final m = move(Difficulty.hard, b);
    // x sắp thắng ngay nên AI bắt buộc phải chặn x ở (8, 4) hoặc (8, 9)
    expect([caroIndex(8, 4), caroIndex(8, 9)], contains(m));
  });
}