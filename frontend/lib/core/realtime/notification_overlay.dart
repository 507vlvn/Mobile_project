import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../features/auth/user_avatar.dart';
import '../../features/history/game_meta.dart';
import '../models/difficulty.dart';
import '../network/models.dart';
import '../services/match_launcher.dart';
import '../services/shell_navigation.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'active_chat.dart';
import 'banner_queue.dart';
import 'realtime_service.dart';

/// Lớp thông báo nổi trong app: bọc quanh Navigator của `MaterialApp.builder`.
///
/// Hiện banner ở đầu màn hình (tối đa một cái, các cái khác xếp hàng) cho:
/// lời mời đấu (đồng hồ 30 giây + Chấp nhận / Từ chối), lời mời kết bạn (Xem),
/// tin nhắn mới (khi chưa mở đúng cuộc trò chuyện đó). Có rung nhẹ.
///
/// Trận GIAO HỮU bắt đầu (sau khi mình chấp nhận, hoặc bạn chấp nhận lời mời
/// của mình) được mở bằng [MatchLauncher]; chưa có ai đăng ký thì hiện
/// SnackBar "Đang mở trận…".
class NotificationOverlay extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Mở màn chat với người gửi (do app truyền vào để lớp core không phụ thuộc
  /// màn hình của tính năng Bạn bè).
  final void Function(NavigatorState navigator, UserSummary partner)? onOpenChat;

  /// Id người dùng hiện tại, để bỏ qua tin do chính mình gửi từ thiết bị khác.
  final int? Function()? myId;

  /// Đồng hồ (cho test điều khiển đếm ngược lời mời).
  final DateTime Function()? clock;

  const NotificationOverlay({
    super.key,
    required this.child,
    this.navigatorKey,
    this.onOpenChat,
    this.myId,
    this.clock,
  });

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay> {
  late final BannerQueue _queue = BannerQueue(now: widget.clock);
  final List<StreamSubscription<Object?>> _subs = [];
  RealtimeService? _rt;
  Timer? _autoTimer;
  String? _shownKey;

  @override
  void initState() {
    super.initState();
    _queue.addListener(_onQueueChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rt != null) return;
    try {
      _rt = context.read<RealtimeService>();
    } catch (_) {
      return; // không có realtime (vd. test/ảnh chụp một màn): lớp phủ vô hiệu
    }
    final rt = _rt!;
    _subs.addAll([
      rt.invitesReceived.listen((e) => _queue.add(InviteBanner(e))),
      rt.friendRequests.listen((e) => _queue.add(FriendRequestBanner(e))),
      rt.messages.listen(_onMessage),
      rt.matchStarted.listen(_onMatchStarted),
    ]);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _queue.removeListener(_onQueueChanged);
    _queue.dispose();
    super.dispose();
  }

  void _onMessage(MessageReceivedEvent e) {
    final m = e.message;
    if (m.senderId == widget.myId?.call()) return;
    if (ActiveChat.partnerId == m.senderId) return;
    _queue.add(MessageBanner(e));
  }

  void _onMatchStarted(MatchInfo match) {
    if (match.mode != MatchMode.friendly) return;
    final nav = widget.navigatorKey?.currentState;
    if (nav != null && MatchLauncher.open(nav, match)) return;
    _snack('Đang mở trận…');
  }

  void _onQueueChanged() {
    final cur = _queue.current;
    if (cur?.key != _shownKey) {
      _shownKey = cur?.key;
      _autoTimer?.cancel();
      if (cur != null) {
        HapticFeedback.lightImpact();
        final d = cur.autoDismiss;
        if (d != null) {
          _autoTimer = Timer(d, () {
            if (mounted && _queue.current?.key == cur.key) {
              _queue.dismissCurrent();
            }
          });
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _respond(InviteBanner b, bool accept) async {
    _queue.dismissKey(b.key);
    try {
      await _rt!.respondInvite(b.invite.inviteId, accept);
      if (accept) _snack('Đang mở trận…');
    } on RealtimeException catch (e) {
      _snack(e.message);
    }
  }

  void _openFriendRequests() {
    final nav = widget.navigatorKey?.currentState;
    nav?.popUntil((r) => r.isFirst);
    try {
      context
          .read<ShellNavigation>()
          .show(ShellTab.friends, segment: FriendsSegment.requests);
    } catch (_) {}
  }

  void _openChat(MessageBanner b) {
    final nav = widget.navigatorKey?.currentState;
    final partner =
        (b.message.sender ?? RtUser(userId: b.message.message.senderId)).summary;
    if (nav != null) widget.onOpenChat?.call(nav, partner);
  }

  @override
  Widget build(BuildContext context) {
    final cur = _queue.current;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: AnimatedSwitcher(
                duration: AppMotion.of(context, AppMotion.normal),
                switchInCurve: AppMotion.enter,
                switchOutCurve: AppMotion.exit,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, -0.3), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: switch (cur) {
                  null => const SizedBox.shrink(key: ValueKey('none')),
                  final InviteBanner b => InviteBannerCard(
                      key: ValueKey(b.key),
                      invite: b.invite,
                      now: widget.clock,
                      onAccept: () => _respond(b, true),
                      onDecline: () => _respond(b, false),
                      onExpired: () => _queue.dismissKey(b.key),
                    ),
                  final FriendRequestBanner b => _SimpleBanner(
                      key: ValueKey(b.key),
                      icon: Icons.person_add_rounded,
                      title: b.request.from.displayName,
                      subtitle: 'Gửi lời mời kết bạn',
                      actionLabel: 'Xem',
                      onAction: () {
                        _queue.dismissKey(b.key);
                        _openFriendRequests();
                      },
                      onClose: () => _queue.dismissKey(b.key),
                    ),
                  final MessageBanner b => _SimpleBanner(
                      key: ValueKey(b.key),
                      icon: Icons.chat_bubble_rounded,
                      title: b.message.sender?.displayName ?? 'Tin nhắn mới',
                      subtitle: b.message.message.content,
                      actionLabel: 'Mở',
                      onAction: () {
                        _queue.dismissKey(b.key);
                        _openChat(b);
                      },
                      onClose: () => _queue.dismissKey(b.key),
                    ),
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ thẻ

class _BannerSurface extends StatelessWidget {
  final Widget child;
  final String semanticsLabel;
  const _BannerSurface({required this.child, required this.semanticsLabel});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticsLabel,
      child: Material(
        color: scheme.surfaceContainerHigh,
        elevation: 6,
        shadowColor: scheme.shadow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Banner lời mời kết bạn / tin nhắn: icon + nội dung + nút hành động + đóng.
class _SimpleBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onClose;

  const _SimpleBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return _BannerSurface(
      semanticsLabel: '$title, $subtitle',
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: scheme.primaryContainer, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
              foregroundColor: scheme.secondary,
            ),
            onPressed: onAction,
            child: Text(actionLabel),
          ),
          // Không dùng tooltip: lớp này nằm trên Navigator nên không có Overlay.
          Semantics(
            button: true,
            label: 'Đóng thông báo',
            excludeSemantics: true,
            child: IconButton(
              constraints: const BoxConstraints(
                  minWidth: kMinTouchTarget, minHeight: kMinTouchTarget),
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner lời mời đấu với vòng đếm ngược. [now] cho phép test điều khiển đồng hồ.
class InviteBannerCard extends StatefulWidget {
  final InviteReceivedEvent invite;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onExpired;
  final DateTime Function()? now;

  const InviteBannerCard({
    super.key,
    required this.invite,
    required this.onAccept,
    required this.onDecline,
    required this.onExpired,
    this.now,
  });

  @override
  State<InviteBannerCard> createState() => _InviteBannerCardState();
}

class _InviteBannerCardState extends State<InviteBannerCard> {
  Timer? _tick;
  late int _remaining = _calc();

  DateTime _now() => (widget.now ?? DateTime.now)();
  int _calc() => widget.invite.remainingSec(_now());

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final r = _calc();
      if (!mounted) return;
      setState(() => _remaining = r);
      if (r <= 0) {
        _tick?.cancel();
        widget.onExpired();
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final inv = widget.invite;
    final game = GameMeta.of(inv.gameCode);
    final total = inv.totalDuration.inSeconds;
    final progress = total <= 0 ? 0.0 : (_remaining / total).clamp(0.0, 1.0);
    final name = inv.from.displayName;
    final level = Difficulty.fromValue(inv.difficulty).label;

    return _BannerSurface(
      semanticsLabel:
          '$name mời bạn đấu ${game.name}, độ khó $level, còn $_remaining giây',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: progress),
                        duration: AppMotion.of(
                            context, const Duration(milliseconds: 900)),
                        builder: (context, v, _) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 4,
                          backgroundColor: scheme.surfaceContainerHighest,
                          color: _remaining <= 5 ? scheme.error : scheme.primary,
                        ),
                      ),
                    ),
                    Text('$_remaining',
                        style: text.titleSmall
                            ?.copyWith(fontFeatures: kTabularFigures)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              UserAvatar(name: name, size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$name mời bạn đấu',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall),
                    Row(
                      children: [
                        Icon(game.icon,
                            size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text('${game.name} · $level · Giao hữu',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(kMinTouchTarget),
                    foregroundColor: scheme.onSurface,
                  ),
                  onPressed: widget.onDecline,
                  child: const Text('Từ chối'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(kMinTouchTarget),
                  ),
                  onPressed: widget.onAccept,
                  child: const Text('Chấp nhận'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
