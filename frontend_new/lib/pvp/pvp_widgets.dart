import 'package:flutter/material.dart';

import '../core/realtime/match_models.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/rank_badge.dart';
import '../core/widgets/user_avatar.dart';
import 'match_session.dart';

/// Thẻ một người chơi trong trận: avatar, tên, rank, quân (X/O), đồng hồ lượt,
/// bong bóng chat nhanh, trạng thái mất kết nối.
class PlayerPanel extends StatelessWidget {
  final MatchPlayer player;
  final String? symbol;
  final bool isMe;
  final bool active;
  final Duration? timeLeft;
  final (String, DateTime)? chat;
  final bool disconnected;

  const PlayerPanel({
    super.key,
    required this.player,
    this.symbol,
    this.isMe = false,
    this.active = false,
    this.timeLeft,
    this.chat,
    this.disconnected = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final recentChat = chat != null && DateTime.now().difference(chat!.$2) < const Duration(seconds: 4);
    final secs = timeLeft == null ? null : (timeLeft!.inMilliseconds / 1000).ceil().clamp(0, 99);
    final urgent = secs != null && secs <= 10;

    return AnimatedContainer(
      duration: AppMotion.fast,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: active ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: active ? scheme.primary : Colors.transparent, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Opacity(
                opacity: disconnected ? 0.4 : 1,
                child: UserAvatar(name: player.displayName, size: 32, highlight: isMe),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isMe ? 'Bạn' : player.displayName,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                    RankBadge(rating: player.rating, tier: player.tier, compact: true),
                  ],
                ),
              ),
              if (symbol != null)
                Text(symbol!,
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: symbol == 'X' ? const Color(0xFFE53935) : const Color(0xFF1E88E5),
                    )),
            ],
          ),
          if (secs != null || recentChat || disconnected) const SizedBox(height: AppSpacing.xs),
          if (disconnected)
            Text('Mất kết nối…', style: text.labelMedium?.copyWith(color: scheme.error))
          else if (recentChat)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
              decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Text(quickChatLabel(chat!.$1), style: text.labelMedium),
            )
          else if (secs != null)
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 16, color: urgent ? scheme.error : scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('${secs}s',
                    style: text.labelLarge?.copyWith(
                      color: urgent ? scheme.error : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ),
        ],
      ),
    );
  }
}

/// Nút chat nhanh (6 câu cố định server cho phép).
class QuickChatButton extends StatelessWidget {
  final MatchSession session;
  final bool enabled;
  const QuickChatButton({super.key, required this.session, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Chat nhanh',
      enabled: enabled,
      icon: const Icon(Icons.chat_bubble_outline_rounded),
      onSelected: session.quickChat,
      itemBuilder: (_) => [
        for (final c in kQuickChatCodes)
          PopupMenuItem(value: c, height: kMinTouchTarget, child: Text(quickChatLabel(c))),
      ],
    );
  }
}

/// Dải báo khi mình đang mất kết nối tới máy chủ.
class ConnectionBanner extends StatelessWidget {
  final MatchSession session;
  const ConnectionBanner({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final rt = session.realtime;
    return ListenableBuilder(
      listenable: rt,
      builder: (context, _) {
        if (rt.isConnected) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Container(
          width: double.infinity,
          color: scheme.errorContainer,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: AppSpacing.xs),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onErrorContainer),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Mất kết nối máy chủ, đang thử lại… (có 30 giây để quay lại trận)',
                    style: TextStyle(color: scheme.onErrorContainer)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Dải báo đối thủ mất kết nối kèm đếm ngược thời gian chờ.
class OpponentStatusBanner extends StatelessWidget {
  final MatchSession session;
  const OpponentStatusBanner({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    if (session.opponentConnected || session.phase != PvpPhase.active) return const SizedBox.shrink();
    final until = session.opponentGraceUntil;
    final left = until?.difference(DateTime.now()).inSeconds.clamp(0, 99);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, 0),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.palette.warning.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: scheme.onSurface),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(left == null
                ? 'Đối thủ mất kết nối…'
                : 'Đối thủ mất kết nối, chờ ${left}s — quá giờ bạn sẽ thắng'),
          ),
        ],
      ),
    );
  }
}

/// Thanh tiến độ của một người trong trận đua.
class RaceProgressBar extends StatelessWidget {
  final String label;
  final int percent;
  final Color color;
  const RaceProgressBar({super.key, required this.label, required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelLarge)),
            Text('$percent%', style: text.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 10,
            color: color,
            backgroundColor: color.withValues(alpha: 0.18),
          ),
        ),
      ],
    );
  }
}
