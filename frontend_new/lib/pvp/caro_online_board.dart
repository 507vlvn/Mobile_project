import 'dart:typed_data';

import '../caro/logic/caro_board.dart';
import '../core/realtime/match_models.dart';

/// Bàn Caro dựng từ danh sách nước đi server gửi (server là nguồn chuẩn).
/// Người đi trước cầm X (mã [kCaroPlayer]), người còn lại cầm O ([kCaroAi]) —
/// đúng cách `CaroBoardView` vẽ quân.
class CaroOnlineBoard {
  final Uint8List cells;
  final int? lastMove;
  final List<int>? winLine;

  /// Mình cầm X?
  final bool iAmX;

  const CaroOnlineBoard._(this.cells, this.lastMove, this.winLine, this.iAmX);

  factory CaroOnlineBoard.from(MatchInfo m, int? firstMoverId) {
    final cells = Uint8List(kCaroCells);
    final first = firstMoverId ?? (m.caro?.moves.isNotEmpty ?? false ? m.caro!.moves.first.userId : m.you);
    int? last;
    for (final mv in m.caro?.moves ?? const <CaroMoveInfo>[]) {
      if (mv.row < 0 || mv.row >= kCaroSize || mv.col < 0 || mv.col >= kCaroSize) continue;
      final idx = caroIndex(mv.row, mv.col);
      cells[idx] = mv.userId == first ? kCaroPlayer : kCaroAi;
      last = idx;
    }
    final win = last == null ? null : caroWinningLine(cells, last);
    return CaroOnlineBoard._(cells, last, win, first == m.you);
  }

  int get moveCount => cells.where((c) => c != kCaroEmpty).length;
}
