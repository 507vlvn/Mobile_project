import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../core/models/game_meta.dart';
import '../core/models/rank.dart';
import '../core/network/api_client.dart';
import '../core/network/models.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/tier_colors.dart';
import '../core/widgets/feedback_states.dart';
import '../core/widgets/rank_badge.dart';
import '../core/widgets/user_avatar.dart';
import '../hub/hub_screen.dart';
import '../profile/player_profile_sheet.dart';
import '../pvp/pvp_lobby_screen.dart';
import 'leaderboard_controller.dart';

/// Game có bảng kỷ lục (điểm chơi đơn lưu ở bảng History).
const _recordGames = ['RUBIK', 'SUDOKU', 'PUZZLE', 'CARO'];

/// Game có bảng đối kháng (rating) — các game chơi được online trong app.
const _rankedGames = ['CARO', 'PUZZLE'];

/// Khóa SharedPreferences nhớ bộ lọc lần trước.
const _prefsKey = 'leaderboard_query';

/// Độ khó mặc định của bảng kỷ lục.
const _defaultDifficulty = 1;

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

String _winLine(int? games, int? wins) {
  final g = games ?? 0;
  final pct = g == 0 ? 0 : ((wins ?? 0) * 100 / g).round();
  return '$g trận · thắng $pct%';
}

Map<String, Object?> _queryToJson(LeaderboardQuery q) => {
      'gameCode': q.gameCode,
      'ranked': q.ranked,
      'difficulty': q.difficulty,
      'friendsOnly': q.friendsOnly,
      'season': q.season,
    };

/// null nếu dữ liệu đã lưu không còn hợp lệ (vd game bị bỏ khỏi bảng đối kháng).
/// Bảng kỷ lục luôn có độ khó 1..3.
LeaderboardQuery? _queryFromJson(Object? raw) {
  if (raw is! Map) return null;
  final ranked = raw['ranked'] == true;
  final game = raw['gameCode'];
  final d = raw['difficulty'];
  if (game is! String || !(ranked ? _rankedGames : _recordGames).contains(game)) return null;
  return LeaderboardQuery(
    gameCode: game,
    ranked: ranked,
    difficulty: ranked ? null : (d is int && d >= 1 && d <= 3 ? d : _defaultDifficulty),
    friendsOnly: raw['friendsOnly'] == true,
    season: raw['season'] != false,
  );
}

/// Màn Xếp hạng: bảng kỷ lục (điểm cao nhất chơi đơn) và bảng đối kháng (rating),
/// lọc theo game / độ khó / tuần này hoặc mọi lúc / toàn server hoặc bạn bè.
/// Top 3 hiện dạng bục, vị trí của mình luôn ghim ở đáy màn hình.
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

  /// Gắn vào dòng của mình để bấm thanh "vị trí của bạn" thì cuộn tới.
  final _myRowKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthController>(context);
    if (_c == null) {
      _c = widget.controllerOverride ??
          LeaderboardController(api: context.read<ApiClient>(), isLoggedIn: () => auth.isAuthenticated);
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreAndLoad());
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

  Future<void> _restoreAndLoad() async {
    LeaderboardQuery? saved;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_prefsKey);
      if (raw != null) saved = _queryFromJson(jsonDecode(raw));
    } catch (_) {
      // Không đọc được thì dùng bộ lọc mặc định.
    }
    if (!mounted) return;
    if (saved != null && saved.key != _c!.query.key) {
      await _c!.setQuery(saved);
    } else {
      await _c!.load();
    }
  }

  @override
  void dispose() {
    if (widget.controllerOverride == null) _c?.dispose();
    super.dispose();
  }

  void _set(LeaderboardQuery q) {
    _c!.setQuery(q);
    SharedPreferences.getInstance()
        .then((p) => p.setString(_prefsKey, jsonEncode(_queryToJson(q))))
        .catchError((_) => false);
  }

  void _openProfile(BuildContext context, UserSummary user, bool loggedIn) {
    if (loggedIn) {
      showPlayerProfileSheet(context, user);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Đăng nhập để xem hồ sơ và kết bạn với người chơi'),
        action: SnackBarAction(label: 'Đăng nhập', onPressed: () => _openLogin(context)),
      ));
  }

  void _scrollToMe() {
    final ctx = _myRowKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, alignment: 0.4, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c!;
    final auth = context.watch<AuthController>();
    final me = auth.isAuthenticated ? auth.currentUser?.userId : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xếp hạng'),
        actions: [
          IconButton(
            tooltip: 'Cách tính xếp hạng',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => _showRulesSheet(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) => RefreshIndicator(
          onRefresh: () => c.load(force: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Filters(controller: c, onChanged: _set)),
              ..._board(context, c, me),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: c,
        builder: (context, _) => _MyPositionBar(
          controller: c,
          loggedIn: me != null,
          meInList: me != null && c.entries.any((e) => e.user.userId == me),
          onTapInList: _scrollToMe,
          onPlay: () => _play(context, c.query),
        ),
      ),
    );
  }

  List<Widget> _board(BuildContext context, LeaderboardController c, int? me) {
    final q = c.query;
    if (c.needsLogin) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.people_rounded,
            title: 'Đăng nhập để xem bảng bạn bè',
            message: 'So tài với bạn bè của bạn trên cùng một bảng.',
            actionLabel: 'Đăng nhập',
            onAction: () => _openLogin(context),
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
      final game = GameMeta.of(q.gameCode).name;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'Chưa có ai trong bảng này',
            message: q.friendsOnly
                ? 'Bạn bè của bạn chưa có thành tích ở bảng này. Hãy là người mở màn!'
                : q.ranked
                    ? 'Đấu xếp hạng $game để là người đầu tiên có tên.'
                    : (q.season ? 'Tuần này chưa có thành tích $game. Chơi để giành hạng 1!' : 'Chơi $game để ghi điểm!'),
            actionLabel: q.ranked ? 'Tìm trận' : 'Chơi $game',
            onAction: () => _play(context, q),
          ),
        ),
      ];
    }

    final entries = c.entries;
    final podium = entries.take(3).toList();
    final rest = entries.skip(podium.length).toList();
    // Bục + danh sách chung MỘT sliver bắt đầu trên màn hình nên được dựng hết
    // (tối đa 50 dòng): cuộn tới dòng của mình được cả khi nó đang ngoài màn hình.
    return [
      SliverToBoxAdapter(
        child: Column(children: [
          _Podium(
            entries: podium,
            ranked: q.ranked,
            me: me,
            myKey: _myRowKey,
            onTap: (u) => _openProfile(context, u, me != null),
          ),
          for (final e in rest)
            _EntryRow(
              key: e.user.userId == me ? _myRowKey : null,
              entry: e,
              ranked: q.ranked,
              isMe: e.user.userId == me,
              onTap: () => _openProfile(context, e.user, me != null),
            ),
        ]),
      ),
    ];
  }
}

void _openLogin(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));

/// Bảng đối kháng: mở sảnh tìm trận; bảng kỷ lục: mở màn game.
void _play(BuildContext context, LeaderboardQuery q) {
  if (q.ranked) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PvpLobbyScreen(initialGame: q.gameCode, embedded: false)));
  } else {
    openGameHome(context, q.gameCode);
  }
}

// ------------------------------------------------------------------ bộ lọc

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
                difficulty: () => ranked ? null : (q.difficulty ?? _defaultDifficulty),
              ));
            },
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.xs),
            child: Text(
              q.ranked ? 'Rating Elo từ các trận xếp hạng online' : 'Điểm cao nhất mỗi người khi chơi một mình',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
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
                      onSelected: (_) => onChanged(q.copyWith(gameCode: g)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Bộ lọc phụ gom vào một hàng menu để danh sách bắt đầu sớm hơn.
          // Bảng kỷ lục luôn chọn một độ khó cụ thể (không có "Mọi độ khó").
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _MenuChip<bool>(
                icon: Icons.calendar_month_rounded,
                value: q.season,
                options: const {true: 'Tuần này', false: 'Mọi lúc'},
                onSelected: (v) => onChanged(q.copyWith(season: v)),
              ),
              _MenuChip<bool>(
                icon: q.friendsOnly ? Icons.people_rounded : Icons.public_rounded,
                value: q.friendsOnly,
                options: const {false: 'Toàn server', true: 'Bạn bè'},
                onSelected: (v) => onChanged(q.copyWith(friendsOnly: v)),
              ),
              if (!q.ranked)
                _MenuChip<int>(
                  icon: Icons.tune_rounded,
                  value: q.difficulty ?? _defaultDifficulty,
                  options: {
                    for (final d in const [1, 2, 3]) d: _difficultyLabel(q.gameCode, d),
                  },
                  onSelected: (v) => onChanged(q.copyWith(difficulty: () => v)),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm, left: AppSpacing.xs),
            child: Row(
              children: [
                Icon(q.season ? Icons.schedule_rounded : Icons.all_inclusive_rounded,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    !q.season
                        ? 'Tính từ trước tới nay'
                        : season == null
                            ? 'Mùa tuần này, làm mới 0 giờ thứ Hai'
                            : 'Mùa tuần này kết thúc sau ${seasonCountdownVi(season.remaining())}',
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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

/// Chip hiện giá trị đang chọn, bấm mở menu các lựa chọn.
class _MenuChip<T> extends StatelessWidget {
  final IconData icon;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onSelected;
  const _MenuChip({required this.icon, required this.value, required this.options, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return PopupMenuButton<T>(
      tooltip: '',
      initialValue: value,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final o in options.entries)
          CheckedPopupMenuItem<T>(value: o.key, checked: o.key == value, child: Text(o.value)),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: scheme.onSecondaryContainer),
            const SizedBox(width: 6),
            Text(options[value] ?? '', style: text.labelLarge?.copyWith(color: scheme.onSecondaryContainer)),
            Icon(Icons.arrow_drop_down_rounded, color: scheme.onSecondaryContainer),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ bục top 3

class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final bool ranked;
  final int? me;
  final GlobalKey myKey;
  final ValueChanged<UserSummary> onTap;
  const _Podium({required this.entries, required this.ranked, required this.me, required this.myKey, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Xếp kiểu bục: hạng 2 · hạng 1 · hạng 3 (hạng 1 cao nhất ở giữa).
    final slots = <(LeaderboardEntry?, double)>[
      (entries.length > 1 ? entries[1] : null, 64),
      (entries.first, 92),
      (entries.length > 2 ? entries[2] : null, 48),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (e, h) in slots)
            Expanded(
              child: e == null
                  ? const SizedBox.shrink()
                  : _PodiumSpot(
                      key: e.user.userId == me ? myKey : null,
                      entry: e,
                      ranked: ranked,
                      isMe: e.user.userId == me,
                      standHeight: h,
                      onTap: () => onTap(e.user),
                    ),
            ),
        ],
      ),
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool ranked;
  final bool isMe;
  final double standHeight;
  final VoidCallback onTap;
  const _PodiumSpot({
    super.key,
    required this.entry,
    required this.ranked,
    required this.isMe,
    required this.standHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final medal = switch (e.rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '${e.rank}',
    };
    final name = isMe ? '${e.user.displayName} (bạn)' : e.user.displayName;
    final value = ranked ? '${e.rating ?? e.bestScore}' : '${e.bestScore}';
    final tier = ranked ? (e.tier ?? Tier.fromRating(e.rating ?? e.bestScore)) : null;
    final standColor = isMe ? scheme.secondaryContainer : scheme.surfaceContainerHigh;

    return Semantics(
      button: true,
      label: 'Hạng ${e.rank}, $name, ${ranked ? 'rating $value' : '$value điểm'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(medal, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: AppSpacing.xs),
              UserAvatar(name: e.user.displayName, size: e.rank == 1 ? 60 : 50, highlight: isMe),
              const SizedBox(height: AppSpacing.xs),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: text.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Container(
                width: double.infinity,
                // Chiều cao tối thiểu: bục thấp vẫn đủ chỗ cho cả điểm lẫn thời gian.
                constraints: BoxConstraints(minHeight: standHeight),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: standColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
                ),
                child: Column(
                  children: [
                    if (tier != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tier.icon, size: 16, color: context.tierColor(tier)),
                          const SizedBox(width: 2),
                          Text(value,
                              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: kTabularFigures)),
                        ],
                      )
                    else
                      Text(value,
                          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: kTabularFigures)),
                    Text(
                      ranked ? _winLine(e.games, e.wins) : _mmss(e.bestTimeSeconds),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontFeatures: kTabularFigures),
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

// ------------------------------------------------------------------ hạng 4 trở đi

class _EntryRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool ranked;
  final bool isMe;
  final VoidCallback? onTap;
  const _EntryRow({super.key, required this.entry, required this.ranked, required this.isMe, this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

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
                  child: Text('${e.rank}',
                      style: text.titleMedium?.copyWith(color: scheme.onSurfaceVariant, fontFeatures: kTabularFigures)),
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
                      ranked ? _winLine(e.games, e.wins) : '@${e.user.username}',
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Text(_mmss(e.bestTimeSeconds),
                            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontFeatures: kTabularFigures)),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ vị trí của bạn

/// Ghim ở đáy: hạng của mình + mục tiêu kế tiếp (vượt người trên / lên bậc).
class _MyPositionBar extends StatelessWidget {
  final LeaderboardController controller;
  final bool loggedIn;
  final bool meInList;
  final VoidCallback onTapInList;
  final VoidCallback onPlay;
  const _MyPositionBar({
    required this.controller,
    required this.loggedIn,
    required this.meInList,
    required this.onTapInList,
    required this.onPlay,
  });

  /// Gợi ý mục tiêu: bao nhiêu điểm nữa để vượt người xếp ngay trên, hoặc lên bậc.
  String? _goal(MyRank r, LeaderboardQuery q, List<LeaderboardEntry> entries) {
    if (r.rank == 1) return 'Bạn đang dẫn đầu bảng này!';
    if (q.ranked) {
      final rating = r.rating;
      if (rating == null) return null;
      final next = (r.tier ?? Tier.fromRating(rating)).next;
      return next == null ? 'Bạn đã ở bậc cao nhất' : 'Còn ${next.minRating - rating} điểm để lên ${next.label}';
    }
    final mine = r.bestScore;
    if (mine == null) return null;
    LeaderboardEntry? above;
    for (final e in entries) {
      if (e.bestScore > mine) above = e; // danh sách giảm dần: lấy người cuối cùng còn hơn mình
    }
    return above == null ? null : 'Thêm ${above.bestScore - mine + 1} điểm để vượt ${above.user.displayName}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final q = controller.query;

    Widget bar({required Widget leading, required String title, String? subtitle, Widget? trailing, VoidCallback? onTap}) {
      return Material(
        color: scheme.primaryContainer,
        child: SafeArea(
          top: false,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: text.bodyMedium?.copyWith(color: scheme.onPrimaryContainer)),
                        if (subtitle != null)
                          Text(subtitle,
                              style: text.bodySmall?.copyWith(
                                  color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!loggedIn) {
      return bar(
        leading: Icon(Icons.emoji_events_rounded, color: scheme.onPrimaryContainer),
        title: 'Đăng nhập để có tên trên bảng xếp hạng',
        trailing: FilledButton.tonal(onPressed: () => _openLogin(context), child: const Text('Đăng nhập')),
      );
    }
    if (controller.needsLogin) return const SizedBox.shrink();

    final r = controller.myRank;
    final has = r?.rank != null;
    final rankText = Text(has ? '#${r!.rank}' : '—',
        style: text.headlineSmall?.copyWith(
            color: scheme.onPrimaryContainer, fontWeight: FontWeight.w800, fontFeatures: kTabularFigures));
    if (!has) {
      return bar(
        leading: rankText,
        title: controller.loading ? 'Đang tải hạng của bạn…' : 'Bạn chưa có thành tích trong bảng này',
        trailing: controller.loading
            ? null
            : FilledButton.tonal(onPressed: onPlay, child: Text(q.ranked ? 'Tìm trận' : 'Chơi ngay')),
      );
    }
    return bar(
      leading: rankText,
      title: q.ranked
          ? 'Hạng của bạn · ${_winLine(r!.games, r.wins)}'
          : 'Hạng của bạn · kỷ lục ${r!.bestScore} điểm (${_mmss(r.bestTimeSeconds ?? 0)})',
      subtitle: _goal(r, q, controller.entries),
      trailing: q.ranked && r.rating != null
          ? RankBadge(rating: r.rating!, tier: r.tier, compact: true)
          : (meInList ? Icon(Icons.my_location_rounded, color: scheme.onPrimaryContainer) : null),
      onTap: meInList ? onTapInList : null,
    );
  }
}

// ------------------------------------------------------------------ luật

void _showRulesSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;
      Widget section(String title, List<String> lines) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text('• $l', style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
              ],
            ),
          );
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.xl),
          children: [
            Text('Cách tính xếp hạng', style: text.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            section('Kỷ lục', const [
              'Mỗi người chỉ tính ván chơi đơn có điểm cao nhất.',
              'Điểm = điểm gốc theo độ khó × hệ số thời gian × hệ số lỗi. Giải nhanh, ít lỗi thì điểm cao.',
              'Bằng điểm thì ai nhanh hơn xếp trên, rồi tới ai đạt trước.',
            ]),
            section('Đối kháng', const [
              'Mỗi game có rating riêng, khởi điểm ${Tier.startRating}.',
              'Chỉ trận Xếp hạng (tìm trận nhanh) làm đổi rating; trận mời bạn thì không.',
              'Thắng được cộng, thua bị trừ; đối thủ mạnh hơn thì thắng được cộng nhiều hơn.',
            ]),
            Text('Bậc rank', style: text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final t in Tier.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(t.icon, color: context.tierColor(t)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(t.label, style: text.bodyLarge)),
                    Text(t.next == null ? 'từ ${t.minRating}' : '${t.minRating}–${t.next!.minRating - 1}',
                        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontFeatures: kTabularFigures)),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            section('Mùa giải', const [
              'Mỗi mùa kéo dài một tuần, bắt đầu 0 giờ thứ Hai (giờ Việt Nam).',
              '"Tuần này" chỉ tính thành tích trong mùa hiện tại; "Mọi lúc" tính từ trước tới nay.',
            ]),
          ],
        ),
      );
    },
  );
}
