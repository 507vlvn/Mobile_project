import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/difficulty.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/models.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/difficulty_selector.dart';
import '../../core/widgets/player_card.dart';
import '../../core/widgets/primary_button.dart';
import '../history/game_meta.dart';
import 'game_stat_tile.dart';
import '../social/chat_screen.dart';

/// Mở thẻ hồ sơ người chơi (GET /users/{id}/profile) dạng bottom sheet:
/// thống kê theo game + Kết bạn / Hủy lời mời / Bạn bè, Nhắn tin & Mời đấu
/// (chỉ khi là bạn bè).
Future<void> showPlayerProfileSheet(BuildContext context, UserSummary user,
    {bool startWithInvite = false}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) =>
        PlayerProfileSheet(user: user, startWithInvite: startWithInvite),
  );
}

enum _Mode { view, pickInvite, waiting }

class PlayerProfileSheet extends StatefulWidget {
  final UserSummary user;

  /// Thời hạn lời mời chờ đối phương (server cũng hết hạn sau 30 giây).
  final int inviteSeconds;

  /// Mở thẳng bước chọn game để mời đấu (khi là bạn bè).
  final bool startWithInvite;

  const PlayerProfileSheet({
    super.key,
    required this.user,
    this.inviteSeconds = 30,
    this.startWithInvite = false,
  });

  @override
  State<PlayerProfileSheet> createState() => _PlayerProfileSheetState();
}

class _PlayerProfileSheetState extends State<PlayerProfileSheet> {
  PlayerProfile? _profile;
  bool _loading = true;
  String? _error;
  bool _busy = false;
  String? _actionError;

  _Mode _mode = _Mode.view;
  String _game = 'CARO';
  Difficulty _difficulty = Difficulty.medium;
  int _waitLeft = 0;
  Timer? _waitTimer;
  StreamSubscription<InviteResultEvent>? _resultSub;
  String? _inviteNote;

  RealtimeService? get _rt {
    try {
      return context.read<RealtimeService>();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    _resultSub?.cancel();
    super.dispose();
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
        if (widget.startWithInvite &&
            p.relationship == Relationship.friends &&
            _rt != null) {
          _mode = _Mode.pickInvite;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _act(Future<void> Function(ApiClient api) call,
      Relationship Function(PlayerProfile p) next) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await call(context.read<ApiClient>());
      if (!mounted) return;
      setState(() {
        _profile = _profile!.copyWith(relationship: next(_profile!));
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

  Future<void> _sendInvite() async {
    final rt = _rt;
    if (rt == null || _busy) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await rt.invite(widget.user.userId, _game, _difficulty.value);
    } on RealtimeException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _actionError = e.message;
      });
      return;
    }
    if (!mounted) return;
    _resultSub?.cancel();
    _resultSub = rt.inviteResults.listen(_onInviteResult);
    _waitLeft = widget.inviteSeconds;
    _waitTimer?.cancel();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _waitLeft--);
      if (_waitLeft <= 0) {
        _finishWaiting('Hết thời gian chờ, bạn chưa trả lời.');
      }
    });
    setState(() {
      _busy = false;
      _mode = _Mode.waiting;
    });
  }

  void _onInviteResult(InviteResultEvent e) {
    if (_mode != _Mode.waiting || !mounted) return;
    switch (e.outcome) {
      case InviteOutcome.accepted:
        // Trận bắt đầu sẽ được lớp thông báo mở; đóng thẻ hồ sơ.
        _stopWaiting();
        Navigator.of(context).pop();
      case InviteOutcome.declined:
        _finishWaiting('${_profile?.displayName ?? 'Đối phương'} đã từ chối.');
      case InviteOutcome.expired:
        _finishWaiting('Lời mời đã hết hạn.');
      case InviteOutcome.cancelled:
        _finishWaiting('Lời mời đã bị hủy.');
    }
  }

  void _stopWaiting() {
    _waitTimer?.cancel();
    _resultSub?.cancel();
    _waitTimer = null;
    _resultSub = null;
  }

  void _finishWaiting(String note) {
    _stopWaiting();
    if (!mounted) return;
    setState(() {
      _mode = _Mode.view;
      _inviteNote = note;
    });
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
          _header(context),
          const SizedBox(height: AppSpacing.lg),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _errorBlock(context)
          else ...[
            ..._body(context),
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final p = _profile;
    final name = p?.displayName ??
        (widget.user.fullName?.trim().isNotEmpty == true
            ? widget.user.fullName!.trim()
            : widget.user.username);
    final best = p?.best;
    return PlayerCard(
      name: name,
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

  List<Widget> _body(BuildContext context) {
    final p = _profile!;
    return switch (_mode) {
      _Mode.view => [
          _statsGrid(context, p),
          if (p.relationship != Relationship.self) ...[
            const SizedBox(height: AppSpacing.xl),
            ..._actions(context, p),
          ],
        ],
      _Mode.pickInvite => _picker(context, p),
      _Mode.waiting => _waiting(context, p),
    };
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
    final api = context.read<ApiClient>();
    final widgets = <Widget>[];

    if (_inviteNote != null) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded,
                size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
                child: Text(_inviteNote!,
                    style: text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant))),
          ],
        ),
      ));
    }

    switch (p.relationship) {
      case Relationship.none:
        widgets.add(PrimaryButton(
          label: 'Kết bạn',
          icon: Icons.person_add_rounded,
          loading: _busy,
          onPressed: () => _act((_) => api.sendFriendRequest(p.userId),
              (_) => Relationship.pendingOut),
        ));
      case Relationship.pendingOut:
        widgets.add(OutlinedButton.icon(
          style: secondary,
          onPressed: _busy
              ? null
              : () => _act(
                  (_) => api.removeFriend(p.userId), (_) => Relationship.none),
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
              : () => _act((_) => api.acceptFriendRequest(p.requestId!),
                  (_) => Relationship.friends),
        ));
        widgets.add(const SizedBox(height: AppSpacing.xs));
        widgets.add(TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(kMinTouchTarget),
            foregroundColor: scheme.secondary,
          ),
          onPressed: _busy || p.requestId == null
              ? null
              : () => _act((_) => api.declineFriendRequest(p.requestId!),
                  (_) => Relationship.none),
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
          label: 'Mời đấu',
          icon: Icons.sports_esports_rounded,
          onPressed: _rt == null
              ? null
              : () => setState(() {
                    _inviteNote = null;
                    _actionError = null;
                    _mode = _Mode.pickInvite;
                  }),
        ));
        widgets.add(const SizedBox(height: AppSpacing.sm));
        widgets.add(OutlinedButton.icon(
          style: secondary,
          onPressed: _openChat,
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          label: const Text('Nhắn tin'),
        ));
      case Relationship.self:
        break;
    }

    if (_actionError != null) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: _ErrorLine(message: _actionError!),
      ));
    }
    return widgets;
  }

  List<Widget> _picker(BuildContext context, PlayerProfile p) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return [
      Text('Chọn game', style: text.titleSmall),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final g in GameMeta.all)
            ChoiceChip(
              avatar: Icon(_game == g.code ? Icons.check_rounded : g.icon,
                  size: 18),
              label: Text(g.name),
              selected: _game == g.code,
              showCheckmark: false,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onSelected: _busy ? null : (_) => setState(() => _game = g.code),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      Text('Độ khó', style: text.titleSmall),
      const SizedBox(height: AppSpacing.sm),
      DifficultySelector(
        value: _difficulty,
        onChanged: (d) {
          if (!_busy) setState(() => _difficulty = d);
        },
      ),
      const SizedBox(height: AppSpacing.sm),
      Text('Trận giao hữu, không tính rating.',
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      if (_actionError != null) ...[
        const SizedBox(height: AppSpacing.md),
        _ErrorLine(message: _actionError!),
      ],
      const SizedBox(height: AppSpacing.lg),
      PrimaryButton(
        label: 'Gửi lời mời',
        icon: Icons.send_rounded,
        loading: _busy,
        onPressed: _sendInvite,
      ),
      const SizedBox(height: AppSpacing.xs),
      TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(kMinTouchTarget),
          foregroundColor: scheme.secondary,
        ),
        onPressed: _busy ? null : () => setState(() => _mode = _Mode.view),
        child: const Text('Quay lại'),
      ),
    ];
  }

  List<Widget> _waiting(BuildContext context, PlayerProfile p) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final total = widget.inviteSeconds;
    final left = _waitLeft < 0 ? 0 : _waitLeft;
    return [
      Center(
        child: SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: total == 0 ? 0 : left / total,
                  strokeWidth: 5,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              Text('$left',
                  style: text.titleMedium
                      ?.copyWith(fontFeatures: kTabularFigures)),
            ],
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Semantics(
        liveRegion: true,
        child: Text(
          'Đang chờ ${p.displayName} chấp nhận… ${left}s',
          textAlign: TextAlign.center,
          style: text.titleSmall,
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(kMinTouchTarget),
          foregroundColor: scheme.secondary,
        ),
        onPressed: () => _finishWaiting('Bạn đã hủy lời mời.'),
        child: const Text('Hủy'),
      ),
    ];
  }
}

class _ErrorLine extends StatelessWidget {
  final String message;
  const _ErrorLine({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_rounded, size: 18, color: scheme.error),
        const SizedBox(width: 6),
        Expanded(
          child: Text(message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.error)),
        ),
      ],
    );
  }
}
