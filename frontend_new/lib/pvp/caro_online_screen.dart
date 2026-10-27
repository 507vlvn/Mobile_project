import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../caro/logic/caro_board.dart';
import '../caro/theme/caro_theme.dart';
import '../caro/widgets/caro_board_view.dart';
import '../core/realtime/match_models.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/feedback_states.dart';
import 'caro_online_board.dart';
import 'match_result_sheet.dart';
import 'match_session.dart';
import 'pvp_widgets.dart';

/// Màn đấu Caro online theo lượt. Bàn cờ dựng lại từ nước đi server gửi;
/// chạm một ô để xem trước, chạm lần nữa để đặt quân.
class CaroOnlineScreen extends StatefulWidget {
  final MatchSession session;
  const CaroOnlineScreen({super.key, required this.session});

  @override
  State<CaroOnlineScreen> createState() => _CaroOnlineScreenState();
}

class _CaroOnlineScreenState extends State<CaroOnlineScreen> {
  MatchSession get s => widget.session;
  Timer? _ticker;
  int? _preview;
  String? _matchId;
  int _matchNo = 0;
  String? _shownResultFor;
  bool _sheetOpen = false;
  CaroBoardTheme _theme = CaroBoardTheme.wood;

  /// Cài đặt "Thao tác 1 chạm" của Caro: chạm là đặt quân, không cần xem trước.
  bool _oneTap = false;
  StreamSubscription<MatchInfo>? _startSub;

  @override
  void initState() {
    super.initState();
    s.addListener(_onSession);
    // Đồng hồ lượt / đếm ngược mất kết nối cập nhật mỗi 0,25 giây.
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
    // Tái đấu bắt đầu trong khi bảng kết quả đang mở: đóng bảng, chơi tiếp.
    _startSub = s.starts.listen((_) {
      if (_sheetOpen && mounted) Navigator.of(context).pop();
    });
    _loadTheme();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSession());
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final t = CaroBoardTheme.fromName(prefs.getString('caro_board_theme'));
      final oneTap = prefs.getBool('caro_one_tap') ?? false;
      if (mounted) {
        setState(() {
          _theme = t;
          _oneTap = oneTap;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    s.removeListener(_onSession);
    _ticker?.cancel();
    _startSub?.cancel();
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    setState(() {}); // vẽ lại ngay khi có sự kiện từ server
    final m = s.match;
    if (m != null && m.matchId != _matchId) {
      _matchId = m.matchId;
      _matchNo++;
      _preview = null;
    }
    final e = s.ended;
    if (s.phase == PvpPhase.ended && e != null && e.matchId != _shownResultFor && !_sheetOpen) {
      _shownResultFor = e.matchId;
      _preview = null;
      unawaited(_showResult());
    }
  }

  Future<void> _showResult() async {
    _sheetOpen = true;
    // Caro: đầu hàng thì cả hai chỉ còn nút "Về sảnh", không tái đấu.
    final leave = await showMatchResultSheet(context, s, rematchAfterResign: false);
    _sheetOpen = false;
    if (!mounted) return;
    if (leave == true) {
      // pop() trực tiếp: PopScope (chặn thoát khi đang đấu) có thể chưa kịp cập nhật.
      Navigator.of(context).pop();
      s.leaveResult();
    }
  }

  void _onCellTap(int idx) {
    final m = s.match;
    if (m == null || !m.active || !m.isMyTurn || s.busy) return;
    final board = CaroOnlineBoard.from(m, s.firstMoverId);
    if (board.cells[idx] != kCaroEmpty) return;
    if (_oneTap || _preview == idx) {
      setState(() => _preview = null);
      s.caroMove(idx ~/ kCaroSize, idx % kCaroSize);
    } else {
      HapticFeedback.selectionClick();
      setState(() => _preview = idx);
    }
  }

  Future<bool> _confirmResign() async {
    final ok = await confirmExit(
      context,
      title: 'Đầu hàng?',
      message: 'Bạn sẽ bị xử thua trận này.',
      confirmLabel: 'Đầu hàng',
      cancelLabel: 'Chơi tiếp',
    );
    if (ok) await s.resign();
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final m = s.match;
    if (m == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Caro online')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final board = CaroOnlineBoard.from(m, s.firstMoverId);
    final me = m.me;
    final opp = m.opponent;
    final myTurn = m.active && m.isMyTurn;
    final left = s.turnDeadline?.difference(DateTime.now());
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !m.active,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          if (s.phase == PvpPhase.ended) s.leaveResult();
          return;
        }
        // Đầu hàng bằng nút Back: không thoát ngay, để người đầu hàng cũng
        // thấy bảng kết quả; "Về sảnh" trên bảng mới đóng màn hình.
        await _confirmResign();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(m.ranked ? 'Caro · Xếp hạng' : 'Caro · Giao hữu'),
          actions: [
            QuickChatButton(session: s, enabled: true),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              ConnectionBanner(session: s),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, 0),
                child: Row(
                  children: [
                    if (opp != null)
                      Expanded(
                        child: PlayerPanel(
                          player: opp,
                          symbol: board.iAmX ? 'O' : 'X',
                          active: m.active && m.caro?.currentTurnUserId == opp.userId,
                          timeLeft: m.caro?.currentTurnUserId == opp.userId ? left : null,
                          chat: s.chatOf(opp.userId),
                          disconnected: !s.opponentConnected,
                        ),
                      ),
                    const SizedBox(width: AppSpacing.sm),
                    if (me != null)
                      Expanded(
                        child: PlayerPanel(
                          player: me,
                          symbol: board.iAmX ? 'X' : 'O',
                          isMe: true,
                          active: myTurn,
                          timeLeft: myTurn ? left : null,
                          chat: s.chatOf(me.userId),
                        ),
                      ),
                  ],
                ),
              ),
              OpponentStatusBanner(session: s),
              if (s.opponentOfferedDraw && m.active)
                _DrawOfferBanner(onAnswer: (accept) => s.respondDraw(accept)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  !m.active
                      ? 'Trận đã kết thúc'
                      : s.busy
                          ? 'Đang gửi nước đi…'
                          : myTurn
                              ? (_preview == null ? 'Lượt của bạn — chạm một ô' : 'Chạm lần nữa để đặt quân')
                              : 'Đang chờ đối thủ…',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: myTurn ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: CaroBoardView(
                    cells: board.cells,
                    version: _matchNo * 1000 + board.moveCount + (_preview == null ? 0 : 500),
                    lastMove: board.lastMove,
                    preview: _preview,
                    winLine: m.active ? null : board.winLine,
                    theme: _theme,
                    interactive: myTurn && !s.busy,
                    onCellTap: _onCellTap,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(kMinTouchTarget)),
                        onPressed: m.active && !s.myDrawPending && s.drawOffersLeft > 0 ? s.offerDraw : null,
                        icon: const Icon(Icons.handshake_outlined),
                        label: Text(s.myDrawPending ? 'Đã xin hòa…' : 'Xin hòa (${s.drawOffersLeft})'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(kMinTouchTarget),
                          foregroundColor: scheme.error,
                        ),
                        onPressed: m.active ? _confirmResign : null,
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('Đầu hàng'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawOfferBanner extends StatelessWidget {
  final ValueChanged<bool> onAnswer;
  const _DrawOfferBanner({required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, 0),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.handshake_rounded, color: scheme.onSecondaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('Đối thủ xin hòa', style: TextStyle(color: scheme.onSecondaryContainer)),
          ),
          TextButton(onPressed: () => onAnswer(false), child: const Text('Từ chối')),
          FilledButton(onPressed: () => onAnswer(true), child: const Text('Đồng ý')),
        ],
      ),
    );
  }
}
