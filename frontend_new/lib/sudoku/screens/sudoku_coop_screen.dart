import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/realtime/match_models.dart';
import '../../core/theme/app_tokens.dart';
import '../logic/sudoku_generator.dart';
import '../models/sudoku_models.dart';
import '../../pvp/match_session.dart';
import '../../pvp/pvp_common.dart';
import '../../pvp/pvp_widgets.dart';

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

  int? _currentTurnUserId;
  int get _myId => widget.session.match?.you ?? 0;
  int get _oppId => widget.session.match?.opponent?.userId ?? 0;
  bool get _isMyTurn => _currentTurnUserId == null || _currentTurnUserId == _myId;

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

    // Khôi phục nước đi đã chơi nếu người chơi vào lại ván đấu (reconnect)
    final coop = widget.session.match?.coop;
    if (coop != null) {
      _sharedMistakes = coop.mistakes;
      for (final mv in coop.moves) {
        if (!mv.isMistake && mv.row >= 0 && mv.row < 9 && mv.col >= 0 && mv.col < 9) {
          final cell = _board[mv.row][mv.col];
          cell.currentValue = mv.value;
          cell.filledByUserId = mv.userId;
          cell.notes.clear();
        }
      }
    }

    // Khởi tạo lượt chơi: ưu tiên từ server, mặc định người chơi đầu tiên đi trước
    _currentTurnUserId = coop?.currentTurnUserId ??
        widget.session.match?.players.firstOrNull?.userId ??
        _myId;

    // Tự động chọn ô trống đầu tiên
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (!_board[r][c].isClue && !_board[r][c].isFilled) {
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
          // Luân phiên đổi lượt: từ server gửi về hoặc đổi cho bên còn lại
          _currentTurnUserId = e.nextTurnUserId ?? (e.byUserId == _myId ? _oppId : _myId);
          if (e.isMistake) {
            _triggerMistakeFeedback();
            _tempErrorTimer?.cancel();
            _tempErrorRow = e.row;
            _tempErrorCol = e.col;
            _tempErrorValue = e.value;
            _tempErrorTimer = Timer(const Duration(milliseconds: 1500), () {
              if (mounted) {
                setState(() {
                  _tempErrorRow = null;
                  _tempErrorCol = null;
                  _tempErrorValue = null;
                });
              }
            });
            if (e.byUserId != myId) {
              final oppName = widget.session.match?.opponent?.displayName ?? 'Đồng đội';
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('❌ $oppName chọn sai số ${e.value}! (+1 lỗi: $_sharedMistakes/$_maxMistakes)'),
                  backgroundColor: const Color(0xFFDC2626),
                  duration: const Duration(milliseconds: 1500),
                ),
              );
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

      // Lắng nghe khi trận tái đấu bắt đầu (cả hai bên đều đã bấm Tái đấu)
      widget.session.starts.listen((m) {
        if (!mounted) return;
        // Đóng dialog kết thúc ván nếu đang mở
        if (_endedDialogShown) {
          Navigator.of(context, rootNavigator: true).pop();
          _endedDialogShown = false;
        }
        // Làm mới lại bàn cờ và tiến trình cho ván mới
        setState(() {
          _board = [];
          _initBoard();
          _sharedMistakes = 0;
          _elapsed = Duration.zero;
          _oppRow = null;
          _oppCol = null;
          _oppChat = null;
          _tempErrorRow = null;
          _tempErrorCol = null;
          _tempErrorValue = null;
        });
        _clockTimer?.cancel();
        _startClock();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎮 Ván tái đấu đã bắt đầu! Chúc hai bạn phối hợp ăn ý.'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
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
    if (_endedDialogShown || _sharedMistakes >= _maxMistakes) return;

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

    // NẾU ĐANG BẬT CHẾ ĐỘ GHI CHÚ:
    // Cho phép người chơi tự do ghi chú / nháp số bất kỳ lúc nào (kể cả khi chưa tới lượt mình)
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

    // NẾU ĐIỀN SỐ CHÍNH THỨC: Bắt buộc phải đến lượt của mình
    if (!_isMyTurn) {
      final oppName = widget.session.match?.opponent?.displayName ?? 'đồng đội';
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏳ Đang là lượt của $oppName! Bạn có thể bật "Ghi chú" để nháp số trước.'),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_countPlaced(number) >= 9) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Số $number đã được điền đủ 9 ô trên bàn cờ'),
          duration: const Duration(milliseconds: 1000),
        ),
      );
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
        _currentTurnUserId = _oppId; // Đổi lượt ngay lập tức cho đồng đội
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
        _currentTurnUserId = _oppId; // Đúng hay sai đều đổi lượt ngay lập tức!
      });
      _tempErrorTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _tempErrorRow = null;
            _tempErrorCol = null;
            _tempErrorValue = null;
          });
        }
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Số $number không đúng cho ô này! (+1 lỗi: $_sharedMistakes/$_maxMistakes)'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(milliseconds: 1500),
        ),
      );
      widget.session.sendSudokuMove(
        row: curRow,
        col: curCol,
        value: number,
        isMistake: true,
      );
      if (_sharedMistakes >= _maxMistakes) {
        _clockTimer?.cancel();
        _showMatchEndedDialog(MatchEndedEvent(
          matchId: widget.session.match?.matchId ?? '',
          winnerId: null,
          reason: 'MISTAKES_LIMIT',
          ranked: false,
        ));
      }
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
            ListenableBuilder(
              listenable: widget.session,
              builder: (context, _) {
                final rematchSent = widget.session.rematchSent;
                final oppWantsRematch = widget.session.rematchRequestedByOpponent;

                return FilledButton.icon(
                  icon: Icon(rematchSent ? Icons.hourglass_top_rounded : Icons.replay_rounded),
                  label: Text(
                    rematchSent
                        ? 'Đang chờ đối thủ…'
                        : (oppWantsRematch ? 'Chấp nhận tái đấu' : 'Tái đấu'),
                  ),
                  onPressed: rematchSent
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = await widget.session.rematch();
                          if (ok && mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Đã gửi lời mời tái đấu tới đối thủ!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tính toán tiến độ và phân bố số trong 1 vòng lặp duy nhất (tránh lặp 81 ô nhiều lần)
    int myCount = 0;
    int oppCount = 0;
    int filledTotal = 0;
    final placedCounts = List<int>.filled(10, 0);

    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final cell = _board[r][c];
        if (cell.isFilled) {
          filledTotal++;
          if (cell.currentValue >= 1 && cell.currentValue <= 9) {
            placedCounts[cell.currentValue]++;
          }
          if (cell.filledByUserId == myId) {
            myCount++;
          } else if (cell.filledByUserId != null) {
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
                                i < _sharedMistakes ? Icons.heart_broken_rounded : Icons.favorite_rounded,
                                size: 18,
                                color: i < _sharedMistakes
                                    ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
                                    : const Color(0xFFEF4444),
                              ),
                            ),
                          const SizedBox(width: 4),
                          Text(
                            '$_sharedMistakes/$_maxMistakes',
                            style: text.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _sharedMistakes > 0 ? const Color(0xFFDC2626) : scheme.onSurfaceVariant,
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
                        isTheirTurn: _isMyTurn,
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
                        isTheirTurn: !_isMyTurn,
                        chat: _oppChat,
                        cursorInfo: (_oppRow != null && _oppCol != null)
                            ? 'Ô [${String.fromCharCode(65 + _oppCol!)}${_oppRow! + 1}]'
                            : null,
                      ),
                    ),
                  ],
                ),
              ),

              // Dải thông báo lượt đi nổi bật
              _buildTurnIndicator(),

              const SizedBox(height: 6),

              // Bàn cờ Sudoku 9x9 (luôn vuông vắn tuyệt đối, không bị méo trên mọi tỉ lệ màn hình)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = min(constraints.maxWidth, constraints.maxHeight);
                      return Center(
                        child: SizedBox(
                          width: size,
                          height: size,
                          child: _buildSudokuGrid(size),
                        ),
                      );
                    },
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
                child: _buildKeypad(placedCounts),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTurnIndicator() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final oppName = widget.session.match?.opponent?.displayName ?? 'Bạn bè';
    final isMyTurn = _isMyTurn;

    final bgColor = isMyTurn
        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));
    final borderColor = isMyTurn
        ? const Color(0xFF10B981)
        : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1));
    final iconColor = isMyTurn ? const Color(0xFF059669) : const Color(0xFF64748B);
    final textColor = isMyTurn
        ? (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46))
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isMyTurn ? 1.8 : 1.2),
        boxShadow: isMyTurn
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.16),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(
            isMyTurn ? Icons.touch_app_rounded : Icons.hourglass_top_rounded,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      isMyTurn ? 'LƯỢT CỦA BẠN' : 'LƯỢT CỦA ${oppName.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isMyTurn ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isMyTurn ? '1 số/lượt' : 'Đang chờ...',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  isMyTurn
                      ? 'Chọn 1 ô và điền 1 số (đúng hay sai đều đổi lượt)'
                      : 'Đồng đội đang điền số, vui lòng chờ đổi lượt...',
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard({
    required String name,
    required int count,
    required Color accentColor,
    required bool isMe,
    required bool isTheirTurn,
    (String, DateTime)? chat,
    String? cursorInfo,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final recentChat = chat != null && DateTime.now().difference(chat.$2) < const Duration(seconds: 4);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isTheirTurn ? accentColor.withValues(alpha: 0.12) : accentColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isTheirTurn ? accentColor : accentColor.withValues(alpha: 0.25),
          width: isTheirTurn ? 2.2 : 1.0,
        ),
        boxShadow: isTheirTurn
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
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
              if (isTheirTurn)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LƯỢT ĐI',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
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

  Widget _buildSudokuGrid(double boardSize) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const borderWidth = 2.0;
    final innerSize = boardSize - (borderWidth * 2);
    final cellSize = innerSize / 9;
    final dividerColor = isDark ? const Color(0xFF475569) : const Color(0xFF1E293B);

    return Container(
      width: boardSize,
      height: boardSize,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: dividerColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md - borderWidth),
        child: Stack(
          children: [
            // 81 ô Sudoku được định vị chính xác tuyệt đối theo pixel (chuẩn hình vuông 100% không lệch)
            for (int r = 0; r < 9; r++)
              for (int c = 0; c < 9; c++)
                Positioned(
                  left: c * cellSize,
                  top: r * cellSize,
                  width: cellSize,
                  height: cellSize,
                  child: _buildGridCell(r, c, cellSize),
                ),

            // Các đường kẻ dày phân tách các khối 3x3
            for (int i = 1; i <= 2; i++) ...[
              // Kẻ dọc
              Positioned(
                left: i * 3 * cellSize - 1.0,
                top: 0,
                bottom: 0,
                width: 2.0,
                child: Container(color: dividerColor),
              ),
              // Kẻ ngang
              Positioned(
                top: i * 3 * cellSize - 1.0,
                left: 0,
                right: 0,
                height: 2.0,
                child: Container(color: dividerColor),
              ),
            ],
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

  Widget _buildGridCell(int r, int c, double cellSize) {
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

    // Kiểm tra ô bị xung đột số với số bị nhập sai (cùng hàng/cột/khối với ô bị nhập sai)
    final isInErrorRowOrCol = (_tempErrorRow == r || _tempErrorCol == c);
    final isInErrorBox = _tempErrorRow != null &&
        _tempErrorCol != null &&
        (r ~/ 3 == _tempErrorRow! ~/ 3 && c ~/ 3 == _tempErrorCol! ~/ 3);
    final isConflictCell = !isTempError &&
        _tempErrorValue != null &&
        (isInErrorRowOrCol || isInErrorBox) &&
        cell.currentValue == _tempErrorValue;

    // Màu nền ô
    Color bgColor;
    if (isTempError) {
      bgColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
    } else if (isConflictCell) {
      bgColor = isDark ? const Color(0xFF78350F).withValues(alpha: 0.7) : const Color(0xFFFEF3C7);
    } else if (isSelected) {
      bgColor = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
    } else if (isSameNumber) {
      bgColor = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.8) : const Color(0xFFEFF6FF);
    } else if (isInSameRowOrCol || isInSameBox) {
      bgColor = isDark ? const Color(0xFF0F172A).withValues(alpha: 0.4) : const Color(0xFFF8FAFC);
    } else {
      bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    }

    // Viền phân tách: chỉ kẻ viền trong khối, các đường phân tách khối 3x3 để lớp Stack vẽ đè lên
    final thinBorderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final borderRight = (c % 3 == 2 || c == 8)
        ? BorderSide.none
        : BorderSide(color: thinBorderColor, width: 0.8);

    final borderBottom = (r % 3 == 2 || r == 8)
        ? BorderSide.none
        : BorderSide(color: thinBorderColor, width: 0.8);

    // Xác định ai điền ô này
    final myId = widget.session.match?.you ?? 0;
    final filledByMe = cell.filledByUserId == myId;
    final filledByOpp = cell.filledByUserId != null && !filledByMe;

    Color numberColor;
    if (isTempError) {
      numberColor = const Color(0xFFDC2626);
    } else if (isConflictCell) {
      numberColor = const Color(0xFFD97706);
    } else if (cell.isClue) {
      numberColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    } else if (filledByMe) {
      numberColor = const Color(0xFF2563EB); // Xanh dương
    } else if (filledByOpp) {
      numberColor = const Color(0xFF10B981); // Xanh lá
    } else {
      numberColor = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
    }

    final fontSize = (cellSize * 0.52).clamp(16.0, 24.0);

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
                  fontSize: fontSize + 1,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFDC2626),
                ),
              )
            else if (cell.currentValue > 0)
              Text(
                '${cell.currentValue}',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: cell.isClue ? FontWeight.w900 : FontWeight.bold,
                  color: numberColor,
                ),
              )
            else if (cell.notes.isNotEmpty)
              _buildNotesGrid(cell.notes, cellSize),

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
            if (isSelected && !isTempError)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF2563EB), width: 2.2),
                  ),
                ),
              ),

            // Lớp phủ viền đỏ + icon X nếu ô này vừa bị bấm sai
            if (isTempError)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFDC2626), width: 2.8),
                    color: const Color(0xFFDC2626).withValues(alpha: 0.18),
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 10, color: Colors.white),
                    ),
                  ),
                ),
              ),

            // Lớp phủ viền cảnh báo nếu ô bị trùng số với số sai
            if (isConflictCell)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFF59E0B), width: 1.8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesGrid(Set<int> notes, double cellSize) {
    final noteFontSize = (cellSize * 0.22).clamp(7.5, 10.0);

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
                          style: TextStyle(
                            fontSize: noteFontSize,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
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

  Widget _buildKeypad(List<int> placedCounts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: (_isMyTurn || _isNotesMode) ? 1.0 : 0.65,
      child: Row(
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
                          '${placedCounts[i]}/9',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: placedCounts[i] >= 9
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
      ),
    );
  }
}
