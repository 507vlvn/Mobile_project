import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/challenge_context.dart';
import '../../core/models/difficulty.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/models.dart';
import '../../core/services/challenge_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/feedback_states.dart';
import '../auth/auth_controller.dart';
import '../history/game_meta.dart';
import 'logic/challenge_groups.dart';

/// Danh sách thách đấu theo 4 nhóm. Tải 1 lần khi mở và khi kéo để làm mới.
class ChallengesTab extends StatefulWidget {
  /// Báo số lời mời đến / số ván đang diễn ra để cập nhật huy hiệu.
  final void Function(int incoming, int active)? onCounts;

  const ChallengesTab({super.key, this.onCounts});

  @override
  State<ChallengesTab> createState() => ChallengesTabState();
}

class ChallengesTabState extends State<ChallengesTab> {
  List<Challenge> _all = const [];
  bool _loading = true;
  String? _error;
  int _requestId = 0;
  final Set<int> _busy = {};

  int get _myId => context.read<AuthController>().currentUser?.userId ?? 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final id = ++_requestId;
    if (_all.isEmpty) setState(() => _loading = true);
    try {
      final list = await context.read<ApiClient>().challenges('all');
      if (!mounted || id != _requestId) return;
      setState(() {
        _all = list;
        _loading = false;
        _error = null;
      });
      _reportCounts();
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  void _reportCounts() {
    final g = groupChallenges(_all, _myId);
    widget.onCounts?.call(g.incoming.length, g.active.length);
  }

  void _replace(Challenge updated) {
    setState(() {
      _all = [for (final c in _all) c.id == updated.id ? updated : c];
    });
    _reportCounts();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _respond(Challenge c, {required bool accept}) async {
    if (_busy.contains(c.id)) return;
    if (!accept) {
      final ok = await _confirmDecline(c);
      if (!ok || !mounted) return;
    }
    setState(() => _busy.add(c.id));
    final api = context.read<ApiClient>();
    try {
      final updated =
          accept ? await api.acceptChallenge(c.id) : await api.declineChallenge(c.id);
      if (!mounted) return;
      _replace(updated);
      _toast(accept ? 'Đã chấp nhận. Vào mục Đang diễn ra để chơi.' : 'Đã từ chối lời thách.');
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
      load(); // trạng thái có thể đã đổi (hết hạn, đã huỷ...)
    }
    if (mounted) setState(() => _busy.remove(c.id));
  }

  Future<bool> _confirmDecline(Challenge c) async {
    final name = c.challenger.displayName;
    final r = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.close_rounded),
        title: const Text('Từ chối lời thách?'),
        content: Text('$name sẽ được báo là bạn đã từ chối.'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
                minimumSize: const Size(kMinTouchTarget, kMinTouchTarget)),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _play(Challenge c) async {
    await ChallengeLauncher.open(
      context,
      ChallengeContext(
        challengeId: c.id,
        gameCode: c.gameCode,
        difficulty: Difficulty.fromValue(c.difficulty),
      ),
    );
    if (mounted) load(); // kết quả vừa nộp có thể đã đổi trạng thái
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _all.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _all.isEmpty) {
      return ErrorState(message: _error!, onRetry: load);
    }
    final myId = _myId;
    final g = groupChallenges(_all, myId);
    if (g.isEmpty) {
      return RefreshIndicator(
        onRefresh: load,
        child: LayoutBuilder(
          builder: (context, c) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: c.maxHeight,
                child: const EmptyState(
                  icon: Icons.sports_esports_rounded,
                  title: 'Chưa có thách đấu',
                  message:
                      'Ở tab Bạn bè, mở menu ba chấm của bạn rồi "Thách đấu không đồng thời" để cùng giải một đề, không cần online cùng lúc.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final children = <Widget>[];
    void section(String title, List<Challenge> items, Widget Function(Challenge) card) {
      if (items.isEmpty) return;
      children.add(_SectionHeader(title: title, count: items.length));
      for (final c in items) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: card(c),
        ));
      }
    }

    section(
      'Lời mời đến',
      g.incoming,
      (c) => _IncomingCard(
        challenge: c,
        busy: _busy.contains(c.id),
        onAccept: () => _respond(c, accept: true),
        onDecline: () => _respond(c, accept: false),
      ),
    );
    section('Đang chờ đối thủ', g.outgoing,
        (c) => _OutgoingCard(challenge: c, myId: myId));
    section('Đang diễn ra', g.active,
        (c) => _ActiveCard(challenge: c, myId: myId, onPlay: () => _play(c)));
    section('Đã kết thúc', g.done, (c) => _DoneCard(challenge: c, myId: myId));

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xl),
        children: children,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Semantics(
        header: true,
        child: Text(
          '$title ($count)',
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

String _diffLabel(int d) => Difficulty.fromValue(d).label;

/// Phần đầu thẻ: icon game, tên game + độ khó, đối thủ, thời gian.
class _CardHeader extends StatelessWidget {
  final Challenge challenge;
  final String subtitle;
  final DateTime time;
  const _CardHeader({
    required this.challenge,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final meta = GameMeta.of(challenge.gameCode);
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(meta.icon, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${meta.name} · ${_diffLabel(challenge.difficulty)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          relativeTimeVi(time),
          style: text.labelSmall?.copyWith(color: context.palette.onSurfaceMuted),
        ),
      ],
    );
  }
}

class _IncomingCard extends StatelessWidget {
  final Challenge challenge;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _IncomingCard({
    required this.challenge,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _CardHeader(
              challenge: challenge,
              subtitle: '${challenge.challenger.displayName} thách bạn',
              time: challenge.createdAt,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(kMinTouchTarget),
                      // secondary đủ tương phản trên nền thẻ ở cả hai giao diện
                      foregroundColor: Theme.of(context).colorScheme.secondary,
                    ),
                    onPressed: busy ? null : onDecline,
                    child: const Text('Từ chối'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(kMinTouchTarget)),
                    onPressed: busy ? null : onAccept,
                    child: busy
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Theme.of(context).colorScheme.onPrimary),
                          )
                        : const Text('Chấp nhận'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutgoingCard extends StatelessWidget {
  final Challenge challenge;
  final int myId;
  const _OutgoingCard({required this.challenge, required this.myId});

  @override
  Widget build(BuildContext context) {
    final other = challenge.otherOf(myId);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _CardHeader(
              challenge: challenge,
              subtitle: 'Bạn thách ${other.displayName}',
              time: challenge.createdAt,
            ),
            const SizedBox(height: AppSpacing.sm),
            _StatusLine(
              icon: Icons.hourglass_empty_rounded,
              label: 'Chờ ${other.displayName} trả lời',
              color: context.palette.onSurfaceMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatusLine({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _ActiveCard extends StatelessWidget {
  final Challenge challenge;
  final int myId;
  final VoidCallback onPlay;
  const _ActiveCard({
    required this.challenge,
    required this.myId,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final other = challenge.otherOf(myId);
    final mine = challenge.myResult;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _CardHeader(
              challenge: challenge,
              subtitle: 'Đấu với ${other.displayName}',
              time: challenge.acceptedAt ?? challenge.createdAt,
            ),
            const SizedBox(height: AppSpacing.md),
            if (mine == null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(kMinTouchTarget)),
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Chơi ngay'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _StatusLine(
                      icon: Icons.hourglass_top_rounded,
                      label: 'Chờ đối thủ hoàn thành',
                      color: context.palette.warning,
                    ),
                  ),
                  Text(
                    '${mine.score} điểm',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontFeatures: kTabularFigures,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DoneCard extends StatelessWidget {
  final Challenge challenge;
  final int myId;
  const _DoneCard({required this.challenge, required this.myId});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final pal = context.palette;
    final other = challenge.otherOf(myId);
    final completed = challenge.status == ChallengeStatus.completed;

    late final IconData icon;
    late final String label;
    late final Color color;
    if (completed) {
      switch (outcomeFor(challenge, myId)) {
        case ChallengeOutcome.win:
          icon = Icons.emoji_events_rounded;
          label = 'Bạn thắng';
          color = pal.success;
        case ChallengeOutcome.lose:
          icon = Icons.flag_rounded;
          label = 'Bạn thua';
          color = scheme.error;
        case ChallengeOutcome.draw:
          icon = Icons.balance_rounded;
          label = 'Hoà';
          color = pal.onSurfaceMuted;
      }
    } else if (challenge.status == ChallengeStatus.declined) {
      icon = Icons.block_rounded;
      label = challenge.opponent.userId == myId
          ? 'Bạn đã từ chối'
          : '${other.displayName} đã từ chối';
      color = pal.onSurfaceMuted;
    } else {
      icon = Icons.timer_off_rounded;
      label = 'Hết hạn, không ai trả lời';
      color = pal.onSurfaceMuted;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _CardHeader(
              challenge: challenge,
              subtitle: 'Đấu với ${other.displayName}',
              time: challenge.completedAt ?? challenge.createdAt,
            ),
            const SizedBox(height: AppSpacing.md),
            if (completed)
              Row(
                children: [
                  Expanded(
                    child: _ScoreColumn(
                      name: 'Bạn',
                      result: challenge.myResult,
                      isWinner: challenge.winnerId == myId,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 56,
                    color: scheme.outlineVariant,
                  ),
                  Expanded(
                    child: _ScoreColumn(
                      name: other.displayName,
                      result: challenge.theirResult,
                      isWinner: challenge.winnerId == other.userId,
                    ),
                  ),
                ],
              ),
            if (completed) const SizedBox(height: AppSpacing.md),
            Semantics(
              container: true,
              child: Row(
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      style: text.titleSmall
                          ?.copyWith(color: color, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  final String name;
  final ChallengeResult? result;
  final bool isWinner;
  const _ScoreColumn({
    required this.name,
    required this.result,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: result == null
          ? '$name: chưa có kết quả'
          : '$name: ${result!.score} điểm, ${formatDuration(result!.timeSeconds)}${isWinner ? ', người thắng' : ''}',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isWinner) ...[
                Icon(Icons.emoji_events_rounded,
                    size: 16, color: context.palette.success),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            result == null ? '--' : '${result!.score}',
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: kTabularFigures,
              color: isWinner ? context.palette.success : scheme.onSurface,
            ),
          ),
          Text(
            result == null ? '' : formatDuration(result!.timeSeconds),
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: kTabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
