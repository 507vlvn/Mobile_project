import 'dart:math';
import '../models/material.dart';

class ReactionResult {
  final List<List<ElementBlock?>> board;
  final int scoreEarned;
  final int comboCount;
  final List<String> reactionLogs;

  const ReactionResult({
    required this.board,
    required this.scoreEarned,
    required this.comboCount,
    required this.reactionLogs,
  });
}

class ReactionEngine {
  static ReactionResult processReactions({
    required List<List<ElementBlock?>> grid,
    required int rows,
    required int cols,
    int initialCombo = 0,
  }) {
    List<List<ElementBlock?>> currentBoard = _cloneBoard(grid, rows, cols);
    int totalScore = 0;
    int comboCount = initialCombo;
    List<String> logs = [];

    bool hasChanged = true;
    while (hasChanged) {
      hasChanged = false;

      // 1. Check for Electric explosions (Rare 5% block)
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final block = currentBoard[r][c];
          if (block?.type == ElementType.electric) {
            bool hasAdjacent = _hasAnyAdjacentBlock(currentBoard, r, c, rows, cols);
            if (hasAdjacent) {
              comboCount++;
              int destroyedCount = 0;
              for (int dr = -1; dr <= 1; dr++) {
                for (int dc = -1; dc <= 1; dc++) {
                  int nr = r + dr;
                  int nc = c + dc;
                  if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
                    if (currentBoard[nr][nc] != null) {
                      currentBoard[nr][nc] = null;
                      destroyedCount++;
                    }
                  }
                }
              }
              int points = destroyedCount * 100 * comboCount;
              totalScore += points;
              logs.add('⚡ Phát nổ Điện! Xóa $destroyedCount khối (+$points điểm)');
              hasChanged = true;
              break;
            }
          }
        }
        if (hasChanged) break;
      }

      if (hasChanged) {
        _applyGravityAndWater(currentBoard, rows, cols);
        continue;
      }

      // 2. Check for Water + Fire (1 Water block extinguishes 1 Fire block, both disappear)
      for (int r = 0; r < rows && !hasChanged; r++) {
        for (int c = 0; c < cols && !hasChanged; c++) {
          final block = currentBoard[r][c];
          if (block?.type == ElementType.water) {
            final firePos = _findAdjacentType(currentBoard, r, c, ElementType.fire, rows, cols);
            if (firePos != null) {
              comboCount++;
              currentBoard[r][c] = null; // Water evaporates
              currentBoard[firePos.key][firePos.value] = null; // Fire is extinguished
              int points = 150 * comboCount;
              totalScore += points;
              logs.add('💧 Nước dập Lửa! (+$points điểm)');
              hasChanged = true;
            }
          }
        }
      }

      if (hasChanged) {
        _applyGravityAndWater(currentBoard, rows, cols);
        continue;
      }

      // 3. Check for Ice + Water (Ice freezes Water into Ice, original Ice block is preserved)
      for (int r = 0; r < rows && !hasChanged; r++) {
        for (int c = 0; c < cols && !hasChanged; c++) {
          final block = currentBoard[r][c];
          if (block?.type == ElementType.ice) {
            final waterPositions = _findAllAdjacentTypes(currentBoard, r, c, ElementType.water, rows, cols);
            if (waterPositions.isNotEmpty) {
              comboCount++;
              int frozenCount = 0;
              for (var pos in waterPositions) {
                currentBoard[pos.key][pos.value] = ElementBlock(
                  type: ElementType.ice,
                  id: 'ice_${DateTime.now().microsecondsSinceEpoch}_${pos.key}_${pos.value}',
                );
                frozenCount++;
              }
              int points = frozenCount * 150 * comboCount;
              totalScore += points;
              logs.add('🧊 Băng đóng băng $frozenCount khối Nước! (+$points điểm)');
              hasChanged = true;
            }
          }
        }
      }

      if (hasChanged) {
        _applyGravityAndWater(currentBoard, rows, cols);
        continue;
      }

      // 4. Check for Fire + Ice (Fire turns Ice into Water, Fire disappears)
      for (int r = 0; r < rows && !hasChanged; r++) {
        for (int c = 0; c < cols && !hasChanged; c++) {
          final block = currentBoard[r][c];
          if (block?.type == ElementType.fire) {
            final icePos = _findAdjacentType(currentBoard, r, c, ElementType.ice, rows, cols);
            if (icePos != null) {
              comboCount++;
              currentBoard[r][c] = null; // Fire disappears
              currentBoard[icePos.key][icePos.value] = ElementBlock(
                type: ElementType.water,
                id: 'water_${DateTime.now().microsecondsSinceEpoch}',
              ); // Ice turns into Water
              int points = 150 * comboCount;
              totalScore += points;
              logs.add('🔥 Lửa tan Băng thành Nước! (+$points điểm)');
              hasChanged = true;
            }
          }
        }
      }

      if (hasChanged) {
        _applyGravityAndWater(currentBoard, rows, cols);
        continue;
      }

      // 5. Check for Acid + Stone (1 Acid dissolves 1 Stone, both disappear)
      for (int r = 0; r < rows && !hasChanged; r++) {
        for (int c = 0; c < cols && !hasChanged; c++) {
          final block = currentBoard[r][c];
          if (block?.type == ElementType.acid) {
            final stonePos = _findAdjacentType(currentBoard, r, c, ElementType.stone, rows, cols);
            if (stonePos != null) {
              comboCount++;
              currentBoard[r][c] = null; // Acid disappears
              currentBoard[stonePos.key][stonePos.value] = null; // Stone dissolves
              int points = 200 * comboCount;
              totalScore += points;
              logs.add('🧪 Axit hòa tan Đá! (+$points điểm)');
              hasChanged = true;
            }
          }
        }
      }

      if (hasChanged) {
        _applyGravityAndWater(currentBoard, rows, cols);
        continue;
      }

      // 6. Check for Frost + Water (Frost freezes Water into Ice, Frost disappears)
      for (int r = 0; r < rows && !hasChanged; r++) {
        for (int c = 0; c < cols && !hasChanged; c++) {
          final block = currentBoard[r][c];
          if (block?.type == ElementType.frost) {
            final waterPositions = _findAllAdjacentTypes(currentBoard, r, c, ElementType.water, rows, cols);
            if (waterPositions.isNotEmpty) {
              comboCount++;
              currentBoard[r][c] = null; // Frost disappears
              int frozenCount = 0;
              for (var pos in waterPositions) {
                currentBoard[pos.key][pos.value] = ElementBlock(
                  type: ElementType.ice,
                  id: 'ice_${DateTime.now().microsecondsSinceEpoch}_${pos.key}_${pos.value}',
                );
                frozenCount++;
              }
              int points = frozenCount * 150 * comboCount;
              totalScore += points;
              logs.add('❄️ Lạnh đóng băng $frozenCount khối Nước! (+$points điểm)');
              hasChanged = true;
            }
          }
        }
      }

      if (hasChanged) {
        _applyGravityAndWater(currentBoard, rows, cols);
        continue;
      }
    }

    return ReactionResult(
      board: currentBoard,
      scoreEarned: totalScore,
      comboCount: comboCount,
      reactionLogs: logs,
    );
  }

  static bool applyPhysicsTick(List<List<ElementBlock?>> board, int rows, int cols) {
    return _applyGravityAndWater(board, rows, cols);
  }

  static bool _applyGravityAndWater(List<List<ElementBlock?>> board, int rows, int cols) {
    bool movedAny = false;

    for (int r = rows - 2; r >= 0; r--) {
      for (int c = 0; c < cols; c++) {
        final block = board[r][c];
        if (block != null && block.type != ElementType.water) {
          if (board[r + 1][c] == null) {
            board[r + 1][c] = block;
            board[r][c] = null;
            movedAny = true;
          }
        }
      }
    }

    for (int r = rows - 1; r >= 0; r--) {
      for (int c = 0; c < cols; c++) {
        final block = board[r][c];
        if (block?.type == ElementType.water) {
          if (r + 1 < rows && board[r + 1][c] == null) {
            board[r + 1][c] = block;
            board[r][c] = null;
            movedAny = true;
          } else {
            List<int> directions = [-1, 1]..shuffle(Random());
            for (int dir in directions) {
              int nc = c + dir;
              if (nc >= 0 && nc < cols && board[r][nc] == null) {
                board[r][nc] = block;
                board[r][c] = null;
                movedAny = true;
                break;
              }
            }
          }
        }
      }
    }

    return movedAny;
  }

  static bool _hasAnyAdjacentBlock(
    List<List<ElementBlock?>> board,
    int r,
    int c,
    int rows,
    int cols,
  ) {
    final dirs = [
      [-1, 0], [1, 0], [0, -1], [0, 1]
    ];
    for (var dir in dirs) {
      int nr = r + dir[0];
      int nc = c + dir[1];
      if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
        if (board[nr][nc] != null) return true;
      }
    }
    return false;
  }

  static MapEntry<int, int>? _findAdjacentType(
    List<List<ElementBlock?>> board,
    int r,
    int c,
    ElementType targetType,
    int rows,
    int cols,
  ) {
    final dirs = [
      [-1, 0], [1, 0], [0, -1], [0, 1]
    ];
    for (var dir in dirs) {
      int nr = r + dir[0];
      int nc = c + dir[1];
      if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
        if (board[nr][nc]?.type == targetType) {
          return MapEntry(nr, nc);
        }
      }
    }
    return null;
  }

  static List<MapEntry<int, int>> _findAllAdjacentTypes(
    List<List<ElementBlock?>> board,
    int r,
    int c,
    ElementType targetType,
    int rows,
    int cols,
  ) {
    List<MapEntry<int, int>> matches = [];
    final dirs = [
      [-1, 0], [1, 0], [0, -1], [0, 1]
    ];
    for (var dir in dirs) {
      int nr = r + dir[0];
      int nc = c + dir[1];
      if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
        if (board[nr][nc]?.type == targetType) {
          matches.add(MapEntry(nr, nc));
        }
      }
    }
    return matches;
  }

  static List<List<ElementBlock?>> _cloneBoard(
    List<List<ElementBlock?>> board,
    int rows,
    int cols,
  ) {
    return List.generate(
      rows,
      (r) => List.generate(cols, (c) => board[r][c]),
    );
  }
}
