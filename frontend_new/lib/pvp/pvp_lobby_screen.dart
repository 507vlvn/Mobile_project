import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/models.dart';
import '../core/realtime/match_models.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/feedback_states.dart';
import '../core/widgets/primary_button.dart';
import '../core/widgets/rank_badge.dart';
import 'match_session.dart';
import 'pvp_common.dart';
import 'pvp_navigator.dart';

/// Sảnh Đối kháng: chọn game (Caro / Xếp số), độ khó Xếp số, xem rating và
/// tìm trận xếp hạng. Đấu giao hữu với bạn bè: nút "Mời đấu" ở tab Bạn bè.
class PvpLobbyScreen extends StatefulWidget {
  /// Game chọn sẵn khi mở từ màn Caro / Xếp hình.
  final String initialGame;

  /// Đang nằm trong tab (không có nút quay lại).
  final bool embedded;

  const PvpLobbyScreen({super.key, this.initialGame = kGameCaro, this.embedded = true});

  @override
  State<PvpLobbyScreen> createState() => _PvpLobbyScreenState();
}

class _PvpLobbyScreenState extends State<PvpLobbyScreen> {
  late String _game = widget.initialGame;
  int _puzzleDifficulty = 1;
  Timer? _ticker;
  List<GameStats>? _ratings;
  int? _ratingsFor;
  PvpPhase? _lastPhase;

  int get _difficulty => _game == kGameCaro ? kCaroOnlineDifficulty : _puzzleDifficulty;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = maybeMatchSessionOf(context);
      if (mounted && s?.phase == PvpPhase.queued) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthController>(context);
    final uid = auth.isAuthenticated ? auth.currentUser?.userId : null;
    if (uid != null && uid != _ratingsFor) {
      _ratingsFor = uid;
      _loadRatings();
    }
    // Vừa xong một trận: tải lại rating.
    final phase = maybeMatchSessionOf(context, listen: true)?.phase;
    if (_lastPhase == PvpPhase.ended && phase == PvpPhase.idle) _loadRatings();
    _lastPhase = phase;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadRatings() async {
    try {
      final r = await context.read<ApiClient>().myRatings();
      if (mounted) setState(() => _ratings = r);
    } on ApiException {
      // Không tải được rating thì chỉ ẩn thẻ rating.
    }
  }

  GameStats? _statsFor(String game) {
    for (final s in _ratings ?? const <GameStats>[]) {
      if (s.gameCode == game) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final session = maybeMatchSessionOf(context, listen: true);
    Widget body;
    if (auth.status == AuthStatus.unknown) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!auth.isAuthenticated || session == null) {
      body = EmptyState(
        icon: Icons.sports_mma_rounded,
        title: 'Đăng nhập để đấu với người khác',
        message: 'Tìm trận xếp hạng hoặc mời bạn bè đấu Caro, đua Xếp số. Cần có tài khoản.',
        actionLabel: 'Đăng nhập',
        onAction: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen())),
      );
    } else {
      body = _buildLobby(context, session);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Đối kháng'), automaticallyImplyLeading: !widget.embedded),
      body: body,
    );
  }

  Widget _buildLobby(BuildContext context, MatchSession s) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final busy = s.phase == PvpPhase.queued || s.phase == PvpPhase.inviting || s.phase == PvpPhase.active;

    return ListenableBuilder(
      listenable: s.realtime,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          if (!s.connected)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Đang kết nối máy chủ đấu trực tiếp…',
                        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
          if (s.phase == PvpPhase.active && s.match != null) ...[
            _ActiveMatchCard(session: s),
            const SizedBox(height: AppSpacing.xl),
          ],
          Text('Chọn trò chơi', style: text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _GameTile(
            selected: _game == kGameCaro,
            icon: pvpGameIcon(kGameCaro),
            title: 'Caro',
            subtitle: 'Đánh theo lượt · bàn 15×15 · 30 giây mỗi nước',
            onTap: busy ? null : () => setState(() => _game = kGameCaro),
          ),
          const SizedBox(height: AppSpacing.sm),
          _GameTile(
            selected: _game == kGamePuzzle,
            icon: pvpGameIcon(kGamePuzzle),
            title: 'Đua Xếp số',
            subtitle: 'Cùng một đề · thấy tiến độ đối thủ · ai xong trước thắng',
            onTap: busy ? null : () => setState(() => _game = kGamePuzzle),
          ),
          if (_game == kGamePuzzle) ...[
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final d in const [1, 2, 3]) ButtonSegment(value: d, label: Text(puzzleSizeLabel(d))),
              ],
              selected: {_puzzleDifficulty},
              onSelectionChanged: busy ? null : (v) => setState(() => _puzzleDifficulty = v.first),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _RatingCard(game: _game, stats: _statsFor(_game)),
          const SizedBox(height: AppSpacing.xl),
          _buildAction(context, s),
          const SizedBox(height: AppSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.people_outline_rounded, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Muốn đấu với bạn bè? Vào tab Bạn bè, bấm biểu tượng tay cầm cạnh người bạn đang online '
                  'để mời đấu giao hữu (không tính rating).',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context, MatchSession s) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    switch (s.phase) {
      case PvpPhase.queued:
        final since = s.queueSince ?? DateTime.now();
        final range = s.queueRatingRange;
        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            children: [
              const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
              const SizedBox(height: AppSpacing.md),
              Text('Đang tìm đối thủ… ${formatMmSs(DateTime.now().difference(since))}', style: text.titleMedium),
              const SizedBox(height: 2),
              Text(
                '${pvpGameLabel(s.queueGame ?? _game, s.queueDifficulty)} · '
                '${range > 0 ? 'chênh lệch rating ±$range' : 'mọi mức rating'}',
                style: text.bodySmall?.copyWith(color: scheme.onPrimaryContainer),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(onPressed: s.cancelQueue, child: const Text('Hủy tìm trận')),
            ],
          ),
        );
      case PvpPhase.inviting:
        final inv = s.outgoingInvite;
        final left = inv == null ? 0 : inv.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 99);
        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('Đang chờ ${inv?.friend.displayName ?? 'bạn'} trả lời… ${left}s',
                    style: text.titleSmall),
              ),
              TextButton(onPressed: s.dismissOutgoing, child: const Text('Ẩn')),
            ],
          ),
        );
      case PvpPhase.active:
        return const SizedBox.shrink();
      case PvpPhase.idle:
      case PvpPhase.ended:
        return PrimaryButton(
          label: 'Tìm trận xếp hạng',
          icon: Icons.search_rounded,
          onPressed: s.connected ? () => s.findMatch(_game, _difficulty) : null,
        );
    }
  }
}

class _GameTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _GameTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: selected ? scheme.primary : Colors.transparent, width: 2),
      ),
      child: ListTile(
        minTileHeight: 72,
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(icon, color: scheme.onPrimaryContainer),
        ),
        title: Text(title, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.w500)),
        subtitle: Text(subtitle),
        trailing: Icon(
          selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
          color: selected ? scheme.primary : scheme.outline,
        ),
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  final String game;
  final GameStats? stats;
  const _RatingCard({required this.game, required this.stats});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final s = stats;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rating ${pvpGameName(game)} của bạn', style: text.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                if (s == null || s.games == 0)
                  Text('Chưa có trận xếp hạng nào', style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))
                else
                  Text('${s.games} trận · thắng ${(s.winRate * 100).round()}%',
                      style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          RankBadge(rating: s?.rating ?? 1000, tier: s?.tier),
        ],
      ),
    );
  }
}

class _ActiveMatchCard extends StatelessWidget {
  final MatchSession session;
  const _ActiveMatchCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final m = session.match!;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: ListTile(
        minTileHeight: 72,
        leading: Icon(pvpGameIcon(m.gameCode), color: scheme.onPrimaryContainer),
        title: Text('Bạn đang trong trận ${pvpGameLabel(m.gameCode, m.difficulty)}'),
        subtitle: Text('Đối thủ: ${m.opponent?.displayName ?? '…'}'),
        trailing: FilledButton(
          onPressed: () => openMatchScreen(session),
          child: const Text('Vào trận'),
        ),
      ),
    );
  }
}
