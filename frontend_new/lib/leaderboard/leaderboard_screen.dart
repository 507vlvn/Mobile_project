import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../core/models/game_meta.dart';
import '../core/network/api_client.dart';
import '../core/network/models.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/feedback_states.dart';
import '../core/widgets/rank_badge.dart';
import '../core/widgets/user_avatar.dart';
import '../profile/player_profile_sheet.dart';
import 'leaderboard_controller.dart';

/// Game có bảng kỷ lục (điểm chơi đơn lưu ở bảng History).
const _recordGames = ['RUBIK', 'SUDOKU', 'PUZZLE', 'CARO'];

/// Game có bảng đối kháng (rating) — các game chơi được online trong app.
const _rankedGames = ['CARO', 'PUZZLE'];

String _difficultyLabel(String game, int d) => game == 'PUZZLE'
    ? '${d + 2}×${d + 2}'
    : switch (d) {
        1 => 'Dễ',
        2 => 'Trung bình',
        _ => 'Khó',
      };

String _mmss(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  String two(int v) => v.toString().padLeft(2, '0');
  return s >= 3600 ? '${s ~/ 3600}:${two(s % 3600 ~/ 60)}:${two(s % 60)}' : '${two(s ~/ 60)}:${two(s % 60)}';
}

/// Màn Xếp hạng: bảng kỷ lục (điểm cao nhất chơi đơn) và bảng đối kháng (rating),
/// lọc theo game / độ khó / tuần này hoặc mọi lúc / toàn server hoặc bạn bè.
class LeaderboardScreen extends StatefulWidget {
  /// Cho test truyền sẵn controller.
  @visibleForTesting
  final LeaderboardController? controllerOverride;

  const LeaderboardScreen({super.key, this.controllerOverride});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardController? _c;
  bool? _wasLoggedIn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthController>(context);
    if (_c == null) {
      _c = widget.controllerOverride ??
          LeaderboardController(api: context.read<ApiClient>(), isLoggedIn: () => auth.isAuthenticated);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _c!.load();
      });
    }
    final now = auth.isAuthenticated;
    if (_wasLoggedIn != null && _wasLoggedIn != now) {
      _c!.clearCache();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _c!.load();
      });
    }
    _wasLoggedIn = now;
  }

  @override
  void dispose() {
    if (widget.controllerOverride == null) _c?.dispose();
    super.dispose();
  }

  void _set(LeaderboardQuery q) => _c!.setQuery(q);

  @override
  Widget build(BuildContext context) {
    final c = _c!;
    final me = context.watch<AuthController>().currentUser?.userId;
    return Scaffold(
      appBar: AppBar(title: const Text('Xếp hạng')),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) => RefreshIndicator(
          onRefresh: () => c.load(force: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Filters(controller: c, onChanged: _set)),
              SliverToBoxAdapter(child: _MyRankCard(controller: c)),
              ..._list(context, c, me),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _list(BuildContext context, LeaderboardController c, int? me) {
    if (c.needsLogin) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.people_rounded,
            title: 'Đăng nhập để xem bảng bạn bè',
            actionLabel: 'Đăng nhập',
            onAction: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen())),
          ),
        ),
      ];
    }
    if (c.loading && c.entries.isEmpty) {
      return const [
        SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator())),
      ];
    }
    if (c.error != null && c.entries.isEmpty) {
      return [
        SliverFillRemaining(hasScrollBody: false, child: ErrorState(message: c.error!, onRetry: () => c.load(force: true))),
      ];
    }
    if (c.entries.isEmpty) {
      final q = c.query;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'Chưa có ai trong bảng này',
            message: q.ranked
                ? 'Đấu xếp hạng ở tab Đối kháng để có tên trên bảng.'
                : (q.season ? 'Tuần này chưa có thành tích. Chơi và đăng nhập để ghi điểm!' : 'Chơi và đăng nhập để ghi điểm!'),
          ),
        ),
      ];
    }
    return [
      SliverList.builder(
        itemCount: c.entries.length,
        itemBuilder: (context, i) => _EntryRow(
          entry: c.entries[i],
          ranked: c.query.ranked,
          isMe: c.entries[i].user.userId == me,
          onTap: me == null ? null : () => showPlayerProfileSheet(context, c.entries[i].user),
        ),
      ),
    ];
  }
}

class _Filters extends StatelessWidget {
  final LeaderboardController controller;
  final ValueChanged<LeaderboardQuery> onChanged;
  const _Filters({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final q = controller.query;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final games = q.ranked ? _rankedGames : _recordGames;
    final season = controller.season;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.emoji_events_outlined), label: Text('Kỷ lục')),
              ButtonSegment(value: true, icon: Icon(Icons.sports_mma_rounded), label: Text('Đối kháng')),
            ],
            selected: {q.ranked},
            onSelectionChanged: (v) {
              final ranked = v.first;
              final allowed = ranked ? _rankedGames : _recordGames;
              onChanged(q.copyWith(
                ranked: ranked,
                gameCode: allowed.contains(q.gameCode) ? q.gameCode : allowed.first,
                difficulty: () => null,
              ));
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final g in games)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      avatar: Icon(GameMeta.of(g).icon, size: 18),
                      label: Text(GameMeta.of(g).name),
                      selected: q.gameCode == g,
                      onSelected: (_) => onChanged(q.copyWith(gameCode: g, difficulty: () => null)),
                    ),
                  ),
              ],
            ),
          ),
          if (!q.ranked)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final d in const <int?>[null, 1, 2, 3])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(d == null ? 'Mọi độ khó' : _difficultyLabel(q.gameCode, d)),
                        selected: q.difficulty == d,
                        onSelected: (_) => onChanged(q.copyWith(difficulty: () => d)),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(value: true, label: Text('Tuần này')),
                    ButtonSegment(value: false, label: Text('Mọi lúc')),
                  ],
                  selected: {q.season},
                  onSelectionChanged: (v) => onChanged(q.copyWith(season: v.first)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(value: false, label: Text('Toàn server')),
                    ButtonSegment(value: true, label: Text('Bạn bè')),
                  ],
                  selected: {q.friendsOnly},
                  onSelectionChanged: (v) => onChanged(q.copyWith(friendsOnly: v.first)),
                ),
              ),
            ],
          ),
          if (q.season && season != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('Mùa tuần này kết thúc sau ${seasonCountdownVi(season.remaining())}',
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MyRankCard extends StatelessWidget {
  final LeaderboardController controller;
  const _MyRankCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (!auth.isAuthenticated || controller.needsLogin) return const SizedBox.shrink();
    final r = controller.myRank;
    final q = controller.query;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final has = r?.rank != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Text(has ? '#${r!.rank}' : '—',
              style: text.headlineSmall?.copyWith(
                  color: scheme.onPrimaryContainer, fontWeight: FontWeight.w800, fontFeatures: kTabularFigures)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              !has
                  ? (controller.loading ? 'Đang tải hạng của bạn…' : 'Bạn chưa có thành tích trong bảng này')
                  : q.ranked
                      ? 'Hạng của bạn · ${r!.games ?? 0} trận, thắng ${r.wins ?? 0}'
                      : 'Hạng của bạn · kỷ lục ${r!.bestScore} điểm (${_mmss(r.bestTimeSeconds ?? 0)})',
              style: text.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
            ),
          ),
          if (has && q.ranked && r!.rating != null) RankBadge(rating: r.rating!, tier: r.tier),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool ranked;
  final bool isMe;
  final VoidCallback? onTap;
  const _EntryRow({required this.entry, required this.ranked, required this.isMe, this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final medal = switch (e.rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };
    final games = e.games ?? 0;
    final winPct = games == 0 ? 0 : ((e.wins ?? 0) * 100 / games).round();

    return Semantics(
      button: onTap != null,
      label: 'Hạng ${e.rank}, ${e.user.displayName}${isMe ? ' (bạn)' : ''}, '
          '${ranked ? 'rating ${e.rating ?? e.bestScore}' : '${e.bestScore} điểm'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isMe ? scheme.secondaryContainer : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Center(
                  child: medal != null
                      ? Text(medal, style: const TextStyle(fontSize: 24))
                      : Text('${e.rank}',
                          style: text.titleMedium?.copyWith(
                              color: scheme.onSurfaceVariant, fontFeatures: kTabularFigures)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              UserAvatar(name: e.user.displayName, size: 40, highlight: isMe),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isMe ? '${e.user.displayName} (bạn)' : e.user.displayName,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                    Text(
                      ranked ? '$games trận · thắng $winPct%' : '@${e.user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (ranked)
                RankBadge(rating: e.rating ?? e.bestScore, tier: e.tier)
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${e.bestScore}',
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: kTabularFigures)),
                    Text(_mmss(e.bestTimeSeconds),
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontFeatures: kTabularFigures)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
