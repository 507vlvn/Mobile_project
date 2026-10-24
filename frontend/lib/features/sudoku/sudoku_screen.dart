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
import 'sudoku_controller.dart';
import 'widgets/sudoku_board_view.dart';
import 'widgets/sudoku_controls.dart';

/// Màn hình Sudoku: chọn độ khó → sinh đề → chơi → kết quả.
class SudokuScreen extends StatefulWidget {
  final ChallengeContext? challenge;

  const SudokuScreen({super.key, this.challenge});

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _gameCode = 'SUDOKU';
  static const _onboardingKey = 'sudoku_onboarding_done';

  late final _controller = SudokuController(challenge: widget.challenge);
  ChallengeContext? get _challenge => widget.challenge;
  late final AnimationController _flash = AnimationController(vsync: this);
  int _lastFlashId = 0;

  Difficulty _difficulty = Difficulty.medium;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onControllerChanged);
    if (_challenge == null) {
      DifficultyMemory.load(_gameCode).then((d) {
        if (mounted) setState(() => _difficulty = d);
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
    _controller.saveNow();
    _controller.dispose();
    _flash.dispose();
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
    if (!mounted) return;
    final f = _controller.flash;
    if (f != null && f.id != _lastFlashId) {
      _lastFlashId = f.id;
      _flash.duration =
          AppMotion.of(context, const Duration(milliseconds: 600));
      _flash.forward(from: 0);
    }
    setState(() {});
  }

  Future<void> _bootstrap() async {
    if (_challenge != null) {
      // Thách đấu: vào ván ngay, không khôi phục ván cũ.
      _controller.startNewGame(_challenge!.difficulty);
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
    if (await SudokuController.hasSavedGame()) {
      if (!mounted) return;
      final resume = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.history_rounded),
          title: const Text('Tiếp tục ván đang dở?'),
          content: const Text('Bạn có một ván Sudoku chưa hoàn thành.'),
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
    if (_challenge != null) return;
    DifficultyMemory.save(_gameCode, _difficulty);
    await _controller.startNewGame(_difficulty);
  }

  void _onDigit(int d) {
    final result = _controller.input(d);
    if (result == PlaceResult.wrong) HapticFeedback.lightImpact();
    if (result == PlaceResult.solved) _onSolved();
  }

  void _onErase() {
    _controller.erase();
  }

  void _onHint() {
    final i = _controller.hint();
    if (i >= 0) {
      HapticFeedback.selectionClick();
      if (_controller.phase == SudokuPhase.solved) _onSolved();
    }
  }

  Future<void> _onSolved() async {
    HapticFeedback.heavyImpact();
    final c = _controller;
    final record = GameRecord(
      gameCode: _gameCode,
      difficulty: c.difficulty,
      timeSeconds: c.clock.seconds,
      mistakes: c.mistakes,
      moves: c.entries,
      hints: c.hints,
      outcome: GameOutcome.completed,
      challengeId: _challenge?.challengeId,
    );
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    ScoreReporter reporter;
    try {
      reporter = context.read<ScoreReporter>();
    } catch (_) {
      reporter = LocalScoreReporter();
    }
    final outcome = await reporter.submit(record);
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
        title: 'Giải xong Sudoku!',
        time: c.clock.elapsed,
        mistakes: c.mistakes,
        mistakesLabel: 'Lỗi',
        moves: c.entries,
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
      _controller.abandon();
      _startNewGame();
    }
  }

  bool get _inGame =>
      _controller.phase == SudokuPhase.playing ||
      _controller.phase == SudokuPhase.paused;

  Future<void> _confirmNewGame() async {
    if (_inGame) {
      final ok = await confirmExit(
        context,
        title: 'Bắt đầu ván mới?',
        message: 'Ván hiện tại sẽ bị huỷ.',
        confirmLabel: 'Ván mới',
        cancelLabel: 'Chơi tiếp',
      );
      if (!ok) return;
    }
    _controller.abandon();
  }

  Future<void> _abandonChallenge() async {
    final c = _controller;
    final record = GameRecord(
      gameCode: _gameCode,
      difficulty: c.difficulty,
      timeSeconds: c.clock.seconds,
      mistakes: c.mistakes,
      moves: c.entries,
      hints: c.hints,
      outcome: GameOutcome.abandoned,
      challengeId: _challenge!.challengeId,
    );
    ScoreReporter reporter;
    try {
      reporter = context.read<ScoreReporter>();
    } catch (_) {
      reporter = LocalScoreReporter();
    }
    try {
      await reporter.submit(record);
    } catch (_) {}
  }

  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop) return;
    if (_challenge != null) {
      final ok = await confirmExit(
        context,
        title: 'Bỏ cuộc thách đấu?',
        message: 'Bỏ cuộc sẽ được tính 0 điểm cho ván thách đấu.',
        confirmLabel: 'Bỏ cuộc',
      );
      if (!ok || !mounted) return;
      await _abandonChallenge();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final ok = await confirmExit(
      context,
      title: 'Rời khỏi ván Sudoku?',
      message: 'Ván đang chơi sẽ được lưu để bạn tiếp tục sau.',
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<void> _showHelp() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _HelpSheet(),
    );
  }

  // ---------------------------------------------------------------------------
  // Giao diện
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final phase = _controller.phase;
    final inGame = _inGame;

    return PopScope(
      canPop: _challenge == null
          ? !inGame
          : (phase == SudokuPhase.solved || phase == SudokuPhase.setup),
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              inGame ? 'Sudoku · ${_controller.difficulty.label}' : 'Sudoku'),
          actions: [
            IconButton(
              tooltip: 'Cách chơi',
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: _showHelp,
            ),
            if (inGame && _challenge == null)
              PopupMenuButton<String>(
                tooltip: 'Tuỳ chọn',
                onSelected: (v) {
                  if (v == 'new') _confirmNewGame();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'new',
                    child: ListTile(
                      leading: Icon(Icons.restart_alt_rounded),
                      title: Text('Ván mới'),
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              if (_challenge != null) ChallengeBanner(challenge: _challenge!),
              if (inGame) _buildHud(),
              Expanded(child: _buildBoardArea(phase)),
              AnimatedSize(
                duration: AppMotion.of(context, AppMotion.normal),
                curve: AppMotion.standard,
                alignment: Alignment.topCenter,
                child: _buildBottom(phase),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHud() {
    final palette = context.palette;
    final paused = _controller.phase == SudokuPhase.paused;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.sm),
      child: Row(
        children: [
          _TimerChip(clock: _controller.clock),
          const SizedBox(width: AppSpacing.sm),
          StatChip(
            icon: Icons.error_outline_rounded,
            value: '${_controller.mistakes}',
            label: 'lỗi',
            color: _controller.mistakes > 0 ? palette.warning : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          StatChip(
            icon: Icons.lightbulb_outline_rounded,
            value: '${_controller.hints}',
            label: 'gợi ý',
          ),
          const Spacer(),
          if (!paused)
            IconButton.filledTonal(
              tooltip: 'Tạm dừng',
              onPressed: _controller.pause,
              icon: const Icon(Icons.pause_rounded),
            )
          else
            IconButton.filled(
              tooltip: 'Tiếp tục',
              onPressed: _controller.resume,
              icon: const Icon(Icons.play_arrow_rounded),
            ),
        ],
      ),
    );
  }

  Widget _buildBoardArea(SudokuPhase phase) {
    return LayoutBuilder(
      builder: (context, c) {
        final side = (c.maxWidth - AppSpacing.screen * 2)
            .clamp(0.0, c.maxHeight - 8)
            .toDouble();
        return Align(
          alignment: const Alignment(0, -0.35),
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              fit: StackFit.expand,
              children: [
                SudokuBoardView(
                  board: _controller.board,
                  selected: _controller.selected,
                  onTap: _controller.select,
                  flash: _flash,
                  flashCells: _controller.flash?.cells ?? const {},
                ),
                if (phase == SudokuPhase.setup && _challenge == null)
                  const _BoardMessage.setup(),
                if (phase == SudokuPhase.generating)
                  const _BoardMessage.loading(),
                if (phase == SudokuPhase.paused)
                  _PausedOverlay(onResume: _controller.resume),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottom(SudokuPhase phase) {
    if (phase == SudokuPhase.setup ||
        phase == SudokuPhase.generating ||
        phase == SudokuPhase.solved) {
      if (_challenge != null) return const SizedBox.shrink();
      return _SetupPanel(
        difficulty: _difficulty,
        loading: phase == SudokuPhase.generating,
        onDifficulty: (d) => setState(() => _difficulty = d),
        onStart: _startNewGame,
      );
    }

    final playing = phase == SudokuPhase.playing;
    final b = _controller.board;
    final remaining = [
      for (var d = 1; d <= 9; d++) 9 - (b?.correctCount(d) ?? 0),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: SudokuToolButton(
                  icon: Icons.undo_rounded,
                  label: 'Hoàn tác',
                  onPressed:
                      playing && _controller.canUndo ? _controller.undo : null,
                ),
              ),
              Expanded(
                child: SudokuToolButton(
                  icon: Icons.backspace_outlined,
                  label: 'Xoá',
                  onPressed: playing ? _onErase : null,
                ),
              ),
              Expanded(
                child: SudokuToolButton(
                  icon: Icons.edit_note_rounded,
                  label: 'Ghi chú',
                  toggled: _controller.notesMode,
                  onPressed: playing ? _controller.toggleNotes : null,
                ),
              ),
              Expanded(
                child: SudokuToolButton(
                  icon: Icons.lightbulb_rounded,
                  label: 'Gợi ý',
                  onPressed: playing ? _onHint : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SudokuNumberPad(
            remaining: remaining,
            notesMode: _controller.notesMode,
            enabled: playing && _controller.selected != null,
            onDigit: _onDigit,
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

class _BoardMessage extends StatelessWidget {
  final bool loading;
  const _BoardMessage.setup() : loading = false;
  const _BoardMessage.loading() : loading = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(strokeWidth: 4))
            else
              Icon(Icons.grid_on_rounded, size: 48, color: scheme.primary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              loading
                  ? 'Đang tạo đề…'
                  : 'Điền số 1–9 sao cho mỗi hàng, cột và khối 3×3 không lặp số',
              style: loading ? text.titleMedium : text.titleSmall,
              textAlign: TextAlign.center,
            ),
            if (loading) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Đề luôn chỉ có một lời giải',
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetupPanel extends StatelessWidget {
  final Difficulty difficulty;
  final bool loading;
  final ValueChanged<Difficulty> onDifficulty;
  final VoidCallback onStart;

  const _SetupPanel({
    required this.difficulty,
    required this.loading,
    required this.onDifficulty,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final hint = switch (difficulty) {
      Difficulty.easy => 'Khoảng 40 ô cho sẵn — hợp để làm quen.',
      Difficulty.medium => 'Khoảng 32 ô cho sẵn — cần suy luận một chút.',
      Difficulty.hard => 'Khoảng 26 ô cho sẵn — dành cho người chơi lâu năm.',
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
          IgnorePointer(
            ignoring: loading,
            child:
                DifficultySelector(value: difficulty, onChanged: onDifficulty),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(hint,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Tạo đề & bắt đầu',
            icon: Icons.play_arrow_rounded,
            loading: loading,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

/// Che kín bàn cờ khi tạm dừng (không làm mờ, tránh nhìn trộm đề).
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
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outline),
      ),
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
            'Đồng hồ đã dừng. Bàn được che để công bằng.',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cách chơi Sudoku', style: text.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            step(Icons.touch_app_rounded, 'Chạm ô rồi chọn số',
                'Mỗi hàng, cột và khối 3×3 phải có đủ các số 1–9, không lặp. Số nhỏ dưới mỗi nút là số ô còn thiếu của chữ số đó.'),
            step(Icons.edit_note_rounded, 'Ghi chú để nháp',
                'Bật Ghi chú để ghi các số có thể điền vào ô. Khi điền đúng một số, ghi chú trùng số đó ở cùng hàng, cột, khối sẽ tự xoá.'),
            step(Icons.error_outline_rounded, 'Mỗi lỗi bị trừ điểm',
                'Điền sai tính 1 lỗi, ô sai hiện màu đỏ kèm biểu tượng. Mỗi lần dùng Gợi ý cũng tính 1 lỗi. Điểm giảm dần theo thời gian và số lỗi.'),
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

/// Biểu ngữ "Ván thách đấu" dưới app bar.
class ChallengeBanner extends StatelessWidget {
  final ChallengeContext challenge;
  const ChallengeBanner({super.key, required this.challenge});

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
