import 'dart:math';
import 'package:flutter/foundation.dart';
import 'models/sliding_tile.dart';
import '../shared/models/difficulty.dart';

class SlidingPuzzleLogic extends ChangeNotifier {
  final GameDifficulty difficulty;
  late int gridSize;
  late List<SlidingTile> tiles;
  int moves = 0;
  bool isCompleted = false;

  SlidingPuzzleLogic({this.difficulty = GameDifficulty.easy}) {
    gridSize = difficulty.gridSize;
    initBoard();
  }

  void initBoard() {
    moves = 0;
    isCompleted = false;
    final int totalTiles = gridSize * gridSize;

    List<int> tileIds = List.generate(totalTiles, (index) => index);

    do {
      tileIds.shuffle(Random());
    } while (!_isSolvable(tileIds) || _isSolved(tileIds));

    tiles = List.generate(totalTiles, (index) {
      final id = tileIds[index];
      return SlidingTile(
        id: id,
        correctIndex: id == 0 ? totalTiles - 1 : id - 1,
        currentIndex: index,
      );
    });

    notifyListeners();
  }

  bool moveTile(int index) {
    if (isCompleted) return false;

    final int emptyIndex = tiles.indexWhere((t) => t.isEmpty);
    if (_canMove(index, emptyIndex)) {
      final temp = tiles[index];
      tiles[index] = tiles[emptyIndex];
      tiles[emptyIndex] = temp;

      tiles[index].currentIndex = index;
      tiles[emptyIndex].currentIndex = emptyIndex;

      moves++;
      _checkWinCondition();
      notifyListeners();
      return true;
    }
    return false;
  }

  bool _canMove(int tileIndex, int emptyIndex) {
    final int tileRow = tileIndex ~/ gridSize;
    final int tileCol = tileIndex % gridSize;
    final int emptyRow = emptyIndex ~/ gridSize;
    final int emptyCol = emptyIndex % gridSize;

    return (tileRow == emptyRow && (tileCol - emptyCol).abs() == 1) ||
        (tileCol == emptyCol && (tileRow - emptyRow).abs() == 1);
  }

  void _checkWinCondition() {
    final int totalTiles = gridSize * gridSize;
    for (int i = 0; i < totalTiles - 1; i++) {
      if (tiles[i].id != i + 1) {
        return;
      }
    }
    if (tiles.last.isEmpty) {
      isCompleted = true;
    }
  }

  bool _isSolved(List<int> list) {
    for (int i = 0; i < list.length - 1; i++) {
      if (list[i] != i + 1) return false;
    }
    return list.last == 0;
  }

  bool _isSolvable(List<int> list) {
    int inversions = 0;
    final int total = list.length;
    for (int i = 0; i < total - 1; i++) {
      if (list[i] == 0) continue;
      for (int j = i + 1; j < total; j++) {
        if (list[j] == 0) continue;
        if (list[i] > list[j]) {
          inversions++;
        }
      }
    }

    if (gridSize % 2 != 0) {
      return inversions % 2 == 0;
    } else {
      final int emptyIndex = list.indexOf(0);
      final int emptyRowFromBottom = gridSize - (emptyIndex ~/ gridSize);
      if (emptyRowFromBottom % 2 == 0) {
        return inversions % 2 != 0;
      } else {
        return inversions % 2 == 0;
      }
    }
  }
}
