import 'dart:isolate';
import 'package:cuber/cuber.dart';

/// Kết quả giải khối Rubik
class SolveResult {
  final bool success;
  final List<String> moves;
  final String? errorMessage;
  final int durationMs;

  const SolveResult({
    required this.success,
    this.moves = const [],
    this.errorMessage,
    this.durationMs = 0,
  });
}

/// Dịch vụ giải Rubik độc lập 100% Offline chạy trên Dart Isolate
class OfflineRubikSolver {
  /// Giải từ cấu trúc sideColorCode của ứng dụng (top, left, front, right, back, bottom)
  static Future<SolveResult> solveFromSideColors(
    Map<String, String> sideColorCode,
  ) async {
    final stopwatch = Stopwatch()..start();

    // 1. Kiểm tra đủ 6 mặt và mỗi mặt đủ 9 ký tự
    const requiredSides = ['top', 'left', 'front', 'right', 'back', 'bottom'];
    for (final side in requiredSides) {
      final code = sideColorCode[side];
      if (code == null || code.length != 9) {
        return SolveResult(
          success: false,
          errorMessage: 'Mặt $side chưa được quét đủ 9 ô màu.',
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }
    }

    // 2. Chạy thuật toán Kociemba trên Background Isolate để 0% nghẽn UI
    try {
      final moves = await Isolate.run(() => _solveInIsolate(sideColorCode));
      stopwatch.stop();

      if (moves == null) {
        return SolveResult(
          success: false,
          errorMessage:
              'Mẫu màu không hợp lệ hoặc khối Rubik bị xoay góc cơ học. Vui lòng kiểm tra lại màu các mặt.',
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }

      return SolveResult(
        success: true,
        moves: moves,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return SolveResult(
        success: false,
        errorMessage: 'Lỗi khi giải khối Rubik: $e',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// Hàm chạy ngầm trong Isolate
  static List<String>? _solveInIsolate(Map<String, String> sideColorCode) {
    try {
      final centerToFace = {
        sideColorCode["top"]![4]: 'U',
        sideColorCode["right"]![4]: 'R',
        sideColorCode["front"]![4]: 'F',
        sideColorCode["bottom"]![4]: 'D',
        sideColorCode["left"]![4]: 'L',
        sideColorCode["back"]![4]: 'B',
      };

      // Đảm bảo 6 tâm là 6 màu khác nhau
      if (centerToFace.length != 6) {
        return null;
      }

      String mapSide(String s) {
        return s.split('').map((c) => centerToFace[c] ?? c).join();
      }

      // Thứ tự quy chuẩn của cuber: U, R, F, D, L, B
      final u = mapSide(sideColorCode["top"]!);
      final r = mapSide(sideColorCode["right"]!);
      final f = mapSide(sideColorCode["front"]!);
      final d = mapSide(sideColorCode["bottom"]!);
      final l = mapSide(sideColorCode["left"]!);
      final b = mapSide(sideColorCode["back"]!);

      final definition = '$u$r$f$d$l$b';
      if (definition.length != 54) {
        return null;
      }

      final cube = Cube.from(definition);
      if (cube.isNotOk) {
        return null;
      }

      if (cube.isSolved) {
        return [];
      }

      final solution = kociemba.solve(
        cube,
        maxDepth: 24,
        timeout: const Duration(seconds: 4),
      );

      if (solution == null) {
        return null;
      }

      return solution.algorithm.moves.map((m) => m.toString()).toList();
    } catch (_) {
      return null;
    }
  }

  /// Dịch ký hiệu Rubik quốc tế sang giải thích tiếng Việt chi tiết và trực quan
  static String getMoveDescription(String move) {
    final clean = move.trim().toUpperCase();
    switch (clean) {
      case 'R':
        return 'Xoay mặt PHẢI (Xanh lá) LÊN TRÊN 90° (1 lần)';
      case "R'":
        return 'Xoay mặt PHẢI (Xanh lá) XUỐNG DƯỚI 90° (1 lần)';
      case 'R2':
        return 'Xoay mặt PHẢI (Xanh lá) 180° (nửa vòng / 2 lần)';
      case 'L':
        return 'Xoay mặt TRÁI (Xanh dương) XUỐNG DƯỚI 90° (1 lần)';
      case "L'":
        return 'Xoay mặt TRÁI (Xanh dương) LÊN TRÊN 90° (1 lần)';
      case 'L2':
        return 'Xoay mặt TRÁI (Xanh dương) 180° (nửa vòng / 2 lần)';
      case 'U':
        return 'Xoay mặt TRÊN (Vàng) SANG TRÁI 90° (1 lần)';
      case "U'":
        return 'Xoay mặt TRÊN (Vàng) SANG PHẢI 90° (1 lần)';
      case 'U2':
        return 'Xoay mặt TRÊN (Vàng) 180° (nửa vòng / 2 lần)';
      case 'D':
        return 'Xoay mặt DƯỚI (Trắng) SANG PHẢI 90° (1 lần)';
      case "D'":
        return 'Xoay mặt DƯỚI (Trắng) SANG TRÁI 90° (1 lần)';
      case 'D2':
        return 'Xoay mặt DƯỚI (Trắng) 180° (nửa vòng / 2 lần)';
      case 'F':
        return 'Xoay mặt TRƯỚC (Đỏ) THEO KIM ĐỒNG HỒ 90° (1 lần)';
      case "F'":
        return 'Xoay mặt TRƯỚC (Đỏ) NGƯỢC KIM ĐỒNG HỒ 90° (1 lần)';
      case 'F2':
        return 'Xoay mặt TRƯỚC (Đỏ) 180° (nửa vòng / 2 lần)';
      case 'B':
        return 'Xoay mặt SAU (Cam) THEO KIM ĐỒNG HỒ 90° (1 lần)';
      case "B'":
        return 'Xoay mặt SAU (Cam) NGƯỢC KIM ĐỒNG HỒ 90° (1 lần)';
      case 'B2':
        return 'Xoay mặt SAU (Cam) 180° (nửa vòng / 2 lần)';
      default:
        return 'Thực hiện bước xoay $move';
    }
  }

  /// Lấy nước đi đảo ngược (Undo/Inverse Move) để diễn hoạt xoay lùi khối Rubik 3D
  static String getInverseMove(String move) {
    final clean = move.trim().toUpperCase();
    if (clean.isEmpty) return clean;

    final face = clean[0];
    if (clean.endsWith("'") || clean.endsWith("3")) {
      return face; // Ví dụ: R' -> R, U' -> U
    } else if (clean.endsWith("2")) {
      return "${face}2"; // Ví dụ: R2 -> R2 (xoay 180° theo chiều nào cũng về vị trí ban đầu)
    } else {
      return "$face'"; // Ví dụ: R -> R', U -> U'
    }
  }
}
