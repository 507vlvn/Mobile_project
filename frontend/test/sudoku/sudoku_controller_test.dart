import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/models/difficulty.dart';
import 'package:mobile_rubik/features/sudoku/logic/sudoku_board.dart';
import 'package:mobile_rubik/features/sudoku/logic/sudoku_generator.dart';
import 'package:mobile_rubik/features/sudoku/sudoku_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

SudokuController _make(SudokuPuzzle p) {
  final c = SudokuController(generator: (d) async => p);
  c.loadPuzzle(p, Difficulty.easy);
  return c;
}

void main() {
  late SudokuPuzzle puzzle;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    puzzle = generatePuzzle(Difficulty.easy, random: Random(42));
  });

  int emptyCell(SudokuController c, [int skip = 0]) {
    final b = c.board!;
    return [
      for (var i = 0; i < 81; i++)
        if (b.isEmpty(i)) i
    ][skip];
  }

  int wrongDigit(SudokuController c, int i) => c.board!.solution[i] % 9 + 1;

  test('điền sai: +1 lỗi, ô sai, đồng hồ chạy', () {
    final c = _make(puzzle);
    final i = emptyCell(c);
    c.select(i);
    expect(c.clock.isRunning, isFalse);
    expect(c.input(wrongDigit(c, i)), PlaceResult.wrong);
    expect(c.mistakes, 1);
    expect(c.wrongEntries, 1);
    expect(c.board!.isWrong(i), isTrue);
    expect(c.clock.isRunning, isTrue);
    c.dispose();
  });

  test('điền đúng không tính lỗi và xoá ghi chú cùng hàng/cột/khối', () {
    final c = _make(puzzle);
    final b = c.board!;
    final i = emptyCell(c);
    final d = b.solution[i];
    final peer = SudokuBoard.peersOf(i).firstWhere(b.isEmpty);
    c.select(peer);
    c.toggleNotes();
    c.input(d);
    expect(b.notes[peer], contains(d));
    c.toggleNotes();
    c.select(i);
    expect(c.input(d), anyOf(PlaceResult.correct, PlaceResult.solved));
    expect(c.mistakes, 0);
    expect(b.notes[peer], isNot(contains(d)));
    c.dispose();
  });

  test('ô đề bài không bị sửa', () {
    final c = _make(puzzle);
    final given = [
      for (var i = 0; i < 81; i++)
        if (c.board!.isGiven(i)) i
    ].first;
    c.select(given);
    expect(c.input(1), PlaceResult.ignored);
    expect(c.erase(), isFalse);
    c.dispose();
  });

  test('gợi ý điền giá trị đúng, tính gợi ý và lỗi', () {
    final c = _make(puzzle);
    final i = emptyCell(c);
    c.select(i);
    expect(c.hint(), i);
    expect(c.board!.isCorrect(i), isTrue);
    expect(c.hints, 1);
    expect(c.mistakes, 1);
    expect(c.entries, 1);
    c.select(null);
    final j = c.hint(random: Random(1));
    expect(j, isNonNegative);
    expect(c.hints, 2);
    c.dispose();
  });

  test('hoàn tác khôi phục giá trị và ghi chú', () {
    final c = _make(puzzle);
    final i = emptyCell(c);
    c.select(i);
    c.toggleNotes();
    c.input(3);
    c.input(5);
    expect(c.board!.notes[i], {3, 5});
    c.toggleNotes();
    final d = c.board!.solution[i];
    c.input(d);
    expect(c.board!.values[i], d);
    expect(c.board!.notes[i], isEmpty);
    expect(c.undo(), isTrue);
    expect(c.board!.values[i], 0);
    expect(c.board!.notes[i], {3, 5});
    expect(c.undo(), isTrue);
    expect(c.board!.notes[i], {3});
    c.dispose();
  });

  test('xoá số sai, lỗi đã tính không bị hoàn lại', () {
    final c = _make(puzzle);
    final i = emptyCell(c);
    c.select(i);
    c.input(wrongDigit(c, i));
    expect(c.erase(), isTrue);
    expect(c.board!.values[i], 0);
    expect(c.mistakes, 1);
    c.dispose();
  });

  test('phát hiện hoàn thành và dừng đồng hồ', () {
    final c = _make(puzzle);
    final empties = [
      for (var i = 0; i < 81; i++)
        if (c.board!.isEmpty(i)) i
    ];
    PlaceResult? last;
    for (final i in empties) {
      c.select(i);
      last = c.input(c.board!.solution[i]);
    }
    expect(last, PlaceResult.solved);
    expect(c.phase, SudokuPhase.solved);
    expect(c.board!.isComplete, isTrue);
    expect(c.clock.isRunning, isFalse);
    expect(c.mistakes, 0);
    expect(c.entries, empties.length);
    c.dispose();
  });

  test('chữ số đủ 9 lần đúng thì correctCount = 9', () {
    final c = _make(puzzle);
    final b = c.board!;
    for (var i = 0; i < 81; i++) {
      if (b.solution[i] == 4 && b.isEmpty(i)) {
        c.select(i);
        c.input(4);
      }
    }
    expect(b.correctCount(4), 9);
    c.dispose();
  });

  test('tạm dừng chặn nhập, tiếp tục chạy lại đồng hồ', () {
    final c = _make(puzzle);
    final i = emptyCell(c);
    c.select(i);
    c.input(c.board!.solution[i]);
    c.pause();
    expect(c.phase, SudokuPhase.paused);
    expect(c.clock.isRunning, isFalse);
    expect(c.input(1), PlaceResult.ignored);
    c.resume();
    expect(c.phase, SudokuPhase.playing);
    expect(c.clock.isRunning, isTrue);
    c.dispose();
  });

  test('lưu và khôi phục ván dở', () async {
    final c = _make(puzzle);
    final i = emptyCell(c);
    c.select(i);
    c.input(wrongDigit(c, i));
    final k = emptyCell(c, 1);
    c.select(k);
    c.toggleNotes();
    c.input(2);
    await c.saveNow();
    expect(await SudokuController.hasSavedGame(), isTrue);

    final r = SudokuController();
    expect(await r.restore(), isTrue);
    expect(r.phase, SudokuPhase.paused);
    expect(r.mistakes, 1);
    expect(r.board!.values, c.board!.values);
    expect(r.board!.notes[k], {2});
    expect(r.board!.solution, c.board!.solution);
    c.dispose();
    r.dispose();
  });

  test('startNewGame qua generator giả', () async {
    final c = SudokuController(generator: (d) async => puzzle);
    final f = c.startNewGame(Difficulty.easy);
    expect(c.phase, SudokuPhase.generating);
    await f;
    expect(c.phase, SudokuPhase.playing);
    expect(c.board, isNotNull);
    c.dispose();
  });
}
