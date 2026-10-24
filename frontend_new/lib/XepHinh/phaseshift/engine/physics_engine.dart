import 'dart:math';
import '../models/material.dart';
import '../../shared/models/difficulty.dart';

class Position {
  final int row;
  final int col;

  const Position(this.row, this.col);

  Position copyWith({int? row, int? col}) {
    return Position(row ?? this.row, col ?? this.col);
  }
}

class PhysicsEngine {
  static int getRows(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        return 10;
      case GameDifficulty.medium:
        return 12;
      case GameDifficulty.hard:
        return 14;
    }
  }

  static int getCols(GameDifficulty difficulty) {
    return 8;
  }

  static Duration getDropInterval(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        return const Duration(milliseconds: 700);
      case GameDifficulty.medium:
        return const Duration(milliseconds: 450);
      case GameDifficulty.hard:
        return const Duration(milliseconds: 250);
    }
  }

  static List<ElementType> getAvailableElements(GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        return [
          ElementType.fire,
          ElementType.ice,
          ElementType.water,
          ElementType.stone,
          ElementType.acid,
          ElementType.electric,
        ];
      case GameDifficulty.medium:
      case GameDifficulty.hard:
        return ElementType.values;
    }
  }

  static ElementBlock generateRandomBlock(GameDifficulty difficulty) {
    final random = Random();
    final int roll = random.nextInt(100);

    ElementType type;
    if (difficulty == GameDifficulty.easy) {
      if (roll < 22) {
        type = ElementType.fire;
      } else if (roll < 44) {
        type = ElementType.ice;
      } else if (roll < 66) {
        type = ElementType.water;
      } else if (roll < 80) {
        type = ElementType.stone;
      } else if (roll < 95) {
        type = ElementType.acid;
      } else {
        type = ElementType.electric;
      }
    } else if (difficulty == GameDifficulty.medium) {
      if (roll < 20) {
        type = ElementType.fire;
      } else if (roll < 40) {
        type = ElementType.ice;
      } else if (roll < 60) {
        type = ElementType.water;
      } else if (roll < 75) {
        type = ElementType.stone;
      } else if (roll < 90) {
        type = ElementType.acid;
      } else if (roll < 95) {
        type = ElementType.frost;
      } else {
        type = ElementType.electric;
      }
    } else {
      if (roll < 18) {
        type = ElementType.fire;
      } else if (roll < 36) {
        type = ElementType.ice;
      } else if (roll < 54) {
        type = ElementType.water;
      } else if (roll < 72) {
        type = ElementType.stone;
      } else if (roll < 90) {
        type = ElementType.acid;
      } else if (roll < 95) {
        type = ElementType.frost;
      } else {
        type = ElementType.electric;
      }
    }

    return ElementBlock(
      type: type,
      id: 'block_${DateTime.now().microsecondsSinceEpoch}_${random.nextInt(1000)}',
    );
  }

  static bool isValidMove({
    required List<List<ElementBlock?>> board,
    required Position position,
    required int rows,
    required int cols,
  }) {
    if (position.row < 0 || position.row >= rows) return false;
    if (position.col < 0 || position.col >= cols) return false;
    return board[position.row][position.col] == null;
  }

  static Position calculateHardDropPosition({
    required List<List<ElementBlock?>> board,
    required Position currentPos,
    required int rows,
    required int cols,
  }) {
    int r = currentPos.row;
    while (r + 1 < rows && board[r + 1][currentPos.col] == null) {
      r++;
    }
    return Position(r, currentPos.col);
  }
}
