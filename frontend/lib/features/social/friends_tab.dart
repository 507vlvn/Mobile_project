import 'package:flutter/material.dart';

import '../../core/models/presence.dart';
import '../../core/network/models.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/player_card.dart';
import '../profile/player_profile_sheet.dart';
import 'chat_screen.dart';
import 'friends_controller.dart';
import 'player_sheet.dart';

/// Hộp xác nhận hủy kết bạn.
Future<bool> confirmUnfriend(BuildContext context, FriendInfo f) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.person_remove_rounded),
      title: const Text('Hủy kết bạn?'),
      content: Text(
          'Bạn và ${f.displayName} sẽ không còn nhắn tin hay mời đấu được với nhau.'),
      actions: [
        TextButton(
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
          child: const Text('Hủy kết bạn'),
        ),
      ],
    ),
  );
  return r ?? false;
}

enum FriendMenu { profile, async, unfriend }

/// Danh sách bạn: online -> đang trong trận -> offline; mỗi dòng có Mời đấu,
/// Nhắn tin và menu (Xem hồ sơ, Thách đấu không đồng thời, Hủy kết bạn).
class FriendsList extends StatelessWidget {
  final FriendsController controller;
  final VoidCallback onFindFriends;
  const FriendsList({
    super.key,
    required this.controller,
    required this.onFindFriends,
  });

  Future<void> _menu(BuildContext context, FriendMenu m, FriendInfo f) async {
    switch (m) {
      case FriendMenu.profile:
        await showPlayerProfileSheet(context, f.summary);
      case FriendMenu.async:
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          useSafeArea: true,
          builder: (_) => PlayerSheet(player: f.summary, startInPicker: true),
        );
      case FriendMenu.unfriend:
        if (await confirmUnfriend(context, f)) {
          final ok = await controller.unfriend(f);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
                content: Text(ok
                    ? 'Đã hủy kết bạn với ${f.displayName}'
                    : (controller.actionError ?? 'Không thực hiện được'))));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.loading && c.friends.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (c.error != null && c.friends.isEmpty) {
      return ErrorState(message: c.error!, onRetry: c.load);
    }
    if (c.friends.isEmpty) {
      return _scrollableEmpty(
        c.load,
        EmptyState(
          icon: Icons.people_outline_rounded,
          title: 'Chưa có bạn bè',
          message: 'Tìm người chơi và gửi lời mời để cùng đấu và nhắn tin.',
          actionLabel: 'Tìm bạn',
          onAction: onFindFriends,
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: c.load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: c.friends.length + 1,
        separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: AppSpacing.screen + 44 + AppSpacing.md,
            color: scheme.outlineVariant),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0,
                  AppSpacing.screen, AppSpacing.sm),
              child: Text(
                '${c.onlineCount} đang online · ${c.friends.length} bạn bè',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            );
          }
          final f = c.friends[i - 1];
          return FriendRow(
            friend: f,
            onInvite: () =>
                showPlayerProfileSheet(context, f.summary, startWithInvite: true),
            onChat: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ChatScreen(partner: f.summary))),
            onMenu: (m) => _menu(context, m, f),
          );
        },
      ),
    );
  }
}

Widget _scrollableEmpty(Future<void> Function() onRefresh, Widget child) =>
    RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, c) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: c.maxHeight, child: child)],
        ),
      ),
    );

class FriendRow extends StatelessWidget {
  final FriendInfo friend;
  final VoidCallback onInvite;
  final VoidCallback onChat;
  final ValueChanged<FriendMenu> onMenu;
  const FriendRow({
    super.key,
    required this.friend,
    required this.onInvite,
    required this.onChat,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final f = friend;
    final scheme = Theme.of(context).colorScheme;
    final canInvite = f.presence == PresenceStatus.online;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.screen),
        child: Row(
          children: [
            Expanded(
              child: PlayerCard(
                name: f.displayName,
                presence: f.presence,
                subtitle: presenceText(f),
              ),
            ),
            IconButton(
              tooltip: canInvite
                  ? 'Mời ${f.displayName} đấu'
                  : '${f.displayName} chưa sẵn sàng để đấu',
              constraints: const BoxConstraints(
                  minWidth: kMinTouchTarget, minHeight: kMinTouchTarget),
              color: scheme.primary,
              onPressed: canInvite ? onInvite : null,
              icon: const Icon(Icons.sports_esports_rounded),
            ),
            IconButton(
              tooltip: 'Nhắn tin cho ${f.displayName}',
              constraints: const BoxConstraints(
                  minWidth: kMinTouchTarget, minHeight: kMinTouchTarget),
              onPressed: onChat,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
            ),
            PopupMenuButton<FriendMenu>(
              tooltip: 'Thêm tùy chọn',
              constraints: const BoxConstraints(minWidth: 220),
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: onMenu,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: FriendMenu.profile,
                  height: kMinTouchTarget,
                  child: Text('Xem hồ sơ'),
                ),
                PopupMenuItem(
                  value: FriendMenu.async,
                  height: kMinTouchTarget,
                  child: Text('Thách đấu không đồng thời'),
                ),
                PopupMenuItem(
                  value: FriendMenu.unfriend,
                  height: kMinTouchTarget,
                  child: Text('Hủy kết bạn'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ lời mời

class RequestsList extends StatelessWidget {
  final FriendsController controller;
  final VoidCallback onFindFriends;
  const RequestsList({
    super.key,
    required this.controller,
    required this.onFindFriends,
  });

  Future<void> _run(BuildContext context, Future<bool> Function() action,
      String okText) async {
    final ok = await action();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(ok
              ? okText
              : (controller.actionError ?? 'Không thực hiện được'))));
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (c.loading && c.incoming.isEmpty && c.outgoing.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (c.error != null && c.incoming.isEmpty && c.outgoing.isEmpty) {
      return ErrorState(message: c.error!, onRetry: c.load);
    }
    if (c.incoming.isEmpty && c.outgoing.isEmpty) {
      return _scrollableEmpty(
        c.load,
        EmptyState(
          icon: Icons.mail_outline_rounded,
          title: 'Chưa có lời mời nào',
          message: 'Lời mời kết bạn đến và đi sẽ hiện ở đây.',
          actionLabel: 'Tìm bạn',
          onAction: onFindFriends,
        ),
      );
    }

    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xs),
          child: Text(t, style: text.titleSmall),
        );

    return RefreshIndicator(
      onRefresh: c.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          if (c.incoming.isNotEmpty) ...[
            header('Lời mời đến (${c.incoming.length})'),
            for (final r in c.incoming)
              _RequestRow(
                item: r,
                actions: [
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                        minimumSize:
                            const Size(kMinTouchTarget, kMinTouchTarget)),
                    onPressed: () => _run(context, () => c.accept(r),
                        'Đã kết bạn với ${r.displayName}'),
                    child: const Text('Chấp nhận'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
                      foregroundColor: scheme.secondary,
                    ),
                    onPressed: () => _run(
                        context, () => c.decline(r), 'Đã từ chối lời mời'),
                    child: const Text('Từ chối'),
                  ),
                ],
              ),
          ],
          if (c.outgoing.isNotEmpty) ...[
            header('Đã gửi (${c.outgoing.length})'),
            for (final r in c.outgoing)
              _RequestRow(
                item: r,
                subtitle: 'Đang chờ trả lời',
                actions: [
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
                      foregroundColor: scheme.secondary,
                    ),
                    onPressed: () => _run(context, () => c.cancelOutgoing(r),
                        'Đã hủy lời mời'),
                    child: const Text('Hủy'),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final FriendRequestItem item;
  final String? subtitle;
  final List<Widget> actions;
  const _RequestRow({required this.item, this.subtitle, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screen, vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => showPlayerProfileSheet(context, item.user),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kMinTouchTarget),
              child: PlayerCard(
                name: item.displayName,
                username: item.user.username,
                subtitle: subtitle,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (final a in actions) ...[
                a,
                const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
