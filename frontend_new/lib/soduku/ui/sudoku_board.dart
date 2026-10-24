import 'package:flutter/material.dart';
import '../logic/sudoku_controller.dart';
import '../logic/sudoku_models.dart';

class SudokuBoard extends StatelessWidget {
  final SudokuController controller;

  const SudokuBoard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Kích thước vuông dựa trên chiều rộng khả dụng
        final boardSize = constraints.maxWidth;
        final cellSize = boardSize / 9;

        return Container(
          width: boardSize,
          height: boardSize,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFF1E293B), width: 2.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9.5),
            child: Stack(
              children: [
                // 81 Ô Sudoku
                for (int r = 0; r < 9; r++)
                  for (int c = 0; c < 9; c++)
                    Positioned(
                      left: c * cellSize,
                      top: r * cellSize,
                      width: cellSize,
                      height: cellSize,
                      child: _buildCell(context, r, c, cellSize),
                    ),

                // Đường kẻ dày phân tách các khối 3x3
                for (int i = 1; i <= 2; i++) ...[
                  // Kẻ dọc
                  Positioned(
                    left: i * 3 * cellSize - 1,
                    top: 0,
                    bottom: 0,
                    width: 2.5,
                    child: Container(color: const Color(0xFF1E293B)),
                  ),
                  // Kẻ ngang
                  Positioned(
                    top: i * 3 * cellSize - 1,
                    left: 0,
                    right: 0,
                    height: 2.5,
                    child: Container(color: const Color(0xFF1E293B)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell(BuildContext context, int row, int col, double cellSize) {
    final cell = controller.board[row][col];
    final isSelected = controller.selectedRow == row && controller.selectedCol == col;
    final selectedCell = controller.selectedCell;

    final isInSameRow = controller.selectedRow == row;
    final isInSameCol = controller.selectedCol == col;
    final isInSameBox = controller.selectedRow != null &&
        controller.selectedCol != null &&
        (controller.selectedRow! ~/ 3 == row ~/ 3) &&
        (controller.selectedCol! ~/ 3 == col ~/ 3);

    final isRelated = isInSameRow || isInSameCol || isInSameBox;

    final hasSameValue = selectedCell != null &&
        selectedCell.value != 0 &&
        cell.value == selectedCell.value;

    // Màu nền ô
    Color cellBgColor = Colors.transparent;
    if (cell.isError) {
      cellBgColor = const Color(0xFFFFE4E6); // Đỏ nhạt khi sai
    } else if (isSelected) {
      cellBgColor = const Color(0xFFC7D2FE); // Xanh đậm ô được chọn
    } else if (hasSameValue) {
      cellBgColor = const Color(0xFFDDD6FE); // Tím nhạt các số trùng nhau
    } else if (isRelated) {
      cellBgColor = const Color(0xFFF1F5F9); // Xám xanh nhạt hàng/cột/khối
    }

    return GestureDetector(
      onTap: () => controller.selectCell(row, col),
      child: Container(
        decoration: BoxDecoration(
          color: cellBgColor,
          border: Border(
            right: BorderSide(
              color: (col % 3 == 2) ? Colors.transparent : const Color(0xFFCBD5E1),
              width: 0.8,
            ),
            bottom: BorderSide(
              color: (row % 3 == 2) ? Colors.transparent : const Color(0xFFCBD5E1),
              width: 0.8,
            ),
          ),
        ),
        child: Center(
          child: cell.value != 0
              ? _buildCellValue(cell, cellSize)
              : _buildCellNotes(cell),
        ),
      ),
    );
  }

  Widget _buildCellValue(SudokuCell cell, double cellSize) {
    Color textColor;
    FontWeight fontWeight;

    if (cell.isError) {
      textColor = const Color(0xFFDC2626); // Đỏ
      fontWeight = FontWeight.w700;
    } else if (cell.isGiven) {
      textColor = const Color(0xFF0F172A); // Đen đậm (số đề bài)
      fontWeight = FontWeight.w800;
    } else {
      textColor = const Color(0xFF2563EB); // Xanh dương (số người chơi điền)
      fontWeight = FontWeight.w600;
    }

    return Text(
      '${cell.value}',
      style: TextStyle(
        fontSize: cellSize * 0.58,
        fontWeight: fontWeight,
        color: textColor,
      ),
    );
  }

  Widget _buildCellNotes(SudokuCell cell) {
    if (cell.notes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (int r = 0; r < 3; r++)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int c = 0; c < 3; c++)
                  Builder(builder: (_) {
                    final num = r * 3 + c + 1;
                    final hasNote = cell.notes.contains(num);
                    return SizedBox(
                      width: 10,
                      height: 10,
                      child: Center(
                        child: Text(
                          hasNote ? '$num' : '',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                            height: 1.0,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
        ],
      ),
    );
  }
}
