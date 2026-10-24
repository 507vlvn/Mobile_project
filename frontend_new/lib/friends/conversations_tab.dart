import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/models.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/feedback_states.dart';
import '../core/widgets/user_avatar.dart';
import '../core/models/game_meta.dart';
import 'chat_screen.dart';

/// Danh sách hội thoại. Chỉ tải khi mở và khi kéo để làm mới.
class ConversationsTab extends StatefulWidget {
  /// Báo số tin chưa đọc chính xác để cập nhật huy hiệu.
  final ValueChanged<int>? onUnreadCount;

  const ConversationsTab({super.key, this.onUnreadCount});

  @override
  State<ConversationsTab> createState() => ConversationsTabState();
}

class ConversationsTabState extends State<ConversationsTab> {
  List<Conversation> _items = const [];
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final id = ++_requestId;
    if (_items.isEmpty) setState(() => _loading = true);
    try {
      final list = await context.read<ApiClient>().conversations();
      if (!mounted || id != _requestId) return;
      setState(() {
        _items = list;
        _loading = false;
        _error = null;
      });
      widget.onUnreadCount?.call(list.fold(0, (s, c) => s + c.unreadCount));
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _open(Conversation c) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ChatScreen(partner: c.user)),
    );
    if (mounted) load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return ErrorState(message: _error!, onRetry: load);
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: load,
        child: LayoutBuilder(
          builder: (context, c) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: c.maxHeight,
                child: const EmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Chưa có cuộc trò chuyện',
                  message:
                      'Chọn một người bạn ở tab Bạn bè rồi bấm biểu tượng tin nhắn.',
                ),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: _items.length,
        separatorBuilder: (_, _) => Divider(
            height: 1,
            indent: AppSpacing.screen + 52 + AppSpacing.md,
            color: Theme.of(context).colorScheme.outlineVariant),
        itemBuilder: (context, i) =>
            ConversationRow(item: _items[i], onTap: () => _open(_items[i])),
      ),
    );
  }
}

class ConversationRow extends StatelessWidget {
  final Conversation item;
  final VoidCallback onTap;
  const ConversationRow({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final unread = item.unreadCount > 0;
    final preview = (item.lastFromMe ? 'Bạn: ' : '') + item.lastMessage;
    final time = relativeTimeVi(item.lastMessageAt);

    return Semantics(
      button: true,
      label:
          '${item.displayName}${unread ? ', ${item.unreadCount} tin chưa đọc' : ''}, $preview, $time',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screen, vertical: AppSpacing.sm),
            child: Row(
              children: [
                UserAvatar(name: item.displayName, size: 52),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(
                          color: unread
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                          fontWeight: unread ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(time,
                        style: text.labelSmall
                            ?.copyWith(color: context.palette.onSurfaceMuted)),
                    const SizedBox(height: 6),
                    if (unread)
                      _UnreadPill(count: item.unreadCount)
                    else
                      const SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadPill extends StatelessWidget {
  final int count;
  const _UnreadPill({required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
              fontFeatures: kTabularFigures,
            ),
      ),
    );
  }
}
