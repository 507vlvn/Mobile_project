import 'package:cuber/cuber.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_new/rubik/services/kociemba_short_solver.dart';

void main() {
  // Nạp bảng tra một lần để không tính vào thời gian của các test bên dưới.
  setUpAll(() => kociemba.solve(Cube.scrambled(n: 25), maxDepth: 24));

  test('lời giải đúng, không dài hơn bản gốc của cuber, xong đúng hạn', () {
    // Ngân sách rộng để không chập chờn khi máy bận (chạy song song nhiều test);
    // app dùng 1 giây và có dự phòng giải lại bằng bản gốc nếu chưa ra lời giải.
    const budget = Duration(seconds: 2);
    var shorter = 0;
    for (var i = 0; i < 6; i++) {
      final cube = Cube.scrambled(n: 25);
      final original = kociemba.solve(cube, maxDepth: 24)!;

      final sw = Stopwatch()..start();
      final s = const KociembaShortSolver().solve(cube, maxDepth: 24, timeout: budget);
      sw.stop();

      expect(s, isNotNull);
      expect(s!.algorithm.apply(cube).isSolved, isTrue, reason: 'lời giải phải giải được khối');
      expect(s.algorithm.moves.length, lessThanOrEqualTo(original.algorithm.moves.length));
      expect(s.algorithm.moves.length, lessThanOrEqualTo(22));
      // Cho phép trễ một chút so với ngân sách (kiểm tra timeout theo lô nút).
      expect(sw.elapsed, lessThan(budget + const Duration(seconds: 1)));
      if (s.algorithm.moves.length < original.algorithm.moves.length) shorter++;
    }
    expect(shorter, greaterThan(0), reason: 'phải rút ngắn được ít nhất vài lời giải');
  });

  test('khối đã giải trả về lời giải rỗng', () {
    final s = const KociembaShortSolver().solve(Cube.solved);
    expect(s, isNotNull);
    expect(s!.algorithm.moves, isEmpty);
  });
}
