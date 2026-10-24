import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/challenge_context.dart';
import '../../core/models/difficulty.dart';
import '../../core/services/score_reporter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/difficulty_selector.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/game_timer.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/result_sheet.dart';
import '../../core/widgets/stat_chip.dart';
import '../render/rubik_3d_view.dart';
import '../screens/solve_player_screen.dart';
import '../services/move_describer.dart';
import '../widgets/move_pad.dart';
import 'practice_controller.dart';

/// Chế độ Luyện giải: app xáo đề, người chơi tự vuốt để giải.
class PracticeScreen extends StatefulWidget {
  /// Khác null → ván thách đấu: đề xáo sinh từ seed chung, không lưu ván,
  /// xong ván thì quay về danh sách thách đấu.
  final ChallengeContext? challenge;

  const PracticeScreen({super.key, this.challenge});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with WidgetsBindingObserver {
  static const _gameCode = 'RUBIK';
  static const _onboardingKey = 'rubik_onboarding_done';

  late final PracticeController _controller =
      PracticeController(persist: widget.challenge == null);

  bool get _isChallenge => widget.challenge != null;
  final _cubeKey = GlobalKey<Rubik3DViewState>();

  Difficulty _difficulty = Difficulty.medium;
  bool _skipScramble = false;
  bool _showPad = false;
  bool _busy = false; // đang diễn hoạt nước đi từ nút bấm

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onControllerChanged);
    if (_isChallenge) {
      _difficulty = widget.challenge!.difficulty;
    } else {
      DifficultyMemory.load(_gameCode).then((d) {
        if (mounted) setState(() => _difficulty = d);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _controller.save();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller.pause();
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    var onboardingDone = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      onboardingDone = prefs.getBool(_onboardingKey) ?? false;
    } catch (_) {}
    if (!mounted) return;
    if (!onboardingDone) {
      await _showOnboarding();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_onboardingKey, true);
      } catch (_) {}
    }
    if (!mounted) return;
    if (_isChallenge) {
      // Thách đấu: vào thẳng ván, không hỏi ván đang dở
      await _startNewGame();
      return;
    }
    if (await PracticeController.hasSavedGame()) {
      if (!mounted) return;
      final resume = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.history_rounded),
          title: const Text('Tiếp tục ván đang dở?'),
          content: const Text('Bạn có một ván Luyện giải chưa hoàn thành.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ván mới'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tiếp tục'),
            ),
          ],
        ),
      );
      if (resume == true) {
        await _controller.restore();
        _difficulty = _controller.difficulty;
      } else {
        await _controller.clearSave();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Luồng ván chơi
  // ---------------------------------------------------------------------------

  Future<void> _startNewGame() async {
    if (!_isChallenge) DifficultyMemory.save(_gameCode, _difficulty);
    // Thách đấu: cả hai người nhận cùng chuỗi xáo nhờ seed chung
    final scramble = _controller.newGame(
      _difficulty,
      random: _isChallenge ? math.Random(widget.challenge!.seed) : null,
    );
    _skipScramble = false;
    setState(() {});
    // Chờ khung hình kế tiếp để Rubik3DView nhận trạng thái khối mới
    await WidgetsBinding.instance.endOfFrame;

    for (var i = 0; i < scramble.length; i++) {
      final view = _cubeKey.currentState;
      if (!mounted) return;
      if (_skipScramble || view == null) {
        _controller.cube.applyMoves(scramble.sublist(i));
        break;
      }
      await view.animateMove(scramble[i],
          duration: const Duration(milliseconds: 130));
    }
    if (!mounted) return;
    _controller.finishScramble();
  }

  Future<void> _playMove(String move, {bool fromUndo = false}) async {
    final view = _cubeKey.currentState;
    if (view == null || _busy || view.isAnimating || !_controller.isPlaying) {
      return;
    }
    _busy = true;
    _controller.onUserActionStart();
    await view.animateMove(move, duration: const Duration(milliseconds: 220));
    _busy = false;
    if (!mounted) return;
    HapticFeedback.selectionClick();
    final solved = _controller.recordMove(move, fromUndo: fromUndo);
    if (solved) _onSolved();
  }

  void _onGestureMove(String move) {
    final solved = _controller.recordMove(move);
    if (solved) _onSolved();
  }

  Future<void> _onSolved() async {
    HapticFeedback.heavyImpact();
    final reporter = context.read<ScoreReporter>();
    final record = GameRecord(
      gameCode: 'RUBIK',
      difficulty: _controller.difficulty,
      timeSeconds: _controller.clock.seconds,
      mistakes: _controller.hints,
      moves: _controller.moves,
      hints: _controller.hints,
      outcome: GameOutcome.completed,
      challengeId: widget.challenge?.challengeId,
    );
    // Gửi điểm song song với khoảng nghỉ ngắn để người chơi thấy khối hoàn chỉnh
    final results = await Future.wait([
      reporter.submit(record),
      Future.delayed(const Duration(milliseconds: 350)),
    ]);
    final outcome = results.first as ReportOutcome;
    if (!mounted) return;
    if (outcome.message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(outcome.message!)));
    }
    final action = await showResultSheet(
      context,
      GameResultData(
        success: true,
        title: 'Giải xong khối Rubik!',
        time: _controller.clock.elapsed,
        mistakes: _controller.hints,
        mistakesLabel: 'Gợi ý',
        moves: _controller.moves,
        score: outcome.score,
        isPersonalBest: outcome.isPersonalBest,
      ),
    );
    if (!mounted) return;
    if (_isChallenge) {
      Navigator.of(context).pop(); // về danh sách thách đấu
    } else if (action == ResultAction.home) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      _startNewGame();
    }
  }

  /// Bỏ cuộc ván thách đấu: gửi kết quả ABANDONED (0 điểm) rồi thoát.
  Future<void> _abandonChallenge() async {
    final ok = await confirmExit(
      context,
      title: 'Bỏ cuộc ván thách đấu?',
      message: 'Bỏ cuộc sẽ được tính 0 điểm cho ván thách đấu.',
      confirmLabel: 'Bỏ cuộc',
      cancelLabel: 'Chơi tiếp',
    );
    if (!ok || !mounted) return;
    _controller.pause();
    final reporter = context.read<ScoreReporter>();
    await reporter.submit(GameRecord(
      gameCode: 'RUBIK',
      difficulty: _controller.difficulty,
      timeSeconds: _controller.clock.seconds,
      mistakes: _controller.hints,
      moves: _controller.moves,
      hints: _controller.hints,
      outcome: GameOutcome.abandoned,
      challengeId: widget.challenge!.challengeId,
    ));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _hint() async {
    final move = await _controller.requestHint();
    if (!mounted) return;
    if (move == null && !_controller.hintLoading) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Chưa tìm được gợi ý, thử lại nhé.')));
    }
  }

  Future<void> _viewSolution() async {
    final ok = await confirmExit(
      context,
      title: 'Xem lời giải?',
      message: 'Ván này sẽ kết thúc và không được tính điểm.',
      confirmLabel: 'Xem lời giải',
      cancelLabel: 'Tự giải tiếp',
    );
    if (!ok || !mounted) return;
    final start = _controller.cube.clone();
    final moves = await _controller.fullSolution();
    if (!mounted) return;
    _controller.giveUp();
    if (moves == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không giải được trạng thái hiện tại.')),
      );
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SolvePlayerScreen(initialCubeState: start, moves: moves),
    ));
  }

  Future<void> _confirmNewGame() async {
    if (_controller.phase == PracticePhase.playing ||
        _controller.phase == PracticePhase.paused) {
      final ok = await confirmExit(
        context,
        title: 'Bắt đầu ván mới?',
        message: 'Ván hiện tại sẽ bị huỷ.',
        confirmLabel: 'Ván mới',
        cancelLabel: 'Chơi tiếp',
      );
      if (!ok) return;
    }
    _controller.giveUp();
  }

  Future<void> _showOnboarding() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _OnboardingSheet(),
    );
  }

  // ---------------------------------------------------------------------------
  // Giao diện
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final phase = _controller.phase;
    final inGame =
        phase == PracticePhase.playing || phase == PracticePhase.paused;

    final inChallengeGame = _isChallenge && phase != PracticePhase.solved;
    return PopScope(
      canPop: !inChallengeGame,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _abandonChallenge();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isChallenge
              ? 'Thách đấu · ${_difficulty.label}'
              : (inGame
                  ? 'Luyện giải · ${_controller.difficulty.label}'
                  : 'Luyện giải')),
          actions: [
            IconButton(
              tooltip: 'Hướng dẫn thao tác',
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: _showOnboarding,
            ),
            if (inGame)
              PopupMenuButton<String>(
                tooltip: 'Tuỳ chọn',
                onSelected: (v) {
                  if (v == 'new') _confirmNewGame();
                  if (v == 'solution') _viewSolution();
                  if (v == 'abandon') _abandonChallenge();
                  if (v == 'camera') _cubeKey.currentState?.resetCamera();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'camera',
                    child: ListTile(
                      leading: Icon(Icons.threed_rotation_rounded),
                      title: Text('Đặt lại góc nhìn'),
                    ),
                  ),
                  if (_isChallenge)
                    const PopupMenuItem(
                      value: 'abandon',
                      child: ListTile(
                        leading: Icon(Icons.flag_outlined),
                        title: Text('Bỏ cuộc (0 điểm)'),
                      ),
                    )
                  else ...const [
                    PopupMenuItem(
                      value: 'new',
                      child: ListTile(
                        leading: Icon(Icons.restart_alt_rounded),
                        title: Text('Ván mới'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'solution',
                      child: ListTile(
                        leading: Icon(Icons.flag_outlined),
                        title: Text('Xem lời giải (bỏ cuộc)'),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              if (_isChallenge) const _ChallengeBanner(),
              if (inGame || phase == PracticePhase.solved) _buildHud(),
              _buildHintBanner(),
              Expanded(child: _buildStage()),
              AnimatedSize(
                duration: AppMotion.of(context, AppMotion.normal),
                curve: AppMotion.standard,
                child: _buildBottom(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHud() {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.sm),
      child: Row(
        children: [
          _TimerChip(clock: _controller.clock),
          const SizedBox(width: AppSpacing.sm),
          StatChip(
              icon: Icons.swipe_rounded,
              value: '${_controller.moves}',
              label: 'nước'),
          const SizedBox(width: AppSpacing.sm),
          StatChip(
            icon: Icons.lightbulb_outline_rounded,
            value: '${_controller.hints}',
            label: 'gợi ý',
            color: _controller.hints > 0 ? palette.warning : null,
          ),
          const Spacer(),
          if (_controller.phase == PracticePhase.playing)
            IconButton.filledTonal(
              tooltip: 'Tạm dừng',
              onPressed: _controller.pause,
              icon: const Icon(Icons.pause_rounded),
            )
          else if (_controller.phase == PracticePhase.paused)
            IconButton.filled(
              tooltip: 'Tiếp tục',
              onPressed: _controller.resume,
              icon: const Icon(Icons.play_arrow_rounded),
            ),
        ],
      ),
    );
  }

  Widget _buildHintBanner() {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hint = _controller.hintMove;
    Widget child = const SizedBox.shrink(key: ValueKey('none'));

    if (_controller.hintLoading) {
      child = Padding(
        key: const ValueKey('loading'),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: AppSpacing.sm),
            Text('Đang tìm nước đi tốt nhất…', style: text.bodyMedium),
          ],
        ),
      );
    } else if (hint != null) {
      final d = describeMove(hint, _controller.cube);
      child = Container(
        key: ValueKey(hint),
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                hint,
                style: text.titleMedium?.copyWith(color: scheme.onPrimary),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.title,
                      style: text.labelLarge
                          ?.copyWith(color: scheme.onPrimaryContainer)),
                  Text(d.action,
                      style: text.bodyMedium
                          ?.copyWith(color: scheme.onPrimaryContainer)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.normal),
      child: child,
    );
  }

  Widget _buildStage() {
    final phase = _controller.phase;
    final text = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, c) {
        final size =
            (c.maxWidth - AppSpacing.screen * 2).clamp(160.0, c.maxHeight - 8);
        return Stack(
          alignment: Alignment.center,
          children: [
            Rubik3DView(
              key: _cubeKey,
              state: _controller.cube,
              size: size,
              enableInteraction: phase != PracticePhase.paused,
              enableLayerTurns: phase == PracticePhase.playing && !_busy,
              hintMove:
                  phase == PracticePhase.playing ? _controller.hintMove : null,
              onTurnStart: _controller.onUserActionStart,
              onMove: _onGestureMove,
            ),
            if (phase == PracticePhase.scrambling)
              Positioned(
                bottom: AppSpacing.sm,
                child: FilledButton.tonalIcon(
                  onPressed: () => setState(() => _skipScramble = true),
                  icon: const Icon(Icons.fast_forward_rounded),
                  label: const Text('Bỏ qua hoạt ảnh xáo'),
                ),
              ),
            if (phase == PracticePhase.playing &&
                _controller.moves == 0 &&
                _controller.hintMove == null)
              Positioned(
                bottom: AppSpacing.sm,
                child: _CoachChip(
                  text: 'Đặt ngón tay lên một ô rồi vuốt để xoay tầng',
                  style: text.bodySmall,
                ),
              ),
            if (phase == PracticePhase.paused)
              Positioned.fill(
                  child: _PausedOverlay(onResume: _controller.resume)),
          ],
        );
      },
    );
  }

  Widget _buildBottom() {
    final phase = _controller.phase;
    // Thách đấu không có bảng chọn độ khó / ván mới
    if (_isChallenge &&
        (phase == PracticePhase.setup || phase == PracticePhase.solved)) {
      return const SizedBox(height: AppSpacing.lg);
    }
    if (phase == PracticePhase.setup || phase == PracticePhase.solved) {
      return _SetupPanel(
        difficulty: _difficulty,
        onDifficulty: (d) => setState(() => _difficulty = d),
        onStart: _startNewGame,
      );
    }
    if (phase == PracticePhase.scrambling) {
      return const SizedBox(height: AppSpacing.lg);
    }

    final playing = phase == PracticePhase.playing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showPad) ...[
            MovePad(
              state: _controller.cube,
              enabled: playing && !_busy,
              onMove: _playMove,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              _ToolButton(
                icon: Icons.undo_rounded,
                label: 'Hoàn tác',
                onPressed: _controller.canUndo && !_busy
                    ? () => _playMove(_controller.undoMove!, fromUndo: true)
                    : null,
              ),
              _ToolButton(
                icon: Icons.redo_rounded,
                label: 'Làm lại',
                onPressed: _controller.canRedo && !_busy
                    ? () => _playMove(_controller.redoMove!)
                    : null,
              ),
              _ToolButton(
                icon: _showPad
                    ? Icons.keyboard_hide_rounded
                    : Icons.dialpad_rounded,
                label: _showPad ? 'Ẩn nút' : 'Bảng nút',
                onPressed: () => setState(() => _showPad = !_showPad),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: playing &&
                          !_controller.hintLoading &&
                          _controller.hintMove == null
                      ? _hint
                      : null,
                  icon: const Icon(Icons.lightbulb_rounded),
                  label: const Text('Gợi ý'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Widget con
// =============================================================================

class _ChallengeBanner extends StatelessWidget {
  const _ChallengeBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.sports_esports_rounded,
              size: 20, color: scheme.onTertiaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Ván thách đấu — cùng đề với đối thủ, điểm cao hơn sẽ thắng',
              style:
                  text.bodySmall?.copyWith(color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  final GameClock clock;
  const _TimerChip({required this.clock});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 18, color: scheme.onSurface),
          const SizedBox(width: 6),
          GameTimerText(
              clock: clock, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ToolButton({required this.icon, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final color =
        enabled ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.38);
    return Expanded(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 2),
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupPanel extends StatelessWidget {
  final Difficulty difficulty;
  final ValueChanged<Difficulty> onDifficulty;
  final VoidCallback onStart;

  const _SetupPanel({
    required this.difficulty,
    required this.onDifficulty,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final hint = switch (difficulty) {
      Difficulty.easy => 'Xáo 5 nước — hợp để làm quen thao tác vuốt.',
      Difficulty.medium => 'Xáo 11 nước — cần suy nghĩ một chút.',
      Difficulty.hard => 'Xáo 22 nước — trạng thái gần như ngẫu nhiên.',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        boxShadow: [
          BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Chọn độ khó', style: text.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          DifficultySelector(value: difficulty, onChanged: onDifficulty),
          const SizedBox(height: AppSpacing.sm),
          Text(hint,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Xáo đề & bắt đầu',
            icon: Icons.shuffle_rounded,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

class _PausedOverlay extends StatelessWidget {
  final VoidCallback onResume;
  const _PausedOverlay({required this.onResume});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: scheme.surface.withValues(alpha: 0.6),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pause_circle_outline_rounded,
                  size: 56, color: scheme.primary),
              const SizedBox(height: AppSpacing.md),
              Text('Đã tạm dừng', style: text.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Đồng hồ đã dừng. Khối được che để công bằng.',
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Tiếp tục'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachChip extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const _CoachChip({required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.inverseSurface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded,
              size: 18, color: scheme.onInverseSurface),
          const SizedBox(width: 6),
          Text(text, style: style?.copyWith(color: scheme.onInverseSurface)),
        ],
      ),
    );
  }
}

/// Hướng dẫn 3 bước — hiện lần đầu, mở lại được bằng nút (?).
class _OnboardingSheet extends StatelessWidget {
  const _OnboardingSheet();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget step(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleSmall),
                    const SizedBox(height: 2),
                    Text(body,
                        style: text.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cách chơi', style: text.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            step(Icons.swipe_rounded, 'Vuốt trên ô để xoay tầng',
                'Đặt ngón tay lên một ô màu rồi vuốt. Tầng chứa ô đó sẽ xoay theo tay, thả ra là tự khớp. Vuốt nhanh để xoay luôn 90°.'),
            step(
                Icons.threed_rotation_rounded,
                'Vuốt ngoài khối để xoay góc nhìn',
                'Vuốt ở vùng trống quanh khối, hoặc dùng 2 ngón ở bất kỳ đâu. Chạm đúp vùng trống để về góc nhìn ban đầu.'),
            step(Icons.lightbulb_rounded, 'Bí thì bấm Gợi ý',
                'Tầng cần xoay sẽ sáng lên và nhún nhẹ theo chiều cần xoay. Mỗi lần gợi ý tính 1 lỗi khi chấm điểm.'),
            PrimaryButton(
              label: 'Đã hiểu',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
