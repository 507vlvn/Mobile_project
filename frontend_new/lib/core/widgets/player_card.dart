import 'package:flutter/material.dart';

import '../models/rank.dart';
import '../theme/app_tokens.dart';
import 'rank_badge.dart';
import 'user_avatar.dart';

/// Thẻ người chơi gọn: avatar (chữ cái đầu), tên, @username,
/// huy hiệu rank (tuỳ chọn), widget cuối hàng (tuỳ chọn).
class PlayerCard extends StatelessWidget {
  final String name;
  final String? username;
  final int? rating;
  final Tier? tier;

  /// Thay cho "@username".
  final String? subtitle;
  final double avatarSize;

  /// Nền nổi bật (dòng của chính mình).
  final bool highlight;
  final Widget? trailing;

  const PlayerCard({
    super.key,
    required this.name,
    this.username,
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
        UserAvatar(name: name, size: avatarSize, highlight: highlight),
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
