import 'package:flutter/material.dart';

import '../../features/auth/user_avatar.dart';
import '../models/presence.dart';
import '../models/rank.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'rank_badge.dart';

/// Thẻ người chơi gọn: avatar (chữ cái đầu) + chấm online, tên, @username,
/// huy hiệu rank (tuỳ chọn), widget cuối hàng (tuỳ chọn).
class PlayerCard extends StatelessWidget {
  final String name;
  final String? username;
  final PresenceStatus? presence;
  final int? rating;
  final Tier? tier;

  /// Thay cho "@username" (vd: "Đang online").
  final String? subtitle;
  final double avatarSize;

  /// Nền nổi bật (dòng của chính mình).
  final bool highlight;
  final Widget? trailing;

  const PlayerCard({
    super.key,
    required this.name,
    this.username,
    this.presence,
    this.rating,
    this.tier,
    this.subtitle,
    this.avatarSize = 44,
    this.highlight = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = highlight ? scheme.onPrimaryContainer : scheme.onSurface;
    final muted =
        highlight ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    final sub = subtitle ?? (username == null ? null : '@$username');

    final row = Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            UserAvatar(name: name, size: avatarSize, highlight: highlight),
            if (presence != null)
              Positioned(
                right: -2,
                bottom: -2,
                child: PresenceDot(status: presence!),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(color: fg)),
              if (sub != null)
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: muted)),
              if (rating != null) ...[
                const SizedBox(height: 2),
                RankBadge(rating: rating!, tier: tier, compact: true),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );

    final label = [
      name,
      if (username != null) '@$username',
      if (presence != null) presence!.label,
      if (rating != null)
        'rank ${(tier ?? Tier.fromRating(rating!)).label}, $rating điểm',
    ].join(', ');

    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(child: row),
    );
  }
}

/// Chấm trạng thái online. Không chỉ dựa vào màu: online = chấm đặc,
/// đang trong trận = chấm có icon tay cầm, offline = chấm rỗng; kèm Semantics.
class PresenceDot extends StatelessWidget {
  final PresenceStatus status;
  final double size;
  const PresenceDot({super.key, required this.status, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final color = switch (status) {
      PresenceStatus.online => palette.success,
      PresenceStatus.inMatch => palette.warning,
      PresenceStatus.offline => scheme.onSurfaceVariant,
    };
    return Semantics(
      label: status.label,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: status == PresenceStatus.offline ? scheme.surface : color,
            border: Border.all(
              color: status == PresenceStatus.offline ? color : scheme.surface,
              width: 2,
            ),
          ),
          child: status == PresenceStatus.inMatch
              ? Icon(Icons.sports_esports_rounded,
                  size: size - 6, color: scheme.surface)
              : null,
        ),
      ),
    );
  }
}
