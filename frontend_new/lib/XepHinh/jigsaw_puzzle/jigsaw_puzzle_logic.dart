import 'dart:math';
import 'package:flutter/foundation.dart';
import 'models/jigsaw_piece.dart';
import '../shared/models/difficulty.dart';

class JigsawPuzzleLogic extends ChangeNotifier {
  final GameDifficulty difficulty;
  late int gridSize;
  late List<JigsawPiece> pieces;
  int moves = 0;
  bool isCompleted = false;
  int? selectedPieceIndex;

  JigsawPuzzleLogic({this.difficulty = GameDifficulty.easy}) {
    gridSize = difficulty.gridSize;
    initBoard();
  }

  void initBoard() {
    moves = 0;
    isCompleted = false;
    selectedPieceIndex = null;
    final int totalPieces = gridSize * gridSize;

    List<int> shuffledIndices = List.generate(totalPieces, (index) => index);
    shuffledIndices.shuffle(Random());

    pieces = List.generate(totalPieces, (index) {
      final correctRow = index ~/ gridSize;
      final correctCol = index % gridSize;
      final currentPos = shuffledIndices[index];
      final currentRow = currentPos ~/ gridSize;
      final currentCol = currentPos % gridSize;

      return JigsawPiece(
        id: index + 1,
        correctRow: correctRow,
        correctCol: correctCol,
        currentRow: currentRow,
        currentCol: currentCol,
      );
    });
    // Màn hình vẽ mảnh theo thứ tự danh sách, nên xếp danh sách theo vị trí
    // hiện tại (ô thứ i của lưới = pieces[i]). Đổi chỗ trong selectOrSwapPiece
    // giữ nguyên quy tắc này. Trước đây danh sách giữ thứ tự đúng nên bàn hiện ra
    // như đã giải sẵn, dù vị trí thật đã bị xáo.
    pieces.sort((a, b) =>
        (a.currentRow * gridSize + a.currentCol).compareTo(b.currentRow * gridSize + b.currentCol));

    _checkWinCondition();
    notifyListeners();
  }

  void selectOrSwapPiece(int index) {
    if (isCompleted) return;

    if (selectedPieceIndex == null) {
      selectedPieceIndex = index;
    } else if (selectedPieceIndex == index) {
      selectedPieceIndex = null;
    } else {
      final int firstIndex = selectedPieceIndex!;
      final int secondIndex = index;

      final tempRow = pieces[firstIndex].currentRow;
      final tempCol = pieces[firstIndex].currentCol;

      pieces[firstIndex].currentRow = pieces[secondIndex].currentRow;
      pieces[firstIndex].currentCol = pieces[secondIndex].currentCol;

      pieces[secondIndex].currentRow = tempRow;
      pieces[secondIndex].currentCol = tempCol;

      final tempPiece = pieces[firstIndex];
      pieces[firstIndex] = pieces[secondIndex];
      pieces[secondIndex] = tempPiece;

      selectedPieceIndex = null;
      moves++;
      _checkWinCondition();
    }
    notifyListeners();
  }

  void _checkWinCondition() {
    for (var piece in pieces) {
      if (!piece.isCorrect) {
        isCompleted = false;
        return;
      }
    }
    isCompleted = true;
  }
}
