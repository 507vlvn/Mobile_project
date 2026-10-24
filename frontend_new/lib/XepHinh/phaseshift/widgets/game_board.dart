import 'package:flutter/material.dart';
import '../models/material.dart';
import '../engine/physics_engine.dart';

class PhaseShiftGameBoard extends StatelessWidget {
  final List<List<ElementBlock?>> board;
  final ElementBlock? activeBlock;
  final Position? activePosition;
  final int rows;
  final int cols;

  const PhaseShiftGameBoard({
    super.key,
    required this.board,
    required this.activeBlock,
    required this.activePosition,
    required this.rows,
    required this.cols,
  });

  @override
  Widget build(BuildContext context) {
    Position? hardDropPos;
    if (activeBlock != null && activePosition != null) {
      hardDropPos = PhysicsEngine.calculateHardDropPosition(
        board: board,
        currentPos: activePosition!,
        rows: rows,
        cols: cols,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E222A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.shade700, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: AspectRatio(
          aspectRatio: cols / rows,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
            ),
            itemCount: rows * cols,
            itemBuilder: (context, index) {
              final r = index ~/ cols;
              final c = index % cols;

              final placedBlock = board[r][c];
              final isActive = activePosition?.row == r && activePosition?.col == c;
              final isHardDropShadow = hardDropPos?.row == r && hardDropPos?.col == c && !isActive;

              if (placedBlock != null) {
                return _buildCell(placedBlock);
              } else if (isActive && activeBlock != null) {
                return _buildCell(activeBlock!, isActive: true);
              } else if (isHardDropShadow && activeBlock != null) {
                return _buildGhostCell(activeBlock!);
              } else {
                return Container(
                  margin: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: (r + c) % 2 == 0
                        ? Colors.white.withAlpha(8)
                        : Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCell(ElementBlock block, {bool isActive = false}) {
    return Container(
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: block.color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? Colors.white : Colors.white24,
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: block.color.withAlpha(153),
            blurRadius: isActive ? 8 : 2,
          )
        ],
      ),
      child: Center(
        child: Icon(
          block.icon,
          size: 18,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildGhostCell(ElementBlock block) {
    return Container(
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: block.color.withAlpha(51),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: block.color.withAlpha(128),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(
          block.icon,
          size: 16,
          color: block.color.withAlpha(128),
        ),
      ),
    );
  }
}
