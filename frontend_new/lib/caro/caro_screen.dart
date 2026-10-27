import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_new/auth/auth_controller.dart';
import 'package:frontend_new/core/network/api_client.dart';
import 'package:frontend_new/caro/models/caro_mode.dart';
import 'package:frontend_new/caro/models/challenge_context.dart';
import 'package:frontend_new/caro/models/difficulty.dart';
import 'package:frontend_new/caro/services/score_reporter.dart';
import 'package:frontend_new/caro/theme/app_tokens.dart';
import 'package:frontend_new/caro/theme/caro_theme.dart';
import 'package:frontend_new/caro/widgets/difficulty_selector.dart';
import 'package:frontend_new/caro/widgets/feedback_states.dart';
import 'package:frontend_new/caro/widgets/game_timer.dart';
import 'package:frontend_new/caro/widgets/primary_button.dart';
import 'package:frontend_new/caro/widgets/result_sheet.dart';
import 'caro_controller.dart';
import 'logic/caro_board.dart';
import 'widgets/caro_board_view.dart';

/// Caro đa chế độ: PvE, 2 Người cùng máy, Cờ sinh tồn (6 quân), Hỗ trợ Theme & Hint.
class CaroScreen extends StatefulWidget {
  const CaroScreen({
    super.key,
    @visibleForTesting this.controller,
    this.challenge,
    this.initialMode,
    this.initialDifficulty,
    this.initialPlayerFirst,
    this.initialTheme,
    this.resumeSaved = false,
    this.userId,
  });

  /// ID người dùng hiện tại (nếu có đăng nhập).
  final int? userId;

  /// Khác null = ván thách đấu (người chơi đi trước, không lưu ván).
  final ChallengeContext? challenge;

  /// Chỉ dùng cho test/chụp màn hình.
  final CaroController? controller;

  /// Chế độ chơi khởi tạo từ màn hình Home.
  final CaroGameMode? initialMode;

  /// Độ khó khởi tạo từ màn hình Home.
  final Difficulty? initialDifficulty;

  /// Lượt đi trước khởi tạo từ màn hình Home.
  final bool? initialPlayerFirst;

  /// Chủ đề bàn cờ khởi tạo từ màn hình Home.
  final CaroBoardTheme? initialTheme;

  /// Mở và tiếp tục ván đang lưu từ trước.
  final bool resumeSaved;

  @override
  State<CaroScreen> createState() => _CaroScreenState();
}

class _CaroScreenState extends State<CaroScreen> with WidgetsBindingObserver {
  static const _gameCode = 'CARO';

  int? get _effectiveUserId {
    if (widget.userId != null) return widget.userId;
    try {
      return context.read<AuthController>().currentUser?.userId;
    } catch (_) {
      return null;
    }
  }
  static const _onboardingKey = 'caro_onboarding_done';
  static const _oneTapKey = 'caro_one_tap';
  static const _firstKey = 'caro_player_first';
  static const _themeKey = 'caro_board_theme';
  static const _modeKey = 'caro_saved_mode';

  late final CaroController _c;
  late final bool _ownsController;
  ChallengeContext? get _challenge => widget.challenge;
  final _boardKey = GlobalKey<CaroBoardViewState>();

  CaroGameMode _mode = CaroGameMode.pve;
  CaroBoardTheme _boardTheme = CaroBoardTheme.wood;
  Difficulty _difficulty = Difficulty.hard;
  bool _playerFirst = true;
  bool _oneTap = false;
  int? _preview;
  bool _resultHandled = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _c = widget.controller ?? CaroController(challenge: widget.challenge, userId: widget.userId);
    WidgetsBinding.instance.addObserver(this);
    _c.addListener(_onControllerChanged);
    if (_challenge == null) {
      _loadPrefs();
    } else {
      _difficulty = _challenge!.difficulty;
      _mode = CaroGameMode.pve;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c.userId ??= _effectiveUserId;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.removeListener(_onControllerChanged);
    if (_ownsController) {
      _c.save(customUserId: _effectiveUserId);
      try {
        final auth = context.read<AuthController>();
        if (auth.isAuthenticated) {
          final api = context.read<ApiClient>();
          _c.saveGameToServer(api);
        }
      } catch (_) {}
      _c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _c.resume();
      _syncLatestFromServer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _c.pause();
      _c.save(customUserId: _effectiveUserId);
      try {
        final auth = context.read<AuthController>();
        if (auth.isAuthenticated) {
          final api = context.read<ApiClient>();
          _c.saveGameToServer(api);
        }
      } catch (_) {}
    }
  }

  Future<void> _syncLatestFromServer() async {
    if (!mounted || _challenge != null) return;
    try {
      final auth = context.read<AuthController>();
      if (auth.isAuthenticated) {
        final api = context.read<ApiClient>();
        final serverSave = await api.getCaroSavedGame();
        if (serverSave != null && serverSave.history.isNotEmpty) {
          if (serverSave.history.length != _c.history.length) {
            _c.restoreFromSavedGame(serverSave);
            if (mounted) setState(() {});
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadPrefs() async {
    final d = await DifficultyMemory.load(_gameCode);
    var oneTap = false, first = true;
    var theme = CaroBoardTheme.wood;
    var mode = CaroGameMode.pve;
    try {
      final prefs = await SharedPreferences.getInstance();
      oneTap = prefs.getBool(_oneTapKey) ?? false;
      first = prefs.getBool(_firstKey) ?? true;
      final savedTheme = prefs.getString(_themeKey);
      if (savedTheme != null) theme = CaroBoardTheme.fromName(savedTheme);
      final savedMode = prefs.getString(_modeKey);
      if (savedMode != null) mode = CaroGameMode.fromName(savedMode);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _difficulty = widget.initialDifficulty ?? d;
        _oneTap = oneTap;
        _playerFirst = widget.initialPlayerFirst ?? first;
        _boardTheme = widget.initialTheme ?? theme;
        _mode = widget.initialMode ?? mode;
      });
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {
      if (!_c.canPlayerMove) _preview = null;
    });
    if (_c.phase == CaroPhase.playing && _c.history.isNotEmpty) {
      try {
        final auth = context.read<AuthController>();
        if (auth.isAuthenticated) {
          final api = context.read<ApiClient>();
          _c.saveGameToServer(api);
        }
      } catch (_) {}
    }

    if (_c.phase == CaroPhase.playing && _c.history.isNotEmpty) {
      try {
        final auth = context.read<AuthController>();
        if (auth.isAuthenticated) {
          final api = context.read<ApiClient>();
          _c.saveGameToServer(api);
        }
      } catch (_) {}
    }

    if (_c.phase == CaroPhase.finished && !_resultHandled) {
      _resultHandled = true;
      _onFinished();
    } else if (_c.phase != CaroPhase.finished) {
      _resultHandled = false;
    }
  }

  Future<void> _bootstrap() async {
    if (_challenge != null) {
      if (_c.phase == CaroPhase.setup) {
        _c.newGame(
          difficulty: _challenge!.difficulty,
          playerFirst: true,
          mode: CaroGameMode.pve,
        );
      }
      return;
    }

    // 1. Nếu yêu cầu tiếp tục ván dở từ màn hình Home
    if (widget.resumeSaved) {
      final uId = _effectiveUserId;
      _c.userId = uId;
      var restored = false;

      // Ưu tiên cao nhất: Tải bản lưu mới nhất từ Cloud nếu đã đăng nhập
      if (mounted) {
        try {
          final auth = context.read<AuthController>();
          if (auth.isAuthenticated && uId != null) {
            final api = context.read<ApiClient>();
            final serverSave = await api.getCaroSavedGame();
            if (serverSave != null && serverSave.history.isNotEmpty) {
              if (_c.restoreFromSavedGame(serverSave)) {
                _difficulty = _c.difficulty;
                _playerFirst = _c.playerFirst;
                _mode = _c.gameMode;
                restored = true;
                return;
              }
            }
          }
        } catch (_) {}
      }

      // Nếu không có mạng hoặc không có trên Cloud, khôi phục từ bộ nhớ thiết bị
      if (!restored && await CaroController.hasSavedGame(userId: uId)) {
        if (await _c.restore(customUserId: uId)) {
          _difficulty = _c.difficulty;
          _playerFirst = _c.playerFirst;
          _mode = _c.gameMode;
          return;
        }
      }
    }

    // 2. Nếu chuyển từ màn hình Home với cấu hình cụ thể
    if (widget.initialMode != null) {
      _mode = widget.initialMode!;
      _difficulty = widget.initialDifficulty ?? _difficulty;
      _playerFirst = widget.initialPlayerFirst ?? _playerFirst;
      _c.newGame(
        difficulty: _difficulty,
        playerFirst: _playerFirst,
        mode: _mode,
      );
      return;
    }

    // 3. Khởi tạo mặc định nếu vào tự do
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
          _mode = _c.gameMode;
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
    try {
      final auth = context.read<AuthController>();
      if (auth.isAuthenticated) {
        final api = context.read<ApiClient>();
        _c.deleteGameFromServer(api);
      }
    } catch (_) {}
    _c.clearSave(customUserId: _effectiveUserId);
    DifficultyMemory.save(_gameCode, _difficulty);
    SharedPreferences.getInstance().then((p) {
      p.setBool(_firstKey, _playerFirst);
      p.setString(_modeKey, _mode.name);
    }).catchError((_) {});
    setState(() => _preview = null);
    _c.newGame(
      difficulty: _difficulty,
      playerFirst: _playerFirst,
      mode: _mode,
    );
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

  Future<void> _requestHint() async {
    if (!_c.canPlayerMove || _c.hintsRemaining <= 0) return;
    HapticFeedback.mediumImpact();
    final hint = await _c.requestHint();
    if (hint != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Gợi ý: Hãy xem ô phát sáng trên bàn cờ! Còn ${_c.hintsRemaining} lần.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
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
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    await Future<void>.delayed(Duration(milliseconds: reduce ? 300 : 1100));
    if (!mounted) return;

    final isPvp = _c.isPvP;
    final title = isPvp
        ? (result == CaroResult.playerWin
            ? 'Người chơi 1 (X) thắng!'
            : result == CaroResult.aiWin
                ? 'Người chơi 2 (O) thắng!'
                : 'Hoà cờ')
        : (result == CaroResult.playerWin
            ? 'Bạn thắng!'
            : result == CaroResult.aiWin
                ? 'Máy thắng'
                : 'Hoà');

    final messenger = ScaffoldMessenger.of(context);
    final outcome = isPvp
        ? const ReportOutcome(score: 1000, synced: false)
        : await _getScoreReporter(context).submit(_c.toRecord());
    if (!mounted) return;

    final action = await showResultSheet(
      context,
      GameResultData(
        success: result == CaroResult.playerWin,
        title: title,
        time: _c.clock.elapsed,
        mistakes: _c.undos,
        mistakesLabel: 'Đi lại',
        moves: isPvp ? _c.history.length : _c.playerMoves,
        score: outcome.score,
        isPersonalBest: outcome.isPersonalBest,
      ),
    );
    if (mounted) {
      try {
        final auth = context.read<AuthController>();
        if (auth.isAuthenticated) {
          final api = context.read<ApiClient>();
          _c.deleteGameFromServer(api);
        }
      } catch (_) {}
    }

    if (outcome.message != null && !isPvp) {
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
      Navigator.of(context).pop();
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
    _startNewGame();
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

  Future<void> _setBoardTheme(CaroBoardTheme theme) async {
    setState(() => _boardTheme = theme);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, theme.name);
    } catch (_) {}
  }

  void _showThemeSelector() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.lg,
            AppSpacing.screen,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chọn chủ đề bàn cờ', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              for (final t in CaroBoardTheme.values)
                ListTile(
                  leading: Icon(t.icon, color: _boardTheme == t ? Theme.of(context).colorScheme.primary : null),
                  title: Text(t.label),
                  trailing: _boardTheme == t
                      ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    _setBoardTheme(t);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
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
        final auth = context.read<AuthController>();
        final api = context.read<ApiClient>();
        final ok = await confirmExit(
          context,
          title: 'Rời khỏi ván?',
          message:
              'Ván đang chơi được lưu lại để tiếp tục sau, và chưa được tính điểm.',
        );
        if (ok && mounted) {
          _c.save(customUserId: _effectiveUserId);
          try {
            if (auth.isAuthenticated) {
              await _c.saveGameToServer(api);
            }
          } catch (_) {}
          if (mounted) nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            inGame
                ? 'Caro · ${_c.gameMode.label}'
                : 'Cờ Caro',
          ),
          actions: [
            IconButton(
              tooltip: 'Đổi chủ đề',
              icon: const Icon(Icons.palette_outlined),
              onPressed: _showThemeSelector,
            ),
            IconButton(
              tooltip: 'Hướng dẫn chơi',
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: _showOnboarding,
            ),
            PopupMenuButton<String>(
              tooltip: 'Tuỳ chọn',
              onSelected: (v) {
                if (v == 'theme') _showThemeSelector();
                if (v == 'one_tap') _setOneTap(!_oneTap);
                if (v == 'new') _confirmNewGame();
              },
              itemBuilder: (context) => [
                CheckedPopupMenuItem(
                  value: 'one_tap',
                  checked: _oneTap,
                  child: const Text('Chạm một lần để đánh'),
                ),
                const PopupMenuItem(
                  value: 'theme',
                  child: ListTile(
                    leading: Icon(Icons.palette_rounded),
                    title: Text('Chủ đề bàn cờ'),
                    contentPadding: EdgeInsets.zero,
                  ),
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

  /// Cụm nhận biết lượt đi rõ nét 100% (Player 1 vs Player 2 / Máy)
  Widget _buildHud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        AppSpacing.sm,
      ),
      child: CaroPlayersHud(controller: _c),
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
            hintCell: _c.hintCell,
            fadingWarningX: _c.fadingWarningX,
            fadingWarningO: _c.fadingWarningO,
            theme: _boardTheme,
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
                child: child,
              ),
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
        mode: _mode,
        onMode: (m) => setState(() => _mode = m),
        difficulty: _difficulty,
        onDifficulty: (d) => setState(() => _difficulty = d),
        playerFirst: _playerFirst,
        onPlayerFirst: (v) => setState(() => _playerFirst = v),
        oneTap: _oneTap,
        onOneTap: _setOneTap,
        theme: _boardTheme,
        onTheme: _setBoardTheme,
        onStart: _startNewGame,
      );
    }
    final canUndo = _c.canUndo;
    final canHint = _c.hintsRemaining > 0 && _c.canPlayerMove && _challenge == null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.xs,
        AppSpacing.screen,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          _ToolButton(
            icon: Icons.undo_rounded,
            label: 'Đi lại',
            onPressed: canUndo ? _undo : null,
          ),
          _ToolButton(
            icon: Icons.lightbulb_rounded,
            label: 'Gợi ý (${_c.hintsRemaining})',
            onPressed: canHint ? _requestHint : null,
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
          _ToolButton(
            icon: Icons.palette_rounded,
            label: 'Chủ đề',
            onPressed: _showThemeSelector,
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
// Widget HUD 2 Người chơi đối đỉnh — Nhận diện lượt đi cực nét
// =============================================================================

class CaroPlayersHud extends StatelessWidget {
  final CaroController controller;

  const CaroPlayersHud({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final scheme = Theme.of(context).colorScheme;
    final isFinished = c.phase == CaroPhase.finished;

    final isP1Turn = !isFinished && c.currentTurnPlayer == kCaroPlayer;
    final isP2Turn = !isFinished && c.currentTurnPlayer == kCaroAi;

    final p1Name = c.isPvP ? 'Người chơi 1' : 'Bạn';
    final p2Name = c.isPvP ? 'Người chơi 2' : 'Máy';

    final p1Subtext = c.isFading
        ? '${c.playerXStones.length}/${CaroController.kFadingStoneLimit} quân'
        : '${c.playerMoves} nước';

    final p2Subtext = c.thinkingVisible
        ? 'Đang tính...'
        : c.isFading
            ? '${c.playerOStones.length}/${CaroController.kFadingStoneLimit} quân'
            : '${c.opponentMoves} nước';

    final p1Won = isFinished && c.result == CaroResult.playerWin;
    final p2Won = isFinished && c.result == CaroResult.aiWin;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          // 1. Thẻ Player 1 (X)
          Expanded(
            child: _PlayerCard(
              name: p1Name,
              subtext: p1Subtext,
              symbol: 'X',
              symbolColor: scheme.primary,
              icon: Icons.person_rounded,
              isActive: isP1Turn,
              isWinner: p1Won,
              isThinking: false,
            ),
          ),

          // 2. Thông tin trung tâm (Timer + Lượt)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      GameTimerText(
                        clock: c.clock,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedRotation(
                  turns: isP2Turn ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: isFinished
                        ? scheme.outline
                        : (isP1Turn ? scheme.primary : scheme.tertiary),
                  ),
                ),
              ],
            ),
          ),

          // 3. Thẻ Player 2 (O)
          Expanded(
            child: _PlayerCard(
              name: p2Name,
              subtext: p2Subtext,
              symbol: 'O',
              symbolColor: scheme.tertiary,
              icon: c.isPvP ? Icons.person_rounded : Icons.smart_toy_rounded,
              isActive: isP2Turn,
              isWinner: p2Won,
              isThinking: c.thinkingVisible,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final String name;
  final String subtext;
  final String symbol;
  final Color symbolColor;
  final IconData icon;
  final bool isActive;
  final bool isWinner;
  final bool isThinking;

  const _PlayerCard({
    required this.name,
    required this.subtext,
    required this.symbol,
    required this.symbolColor,
    required this.icon,
    required this.isActive,
    required this.isWinner,
    required this.isThinking,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final bgColor = isWinner
        ? Colors.amber.withValues(alpha: 0.2)
        : isActive
            ? symbolColor.withValues(alpha: 0.16)
            : scheme.surface.withValues(alpha: 0.5);

    final borderColor = isWinner
        ? Colors.amber
        : isActive
            ? symbolColor
            : Colors.transparent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor, width: isActive || isWinner ? 2.0 : 1.0),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: symbolColor.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: symbolColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  symbol,
                  style: TextStyle(
                    color: symbolColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    fontWeight: isActive || isWinner ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
              if (isWinner)
                const Text('👑', style: TextStyle(fontSize: 16))
              else if (isActive)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: symbolColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (isThinking)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: symbolColor),
                  ),
                ),
              Expanded(
                child: Text(
                  subtext,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    fontSize: 11,
                    color: isActive ? scheme.onSurface : scheme.onSurfaceVariant,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
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
            constraints: const BoxConstraints(minHeight: 52),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        color: color,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupPanel extends StatelessWidget {
  final CaroGameMode mode;
  final ValueChanged<CaroGameMode> onMode;
  final Difficulty difficulty;
  final ValueChanged<Difficulty> onDifficulty;
  final bool playerFirst;
  final ValueChanged<bool> onPlayerFirst;
  final bool oneTap;
  final ValueChanged<bool> onOneTap;
  final CaroBoardTheme theme;
  final ValueChanged<CaroBoardTheme> onTheme;
  final VoidCallback onStart;

  const _SetupPanel({
    required this.mode,
    required this.onMode,
    required this.difficulty,
    required this.onDifficulty,
    required this.playerFirst,
    required this.onPlayerFirst,
    required this.oneTap,
    required this.onOneTap,
    required this.theme,
    required this.onTheme,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      elevation: 6,
      shadowColor: scheme.shadow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.md,
          AppSpacing.screen,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Chọn Chế độ chơi
            Text('Chế độ chơi', style: text.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            SegmentedButton<CaroGameMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: CaroGameMode.pve,
                  icon: Icon(Icons.smart_toy_rounded, size: 18),
                  label: Text('Đấu máy'),
                ),
                ButtonSegment(
                  value: CaroGameMode.pvpLocal,
                  icon: Icon(Icons.people_rounded, size: 18),
                  label: Text('2 Người'),
                ),
                ButtonSegment(
                  value: CaroGameMode.fading,
                  icon: Icon(Icons.hourglass_top_rounded, size: 18),
                  label: Text('Sinh tồn'),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (s) => onMode(s.first),
            ),
            const SizedBox(height: 4),
            Text(
              mode.description,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.sm),

            // 2. Chọn Độ khó (chỉ hiện khi đấu máy hoặc sinh tồn với máy)
            if (mode != CaroGameMode.pvpLocal) ...[
              Text('Độ khó', style: text.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              DifficultySelector(value: difficulty, onChanged: onDifficulty),
              const SizedBox(height: AppSpacing.sm),
            ],

            // 3. Ai đi trước
            Text(
              mode == CaroGameMode.pvpLocal ? 'Ai đi trước (Quân X)' : 'Ai đi trước',
              style: text.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(mode == CaroGameMode.pvpLocal ? 'Người 1 đi trước' : 'Bạn đi trước'),
                ),
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.circle_outlined, size: 18),
                  label: Text(mode == CaroGameMode.pvpLocal ? 'Người 2 đi trước' : 'Máy đi trước'),
                ),
              ],
              selected: {playerFirst},
              onSelectionChanged: (s) => onPlayerFirst(s.first),
            ),
            const SizedBox(height: AppSpacing.xs),

            // 4. Chọn nhanh Theme bàn cờ
            Row(
              children: [
                Text('Chủ đề: ', style: text.labelMedium),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final t in CaroBoardTheme.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(t.label, style: const TextStyle(fontSize: 12)),
                              selected: theme == t,
                              onSelected: (_) => onTheme(t),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Chạm một lần để đánh'),
              subtitle: const Text('Bỏ bước xem trước — thao tác nhanh hơn'),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.inverseSurface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded, size: 18, color: scheme.onInverseSurface),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onInverseSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hướng dẫn chơi Caro
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: AppSpacing.md),
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cách chơi Caro', style: text.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              step(
                Icons.sports_esports_rounded,
                'Các chế độ chơi',
                '• Đấu với Máy (PvE): Luyện tập từ Dễ đến Khó.\n'
                '• 2 Người (Cùng máy): Chơi luân phiên với bạn bè trên cùng thiết bị.\n'
                '• Cờ sinh tồn (Fading): Mỗi bên chỉ giữ tối đa 6 quân. Đánh quân thứ 7 thì quân đầu tiên sẽ tự động tan biến!',
              ),
              step(
                Icons.lightbulb_rounded,
                'Gợi ý nước đi',
                'Khi bị bế tắc, bấm nút "Gợi ý" để AI tính toán nước cờ tối ưu nhất và hiển thị vòng hào quang vàng trên bàn cờ (tối đa 3 lần/ván).',
              ),
              step(
                Icons.palette_rounded,
                'Đổi giao diện bàn cờ',
                'Tuỳ ý chọn giữa Gỗ cổ điển, Vở ô ly học sinh, Cờ vây đá bóng 3D hoặc Cyberpunk Neon phát sáng.',
              ),
              step(
                Icons.touch_app_rounded,
                'Thao tác đặt quân',
                'Chạm một ô để xem trước quân, bấm "Đánh vào đây" hoặc chạm lần nữa để xác nhận. Bạn có thể chụm 2 ngón để phóng to thu nhỏ.',
              ),
              PrimaryButton(
                label: 'Đã hiểu',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
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
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.sports_esports_rounded, size: 20, color: scheme.onPrimaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ván thách đấu · ${challenge.difficulty.label}',
                  style: text.labelLarge?.copyWith(color: scheme.onPrimaryContainer),
                ),
                Text(
                  'Cùng đề với đối thủ — điểm cao hơn sẽ thắng',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
