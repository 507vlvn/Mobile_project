import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_new/caro/models/challenge_context.dart';
import 'package:frontend_new/caro/models/difficulty.dart';
import 'package:frontend_new/caro/services/score_reporter.dart';
import 'package:frontend_new/caro/theme/app_colors.dart';
import 'package:frontend_new/caro/theme/app_tokens.dart';
import 'package:frontend_new/caro/widgets/difficulty_selector.dart';
import 'package:frontend_new/caro/widgets/feedback_states.dart';
import 'package:frontend_new/caro/widgets/game_timer.dart';
import 'package:frontend_new/caro/widgets/primary_button.dart';
import 'package:frontend_new/caro/widgets/result_sheet.dart';
import 'package:frontend_new/caro/widgets/stat_chip.dart';
import 'caro_controller.dart';
import 'widgets/caro_board_view.dart';

/// Caro với máy: bàn 15×15, 5 quân liên tiếp thì thắng.
///
/// Rời ván giữa chừng (sau khi xác nhận) KHÔNG nộp điểm; ván được tự lưu để tiếp tục sau.
class CaroScreen extends StatefulWidget {
  const CaroScreen(
      {super.key, @visibleForTesting this.controller, this.challenge});

  /// Khác null = ván thách đấu (người chơi đi trước, không lưu ván).
  final ChallengeContext? challenge;

  /// Chỉ dùng cho test/chụp màn hình.
  final CaroController? controller;

  @override
  State<CaroScreen> createState() => _CaroScreenState();
}

class _CaroScreenState extends State<CaroScreen> with WidgetsBindingObserver {
  static const _gameCode = 'CARO';
  static const _onboardingKey = 'caro_onboarding_done';
  static const _oneTapKey = 'caro_one_tap';
  static const _firstKey = 'caro_player_first';

  late final CaroController _c;
  late final bool _ownsController;
  ChallengeContext? get _challenge => widget.challenge;
  final _boardKey = GlobalKey<CaroBoardViewState>();

  Difficulty _difficulty = Difficulty.medium;
  bool _playerFirst = true;
  bool _oneTap = false;
  int? _preview;
  bool _resultHandled = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _c = widget.controller ?? CaroController(challenge: widget.challenge);
    WidgetsBinding.instance.addObserver(this);
    _c.addListener(_onControllerChanged);
    if (_challenge == null) {
      _loadPrefs();
    } else {
      _difficulty = _challenge!.difficulty;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.removeListener(_onControllerChanged);
    if (_ownsController) {
      _c.save();
      _c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _c.resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _c.pause();
      _c.save();
    }
  }

  Future<void> _loadPrefs() async {
    final d = await DifficultyMemory.load(_gameCode);
    var oneTap = false, first = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      oneTap = prefs.getBool(_oneTapKey) ?? false;
      first = prefs.getBool(_firstKey) ?? true;
    } catch (_) {}
    if (mounted) {
      setState(() {
        _difficulty = d;
        _oneTap = oneTap;
        _playerFirst = first;
      });
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {
      if (!_c.canPlayerMove) _preview = null;
    });
    if (_c.phase == CaroPhase.finished && !_resultHandled) {
      _resultHandled = true;
      _onFinished();
    } else if (_c.phase != CaroPhase.finished) {
      _resultHandled = false;
    }
  }

  Future<void> _bootstrap() async {
    if (_challenge != null) {
      // Thách đấu: vào ván ngay, không khôi phục ván cũ.
      if (_c.phase == CaroPhase.setup) {
        _c.newGame(difficulty: _challenge!.difficulty, playerFirst: true);
      }
      return;
    }
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
    if (!mounted || _c.phase != CaroPhase.setup) return;
    if (await CaroController.hasSavedGame()) {
      if (!mounted) return;
      final resume = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.history_rounded),
          title: const Text('Tiếp tục ván đang dở?'),
          content: const Text('Bạn có một ván Caro chưa hoàn thành.'),
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
        if (await _c.restore()) {
          _difficulty = _c.difficulty;
          _playerFirst = _c.playerFirst;
        }
      } else {
        await _c.clearSave();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Luồng ván chơi
  // ---------------------------------------------------------------------------

  void _startNewGame() {
    if (_challenge != null) return;
    DifficultyMemory.save(_gameCode, _difficulty);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_firstKey, _playerFirst))
        .catchError((_) => false);
    setState(() => _preview = null);
    _c.newGame(difficulty: _difficulty, playerFirst: _playerFirst);
  }

  void _onCellTap(int idx) {
    if (!_c.canPlayerMove || !_c.isEmptyCell(idx)) return;
    if (_oneTap || _preview == idx) {
      _confirm(idx);
    } else {
      HapticFeedback.selectionClick();
      setState(() => _preview = idx);
    }
  }

  void _confirm(int idx) {
    setState(() => _preview = null);
    _c.placePlayer(idx);
  }

  ScoreReporter _getScoreReporter(BuildContext context) {
    try {
      return Provider.of<ScoreReporter>(context, listen: false);
    } catch (_) {
      return LocalScoreReporter();
    }
  }

  Future<void> _onFinished() async {
    final result = _c.result;
    if (result == CaroResult.playerWin) HapticFeedback.heavyImpact();
    // Chờ để người chơi nhìn thấy đường thắng.
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    await Future<void>.delayed(Duration(milliseconds: reduce ? 300 : 1100));
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final outcome = await _getScoreReporter(context).submit(_c.toRecord());
    if (!mounted) return;

    final action = await showResultSheet(
      context,
      GameResultData(
        success: result == CaroResult.playerWin,
        title: switch (result) {
          CaroResult.playerWin => 'Bạn thắng!',
          CaroResult.aiWin => 'Máy thắng',
          _ => 'Hoà',
        },
        time: _c.clock.elapsed,
        mistakes: _c.undos,
        mistakesLabel: 'Đi lại',
        moves: _c.playerMoves,
        score: outcome.score,
        isPersonalBest: outcome.isPersonalBest,
      ),
    );
    if (outcome.message != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(outcome.message!)));
    }
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

  void _undo() {
    if (_c.undo()) {
      setState(() => _preview = null);
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _confirmNewGame() async {
    if (_c.isPlaying && _c.history.isNotEmpty) {
      final ok = await confirmExit(
        context,
        title: 'Bắt đầu ván mới?',
        message: 'Ván hiện tại sẽ bị huỷ và không được tính điểm.',
        confirmLabel: 'Ván mới',
        cancelLabel: 'Chơi tiếp',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _preview = null);
    _c.toSetup();
  }

  Future<void> _setOneTap(bool v) async {
    setState(() {
      _oneTap = v;
      _preview = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_oneTapKey, v);
    } catch (_) {}
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
    final phase = _c.phase;
    final inGame = phase != CaroPhase.setup;
    final challenge = _challenge;
    final guard = challenge != null
        ? _c.isPlaying
        : _c.isPlaying && _c.history.isNotEmpty;

    return PopScope(
      canPop: !guard,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final reporter = _getScoreReporter(context);
        if (challenge != null) {
          final ok = await confirmExit(
            context,
            title: 'Bỏ cuộc thách đấu?',
            message: 'Bỏ cuộc sẽ được tính 0 điểm cho ván thách đấu.',
            confirmLabel: 'Bỏ cuộc',
          );
          if (!ok || !mounted) return;
          final record = _c.toAbandonRecord();
          try {
            await reporter.submit(record);
          } catch (_) {}
          if (mounted) nav.pop();
          return;
        }
        final ok = await confirmExit(
          context,
          title: 'Rời khỏi ván?',
          message:
              'Ván đang chơi được lưu lại để tiếp tục sau, và chưa được tính điểm.',
        );
        if (ok && mounted) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title:
              Text(inGame ? 'Caro · ${_c.difficulty.label}' : 'Caro với máy'),
          actions: [
            IconButton(
              tooltip: 'Hướng dẫn chơi',
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: _showOnboarding,
            ),
            PopupMenuButton<String>(
              tooltip: 'Tuỳ chọn',
              onSelected: (v) {
                if (v == 'one_tap') _setOneTap(!_oneTap);
                if (v == 'new') _confirmNewGame();
              },
              itemBuilder: (context) => [
                CheckedPopupMenuItem(
                  value: 'one_tap',
                  checked: _oneTap,
                  child: const Text('Chạm một lần để đánh'),
                ),
                if (inGame && challenge == null)
                  const PopupMenuItem(
                    value: 'new',
                    child: ListTile(
                      leading: Icon(Icons.restart_alt_rounded),
                      title: Text('Ván mới'),
                      contentPadding: EdgeInsets.zero,
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
              if (challenge != null) _ChallengeBanner(challenge: challenge),
              if (inGame) _buildHud(),
              Expanded(child: _buildBoardArea()),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.sm),
      child: Column(
        children: [
          Row(
            children: [
              _TimerChip(clock: _c.clock),
              const SizedBox(width: AppSpacing.sm),
              StatChip(
                  icon: Icons.touch_app_rounded,
                  value: '${_c.playerMoves}',
                  label: 'nước'),
              const SizedBox(width: AppSpacing.sm),
              StatChip(
                icon: Icons.undo_rounded,
                value: '${_c.undos}',
                label: 'đi lại',
                color: _c.undos > 0 ? context.palette.warning : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _TurnPill(controller: _c),
        ],
      ),
    );
  }

  Widget _buildBoardArea() {
    final showConfirm = _preview != null && _c.canPlayerMove && !_oneTap;
    final showCoach = !showConfirm &&
        _c.canPlayerMove &&
        _c.playerMoves == 0 &&
        _c.history.length < 2;
    return Stack(
      children: [
        Positioned.fill(
          child: CaroBoardView(
            key: _boardKey,
            cells: _c.cells,
            version: _c.version,
            lastMove: _c.lastMove,
            preview: _preview,
            winLine: _c.winLine,
            interactive: _c.canPlayerMove,
            onCellTap: _onCellTap,
          ),
        ),
        Positioned(
          left: AppSpacing.screen,
          right: AppSpacing.screen,
          bottom: AppSpacing.md,
          child: AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.normal),
            switchInCurve: AppMotion.enter,
            switchOutCurve: AppMotion.exit,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                  scale: Tween(begin: 0.92, end: 1.0).animate(anim),
                  child: child),
            ),
            child: showConfirm
                ? Center(
                    key: const ValueKey('confirm'),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(220, 52),
                        elevation: 3,
                      ),
                      onPressed: () => _confirm(_preview!),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Đánh vào đây'),
                    ),
                  )
                : showCoach
                    ? Center(
                        key: const ValueKey('coach'),
                        child: _CoachChip(
                          text: _oneTap
                              ? 'Chạm vào một ô để đánh'
                              : 'Chạm một ô để xem trước, chạm lần nữa để đánh',
                        ),
                      )
                    : const SizedBox(key: ValueKey('none'), height: 52),
          ),
        ),
      ],
    );
  }

  Widget _buildBottom() {
    final phase = _c.phase;
    if (phase == CaroPhase.setup) {
      if (_challenge != null) return const SizedBox.shrink();
      return _SetupPanel(
        difficulty: _difficulty,
        onDifficulty: (d) => setState(() => _difficulty = d),
        playerFirst: _playerFirst,
        onPlayerFirst: (v) => setState(() => _playerFirst = v),
        oneTap: _oneTap,
        onOneTap: _setOneTap,
        onStart: _startNewGame,
      );
    }
    final canUndo = _c.canUndo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.xs, AppSpacing.screen, AppSpacing.md),
      child: Row(
        children: [
          _ToolButton(
            icon: Icons.undo_rounded,
            label: 'Đi lại',
            onPressed: canUndo ? _undo : null,
          ),
          _ToolButton(
            icon: (_boardKey.currentState?.isZoomed ?? false)
                ? Icons.zoom_out_map_rounded
                : Icons.zoom_in_rounded,
            label: 'Thu phóng',
            onPressed: () {
              _boardKey.currentState?.toggleZoom();
              setState(() {});
            },
          ),
          if (_challenge == null)
            _ToolButton(
              icon: Icons.restart_alt_rounded,
              label: 'Ván mới',
              onPressed: _confirmNewGame,
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

/// Ai đang đến lượt — icon + chữ (không chỉ dựa vào màu), kiêm chỉ báo "Máy đang nghĩ…".
class _TurnPill extends StatelessWidget {
  final CaroController controller;
  const _TurnPill({required this.controller});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final c = controller;

    IconData icon;
    String label;
    Color tint;
    Widget? leading;
    if (c.phase == CaroPhase.finished) {
      switch (c.result) {
        case CaroResult.playerWin:
          icon = Icons.emoji_events_rounded;
          label = 'Bạn thắng!';
          tint = palette.success;
        case CaroResult.aiWin:
          icon = Icons.smart_toy_rounded;
          label = 'Máy thắng';
          tint = scheme.error;
        default:
          icon = Icons.handshake_rounded;
          label = 'Hoà';
          tint = scheme.onSurfaceVariant;
      }
    } else if (c.isPlayerTurn && !c.thinking) {
      icon = Icons.close_rounded;
      label = 'Lượt của bạn (X)';
      tint = scheme.primary;
    } else {
      icon = Icons.circle_outlined;
      label = c.thinkingVisible ? 'Máy đang nghĩ…' : 'Lượt của máy (O)';
      tint = scheme.tertiary;
      if (c.thinkingVisible) {
        leading = SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: tint),
        );
      }
    }

    return Semantics(
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.normal),
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: tint.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading ?? Icon(icon, size: 20, color: tint),
            const SizedBox(width: AppSpacing.sm),
            Text(label,
                style: text.labelLarge?.copyWith(color: scheme.onSurface)),
          ],
        ),
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
  final bool playerFirst;
  final ValueChanged<bool> onPlayerFirst;
  final bool oneTap;
  final ValueChanged<bool> onOneTap;
  final VoidCallback onStart;

  const _SetupPanel({
    required this.difficulty,
    required this.onDifficulty,
    required this.playerFirst,
    required this.onPlayerFirst,
    required this.oneTap,
    required this.onOneTap,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final hint = switch (difficulty) {
      Difficulty.easy => 'Máy đánh theo thế cờ đơn giản và hay bỏ sót.',
      Difficulty.medium =>
        'Máy chấm điểm từng nước, luôn chặn khi bạn có 4 quân.',
      Difficulty.hard =>
        'Máy tính trước nhiều nước (minimax) — có thể mất tới ~1 giây.',
    };
    return Material(
      color: scheme.surface,
      elevation: 6,
      shadowColor: scheme.shadow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Chọn độ khó', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            DifficultySelector(value: difficulty, onChanged: onDifficulty),
            const SizedBox(height: AppSpacing.sm),
            Text(hint,
                style:
                    text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.md),
            Text('Ai đi trước', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: true,
                    icon: Icon(Icons.close_rounded),
                    label: Text('Bạn đi trước')),
                ButtonSegment(
                    value: false,
                    icon: Icon(Icons.circle_outlined),
                    label: Text('Máy đi trước')),
              ],
              selected: {playerFirst},
              onSelectionChanged: (s) => onPlayerFirst(s.first),
            ),
            const SizedBox(height: AppSpacing.xs),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Chạm một lần để đánh'),
              subtitle:
                  const Text('Bỏ bước xem trước — dành cho người đã quen'),
              value: oneTap,
              onChanged: onOneTap,
            ),
            const SizedBox(height: AppSpacing.xs),
            PrimaryButton(
              label: 'Bắt đầu ván',
              icon: Icons.play_arrow_rounded,
              onPressed: onStart,
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachChip extends StatelessWidget {
  final String text;
  const _CoachChip({required this.text});

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
          Flexible(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onInverseSurface),
            ),
          ),
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
            Text('Cách chơi Caro', style: text.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            step(Icons.flag_rounded, 'Xếp 5 quân liên tiếp',
                'Bàn 15×15. Ai có 5 quân (hoặc hơn) thẳng hàng ngang, dọc hay chéo trước thì thắng. Bạn là X, máy là O.'),
            step(Icons.touch_app_rounded, 'Chạm hai lần để đánh',
                'Chạm một ô để xem trước quân, rồi bấm "Đánh vào đây" hoặc chạm lại đúng ô đó. Chạm sai chỉ cần chạm ô khác. Có thể bật "Chạm một lần" trong tuỳ chọn.'),
            step(Icons.zoom_in_rounded, 'Phóng to để chạm chính xác',
                'Chụm hai ngón để phóng to, kéo để di chuyển. Chạm đúp nhanh để chuyển giữa vừa khung và phóng 2×. "Đi lại" xoá nước của bạn và nước đáp trả của máy, tính 1 lần đi lại.'),
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
