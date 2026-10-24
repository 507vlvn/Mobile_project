import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/game_meta.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/models.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/player_card.dart';
import '../core/widgets/primary_button.dart';
import '../friends/chat_screen.dart';
import 'game_stat_tile.dart';

/// Mở thẻ hồ sơ người chơi (GET /users/{id}/profile) dạng bottom sheet:
/// thống kê theo game + Kết bạn / Hủy lời mời / Chấp nhận, Nhắn tin (khi là bạn bè).
Future<void> showPlayerProfileSheet(BuildContext context, UserSummary user) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => PlayerProfileSheet(user: user),
  );
}

class PlayerProfileSheet extends StatefulWidget {
  final UserSummary user;

  const PlayerProfileSheet({super.key, required this.user});

  @override
  State<PlayerProfileSheet> createState() => _PlayerProfileSheetState();
}

class _PlayerProfileSheetState extends State<PlayerProfileSheet> {
  PlayerProfile? _profile;
  bool _loading = true;
  String? _error;
  bool _busy = false;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await context.read<ApiClient>().userProfile(widget.user.userId);
      if (!mounted) return;
      setState(() {
        _profile = p;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _act(
      Future<void> Function(ApiClient api) call, Relationship next) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await call(context.read<ApiClient>());
      if (!mounted) return;
      setState(() {
        _profile = _profile!.withRelationship(next);
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _actionError = e.message;
      });
    }
  }

  void _openChat() {
    final nav = Navigator.of(context);
    final partner = widget.user;
    nav.pop();
    nav.push(
        MaterialPageRoute<void>(builder: (_) => ChatScreen(partner: partner)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.xl + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: AppSpacing.lg),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _errorBlock(context)
          else ...[
            _statsGrid(context, _profile!),
            if (_profile!.relationship != Relationship.self) ...[
              const SizedBox(height: AppSpacing.xl),
              ..._actions(context, _profile!),
            ],
          ],
        ],
      ),
    );
  }

  Widget _header() {
    final p = _profile;
    final best = p?.best;
    return PlayerCard(
      name: p?.displayName ?? widget.user.displayName,
      username: p?.username ?? widget.user.username,
      avatarSize: 56,
      presence: p?.presence,
      rating: best?.rating,
      tier: best?.tier,
    );
  }

  Widget _errorBlock(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(_error!,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.error)),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(kMinTouchTarget)),
          onPressed: _load,
          child: const Text('Thử lại'),
        ),
      ],
    );
  }

  // ---- thống kê ----

  Widget _statsGrid(BuildContext context, PlayerProfile p) {
    final tiles = [
      for (final g in GameMeta.all)
        GameStatTile(
            meta: g, stats: p.statsFor(g.code) ?? GameStats(gameCode: g.code)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Thống kê đối kháng',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: tiles[0]),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: tiles[1]),
        ])),
        const SizedBox(height: AppSpacing.sm),
        IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: tiles[2]),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: tiles[3]),
        ])),
      ],
    );
  }

  // ---- hành động ----

  List<Widget> _actions(BuildContext context, PlayerProfile p) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final secondary = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(kMinTouchTarget),
      foregroundColor: scheme.secondary,
    );
    final widgets = <Widget>[];

    switch (p.relationship) {
      case Relationship.none:
        widgets.add(PrimaryButton(
          label: 'Kết bạn',
          icon: Icons.person_add_rounded,
          loading: _busy,
          onPressed: () => _act((api) => api.sendFriendRequest(p.userId),
              Relationship.pendingOut),
        ));
      case Relationship.pendingOut:
        widgets.add(OutlinedButton.icon(
          style: secondary,
          onPressed: _busy
              ? null
              : () => _act(
                  (api) => api.removeFriend(p.userId), Relationship.none),
          icon: const Icon(Icons.undo_rounded),
          label: const Text('Hủy lời mời'),
        ));
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text('Đã gửi lời mời, đang chờ ${p.displayName} trả lời.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ));
      case Relationship.pendingIn:
        widgets.add(PrimaryButton(
          label: 'Chấp nhận kết bạn',
          icon: Icons.check_rounded,
          loading: _busy,
          onPressed: p.requestId == null
              ? null
              : () => _act((api) => api.acceptFriendRequest(p.requestId!),
                  Relationship.friends),
        ));
        widgets.add(const SizedBox(height: AppSpacing.xs));
        widgets.add(TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(kMinTouchTarget),
            foregroundColor: scheme.secondary,
          ),
          onPressed: _busy || p.requestId == null
              ? null
              : () => _act((api) => api.declineFriendRequest(p.requestId!),
                  Relationship.none),
          child: const Text('Từ chối'),
        ));
      case Relationship.friends:
        widgets.add(Semantics(
          label: 'Đã là bạn bè',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 20, color: context.palette.success),
              const SizedBox(width: 6),
              Text('Bạn bè', style: text.titleSmall),
            ],
          ),
        ));
        widgets.add(const SizedBox(height: AppSpacing.md));
        widgets.add(PrimaryButton(
          label: 'Nhắn tin',
          icon: Icons.chat_bubble_outline_rounded,
          onPressed: _openChat,
        ));
      case Relationship.self:
        break;
    }

    if (_actionError != null) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_rounded, size: 18, color: scheme.error),
            const SizedBox(width: 6),
            Expanded(
              child: Text(_actionError!,
                  style: text.bodyMedium?.copyWith(color: scheme.error)),
            ),
          ],
        ),
      ));
    }
    return widgets;
  }
}
