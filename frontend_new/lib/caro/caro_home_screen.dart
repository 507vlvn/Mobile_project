import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_new/auth/auth_controller.dart';
import 'package:frontend_new/core/network/api_client.dart';
import 'package:frontend_new/caro/caro_controller.dart';
import 'package:frontend_new/caro/caro_screen.dart';
import 'package:frontend_new/caro/logic/caro_board.dart';
import 'package:frontend_new/caro/models/caro_mode.dart';
import 'package:frontend_new/caro/models/difficulty.dart';
import 'package:frontend_new/caro/theme/app_tokens.dart';
import 'package:frontend_new/caro/theme/caro_theme.dart';
import 'package:frontend_new/caro/widgets/caro_board_view.dart';
import 'package:frontend_new/caro/widgets/difficulty_selector.dart';
import 'package:frontend_new/caro/widgets/primary_button.dart';
import 'package:frontend_new/core/realtime/match_models.dart';
import 'package:frontend_new/pvp/pvp_lobby_screen.dart';

/// Màn hình chọn chế độ chơi Caro: Thiết kế tinh gọn, hiện đại, xem trước bàn cờ trực tiếp.
class CaroHomeScreen extends StatefulWidget {
  const CaroHomeScreen({super.key});

  @override
  State<CaroHomeScreen> createState() => _CaroHomeScreenState();
}

class _CaroHomeScreenState extends State<CaroHomeScreen> with WidgetsBindingObserver {
  static const _gameCode = 'CARO';
  static const _oneTapKey = 'caro_one_tap';
  static const _firstKey = 'caro_player_first';
  static const _themeKey = 'caro_board_theme';

  int? _lastUserId;
  CaroGameMode _selectedMode = CaroGameMode.pve;
  Difficulty _difficulty = Difficulty.hard;
  bool _playerFirst = true;
  bool _oneTap = false;
  CaroBoardTheme _boardTheme = CaroBoardTheme.wood;
  bool _hasSaved = false;

  late final Uint8List _previewCells;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _previewCells = Uint8List(kCaroCells);
    _initPreviewBoard();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrefs());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPrefs();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final auth = context.watch<AuthController>();
      final currentUserId = auth.currentUser?.userId;
      if (_lastUserId != currentUserId) {
        _lastUserId = currentUserId;
        _loadPrefs();
      }
    } catch (_) {}
  }

  void _initPreviewBoard() {
    // Thế cờ mẫu kinh điển quanh tâm bàn cờ để người dùng ngắm skin
    _previewCells[caroIndex(7, 7)] = kCaroPlayer; // X (Tâm)
    _previewCells[caroIndex(7, 8)] = kCaroAi;     // O
    _previewCells[caroIndex(6, 7)] = kCaroPlayer; // X
    _previewCells[caroIndex(8, 7)] = kCaroAi;     // O
    _previewCells[caroIndex(6, 6)] = kCaroPlayer; // X
    _previewCells[caroIndex(8, 8)] = kCaroAi;     // O
    _previewCells[caroIndex(5, 5)] = kCaroPlayer; // X
  }

  Future<void> _loadPrefs() async {
    final d = await DifficultyMemory.load(_gameCode);
    int? userId;
    var hasSave = false;

    if (mounted) {
      try {
        final auth = context.read<AuthController>();
        userId = auth.currentUser?.userId;
        if (auth.isAuthenticated && userId != null) {
          try {
            final api = context.read<ApiClient>();
            final serverSave = await api.getCaroSavedGame();
            if (serverSave != null && serverSave.history.isNotEmpty) {
              hasSave = true;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                CaroController.saveKeyFor(userId),
                jsonEncode({
                  'difficulty': serverSave.difficulty,
                  'playerFirst': serverSave.playerFirst,
                  'gameMode': serverSave.gameMode,
                  'hintsRemaining': serverSave.hintsRemaining,
                  'history': serverSave.history,
                  'undos': serverSave.undos,
                  'seconds': serverSave.elapsedSeconds,
                }),
              );
            } else {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(CaroController.saveKeyFor(userId));
              hasSave = false;
            }
          } catch (_) {
            hasSave = await CaroController.hasSavedGame(userId: userId);
          }
        } else {
          hasSave = await CaroController.hasSavedGame(userId: null);
        }
      } catch (_) {
        hasSave = await CaroController.hasSavedGame(userId: null);
      }
    } else {
      hasSave = await CaroController.hasSavedGame(userId: null);
    }

    var oneTap = false, first = true;
    var theme = CaroBoardTheme.wood;
    try {
      final prefs = await SharedPreferences.getInstance();
      oneTap = prefs.getBool(_oneTapKey) ?? false;
      first = prefs.getBool(_firstKey) ?? true;
      final savedTheme = prefs.getString(_themeKey);
      if (savedTheme != null) theme = CaroBoardTheme.fromName(savedTheme);
    } catch (_) {}
    if (mounted) {
      setState(() {
        _difficulty = d;
        _oneTap = oneTap;
        _playerFirst = first;
        _boardTheme = theme;
        _hasSaved = hasSave;
      });
    }
  }

  void _startGame() {
    DifficultyMemory.save(_gameCode, _difficulty);
    SharedPreferences.getInstance().then((p) {
      p.setBool(_firstKey, _playerFirst);
      p.setString(_themeKey, _boardTheme.name);
    }).catchError((_) {});

    int? userId;
    try {
      userId = context.read<AuthController>().currentUser?.userId;
    } catch (_) {}

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaroScreen(
          initialMode: _selectedMode,
          initialDifficulty: _difficulty,
          initialPlayerFirst: _playerFirst,
          initialTheme: _boardTheme,
          userId: userId,
        ),
      ),
    ).then((_) => _loadPrefs());
  }

  void _resumeSavedGame() {
    int? userId;
    try {
      userId = context.read<AuthController>().currentUser?.userId;
    } catch (_) {}

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaroScreen(
          resumeSaved: true,
          userId: userId,
        ),
      ),
    ).then((_) => _loadPrefs());
  }
  void _setBoardTheme(CaroBoardTheme theme) {
    setState(() => _boardTheme = theme);
    SharedPreferences.getInstance().then((p) {
      p.setString(_themeKey, theme.name);
    }).catchError((_) {});
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cờ Caro'),
        actions: [
          IconButton(
            tooltip: 'Chọn chủ đề',
            icon: const Icon(Icons.palette_outlined),
            onPressed: _showThemeSelector,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screen,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Thẻ tiếp tục ván dở (chỉ hiện nếu có ván chưa kết thúc)
              if (_hasSaved) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, size: 22, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bạn có một ván chưa kết thúc',
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: _resumeSavedGame,
                        child: const Text('Chơi tiếp'),
                      ),
                    ],
                  ),
                ),
              ],

              // 2. Bộ chọn Chế độ chơi (Đấu máy | 2 Người | Sinh tồn)
              Text('Chế độ chơi', style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
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
                selected: {_selectedMode},
                onSelectionChanged: (s) => setState(() => _selectedMode = s.first),
              ),
              const SizedBox(height: AppSpacing.md),

              // 3. Khung thiết lập chi tiết cho chế độ đang chọn
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _selectedMode.icon,
                            size: 20,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedMode.description,
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // Cấu hình Độ khó (chỉ hiện khi Đấu máy hoặc Sinh tồn)
                      if (_selectedMode != CaroGameMode.pvpLocal) ...[
                        Text('Độ khó', style: text.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        DifficultySelector(
                          value: _difficulty,
                          onChanged: (d) => setState(() => _difficulty = d),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      // Cấu hình Lượt đi
                      Text(
                        _selectedMode == CaroGameMode.pvpLocal
                            ? 'Người đi trước (Quân X)'
                            : 'Ai đi trước',
                        style: text.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: true,
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: Text(_selectedMode == CaroGameMode.pvpLocal
                                ? 'Người 1 (X)'
                                : 'Bạn đi trước (X)'),
                          ),
                          ButtonSegment(
                            value: false,
                            icon: const Icon(Icons.circle_outlined, size: 16),
                            label: Text(_selectedMode == CaroGameMode.pvpLocal
                                ? 'Người 2 (O)'
                                : 'Máy đi trước (O)'),
                          ),
                        ],
                        selected: {_playerFirst},
                        onSelectionChanged: (s) => setState(() => _playerFirst = s.first),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // 4. Chọn chủ đề bàn cờ (8 Chủ đề đa phong cách)
              Row(
                children: [
                  Icon(Icons.palette_rounded, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text('Chủ đề bàn cờ', style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _boardTheme.label,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: CaroBoardTheme.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final t = CaroBoardTheme.values[index];
                    final isSelected = _boardTheme == t;
                    return ChoiceChip(
                      avatar: Icon(
                        t.icon,
                        size: 16,
                        color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                      ),
                      label: Text(t.label, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) _setBoardTheme(t);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // 5. Khung xem trước bàn cờ (Live Board Preview)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  height: 270,
                  padding: const EdgeInsets.all(8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CaroBoardView(
                        cells: _previewCells,
                        version: 1,
                        lastMove: caroIndex(5, 5),
                        hintCell: caroIndex(9, 9),
                        theme: _boardTheme,
                        interactive: false,
                        onCellTap: (_) {},
                      ),
                      Positioned(
                        top: 6,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_boardTheme.icon, size: 12, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                'Xem trước: ${_boardTheme.label}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // 6. Cài đặt phụ (Thao tác 1 chạm - Thẻ riêng biệt không gây tràn layout)
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                child: SwitchListTile(
                  dense: true,
                  secondary: Icon(Icons.touch_app_rounded, size: 20, color: scheme.primary),
                  title: const Text('Thao tác 1 chạm', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Đánh cờ ngay khi chạm không cần bấm nút Đặt', style: TextStyle(fontSize: 11)),
                  value: _oneTap,
                  onChanged: (v) {
                    setState(() => _oneTap = v);
                    SharedPreferences.getInstance().then((p) {
                      p.setBool(_oneTapKey, v);
                    }).catchError((_) {});
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 7. Nút Bắt đầu chơi
              PrimaryButton(
                label: 'Bắt đầu chơi',
                icon: Icons.play_arrow_rounded,
                onPressed: _startGame,
              ),
              const SizedBox(height: AppSpacing.sm),
              // Đấu online với người khác (xếp hạng / mời bạn bè) — sảnh Đối kháng
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const PvpLobbyScreen(initialGame: kGameCaro, embedded: false),
                )),
                icon: const Icon(Icons.public_rounded),
                label: const Text('Đấu online với người khác'),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
