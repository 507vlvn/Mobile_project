import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../core/network/api_client.dart';
import '../core/network/models.dart';
import '../core/realtime/realtime_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/feedback_states.dart';
import '../core/widgets/user_avatar.dart';
import 'chat_controller.dart';
import 'logic/chat_format.dart';

/// Màn chat 1-1. Tin mới đến qua realtime; mất kết nối thì hỏi định kỳ để dự phòng.
class ChatScreen extends StatefulWidget {
  final UserSummary partner;

  /// Cho phép test truyền controller dựng sẵn.
  @visibleForTesting
  final ChatController? controllerOverride;

  const ChatScreen({super.key, required this.partner, this.controllerOverride});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  late final ChatController _chat;
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _focus = FocusNode();

  int? _lastSeenId; // id tin cuối đã được xử lý cuộn
  int _lastPendingCount = 0;
  bool _showNewChip = false;

  static const _bottomSlack = 80.0;

  bool get _atBottom => !_scroll.hasClients || _scroll.offset <= _bottomSlack;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chat = widget.controllerOverride ??
        ChatController(
          api: context.read<ApiClient>(),
          myId: context.read<AuthController>().currentUser?.userId ?? 0,
          partnerId: widget.partner.userId,
          realtime: maybeRealtimeOf(context),
        );
    _chat.addListener(_onChat);
    _scroll.addListener(_onScroll);
    _chat.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chat.removeListener(_onChat);
    if (widget.controllerOverride == null) _chat.dispose();
    _scroll.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _chat.resume();
    } else {
      _chat.pause();
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_atBottom && _showNewChip) setState(() => _showNewChip = false);
    // Danh sách đảo chiều: extentAfter là phần còn lại phía tin cũ.
    if (_scroll.position.extentAfter < 200) _chat.loadOlder();
  }

  void _onChat() {
    final msgs = _chat.messages;
    final lastId = msgs.isEmpty ? null : msgs.last.messageId;
    final pendingGrew = _chat.pending.length > _lastPendingCount;
    _lastPendingCount = _chat.pending.length;

    if (lastId != _lastSeenId) {
      final first = _lastSeenId == null;
      _lastSeenId = lastId;
      final lastIsMine = msgs.isNotEmpty && msgs.last.senderId == _chat.myId;
      if (!first && !lastIsMine && !_atBottom) {
        _showNewChip = true; // đang đọc tin cũ: không giật màn hình
      } else {
        _scrollToBottom();
      }
    } else if (pendingGrew) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (reduce) {
        _scroll.jumpTo(0);
      } else {
        _scroll.animateTo(0,
            duration: AppMotion.normal, curve: AppMotion.enter);
      }
    });
    if (_showNewChip) setState(() => _showNewChip = false);
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    _chat.send(text);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.partner;
    final name = (p.fullName != null && p.fullName!.trim().isNotEmpty)
        ? p.fullName!.trim()
        : p.username;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(name: name, size: 36),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium),
                  Text('@${p.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: _chat,
                builder: (context, _) => _buildList(context),
              ),
            ),
            _Composer(
              controller: _input,
              focusNode: _focus,
              chat: _chat,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    if (_chat.loading && _chat.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_chat.error != null && _chat.messages.isEmpty) {
      return ErrorState(message: _chat.error!, onRetry: _chat.retryInitial);
    }
    final rows = buildChatRows(_chat.messages, _chat.pending);
    if (rows.isEmpty) {
      return const EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Chưa có tin nhắn',
        message: 'Gửi lời chào để bắt đầu cuộc trò chuyện.',
      );
    }
    final myId = _chat.myId;
    // Đảo chiều: phần tử 0 là tin mới nhất, nằm sát ô nhập.
    final reversed = rows.reversed.toList();
    final hasOlder = _chat.hasMore;
    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screen, vertical: AppSpacing.sm),
          itemCount: reversed.length + (hasOlder ? 1 : 0),
          itemBuilder: (context, i) {
            if (i >= reversed.length) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5)),
                ),
              );
            }
            final row = reversed[i];
            return switch (row) {
              DaySeparatorRow() => _DaySeparator(day: row.day),
              MessageRow() => _Bubble(
                  text: row.message.content,
                  time: row.message.sentAt,
                  mine: row.message.senderId == myId,
                ),
              PendingRow() => _Bubble(
                  text: row.pending.text,
                  time: row.pending.time,
                  mine: true,
                  sending: !row.pending.failed,
                  failed: row.pending.failed,
                  error: row.pending.error,
                  onRetry: () => _chat.retry(row.pending.localId),
                  onDiscard: () => _chat.discard(row.pending.localId),
                ),
            };
          },
        ),
        if (_showNewChip)
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.sm,
            child: Center(
              child: ActionChip(
                avatar: const Icon(Icons.arrow_downward_rounded, size: 18),
                label: const Text('Tin mới'),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onPressed: _scrollToBottom,
              ),
            ),
          ),
      ],
    );
  }
}

class _DaySeparator extends StatelessWidget {
  final DateTime day;
  const _DaySeparator({required this.day});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Text(
            dayLabel(day),
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final DateTime time;
  final bool mine;
  final bool sending;
  final bool failed;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  const _Bubble({
    required this.text,
    required this.time,
    required this.mine,
    this.sending = false,
    this.failed = false,
    this.error,
    this.onRetry,
    this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final bg = mine ? scheme.primary : scheme.surfaceContainerHigh;
    final fg = mine ? scheme.onPrimary : scheme.onSurface;
    final meta = scheme.onSurfaceVariant;
    final maxW = MediaQuery.sizeOf(context).width * 0.78;
    final status = failed
        ? 'gửi lỗi'
        : sending
            ? 'đang gửi'
            : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Semantics(
            label:
                '${mine ? 'Bạn' : 'Đối phương'}, ${formatClock(time)}${status == null ? '' : ', $status'}: $text',
            excludeSemantics: true,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppRadius.lg),
                    topRight: const Radius.circular(AppRadius.lg),
                    bottomLeft: Radius.circular(mine ? AppRadius.lg : AppRadius.sm),
                    bottomRight:
                        Radius.circular(mine ? AppRadius.sm : AppRadius.lg),
                  ),
                  border: failed
                      ? Border.all(color: scheme.error, width: 1.5)
                      : null,
                ),
                child: Text(text,
                    style: theme.bodyMedium?.copyWith(color: fg, height: 1.35)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: failed
                ? _FailedFooter(error: error, onRetry: onRetry, onDiscard: onDiscard)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sending) ...[
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: meta),
                        ),
                        const SizedBox(width: 6),
                        Text('Đang gửi',
                            style: theme.labelSmall?.copyWith(color: meta)),
                      ] else
                        Text(formatClock(time),
                            style: theme.labelSmall?.copyWith(color: meta)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FailedFooter extends StatelessWidget {
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;
  const _FailedFooter({this.error, this.onRetry, this.onDiscard});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_rounded, size: 16, color: scheme.error),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                (error != null && error!.length <= 48) ? error! : 'Chưa gửi được',
                style: theme.labelMedium?.copyWith(color: scheme.error),
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
                foregroundColor: scheme.secondary,
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
                foregroundColor: context.palette.onSurfaceMuted,
              ),
              onPressed: onDiscard,
              child: const Text('Xoá'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ChatController chat;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.chat,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 5,
                maxLength: ChatController.maxLength,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                  // Chỉ hiện bộ đếm khi gần chạm giới hạn
                  if (maxLength == null || currentLength < maxLength * 0.9) {
                    return null;
                  }
                  return Text(
                    '$currentLength/$maxLength',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: currentLength >= maxLength
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                  );
                },
                decoration: const InputDecoration(
                  hintText: 'Nhập tin nhắn',
                  isDense: false,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ListenableBuilder(
              listenable: Listenable.merge([chat, controller]),
              builder: (context, _) {
                final sending = chat.sending;
                final empty = controller.text.trim().isEmpty;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Semantics(
                    label: sending ? 'Gửi tin nhắn, đang gửi' : 'Gửi tin nhắn',
                    button: true,
                    excludeSemantics: true,
                    child: IconButton.filled(
                      constraints: const BoxConstraints(
                          minWidth: kMinTouchTarget, minHeight: kMinTouchTarget),
                      // Đang gửi: giữ màu nút (không xám) nhưng chặn bấm lặp
                      onPressed: empty ? null : (sending ? () {} : onSend),
                      icon: sending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: scheme.onPrimary),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
