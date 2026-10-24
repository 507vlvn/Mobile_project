import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/difficulty.dart';
import '../../core/network/api_client.dart';
import '../../core/network/models.dart';
import '../../core/services/shell_navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/player_card.dart';
import '../../core/widgets/rank_badge.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../auth/user_avatar.dart';
import '../history/game_meta.dart';
import '../profile/player_profile_sheet.dart';
import 'leaderboard_controller.dart';
import 'leaderboard_repository.dart';

/// Bảng xếp hạng v2 (TASKS_V2 §2.2): tab game; Đối kháng | Kỷ lục; độ khó (Kỷ lục);
/// Toàn server | Bạn bè; Mùa này | Mọi thời điểm; top 3 nổi bật; thanh "Hạng của bạn"
/// dính ở cuối; chạm một dòng để mở thẻ hồ sơ.
class LeaderboardScreen extends StatefulWidget {
  /// Cho test/ảnh chụp truyền sẵn controller (đã có dữ liệu giả).
  @visibleForTesting
  final LeaderboardController? controllerOverride;

  const LeaderboardScreen({super.key, this.controllerOverride});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: GameMeta.all.length, vsync: this)
        ..addListener(_onTab);
  LeaderboardController? _c;
  bool _started = false;
  int? _lastUserId;
  bool _wasVisible = false;

  LeaderboardController get c => _c!;

  void _onTab() {
    if (_tabs.indexIsChanging) return;
    final code = GameMeta.all[_tabs.index].code;
    c.select(c.selection.copyWith(gameCode: code));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c ??= widget.controllerOverride ??
        LeaderboardController(
            repository: LeaderboardRepository(context.read<ApiClient>()));
    final auth = Provider.of<AuthController>(context);
    final userId = auth.isAuthenticated ? auth.currentUser?.userId : null;
    final visible = TickerMode.valuesOf(context).enabled;
    if (!_started) {
      _started = true;
      _lastUserId = userId;
      c.setUser(userId);
      // Chỉ tải khi tab hiển thị lần đầu (IndexedStack tắt ticker của tab ẩn).
      if (visible) _start();
    } else {
      if (userId != _lastUserId) {
        _lastUserId = userId;
        c.setUser(userId);
      }
      if (visible && !_wasVisible && !_restored) _start();
    }
    _wasVisible = visible;
  }

  bool _restored = false;

  void _start() {
    _restored = true;
    if (widget.controllerOverride != null) {
      c.reload();
      return;
    }
    c.restore().then((_) {
      if (!mounted) return;
      final i = GameMeta.all.indexWhere((g) => g.code == c.selection.gameCode);
      if (i >= 0 && i != _tabs.index) _tabs.index = i;
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    if (widget.controllerOverride == null) _c?.dispose();
    super.dispose();
  }

  void _openProfile(BoardEntry e) =>
      showPlayerProfileSheet(context, e.summary);

  void _login() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));

  void _findFriends() {
    try {
      context.read<ShellNavigation>().show(ShellTab.friends);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xếp hạng'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final g in GameMeta.all)
              Tab(height: kMinTouchTarget, icon: null, text: g.name),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final auth = context.watch<AuthController>();
          final myId = auth.isAuthenticated ? auth.currentUser?.userId : null;
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => c.reload(force: true),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(AppSpacing.screen,
                        AppSpacing.md, AppSpacing.screen, AppSpacing.lg),
                    children: [
                      _Controls(controller: c),
                      const SizedBox(height: AppSpacing.md),
                      ..._content(context, myId),
                    ],
                  ),
                ),
              ),
              if (!c.needsLogin)
                MyRankBar(
                  board: c.selection.board,
                  loggedIn: auth.isAuthenticated,
                  me: c.data?.me,
                  loading: c.loading && c.data == null,
                  onLogin: _login,
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _content(BuildContext context, int? myId) {
    final sel = c.selection;
    if (c.needsLogin) {
      return [
        SizedBox(
          height: 320,
          child: EmptyState(
            icon: Icons.group_rounded,
            title: 'Đăng nhập để xem bảng bạn bè',
            message: 'So điểm và rating với bạn bè của bạn.',
            actionLabel: 'Đăng nhập',
            onAction: _login,
          ),
        ),
      ];
    }
    if (c.loading && c.data == null) {
      return const [LeaderboardSkeleton()];
    }
    if (c.error != null && c.data == null) {
      return [
        SizedBox(
          height: 320,
          child: ErrorState(
              message: c.error!, onRetry: () => c.reload(force: true)),
        ),
      ];
    }
    final entries = c.data?.entries ?? const <BoardEntry>[];
    if (entries.isEmpty) {
      final friends = sel.scope == BoardScope.friends;
      return [
        SizedBox(
          height: 320,
          child: EmptyState(
            icon: Icons.leaderboard_rounded,
            title: friends ? 'Chưa có bạn bè trên bảng' : 'Chưa có ai trên bảng',
            message: friends
                ? 'Kết bạn để so điểm với nhau.'
                : sel.board == BoardType.ranked
                    ? 'Chưa có trận xếp hạng nào. Hãy là người đầu tiên!'
                    : sel.period == BoardPeriod.season
                        ? 'Mùa này chưa có ván nào. Hãy là người đầu tiên!'
                        : 'Hoàn thành một ván để ghi tên mình lên bảng.',
            actionLabel: friends ? 'Tìm bạn' : null,
            onAction: friends ? _findFriends : null,
          ),
        ),
      ];
    }
    final ranked = sel.board == BoardType.ranked;
    final top = entries.take(3).toList();
    final rest = entries.skip(3).toList();
    return [
      Podium(
        entries: top,
        myId: myId,
        ranked: ranked,
        onTap: _openProfile,
      ),
      const SizedBox(height: AppSpacing.md),
      for (final e in rest)
        BoardRow(
          entry: e,
          isMe: e.userId == myId,
          ranked: ranked,
          onTap: () => _openProfile(e),
        ),
    ];
  }
}

// -------------------------------------------------------------- điều khiển

class _Controls extends StatelessWidget {
  final LeaderboardController controller;
  const _Controls({required this.controller});

  @override
  Widget build(BuildContext context) {
    final sel = controller.selection;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    void pick(BoardSelection s) => controller.select(s);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<BoardType>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
                value: BoardType.ranked,
                icon: Icon(Icons.sports_mma_rounded),
                label: Text('Đối kháng')),
            ButtonSegment(
                value: BoardType.record,
                icon: Icon(Icons.timer_rounded),
                label: Text('Kỷ lục')),
          ],
          selected: {sel.board},
          onSelectionChanged: (s) => pick(sel.copyWith(board: s.first)),
        ),
        if (sel.board == BoardType.record) ...[
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final opt in <(String, int?)>[
                  ('Tất cả', null),
                  for (final d in Difficulty.values) (d.label, d.value),
                ]) ...[
                  ChoiceChip(
                    label: Text(opt.$1),
                    selected: sel.difficulty == opt.$2,
                    showCheckmark: false,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected: (_) => pick(sel.copyWith(difficulty: opt.$2)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<BoardScope>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
                value: BoardScope.global,
                icon: Icon(Icons.public_rounded),
                label: Text('Toàn server')),
            ButtonSegment(
                value: BoardScope.friends,
                icon: Icon(Icons.group_rounded),
                label: Text('Bạn bè')),
          ],
          selected: {sel.scope},
          onSelectionChanged: (s) => pick(sel.copyWith(scope: s.first)),
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<BoardPeriod>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: BoardPeriod.season, label: Text('Mùa này')),
            ButtonSegment(
                value: BoardPeriod.all, label: Text('Mọi thời điểm')),
          ],
          selected: {sel.period},
          onSelectionChanged: (s) => pick(sel.copyWith(period: s.first)),
        ),
        if (sel.period == BoardPeriod.season &&
            controller.seasonRemaining != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.hourglass_bottom_rounded,
                  size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  seasonCountdownVi(controller.seasonRemaining!),
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- podium

class Podium extends StatelessWidget {
  final List<BoardEntry> entries; // theo thứ tự danh sách (tối đa 3)
  final int? myId;
  final bool ranked;
  final ValueChanged<BoardEntry>? onTap;
  const Podium({
    super.key,
    required this.entries,
    this.myId,
    this.ranked = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    BoardEntry? at(int i) => i < entries.length ? entries[i] : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _slot(at(1), 2)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _slot(at(0), 1)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _slot(at(2), 3)),
      ],
    );
  }

  Widget _slot(BoardEntry? e, int place) => e == null
      ? const SizedBox.shrink()
      : _PodiumSlot(
          entry: e,
          place: place,
          isMe: e.userId == myId,
          ranked: ranked,
          onTap: onTap == null ? null : () => onTap!(e),
        );
}

class _PodiumSlot extends StatelessWidget {
  final BoardEntry entry;
  final int place; // vị trí hiển thị 1..3 (quyết định chiều cao)
  final bool isMe;
  final bool ranked;
  final VoidCallback? onTap;
  const _PodiumSlot({
    required this.entry,
    required this.place,
    required this.isMe,
    required this.ranked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final (Color medal, IconData icon, double height) = switch (place) {
      1 => (palette.warning, Icons.emoji_events_rounded, 88.0),
      2 => (scheme.onSurfaceVariant, Icons.military_tech_rounded, 68.0),
      _ => (palette.accent, Icons.military_tech_rounded, 52.0),
    };
    return Semantics(
      button: true,
      label:
          'Hạng ${e.rank}, ${e.displayName}${isMe ? ' (bạn)' : ''}, ${e.value} ${ranked ? 'điểm rating' : 'điểm'}. Chạm để xem hồ sơ',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: medal, size: place == 1 ? 32 : 26),
              const SizedBox(height: AppSpacing.xs),
              UserAvatar(
                  name: e.displayName,
                  size: place == 1 ? 56 : 48,
                  highlight: isMe),
              const SizedBox(height: AppSpacing.xs),
              Text(
                e.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: text.labelLarge,
              ),
              Text(
                '${e.value}',
                style: text.titleSmall?.copyWith(
                    fontFeatures: kTabularFigures, color: scheme.secondary),
              ),
              if (ranked && e.tier != null)
                RankBadge(rating: e.value, tier: e.tier, compact: true)
              else if (e.bestTimeSeconds != null)
                Text(
                  formatDuration(e.bestTimeSeconds!),
                  style: text.bodySmall?.copyWith(
                      fontFeatures: kTabularFigures,
                      color: scheme.onSurfaceVariant),
                ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                height: height,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isMe
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.md)),
                  border: Border(top: BorderSide(color: medal, width: 3)),
                ),
                child: Text(
                  '${e.rank}',
                  style: text.headlineMedium?.copyWith(
                      color: scheme.onSurface, fontFeatures: kTabularFigures),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ dòng

class BoardRow extends StatelessWidget {
  final BoardEntry entry;
  final bool isMe;
  final bool ranked;
  final VoidCallback? onTap;
  const BoardRow({
    super.key,
    required this.entry,
    required this.isMe,
    required this.ranked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final e = entry;
    final fg = isMe ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    final valueColor = isMe ? scheme.onPrimaryContainer : scheme.secondary;
    return Semantics(
      button: true,
      label:
          'Hạng ${e.rank}, ${e.displayName}${isMe ? ' (bạn)' : ''}, ${e.value} ${ranked ? 'điểm rating' : 'điểm'}${e.bestTimeSeconds != null && !ranked ? ', thời gian ${formatDuration(e.bestTimeSeconds!)}' : ''}. Chạm để xem hồ sơ',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Material(
            color: isMe ? scheme.primaryContainer : scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                      color: isMe ? scheme.primary : scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${e.rank}',
                        style: text.titleSmall
                            ?.copyWith(fontFeatures: kTabularFigures, color: fg),
                      ),
                    ),
                    Expanded(
                      child: PlayerCard(
                        name: isMe ? '${e.displayName} (bạn)' : e.displayName,
                        username: e.username,
                        rating: ranked ? e.value : null,
                        tier: ranked ? e.tier : null,
                        highlight: isMe,
                        avatarSize: 40,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${e.value}',
                          style: text.titleSmall?.copyWith(
                              fontFeatures: kTabularFigures,
                              color: valueColor),
                        ),
                        if (!ranked && e.bestTimeSeconds != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_outlined, size: 14, color: fg),
                              const SizedBox(width: 2),
                              Text(
                                formatDuration(e.bestTimeSeconds!),
                                style: text.bodySmall?.copyWith(
                                    fontFeatures: kTabularFigures, color: fg),
                              ),
                            ],
                          )
                        else if (ranked && e.games != null)
                          Text('${e.games} trận',
                              style: text.bodySmall?.copyWith(
                                  fontFeatures: kTabularFigures, color: fg)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ my rank bar

class MyRankBar extends StatelessWidget {
  final BoardType board;
  final bool loggedIn;
  final BoardMe? me;
  final bool loading;
  final VoidCallback onLogin;
  const MyRankBar({
    super.key,
    required this.board,
    required this.loggedIn,
    required this.me,
    required this.loading,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ranked = board == BoardType.ranked;

    Widget content;
    if (!loggedIn) {
      content = Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child:
                Text('Đăng nhập để xem hạng của bạn', style: text.bodyMedium),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
                minimumSize: const Size(kMinTouchTarget, kMinTouchTarget)),
            onPressed: onLogin,
            child: const Text('Đăng nhập'),
          ),
        ],
      );
    } else if (loading) {
      content = Text('Đang tải hạng của bạn…',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant));
    } else if (me == null) {
      content = Text('Chưa tải được hạng của bạn — kéo xuống để thử lại',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant));
    } else if (!me!.hasPlayed) {
      content = Row(
        children: [
          Icon(Icons.sports_esports_rounded, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
                ranked
                    ? 'Bạn chưa có trận xếp hạng ở bảng này'
                    : 'Chưa có lượt chơi ở bảng này',
                style: text.bodyMedium),
          ),
        ],
      );
    } else {
      content = Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              '#${me!.rank}',
              style: text.titleSmall?.copyWith(
                  color: scheme.onPrimary, fontFeatures: kTabularFigures),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: ranked
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: RankBadge(rating: me!.value!),
                  )
                : Text('${me!.value} điểm',
                    style: text.titleSmall
                        ?.copyWith(fontFeatures: kTabularFigures)),
          ),
          if (!ranked && me!.bestTimeSeconds != null) ...[
            Icon(Icons.timer_outlined,
                size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              formatDuration(me!.bestTimeSeconds!),
              style: text.bodyMedium?.copyWith(
                  fontFeatures: kTabularFigures,
                  color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      );
    }

    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 3,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screen, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Semantics(
          container: true,
          label: 'Hạng của bạn',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hạng của bạn',
                  style: text.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.xs),
              content,
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- skeleton

class LeaderboardSkeleton extends StatefulWidget {
  const LeaderboardSkeleton({super.key});

  @override
  State<LeaderboardSkeleton> createState() => _LeaderboardSkeletonState();
}

class _LeaderboardSkeletonState extends State<LeaderboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bone(double w, double h, {double r = AppRadius.sm}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(r)),
        );
    return Semantics(
      label: 'Đang tải bảng xếp hạng',
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final h in [120.0, 150.0, 104.0]) ...[
                    Expanded(child: bone(double.infinity, h, r: AppRadius.md)),
                    if (h != 104.0) const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    children: [
                      bone(28, 18),
                      const SizedBox(width: AppSpacing.md),
                      bone(40, 40, r: 20),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            bone(140, 14),
                            const SizedBox(height: 6),
                            bone(80, 12),
                          ],
                        ),
                      ),
                      bone(48, 20),
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
