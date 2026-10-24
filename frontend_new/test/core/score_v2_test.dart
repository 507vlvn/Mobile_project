import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_new/core/models/difficulty.dart';
import 'package:frontend_new/core/models/score.dart';
import 'package:frontend_new/core/services/score_reporter.dart';

int score(
  String game,
  Difficulty d, {
  int time = 0,
  int mistakes = 0,
  int moves = 0,
  bool completed = true,
}) =>
    computeScore(
      gameCode: game,
      difficulty: d,
      timeSeconds: time,
      mistakes: mistakes,
      moves: moves,
      completed: completed,
    );

GameRecord rec(
  String game,
  Difficulty d,
  GameOutcome o, {
  int time = 0,
  int mistakes = 0,
  int moves = 0,
}) =>
    GameRecord(
      gameCode: game,
      difficulty: d,
      timeSeconds: time,
      mistakes: mistakes,
      moves: moves,
      outcome: o,
    );

void main() {
  group('par table (TASKS_V2 §2.1)', () {
    test('Sudoku 6/12/25 phút, Xếp hình 60s/4/10 phút, Rubik 90s/4/10 phút', () {
      expect(parFor('SUDOKU', Difficulty.easy), 360);
      expect(parFor('SUDOKU', Difficulty.medium), 720);
      expect(parFor('SUDOKU', Difficulty.hard), 1500);
      expect(parFor('PUZZLE', Difficulty.easy), 60);
      expect(parFor('PUZZLE', Difficulty.medium), 240);
      expect(parFor('PUZZLE', Difficulty.hard), 600);
      expect(parFor('RUBIK', Difficulty.easy), 90);
      expect(parFor('RUBIK', Difficulty.medium), 240);
      expect(parFor('RUBIK', Difficulty.hard), 600);
      expect(parFor('CARO', Difficulty.easy), 20);
      expect(parFor('CARO', Difficulty.medium), 30);
      expect(parFor('CARO', Difficulty.hard), 45);
    });
  });

  group('computeScore', () {
    test('đúng par, không lỗi = base (1000/2000/3000)', () {
      expect(score('SUDOKU', Difficulty.easy, time: 360), 1000);
      expect(score('SUDOKU', Difficulty.medium, time: 720), 2000);
      expect(score('SUDOKU', Difficulty.hard, time: 1500), 3000);
    });

    test('nhanh hơn par được thưởng nhưng tối đa x1.5', () {
      expect(score('SUDOKU', Difficulty.medium, time: 360), 3000);
      expect(score('SUDOKU', Difficulty.medium, time: 60), 3000); // chặn ở 1.5
      expect(score('PUZZLE', Difficulty.easy, time: 40), 1500);
    });

    test('chậm hơn par giảm theo tỉ lệ, sàn x0.25', () {
      expect(score('RUBIK', Difficulty.hard, time: 900), 2000); // 600/900
      expect(score('RUBIK', Difficulty.medium, time: 480), 1000); // 240/480
      expect(score('SUDOKU', Difficulty.medium, time: 3600), 500); // sàn 0.25
      expect(score('SUDOKU', Difficulty.medium, time: 100000), 500);
    });

    test('mỗi lỗi nhân 0.92', () {
      expect(score('SUDOKU', Difficulty.medium, time: 720, mistakes: 1), 1840);
      expect(score('SUDOKU', Difficulty.medium, time: 720, mistakes: 2), 1693);
      expect(score('SUDOKU', Difficulty.hard, time: 1500, mistakes: 5), 1977);
    });

    test('thời gian bằng 0 không chia cho 0 (tính như nhanh nhất)', () {
      expect(score('SUDOKU', Difficulty.easy, time: 0), 1500);
    });

    test('thua / bỏ cuộc = 0', () {
      expect(score('SUDOKU', Difficulty.medium, time: 720, completed: false), 0);
    });

    test('Caro tính theo số nước, không theo thời gian', () {
      expect(score('CARO', Difficulty.easy, time: 9999, moves: 20), 1000);
      expect(score('CARO', Difficulty.easy, time: 1, moves: 10), 1500);
      expect(score('CARO', Difficulty.medium, time: 5, moves: 60), 1000);
      expect(score('CARO', Difficulty.hard, moves: 45), 3000);
      expect(score('CARO', Difficulty.easy, moves: 1000), 250); // sàn
    });
  });

  group('GameRecord.localScore', () {
    test('hoàn thành / thắng dùng công thức v2', () {
      expect(
          rec('SUDOKU', Difficulty.medium, GameOutcome.completed, time: 720)
              .localScore,
          2000);
      expect(rec('CARO', Difficulty.hard, GameOutcome.win, moves: 45).localScore,
          3000);
    });

    test('thua và bỏ cuộc = 0', () {
      expect(rec('CARO', Difficulty.hard, GameOutcome.lose, moves: 20).localScore,
          0);
      expect(
          rec('SUDOKU', Difficulty.easy, GameOutcome.abandoned, time: 100)
              .localScore,
          0);
    });

    test('Caro hòa = 30% điểm đầy đủ', () {
      expect(rec('CARO', Difficulty.hard, GameOutcome.draw, moves: 45).localScore,
          900);
      expect(rec('CARO', Difficulty.easy, GameOutcome.draw, moves: 20).localScore,
          300);
    });
  });
}
