import 'dart:math' as math;

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
import 'logic/puzzle_logic.dart';
import 'puzzle_controller.dart';
import 'widgets/puzzle_board.dart';

/// Màn hình Xếp hình (trượt ô số).
class PuzzleScreen extends StatefulWidget {
  /// Chỉ dùng cho kiểm thử/ảnh chụp: truyền controller dựng sẵn.
  @visibleForTesting
  final PuzzleController? controller;

  /// Khác null = ván thách đấu (cùng đề với đối thủ, không lưu ván).
  final ChallengeContext? challenge;

  const PuzzleScreen({super.key, this.controller, this.challenge});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> with WidgetsBindingObserver {
  static const _gameCode = 'PUZZLE';
  static const _onboardingKey = 'puzzle_onboarding_done';

  late final PuzzleController _controller =
      widget.controller ?? PuzzleController(challenge: widget.challenge);
  ChallengeContext? get _challenge => widget.challenge;
  final _boardKey = GlobalKey<PuzzleBoardViewState>();

  Difficulty _difficulty = Difficulty.easy;
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onControllerChanged);
    if (_challenge == null) {
      DifficultyMemory.load(_gameCode).then((d) {
        if (mounted && _controller.phase == PuzzlePhase.setup) setState(() => _difficulty = d);
      });
    } else {
      _difficulty = _challenge!.difficulty;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _controller.save();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _controller.pause();
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (_controller.phase != PuzzlePhase.solved) {
      _resultShown = false;
    } else if (!_resultShown) {
      _onSolved();
    }
    setState(() {});
  }

  Future<void> _bootstrap() async {
    if (_controller.phase != PuzzlePhase.setup) return;
    if (_challenge != null) {
      // Thách đấu: vào ván ngay, không khôi phục ván cũ.
      _controller.newGame(_challenge!.difficulty);
      return;
    }
    var onboardingDone = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      onboardingDone = prefs.getBool(_onboardingKey) ?? false;
    } catch (_) {}
    if (!mounted) return;
    if (!onboardingDone) {
      await _showHelp();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_onboardingKey, true);
      } catch (_) {}
    }
    if (!mounted) return;
    if (await PuzzleController.hasSavedGame()) {
      if (!mounted) return;
      final resume = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.history_rounded),
          title: const Text('Tiếp tục ván đang dở?'),
          content: const Text('Bạn có một ván Xếp hình chưa hoàn thành.'),
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

  void _startNewGame() {
    if (_challenge != null) return;
    DifficultyMemory.save(_gameCode, _difficulty);
    _controller.newGame(_difficulty);
  }

  void _handleResult(TapResult r, int index) {
    switch (r) {
      case TapResult.moved:
        HapticFeedback.selectionClick();
      case TapResult.solved:
        HapticFeedback.heavyImpact();
      case TapResult.blocked:
        _boardKey.currentState?.shake(index);
        HapticFeedback.lightImpact();
      case TapResult.ignored:
        break;
    }
  }

  void _onTileTap(int index) => _handleResult(_controller.tap(index), index);

  void _undo() => _handleResult(_controller.undo(), -1);

  Future<void> _onSolved() async {
    if (_resultShown) return;
    _resultShown = true;
    final stats = await _controller.stats();
    final record = GameRecord(
      gameCode: _gameCode,
      difficulty: _controller.difficulty,
      timeSeconds: _controller.clock.seconds,
      mistakes: stats.mistakes,
      moves: _controller.moves,
      hints: stats.hints,
      outcome: GameOutcome.completed,
      challengeId: _challenge?.challengeId,
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    ReportOutcome outcome;
    try {
      outcome = await context.read<ScoreReporter>().submit(record);
    } catch (_) {
      outcome = ReportOutcome(score: record.localScore);
    }
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
        title: 'Xếp xong rồi!',
        time: _controller.clock.elapsed,
        mistakes: stats.mistakes,
        mistakesLabel: 'Bước thừa',
        moves: _controller.moves,
        score: outcome.score,
        isPersonalBest: outcome.isPersonalBest,
      ),
    );
    if (!mounted) return;
    if (_challenge != null) {
      Navigator.of(context).pop();
      return;
    }
    if (action == ResultAction.home) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      _startNewGame();
    }
  }

  Future<void> _abandonChallenge() async {
    final c = _controller;
    final stats = await c.stats();
    final record = GameRecord(
      gameCode: _gameCode,
      difficulty: c.difficulty,
      timeSeconds: c.clock.seconds,
      mistakes: stats.mistakes,
      moves: c.moves,
      hints: c.hints,
      outcome: GameOutcome.abandoned,
      challengeId: _challenge!.challengeId,
    );
    if (!mounted) return;
    try {
      await context.read<ScoreReporter>().submit(record);
    } catch (_) {}
  }

  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop || _challenge == null) return;
    final ok = await confirmExit(
      context,
      title: 'Bỏ cuộc thách đấu?',
      message: 'Bỏ cuộc sẽ được tính 0 điểm cho ván thách đấu.',
      confirmLabel: 'Bỏ cuộc',
    );
    if (!ok || !mounted) return;
    await _abandonChallenge();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _hint() async {
    await _controller.requestHint();
  }

  Future<void> _confirmNewGame() async {
    if (_controller.phase == PuzzlePhase.playing || _controller.phase == PuzzlePhase.paused) {
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

  Future<void> _showHelp() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _HelpSheet(),
    );
  }

  void _showGoal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _GoalSheet(n: _controller.n),
    );
  }

  // ---------------------------------------------------------------------------
  // Giao diện
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final phase = _controller.phase;
    final inGame = phase == PuzzlePhase.playing || phase == PuzzlePhase.paused;
    final n = _controller.n;

    return PopScope(
      canPop: _challenge == null ||
          phase == PuzzlePhase.solved ||
          phase == PuzzlePhase.setup,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
      appBar: AppBar(
        title: Text(inGame ? 'Xếp hình · ${_controller.difficulty.label} $n×$n' : 'Xếp hình'),
        actions: [
          IconButton(
            tooltip: 'Hướng dẫn',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: _showHelp,
          ),
          if (inGame && _challenge == null)
            IconButton(
              tooltip: 'Ván mới',
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: _confirmNewGame,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_challenge != null) _ChallengeBanner(challenge: _challenge!),
            if (inGame || phase == PuzzlePhase.solved) _buildHud(),
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
    final playing = _controller.phase == PuzzlePhase.playing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.sm),
      child: Row(
        children: [
          _TimerChip(clock: _controller.clock),
          const SizedBox(width: AppSpacing.sm),
          StatChip(icon: Icons.swipe_rounded, value: '${_controller.moves}', label: 'bước'),
          const SizedBox(width: AppSpacing.sm),
          StatChip(
            icon: Icons.lightbulb_outline_rounded,
            value: '${_controller.hints}',
            label: 'gợi ý',
            color: _controller.hints > 0 ? palette.warning : null,
          ),
          const Spacer(),
          if (playing)
            IconButton.filledTonal(
              tooltip: 'Tạm dừng',
              onPressed: _controller.pause,
              icon: const Icon(Icons.pause_rounded),
            )
          else if (_controller.phase == PuzzlePhase.paused)
            IconButton.filled(
              tooltip: 'Tiếp tục',
              onPressed: _controller.resume,
              icon: const Icon(Icons.play_arrow_rounded),
            ),
        ],
      ),
    );
  }

  Widget _buildStage() {
    final phase = _controller.phase;
    final setup = phase == PuzzlePhase.setup;
    final n = setup ? PuzzleLogic.sizeOf(_difficulty) : _controller.n;
    final board = setup ? PuzzleLogic.solved(n) : _controller.board;

    return LayoutBuilder(
      builder: (context, c) {
        final side = math.max(
          160.0,
          math.min(c.maxWidth - AppSpacing.screen * 2, c.maxHeight - AppSpacing.sm),
        );
        final paused = phase == PuzzlePhase.paused;
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              children: [
                PuzzleBoardView(
                  key: _boardKey,
                  board: board,
                  n: n,
                  side: side,
                  hintIndex: phase == PuzzlePhase.playing ? _controller.hintIndex : null,
                  interactive: phase == PuzzlePhase.playing,
                  showCorrect: !setup,
                  onTileTap: _onTileTap,
                ),
                if (setup)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                    ),
                  ),
                if (paused) Positioned.fill(child: _PausedOverlay(onResume: _controller.resume)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottom() {
    final phase = _controller.phase;
    if (phase == PuzzlePhase.setup || phase == PuzzlePhase.solved) {
      if (_challenge != null) return const SizedBox.shrink();
      return _SetupPanel(
        difficulty: _difficulty,
        onDifficulty: (d) => setState(() => _difficulty = d),
        onStart: _startNewGame,
      );
    }
    final playing = phase == PuzzlePhase.playing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          _ToolButton(
            icon: Icons.undo_rounded,
            label: 'Hoàn tác',
            onPressed: _controller.canUndo ? _undo : null,
          ),
          _ToolButton(
            icon: Icons.grid_view_rounded,
            label: 'Mục tiêu',
            onPressed: _showGoal,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: playing && !_controller.hintLoading && _controller.hintIndex == null
                  ? _hint
                  : null,
              icon: _controller.hintLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.lightbulb_rounded),
              label: const Text('Gợi ý'),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Widget con
// =============================================================================

class _TimerChip extends StatelessWidget {
  final GameClock clock;
  const _TimerChip({required this.clock});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 18, color: scheme.onSurface),
          const SizedBox(width: 6),
          GameTimerText(clock: clock, style: Theme.of(context).textTheme.labelLarge),
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
    final color = enabled ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.38);
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
                Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
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
    final n = PuzzleLogic.sizeOf(difficulty);
    final hint = switch (n) {
      3 => 'Bảng 3×3, 8 ô. Số bước tối ưu được tính chính xác.',
      4 => 'Bảng 4×4, 15 ô. Cần có kế hoạch từng hàng.',
      _ => 'Bảng 5×5, 24 ô. Thử thách kiên nhẫn.',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        boxShadow: [
          BoxShadow(color: scheme.shadow.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, -4)),
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
          Text(hint, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
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
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pause_circle_outline_rounded, size: 56, color: scheme.primary),
          const SizedBox(height: AppSpacing.md),
          Text('Đã tạm dừng', style: text.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Đồng hồ đã dừng. Bảng được che để công bằng.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
  }
}

class _GoalSheet extends StatelessWidget {
  final int n;
  const _GoalSheet({required this.n});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final side = math.min(MediaQuery.sizeOf(context).width - AppSpacing.xl * 2, 280.0);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mục tiêu', style: text.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Xếp các ô theo thứ tự từ 1 đến ${n * n - 1}, ô trống ở góc dưới bên phải.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            ExcludeSemantics(
              child: PuzzleBoardView(
                board: PuzzleLogic.solved(n),
                n: n,
                side: side,
                interactive: false,
                showCorrect: false,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(label: 'Đã rõ', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

/// Hướng dẫn — hiện lần đầu, mở lại được bằng nút (?).
class _HelpSheet extends StatelessWidget {
  const _HelpSheet();

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
                    Text(body, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cách chơi', style: text.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            step(Icons.touch_app_rounded, 'Chạm để trượt ô',
                'Chạm một ô cùng hàng hoặc cột với ô trống, cả đoạn ô ở giữa sẽ trượt theo. Trượt k ô tính là k bước.'),
            step(Icons.swipe_rounded, 'Hoặc vuốt trên bảng',
                'Vuốt theo hướng bạn muốn ô kề ô trống di chuyển. Cần nhầm thì dùng Hoàn tác.'),
            step(Icons.grid_view_rounded, 'Xếp 1, 2, 3… theo thứ tự',
                'Ô đúng chỗ có dấu tích. Nút Mục tiêu cho xem bảng đã xếp xong.'),
            step(Icons.lightbulb_rounded, 'Bí thì bấm Gợi ý',
                'Ô cần trượt sẽ nhấp nháy kèm mũi tên. Mỗi lần gợi ý và mỗi bước thừa so với mức tối ưu tính 1 lỗi.'),
            PrimaryButton(label: 'Đã hiểu', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

/// Biểu ngữ "Ván thách đấu" dưới app bar.
class _ChallengeBanner extends StatelessWidget {
  final ChallengeContext challenge;
  const _ChallengeBanner({required this.challenge});

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
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.sports_esports_rounded,
              size: 20, color: scheme.onPrimaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ván thách đấu · ${challenge.difficulty.label}',
                  style: text.labelLarge
                      ?.copyWith(color: scheme.onPrimaryContainer),
                ),
                Text(
                  'Cùng đề với đối thủ — điểm cao hơn sẽ thắng',
                  style: text.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
