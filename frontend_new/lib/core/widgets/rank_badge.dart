import 'package:flutter/material.dart';

import '../models/rank.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../theme/tier_colors.dart';

/// Huy hiệu rank: icon + tên bậc + rating (không chỉ dựa vào màu).
/// [compact]: chỉ icon + tên bậc (dùng trong hàng danh sách hẹp).
class RankBadge extends StatelessWidget {
  final int rating;
  final Tier? tier;
  final bool compact;

  const RankBadge({
    super.key,
    required this.rating,
    this.tier,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = tier ?? Tier.fromRating(rating);
    final color = context.tierColor(t);
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: 'Rank ${t.label}, $rating điểm',
      child: ExcludeSemantics(
        child: compact
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t.icon, size: 16, color: color),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      t.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelMedium?.copyWith(
                          color: color, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              )
            : Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.icon, size: 20, color: color),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Flexible(
                      child: Text(
                        '${t.label} · $rating',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontFeatures: kTabularFigures,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
