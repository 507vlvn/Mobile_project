import 'package:flutter/material.dart';

import '../models/jigsaw_picture.dart';

/// Hiện đúng phần (hàng [row], cột [col]) của [picture] khi chia thành lưới
/// [gridSize] × [gridSize]. Ô vuông bao nhiêu thì hình gốc được phóng tương ứng.
class JigsawPieceImage extends StatelessWidget {
  final JigsawPicture picture;
  final int row;
  final int col;
  final int gridSize;

  const JigsawPieceImage({
    super.key,
    required this.picture,
    required this.row,
    required this.col,
    required this.gridSize,
  });

  @override
  Widget build(BuildContext context) {
    final n = gridSize;
    double pos(int i) => n == 1 ? 0 : -1 + 2 * i / (n - 1);
    // OverflowBox cho hình lớn gấp n lần ô (Align/SizedBox sẽ bị ép về cỡ ô),
    // căn để đúng phần (row, col) nằm trong ô, ClipRect cắt phần thừa.
    return LayoutBuilder(
      builder: (context, c) => ClipRect(
        child: OverflowBox(
          alignment: Alignment(pos(col), pos(row)),
          minWidth: c.maxWidth * n,
          maxWidth: c.maxWidth * n,
          minHeight: c.maxHeight * n,
          maxHeight: c.maxHeight * n,
          child: picture.build(),
        ),
      ),
    );
  }
}
