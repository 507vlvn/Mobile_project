import 'dart:async';

import 'package:flutter/material.dart';

import '../XepHinh/shared/models/difficulty.dart';
import '../XepHinh/sliding_puzzle/sliding_puzzle_logic.dart';
import '../core/realtime/match_models.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/feedback_states.dart';
import 'match_result_sheet.dart';
import 'match_session.dart';
import 'pvp_common.dart';
import 'pvp_widgets.dart';

/// Màn đua Xếp số: hai người cùng một đề (sinh từ `seed` của server), xem tiến
/// độ của nhau theo thời gian thực, ai xếp xong trước thắng.
class RacePuzzleScreen extends StatefulWidget {
  final MatchSession session;
  const RacePuzzleScreen({super.key, required this.session});

  @override
  State<RacePuzzleScreen> createState() => _RacePuzzleScreenState();
}

class _RacePuzzleScreenState extends State<RacePuzzleScreen> {
  static const _countdown = Duration(seconds: 3);

  MatchSession get s => widget.session;
  SlidingPuzzleLogic? _logic;
  String? _matchId;
  Timer? _ticker;
  bool _submitted = false;
  String? _shownResultFor;
  bool _sheetOpen = false;
  StreamSubscription<MatchInfo>? _startSub;

  @override
  void initState() {
    super.initState();
    s.addListener(_onSession);
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
    _startSub = s.starts.listen((_) {
      if (_sheetOpen && mounted) Navigator.of(context).pop();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSession());
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
    if (m != null && m.matchId != _matchId && !m.isTurn) {
      _matchId = m.matchId;
      _submitted = false;
      final d = GameDifficulty.values[(m.difficulty - 1).clamp(0, GameDifficulty.values.length - 1)];
      _logic = SlidingPuzzleLogic(difficulty: d, seed: m.seed);
      setState(() {});
    }
    final e = s.ended;
    if (s.phase == PvpPhase.ended && e != null && e.matchId != _shownResultFor && !_sheetOpen) {
      _shownResultFor = e.matchId;
      unawaited(_showResult());
    }
  }

  Future<void> _showResult() async {
    _sheetOpen = true;
    final leave = await showMatchResultSheet(context, s);
    _sheetOpen = false;
    if (!mounted) return;
    if (leave == true) {
      // pop() trực tiếp: PopScope (chặn thoát khi đang đấu) có thể chưa kịp cập nhật.
      Navigator.of(context).pop();
      s.leaveResult();
    }
  }

  DateTime get _startedAt => s.matchStartedAt ?? DateTime.now();
  bool get _counting => DateTime.now().isBefore(_startedAt.add(_countdown));

  void _onTileTap(int index) {
    final logic = _logic;
    final m = s.match;
    if (logic == null || m == null || !m.active || _counting || _submitted) return;
    if (!logic.moveTile(index)) return;
    setState(() {});
    s.reportProgress(logic.progressPercent);
    if (logic.isCompleted) {
      _submitted = true;
      final timeMs = DateTime.now().difference(_startedAt).inMilliseconds;
      s.finishRace(timeMs: timeMs, minTimeMs: raceMinTimeMs(m.gameCode, m.difficulty)).then((ok) {
        if (!ok && mounted) setState(() => _submitted = false);
      });
    }
  }

  Future<bool> _confirmResign() async {
    final ok = await confirmExit(
      context,
      title: 'Bỏ cuộc?',
      message: 'Bạn sẽ bị xử thua trận đua này.',
      confirmLabel: 'Bỏ cuộc',
      cancelLabel: 'Đua tiếp',
    );
    if (ok) await s.resign();
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final m = s.match;
    final logic = _logic;
    if (m == null || logic == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đua Xếp số')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final counting = _counting;
    final countLeft = (_startedAt.add(_countdown).difference(now).inMilliseconds / 1000).ceil();
    final elapsed = counting ? Duration.zero : now.difference(_startedAt.add(_countdown));
    final deadline = m.race?.deadline;
    final opp = m.opponent;
    final myPct = logic.progressPercent;

    return PopScope(
      canPop: !m.active,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          if (s.phase == PvpPhase.ended) s.leaveResult();
          return;
        }
        final resigned = await _confirmResign();
        if (resigned && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${pvpGameLabel(m.gameCode, m.difficulty)} · ${m.ranked ? 'Xếp hạng' : 'Giao hữu'}'),
          actions: [QuickChatButton(session: s)],
        ),
        body: SafeArea(
          child: Column(
            children: [
              ConnectionBanner(session: s),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, 0),
                child: Column(
                  children: [
                    if (opp != null)
                      RaceProgressBar(
                        label: '${opp.displayName}${s.opponentConnected ? '' : ' (mất kết nối)'}'
                            '${_chatSuffix(opp.userId)}',
                        percent: s.opponentProgress,
                        color: scheme.error,
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    RaceProgressBar(
                      label: 'Bạn${_chatSuffix(m.you)}',
                      percent: myPct,
                      color: context.palette.success,
                    ),
                  ],
                ),
              ),
              OpponentStatusBanner(session: s),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_outlined, size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(formatMmSs(elapsed), style: text.titleMedium),
                    if (deadline != null) ...[
                      const SizedBox(width: AppSpacing.lg),
                      Text('Còn ${formatMmSs(deadline.difference(now))}',
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      children: [
                        _Board(logic: logic, enabled: m.active && !counting && !_submitted, onTap: _onTileTap),
                        if (counting)
                          Positioned.fill(
                            child: Container(
                              margin: const EdgeInsets.all(AppSpacing.screen),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                              ),
                              alignment: Alignment.center,
                              child: Text('$countLeft',
                                  style: text.displayLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _submitted
                            ? (s.busy ? 'Đang nộp kết quả…' : 'Đã xếp xong!')
                            : 'Số bước: ${logic.moves}',
                        style: text.bodyMedium,
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                      onPressed: m.active ? _confirmResign : null,
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Bỏ cuộc'),
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

  String _chatSuffix(int userId) {
    final c = s.chatOf(userId);
    if (c == null || DateTime.now().difference(c.$2) > const Duration(seconds: 4)) return '';
    return '  · ${quickChatLabel(c.$1)}';
  }
}

class _Board extends StatelessWidget {
  final SlidingPuzzleLogic logic;
  final bool enabled;
  final ValueChanged<int> onTap;
  const _Board({required this.logic, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(AppSpacing.screen),
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: logic.gridSize,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: logic.tiles.length,
        itemBuilder: (context, index) {
          final tile = logic.tiles[index];
          if (tile.isEmpty) return const SizedBox.shrink();
          return GestureDetector(
            onTap: enabled ? () => onTap(index) : null,
            child: Container(
              decoration: BoxDecoration(
                color: tile.isCorrect ? Colors.teal.shade400 : Colors.indigo.shade400,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              alignment: Alignment.center,
              child: Text(
                '${tile.id}',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }
}
