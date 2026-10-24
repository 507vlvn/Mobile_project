import 'dart:typed_data';

/// Kích thước bàn cờ (15×15) và mã quân.
const int kCaroSize = 15;
const int kCaroCells = kCaroSize * kCaroSize;
const int kCaroEmpty = 0;

/// Quân X — người chơi.
const int kCaroPlayer = 1;

/// Quân O — máy.
const int kCaroAi = 2;

/// Số quân liên tiếp để thắng (luật tự do: từ 5 quân trở lên đều thắng).
const int kCaroWinLength = 5;

/// 4 hướng: ngang, dọc, chéo xuống, chéo lên.
const List<int> kCaroDr = [0, 1, 1, 1];
const List<int> kCaroDc = [1, 0, 1, -1];

int caroIndex(int row, int col) => row * kCaroSize + col;

/// Độ dài dãy quân cùng loại đi qua ô [idx] theo hướng [dir] (tính cả ô đó).
int caroRunLength(Uint8List cells, int idx, int dir) {
  final p = cells[idx];
  if (p == kCaroEmpty) return 0;
  final r = idx ~/ kCaroSize, c = idx % kCaroSize;
  var n = 1;
  for (final s in const [1, -1]) {
    var rr = r + s * kCaroDr[dir], cc = c + s * kCaroDc[dir];
    while (rr >= 0 && rr < kCaroSize && cc >= 0 && cc < kCaroSize && cells[rr * kCaroSize + cc] == p) {
      n++;
      rr += s * kCaroDr[dir];
      cc += s * kCaroDc[dir];
    }
  }
  return n;
}

/// Quân vừa đặt ở [idx] có tạo thành dãy ≥ 5 không?
bool caroMakesWin(Uint8List cells, int idx) {
  for (var d = 0; d < 4; d++) {
    if (caroRunLength(cells, idx, d) >= kCaroWinLength) return true;
  }
  return false;
}

/// Các ô của dãy thắng đi qua [idx] (theo thứ tự từ đầu đến cuối), hoặc null.
List<int>? caroWinningLine(Uint8List cells, int idx) {
  final p = cells[idx];
  if (p == kCaroEmpty) return null;
  final r = idx ~/ kCaroSize, c = idx % kCaroSize;
  for (var d = 0; d < 4; d++) {
    if (caroRunLength(cells, idx, d) < kCaroWinLength) continue;
    var sr = r, sc = c;
    while (true) {
      final pr = sr - kCaroDr[d], pc = sc - kCaroDc[d];
      if (pr < 0 || pr >= kCaroSize || pc < 0 || pc >= kCaroSize) break;
      if (cells[pr * kCaroSize + pc] != p) break;
      sr = pr;
      sc = pc;
    }
    final line = <int>[];
    while (sr >= 0 && sr < kCaroSize && sc >= 0 && sc < kCaroSize && cells[sr * kCaroSize + sc] == p) {
      line.add(sr * kCaroSize + sc);
      sr += kCaroDr[d];
      sc += kCaroDc[d];
    }
    return line;
  }
  return null;
}

bool caroIsFull(Uint8List cells) {
  for (final v in cells) {
    if (v == kCaroEmpty) return false;
  }
  return true;
}
