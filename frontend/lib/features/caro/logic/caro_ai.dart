import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import '../../../core/models/difficulty.dart';
import 'caro_board.dart';

/// Yêu cầu tính nước đi cho máy (chỉ chứa kiểu đơn giản để gửi qua isolate).
class CaroAiRequest {
  final List<int> cells;
  final int aiPlayer;
  final Difficulty difficulty;
  final int seed;

  /// Ngân sách thời gian cho mức Khó (ms).
  final int budgetMs;

  const CaroAiRequest({
    required this.cells,
    required this.difficulty,
    this.aiPlayer = kCaroAi,
    this.seed = 0,
    this.budgetMs = 1200,
  });
}

/// Chạy AI trên isolate riêng để UI không bị giật.
Future<int> runCaroAiInIsolate(CaroAiRequest request) =>
    Isolate.run(() => chooseCaroMove(request));

// ---------------------------------------------------------------------------
// Đánh giá thế cờ theo từng đường
// ---------------------------------------------------------------------------

// Mức: 0 không, 1 hai kín, 2 hai mở, 3 ba kín, 4 ba mở, 5 bốn kín, 6 bốn mở, 7 năm
const List<int> _levelScore = [0, 50, 300, 500, 5000, 10000, 100000, 1000000];
const int _five = 7;
const int _openFour = 6;
const int _closedFour = 5;
const int _openThree = 4;

/// Cache theo khoá 9 ô (3^9) quanh ô đang xét: 0 trống, 1 quân mình, 2 chặn/tường.
final Int8List _levelCache = Int8List(19683)..fillRange(0, 19683, -1);

bool _hasFive(List<int> a) {
  for (var s = 0; s < 5; s++) {
    var ok = true;
    for (var i = 0; i < 5; i++) {
      if (a[s + i] != 1) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

/// Số ô trống khác nhau mà đặt quân vào sẽ tạo đủ 5 (trong các cửa sổ chứa ô giữa).
int _completions(List<int> a) {
  var mask = 0;
  for (var s = 0; s < 5; s++) {
    var ones = 0, empty = -1;
    var blocked = false;
    for (var i = 0; i < 5; i++) {
      final v = a[s + i];
      if (v == 2) {
        blocked = true;
        break;
      }
      if (v == 1) {
        ones++;
      } else {
        empty = s + i;
      }
    }
    if (!blocked && ones == 4 && empty >= 0) mask |= 1 << empty;
  }
  var n = 0;
  while (mask != 0) {
    n += mask & 1;
    mask >>= 1;
  }
  return n;
}

bool _window(List<int> a, int minOnes) {
  for (var s = 0; s < 5; s++) {
    var ones = 0;
    var blocked = false;
    for (var i = 0; i < 5; i++) {
      final v = a[s + i];
      if (v == 2) {
        blocked = true;
        break;
      }
      if (v == 1) ones++;
    }
    if (!blocked && ones >= minOnes) return true;
  }
  return false;
}

bool _existsAdd(List<int> a, bool Function(List<int>) test) {
  for (var e = 0; e < 9; e++) {
    if (a[e] != 0) continue;
    a[e] = 1;
    final ok = test(a);
    a[e] = 0;
    if (ok) return true;
  }
  return false;
}

bool _isOpenThree(List<int> a) =>
    !_hasFive(a) && _completions(a) < 2 && _existsAdd(a, (b) => _completions(b) >= 2);

int _classify(List<int> a) {
  if (_hasFive(a)) return _five;
  final c = _completions(a);
  if (c >= 2) return _openFour;
  if (c == 1) return _closedFour;
  if (_existsAdd(a, (b) => _completions(b) >= 2)) return _openThree;
  if (_window(a, 3)) return 3;
  if (_existsAdd(a, _isOpenThree)) return 2;
  if (_window(a, 2)) return 1;
  return 0;
}

int _levelForKey(int key) {
  final cached = _levelCache[key];
  if (cached >= 0) return cached;
  final a = List<int>.filled(9, 0);
  var k = key;
  for (var i = 8; i >= 0; i--) {
    a[i] = k % 3;
    k ~/= 3;
  }
  a[4] = 1;
  final lvl = _classify(a);
  _levelCache[key] = lvl;
  return lvl;
}

int _evScore = 0;
int _evMax = 0;

/// Giá trị nếu [p] đặt quân vào ô trống [idx]. Kết quả ở [_evScore], [_evMax].
void _evalCell(Uint8List cells, int idx, int p) {
  final r = idx ~/ kCaroSize, c = idx % kCaroSize;
  var score = 0, mx = 0, n4 = 0, n3 = 0;
  for (var d = 0; d < 4; d++) {
    var key = 0;
    for (var k = -4; k <= 4; k++) {
      int v;
      if (k == 0) {
        v = 1;
      } else {
        final rr = r + k * kCaroDr[d], cc = c + k * kCaroDc[d];
        if (rr < 0 || rr >= kCaroSize || cc < 0 || cc >= kCaroSize) {
          v = 2;
        } else {
          final cv = cells[rr * kCaroSize + cc];
          v = cv == 0 ? 0 : (cv == p ? 1 : 2);
        }
      }
      key = key * 3 + v;
    }
    final lvl = _levelForKey(key);
    score += _levelScore[lvl];
    if (lvl > mx) mx = lvl;
    if (lvl == _closedFour) n4++;
    if (lvl == _openThree) n3++;
  }
  if (n4 >= 2 || (n4 >= 1 && n3 >= 1)) {
    score += 50000;
    if (mx < _openFour) mx = _openFour;
  } else if (n3 >= 2) {
    score += 3000;
  }
  _evScore = score;
  _evMax = mx;
}

int _centerBonus(int idx) {
  final r = idx ~/ kCaroSize, c = idx % kCaroSize;
  return 14 - ((r - 7).abs() + (c - 7).abs());
}

/// Các ô trống cách quân bất kỳ không quá 2 ô.
List<int> _candidates(Uint8List cells) {
  final mark = Uint8List(kCaroCells);
  var any = false;
  for (var i = 0; i < kCaroCells; i++) {
    if (cells[i] == 0) continue;
    any = true;
    final r = i ~/ kCaroSize, c = i % kCaroSize;
    for (var rr = max(0, r - 2); rr <= min(kCaroSize - 1, r + 2); rr++) {
      for (var cc = max(0, c - 2); cc <= min(kCaroSize - 1, c + 2); cc++) {
        mark[rr * kCaroSize + cc] = 1;
      }
    }
  }
  if (!any) return [kCaroCells ~/ 2];
  return [
    for (var i = 0; i < kCaroCells; i++)
      if (cells[i] == 0 && mark[i] == 1) i,
  ];
}

// ---------------------------------------------------------------------------
// Chọn nước đi
// ---------------------------------------------------------------------------

/// Chọn nước đi cho máy. Thuần Dart, đồng bộ — trong app gọi qua [runCaroAiInIsolate].
int chooseCaroMove(CaroAiRequest req) {
  final cells = Uint8List.fromList(req.cells);
  final ai = req.aiPlayer, opp = 3 - ai;
  final cands = _candidates(cells);
  if (cands.length == 1) return cands.first;

  final rng = Random(req.seed);
  final n = cands.length;
  final scores = List<int>.filled(n, 0);
  var winAt = -1, blockAt = -1;
  for (var i = 0; i < n; i++) {
    final idx = cands[i];
    _evalCell(cells, idx, ai);
    final a = _evScore, am = _evMax;
    _evalCell(cells, idx, opp);
    final d = _evScore, dm = _evMax;
    scores[i] = a + (d * 9) ~/ 10 + _centerBonus(idx);
    if (am == _five) winAt = i;
    if (dm == _five && (blockAt < 0 || scores[i] > scores[blockAt])) blockAt = i;
  }

  final order = List<int>.generate(n, (i) => i)..sort((x, y) => scores[y].compareTo(scores[x]));

  final easy = req.difficulty == Difficulty.easy;
  // Mức Dễ có 25% bỏ sót thắng/chặn.
  final applyTactics = !easy || rng.nextDouble() >= 0.25;
  if (applyTactics) {
    if (winAt >= 0) return cands[winAt];
    if (blockAt >= 0) return cands[blockAt];
  }

  if (easy) {
    final top = min(5, n);
    return cands[order[rng.nextInt(top)]];
  }

  // Vừa: nước tốt nhất theo heuristic, hoà điểm thì chọn ngẫu nhiên.
  final bestScore = scores[order.first];
  final ties = [
    for (final i in order)
      if (scores[i] == bestScore) i,
  ];
  final heuristicBest = cands[ties[rng.nextInt(ties.length)]];
  if (req.difficulty == Difficulty.medium) return heuristicBest;

  // Khó: minimax + alpha-beta, đào sâu dần trong ngân sách thời gian.
  return _Search(cells, req.budgetMs).run(ai, heuristicBest);
}

// ---------------------------------------------------------------------------
// Minimax
// ---------------------------------------------------------------------------

const int _inf = 10000000;
const int _beam = 12;

final Int32List _windows = _buildWindows();

Int32List _buildWindows() {
  final out = <int>[];
  for (var r = 0; r < kCaroSize; r++) {
    for (var c = 0; c < kCaroSize; c++) {
      for (var d = 0; d < 4; d++) {
        final er = r + 4 * kCaroDr[d], ec = c + 4 * kCaroDc[d];
        if (er < 0 || er >= kCaroSize || ec < 0 || ec >= kCaroSize) continue;
        for (var k = 0; k < 5; k++) {
          out.add((r + k * kCaroDr[d]) * kCaroSize + c + k * kCaroDc[d]);
        }
      }
    }
  }
  return Int32List.fromList(out);
}

const List<int> _winWeight = [0, 2, 14, 120, 1200, 100000];

class _Gen {
  final int win; // ô thắng ngay, hoặc -1
  final bool lost; // đối thủ có từ 2 ô thắng trở lên
  final List<int> moves;
  const _Gen(this.win, this.lost, this.moves);
}

class _Search {
  _Search(this.cells, this.budgetMs) {
    for (var i = 0; i < kCaroCells; i++) {
      if (cells[i] != 0) _mark(i, 1);
    }
  }

  final Uint8List cells;
  final int budgetMs;
  final Int8List near = Int8List(kCaroCells);
  final Stopwatch sw = Stopwatch()..start();
  bool aborted = false;
  int nodes = 0;

  void _mark(int idx, int delta) {
    final r = idx ~/ kCaroSize, c = idx % kCaroSize;
    for (var rr = max(0, r - 2); rr <= min(kCaroSize - 1, r + 2); rr++) {
      for (var cc = max(0, c - 2); cc <= min(kCaroSize - 1, c + 2); cc++) {
        near[rr * kCaroSize + cc] += delta;
      }
    }
  }

  void _make(int idx, int p) {
    cells[idx] = p;
    _mark(idx, 1);
  }

  void _unmake(int idx) {
    cells[idx] = 0;
    _mark(idx, -1);
  }

  _Gen _gen(int side) {
    final opp = 3 - side;
    final packed = <int>[];
    final blocks = <int>[];
    for (var i = 0; i < kCaroCells; i++) {
      if (cells[i] != 0 || near[i] <= 0) continue;
      _evalCell(cells, i, side);
      final a = _evScore, am = _evMax;
      if (am == _five) return _Gen(i, false, const []);
      _evalCell(cells, i, opp);
      final d = _evScore, dm = _evMax;
      if (dm == _five) blocks.add(i);
      packed.add(((a + (d * 9) ~/ 10 + _centerBonus(i)) << 8) | i);
    }
    if (blocks.length >= 2) return const _Gen(-1, true, []);
    if (blocks.length == 1) return _Gen(-1, false, blocks);
    packed.sort((x, y) => y.compareTo(x));
    final take = min(_beam, packed.length);
    return _Gen(-1, false, [for (var i = 0; i < take; i++) packed[i] & 255]);
  }

  int _evalBoard(int side) {
    final opp = 3 - side;
    var total = 0;
    final w = _windows;
    for (var i = 0; i < w.length; i += 5) {
      var a = 0, b = 0;
      for (var k = 0; k < 5; k++) {
        final v = cells[w[i + k]];
        if (v == side) {
          a++;
        } else if (v == opp) {
          b++;
        }
      }
      if (a > 0 && b == 0) {
        total += _winWeight[a];
      } else if (b > 0 && a == 0) {
        total -= _winWeight[b];
      }
    }
    return total;
  }

  int _nega(int depth, int alpha, int beta, int side, int ply) {
    if (depth == 0) return _evalBoard(side);
    if ((++nodes & 63) == 0 && sw.elapsedMilliseconds > budgetMs) aborted = true;
    if (aborted) return 0;
    final g = _gen(side);
    if (g.win >= 0) return _inf - ply;
    if (g.lost) return -(_inf - ply - 1);
    if (g.moves.isEmpty) return 0;
    var best = -_inf * 2;
    for (final m in g.moves) {
      _make(m, side);
      final v = -_nega(depth - 1, -beta, -alpha, 3 - side, ply + 1);
      _unmake(m);
      if (aborted) return 0;
      if (v > best) best = v;
      if (v > alpha) alpha = v;
      if (alpha >= beta) break;
    }
    return best;
  }

  int run(int ai, int fallback) {
    final g = _gen(ai);
    if (g.win >= 0) return g.win;
    if (g.moves.isEmpty) return fallback;
    if (g.moves.length == 1) return g.moves.first;
    var result = g.moves.contains(fallback) ? fallback : g.moves.first;
    var rootMoves = List<int>.from(g.moves);
    for (var depth = 2; depth <= 4; depth++) {
      var alpha = -_inf * 2;
      var best = -1, bestVal = -_inf * 2;
      for (final m in rootMoves) {
        _make(m, ai);
        final v = -_nega(depth - 1, -_inf * 2, -alpha, 3 - ai, 1);
        _unmake(m);
        if (aborted) break;
        if (v > bestVal) {
          bestVal = v;
          best = m;
        }
        if (v > alpha) alpha = v;
      }
      if (aborted || best < 0) break;
      result = best;
      rootMoves = [best, ...rootMoves.where((m) => m != best)];
      if (bestVal >= _inf - 100 || bestVal <= -_inf + 100) break;
    }
    return result;
  }
}
