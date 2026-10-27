import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/realtime/match_models.dart';
import '../core/theme/app_tokens.dart';
import '../soduku/logic/sudoku_generator.dart';
import '../soduku/logic/sudoku_models.dart';
import 'match_session.dart';
import 'pvp_common.dart';
import 'pvp_widgets.dart';

/// Ô cờ Sudoku trong chế độ Đồng Đội Co-op.
class _CoopCell {
  final int row;
  final int col;
  final int initialValue; // > 0 nếu là ô cho sẵn
  final int solution;
  int currentValue;
  int? filledByUserId;
  final Set<int> notes = {};

  _CoopCell({
    required this.row,
    required this.col,
    required this.initialValue,
    required this.solution,
    required this.currentValue,
    this.filledByUserId,
  });

  bool get isClue => initialValue > 0;
  bool get isFilled => currentValue > 0;
}

/// Màn hình chơi Sudoku đồng đội giữa 2 bạn bè theo thời gian thực.
class SudokuCoopScreen extends StatefulWidget {
  final MatchSession session;

  const SudokuCoopScreen({super.key, required this.session});

  @override
  State<SudokuCoopScreen> createState() => _SudokuCoopScreenState();
}

class _SudokuCoopScreenState extends State<SudokuCoopScreen> with TickerProviderStateMixin {
  late final List<List<_CoopCell>> _board;
  int? _selectedRow;
  int? _selectedCol;
  int? _oppRow;
  int? _oppCol;

  int _sharedMistakes = 0;
  static const int _maxMistakes = 3;
  bool _isNotesMode = false;

  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _clockTimer;
  Duration _elapsed = Duration.zero;

  // Chat gần nhất của đối thủ: (nội dung, thời điểm)
  (String, DateTime)? _oppChat;

  // Trạng thái hiển thị số lỗi tạm thời trên ô khi bấm sai
  int? _tempErrorRow;
  int? _tempErrorCol;
  int? _tempErrorValue;
  Timer? _tempErrorTimer;
  bool _endedDialogShown = false;

  // Hiệu ứng rung khi mắc lỗi
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _initShakeAnimation();
    _initBoard();
    _startClock();
    _wireRealtimeEvents();
  }

  void _initShakeAnimation() {
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  void _initBoard() {
    final m = widget.session.match;
    final diff = switch (m?.difficulty ?? 2) {
      1 => SudokuDifficulty.easy,
      2 => SudokuDifficulty.medium,
      3 => SudokuDifficulty.hard,
      4 => SudokuDifficulty.expert,
      _ => SudokuDifficulty.medium,
    };
    final seed = m?.seed ?? 42;
    final puzzleData = SudokuGenerator.generate(difficulty: diff, seed: seed);

    _board = List.generate(9, (r) {
      return List.generate(9, (c) {
        final clue = puzzleData.puzzle[r][c];
        final sol = puzzleData.solution[r][c];
        return _CoopCell(
          row: r,
          col: c,
          initialValue: clue,
          solution: sol,
          currentValue: clue,
          filledByUserId: null,
        );
      });
    });

    // Tự động chọn ô trống đầu tiên
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (!_board[r][c].isClue) {
          _selectedRow = r;
          _selectedCol = c;
          return;
        }
      }
    }
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final start = widget.session.match?.startedAt;
      if (start != null) {
        setState(() => _elapsed = DateTime.now().difference(start));
      } else {
        setState(() => _elapsed += const Duration(seconds: 1));
      }
    });
  }

  void _wireRealtimeEvents() {
    final rt = widget.session.realtime;
    final myId = widget.session.match?.you ?? 0;

    _subs.addAll([
      rt.sudokuMoves.listen((e) {
        if (!mounted || e.matchId != widget.session.match?.matchId) return;
        setState(() {
          _sharedMistakes = e.mistakes;
          if (e.isMistake) {
            // Chỉ rung chuông báo lỗi nếu lỗi do bạn bè làm (nếu là mình làm thì đã rung lúc bấm)
            if (e.byUserId != myId) {
              _triggerMistakeFeedback();
            }
          } else if (e.row >= 0 && e.row < 9 && e.col >= 0 && e.col < 9) {
            final cell = _board[e.row][e.col];
            cell.currentValue = e.value;
            cell.filledByUserId = e.byUserId;
            cell.notes.clear();
          }
        });
        _checkBoardCompletion();
      }),

      rt.sudokuCursors.listen((e) {
        if (!mounted || e.matchId != widget.session.match?.matchId) return;
        if (e.userId != myId) {
          setState(() {
            _oppRow = e.row;
            _oppCol = e.col;
          });
        }
      }),

      rt.quickChats.listen((e) {
        if (!mounted || e.matchId != widget.session.match?.matchId) return;
        if (e.fromUserId != myId && e.code != null) {
          setState(() => _oppChat = (e.code!, DateTime.now()));
        }
      }),

      widget.session.notices.listen((msg) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }),

      rt.matchEnded.listen((e) {
        if (!mounted || e.matchId != widget.session.match?.matchId) return;
        _showMatchEndedDialog(e);
      }),
    ]);
  }

  void _triggerMistakeFeedback() {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0);
  }

  void _selectCell(int r, int c) {
    if (_selectedRow == r && _selectedCol == c) return;
    setState(() {
      _selectedRow = r;
      _selectedCol = c;
    });
    widget.session.sendSudokuCursor(row: r, col: c);
  }

  void _selectNextEmptyCell(int fromRow, int fromCol) {
    for (int i = 1; i <= 81; i++) {
      final idx = (fromRow * 9 + fromCol + i) % 81;
      final r = idx ~/ 9;
      final c = idx % 9;
      if (!_board[r][c].isClue && !_board[r][c].isFilled) {
        _selectCell(r, c);
        return;
      }
    }
  }

  void _onNumberTap(int number) {
    if (_selectedRow == null || _selectedCol == null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chạm chọn ô trên bàn cờ trước'),
          duration: Duration(milliseconds: 1000),
        ),
      );
      return;
    }
    final cell = _board[_selectedRow!][_selectedCol!];
    if (cell.isClue) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ô này là số đề bài cho sẵn, không thể sửa'),
          duration: Duration(milliseconds: 1000),
        ),
      );
      return;
    }
    if (cell.isFilled && cell.currentValue == cell.solution) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ô này đã được giải đúng rồi'),
          duration: Duration(milliseconds: 1000),
        ),
      );
      return;
    }

    if (_isNotesMode) {
      setState(() {
        if (cell.notes.contains(number)) {
          cell.notes.remove(number);
        } else {
          cell.notes.add(number);
        }
      });
      return;
    }

    final myId = widget.session.match?.you ?? 0;
    final isCorrect = number == cell.solution;
    final curRow = _selectedRow!;
    final curCol = _selectedCol!;

    if (isCorrect) {
      HapticFeedback.lightImpact();
      setState(() {
        cell.currentValue = number;
        cell.filledByUserId = myId;
        cell.notes.clear();
      });
      widget.session.sendSudokuMove(
        row: curRow,
        col: curCol,
        value: number,
        isMistake: false,
      );
      _checkBoardCompletion();
      _selectNextEmptyCell(curRow, curCol);
    } else {
      _triggerMistakeFeedback();
      _tempErrorTimer?.cancel();
      setState(() {
        _tempErrorRow = curRow;
        _tempErrorCol = curCol;
        _tempErrorValue = number;
        _sharedMistakes++;
      });
      _tempErrorTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) {
          setState(() {
            _tempErrorRow = null;
            _tempErrorCol = null;
            _tempErrorValue = null;
          });
        }
      });
      widget.session.sendSudokuMove(
        row: curRow,
        col: curCol,
        value: number,
        isMistake: true,
      );
    }
  }

  void _onEraseTap() {
    if (_selectedRow == null || _selectedCol == null) return;
    final cell = _board[_selectedRow!][_selectedCol!];
    if (cell.isClue || cell.isFilled) return;

    if (cell.notes.isNotEmpty) {
      setState(() => cell.notes.clear());
    }
  }

  void _checkBoardCompletion() {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_board[r][c].currentValue != _board[r][c].solution) {
          return;
        }
      }
    }
    // Toàn bộ 81 ô đã được điền chính xác!
    widget.session.finishSudoku(timeSeconds: _elapsed.inSeconds);
  }

  void _showMatchEndedDialog(MatchEndedEvent event) {
    if (_endedDialogShown) return;
    _endedDialogShown = true;

    final myId = widget.session.match?.you ?? 0;
    final opp = widget.session.match?.opponent;
    final isWin = event.reason == 'COOP_WIN';

    final (icon, title, desc) = switch (event.reason) {
      'COOP_WIN' => (
        '🎉',
        'Chiến Thắng Đồng Đội!',
        'Tuyệt vời! Hai bạn đã phối hợp rất ăn ý để hoàn thành toàn bộ bảng Sudoku.'
      ),
      'MISTAKES_LIMIT' => (
        '💔',
        'Hết Lượt Thử (3/3 Lỗi)',
        'Rất tiếc! Cả hai đã phạm quá 3 lỗi. Hãy cùng rút kinh nghiệm và thử lại nhé!'
      ),
      'RESIGN' => (
        '🚪',
        'Ván đấu kết thúc',
        '${event.winnerId == myId ? (opp?.displayName ?? "Bạn bè") : "Bạn"} đã rời phòng đấu.'
      ),
      'ABANDON' => (
        '📡',
        'Mất kết nối',
        '${opp?.displayName ?? "Bạn bè"} đã mất kết nối quá thời gian chờ.'
      ),
      'TIME_LIMIT' => (
        '⏱️',
        'Hết thời gian',
        'Đã hết thời gian 30 phút cho trận Sudoku đồng đội.'
      ),
      _ => ('🏁', 'Kết thúc ván', matchEndReasonVi(event, myId)),
    };

    int myCount = 0;
    int oppCount = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_board[r][c].filledByUserId == myId) {
          myCount++;
        } else if (_board[r][c].filledByUserId != null) {
          oppCount++;
        }
      }
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final scheme = theme.colorScheme;
        final text = theme.textTheme;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                desc,
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Thời gian:'),
                        Text(formatMmSs(_elapsed), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Lỗi mắc phải:'),
                        Text('$_sharedMistakes / $_maxMistakes', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Bạn đã giải:'),
                        Text('$myCount ô', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${opp?.displayName ?? "Bạn bè"} đã giải:'),
                        Text('$oppCount ô', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.session.leaveResult();
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text('Về sảnh'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tái đấu'),
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.session.rematch();
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rời ván chơi?'),
        content: const Text('Rời phòng sẽ kết thúc ván Sudoku đồng đội đối với cả hai người bạn.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Tiếp tục chơi')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rời phòng'),
          ),
        ],
      ),
    );
    if (leave == true) {
      await widget.session.resign();
      widget.session.leaveResult();
      if (mounted) Navigator.of(context).pop();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _tempErrorTimer?.cancel();
    _shakeController.dispose();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.session.match;
    final isMatchActive = m != null && m.active && widget.session.phase == PvpPhase.active;
    final myId = m?.you ?? 0;
    final opp = m?.opponent;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Đếm số ô mỗi người đã điền
    int myCount = 0;
    int oppCount = 0;
    int filledTotal = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_board[r][c].isFilled) {
          filledTotal++;
          if (_board[r][c].filledByUserId == myId) {
            myCount++;
          } else if (_board[r][c].filledByUserId != null) {
            oppCount++;
          }
        }
      }
    }

    return PopScope(
      canPop: !isMatchActive,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          if (widget.session.phase == PvpPhase.ended) {
            widget.session.leaveResult();
          }
          return;
        }
        await _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          title: Column(
            children: [
              const Text('Sudoku Đồng Đội', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                'Độ khó: ${sudokuDifficultyLabel(m?.difficulty ?? 2)} · Cùng nhau giải',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Rời phòng',
            onPressed: () async {
              if (!isMatchActive) {
                widget.session.leaveResult();
                Navigator.of(context).pop();
                return;
              }
              await _confirmLeave();
            },
          ),
          actions: [
            QuickChatButton(session: widget.session),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              ConnectionBanner(session: widget.session),
              OpponentStatusBanner(session: widget.session),

              // Dải thông tin trận (Thời gian, Số lỗi dùng chung)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: AppSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Timer
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 20, color: scheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          formatMmSs(_elapsed),
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),

                    // Tiến độ
                    Text(
                      'Tiến độ: $filledTotal/81',
                      style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),

                    // Lỗi chung (Mistakes)
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: child,
                        );
                      },
                      child: Row(
                        children: [
                          Text('Lỗi: ', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                          for (int i = 0; i < _maxMistakes; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: Icon(
                                i < _sharedMistakes ? Icons.close_rounded : Icons.favorite_rounded,
                                size: 18,
                                color: i < _sharedMistakes ? scheme.error : const Color(0xFFEF4444),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bảng thông tin đóng góp của 2 người chơi
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: 4),
                child: Row(
                  children: [
                    // Người chơi 1: Bạn
                    Expanded(
                      child: _buildPlayerCard(
                        name: 'Bạn',
                        count: myCount,
                        accentColor: const Color(0xFF2563EB),
                        isMe: true,
                        chat: null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Người chơi 2: Bạn bè
                    Expanded(
                      child: _buildPlayerCard(
                        name: opp?.displayName ?? 'Bạn bè',
                        count: oppCount,
                        accentColor: const Color(0xFF10B981),
                        isMe: false,
                        chat: _oppChat,
                        cursorInfo: (_oppRow != null && _oppCol != null)
                            ? 'Ô [${String.fromCharCode(65 + _oppCol!)}${_oppRow! + 1}]'
                            : null,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // Bàn cờ Sudoku 9x9
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: _buildSudokuGrid(),
                    ),
                  ),
                ),
              ),

              // Thanh công cụ (Ghi chú, Xóa)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Bật/tắt chế độ ghi chú (Notes / Pencil)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _isNotesMode ? scheme.primaryContainer : null,
                        side: BorderSide(
                          color: _isNotesMode ? scheme.primary : scheme.outlineVariant,
                          width: _isNotesMode ? 2 : 1,
                        ),
                      ),
                      onPressed: () => setState(() => _isNotesMode = !_isNotesMode),
                      icon: Icon(
                        _isNotesMode ? Icons.edit_rounded : Icons.edit_outlined,
                        color: _isNotesMode ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      label: Text(
                        'Ghi chú ${_isNotesMode ? "BẬT" : "TẮT"}',
                        style: TextStyle(
                          color: _isNotesMode ? scheme.primary : scheme.onSurfaceVariant,
                          fontWeight: _isNotesMode ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),

                    // Nút Xóa
                    OutlinedButton.icon(
                      onPressed: _onEraseTap,
                      icon: const Icon(Icons.backspace_outlined, size: 20),
                      label: const Text('Xóa ghi chú'),
                    ),
                  ],
                ),
              ),

              // Bàn phím số 1..9
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 4, AppSpacing.screen, AppSpacing.md),
                child: _buildKeypad(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCard({
    required String name,
    required int count,
    required Color accentColor,
    required bool isMe,
    (String, DateTime)? chat,
    String? cursorInfo,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final recentChat = chat != null && DateTime.now().difference(chat.$2) < const Duration(seconds: 4);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '$count ô',
                style: text.labelMedium?.copyWith(color: accentColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 2),
          if (recentChat)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4),
                ],
              ),
              child: Text(quickChatLabel(chat.$1), style: text.labelSmall),
            )
          else if (cursorInfo != null)
            Text(
              'Đang xem: $cursorInfo',
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  Widget _buildSudokuGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFF0F172A), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md - 2),
        child: Column(
          children: [
            for (int r = 0; r < 9; r++)
              Expanded(
                child: Row(
                  children: [
                    for (int c = 0; c < 9; c++)
                      Expanded(
                        child: _buildGridCell(r, c),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _countPlaced(int num) {
    int count = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_board[r][c].currentValue == num) count++;
      }
    }
    return count;
  }

  Widget _buildGridCell(int r, int c) {
    final cell = _board[r][c];
    final isSelected = _selectedRow == r && _selectedCol == c;
    final isOppSelected = _oppRow == r && _oppCol == c;
    final isTempError = _tempErrorRow == r && _tempErrorCol == c;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Phân tích quan hệ hàng/cột/khối để tô bóng nhẹ
    final isInSameRowOrCol = (_selectedRow == r || _selectedCol == c);
    final isInSameBox = _selectedRow != null &&
        _selectedCol != null &&
        (r ~/ 3 == _selectedRow! ~/ 3 && c ~/ 3 == _selectedCol! ~/ 3);

    // Kiểm tra số trùng với số đang được chọn
    final selectedVal = (_selectedRow != null && _selectedCol != null)
        ? _board[_selectedRow!][_selectedCol!].currentValue
        : 0;
    final isSameNumber = selectedVal > 0 && cell.currentValue == selectedVal;

    // Màu nền ô
    Color bgColor;
    if (isTempError) {
      bgColor = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.75) : const Color(0xFFFFE4E6);
    } else if (isSelected) {
      bgColor = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
    } else if (isSameNumber) {
      bgColor = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.8) : const Color(0xFFEFF6FF);
    } else if (isInSameRowOrCol || isInSameBox) {
      bgColor = isDark ? const Color(0xFF0F172A).withValues(alpha: 0.4) : const Color(0xFFF8FAFC);
    } else {
      bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    }

    // Viền phân tách 3x3
    final borderRight = (c % 3 == 2 && c < 8)
        ? BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFF334155), width: 1.8)
        : BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 0.6);

    final borderBottom = (r % 3 == 2 && r < 8)
        ? BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFF334155), width: 1.8)
        : BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 0.6);

    // Xác định ai điền ô này
    final myId = widget.session.match?.you ?? 0;
    final filledByMe = cell.filledByUserId == myId;
    final filledByOpp = cell.filledByUserId != null && !filledByMe;

    Color numberColor;
    if (isTempError) {
      numberColor = const Color(0xFFDC2626);
    } else if (cell.isClue) {
      numberColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    } else if (filledByMe) {
      numberColor = const Color(0xFF2563EB); // Xanh dương
    } else if (filledByOpp) {
      numberColor = const Color(0xFF10B981); // Xanh lá
    } else {
      numberColor = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectCell(r, c),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(right: borderRight, bottom: borderBottom),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Hiển thị số hoặc ghi chú hoặc số lỗi tạm thời
            if (isTempError && _tempErrorValue != null)
              Text(
                '$_tempErrorValue',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: numberColor,
                ),
              )
            else if (cell.currentValue > 0)
              Text(
                '${cell.currentValue}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: cell.isClue ? FontWeight.w900 : FontWeight.bold,
                  color: numberColor,
                ),
              )
            else if (cell.notes.isNotEmpty)
              _buildNotesGrid(cell.notes),

            // Viền con trỏ của bạn bè (Opponent focus)
            if (isOppSelected && !isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF10B981), width: 2),
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),

            // Viền con trỏ của chính mình
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF2563EB), width: 2.2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesGrid(Set<int> notes) {
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: Column(
        children: [
          for (int row = 0; row < 3; row++)
            Expanded(
              child: Row(
                children: [
                  for (int col = 0; col < 3; col++)
                    Expanded(
                      child: Center(
                        child: Text(
                          notes.contains(row * 3 + col + 1) ? '${row * 3 + col + 1}' : '',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        for (int i = 1; i <= 9; i++) ...[
          if (i > 1) const SizedBox(width: 4),
          Expanded(
            child: Material(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => _onNumberTap(i),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$i',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          height: 1.1,
                        ),
                      ),
                      Text(
                        '${_countPlaced(i)}/9',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _countPlaced(i) >= 9
                              ? const Color(0xFF10B981)
                              : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
