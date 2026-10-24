import 'package:flutter/material.dart';

import '../core/network/models.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/rank_badge.dart';
import '../core/models/game_meta.dart';

/// Ô thống kê một game: rank + rating, số trận, tỉ lệ thắng, kỷ lục (nếu có).
class GameStatTile extends StatelessWidget {
  final GameMeta meta;
  final GameStats stats;

  /// Điểm kỷ lục chơi đơn (hiện ở dòng cuối nếu khác null).
  final int? bestScore;

  const GameStatTile({
    super.key,
    required this.meta,
    required this.stats,
    this.bestScore,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final played = stats.games > 0;
    final pct = (stats.winRate * 100).round();
    final best = bestScore ?? stats.bestScore;
    return Semantics(
      container: true,
      label: [
        meta.name,
        if (played)
          'rank ${stats.tier.label}, ${stats.rating} điểm, ${stats.games} trận, thắng $pct phần trăm'
        else
          'chưa đấu trận xếp hạng nào',
        if (best != null) 'kỷ lục $best điểm',
      ].join(', '),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          constraints: const BoxConstraints(minHeight: 104),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(meta.icon, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(meta.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (played) ...[
                RankBadge(
                    rating: stats.rating, tier: stats.tier, compact: true),
                Text('${stats.rating} điểm',
                    style: text.titleSmall
                        ?.copyWith(fontFeatures: kTabularFigures)),
                Text('${stats.games} trận · thắng $pct%',
                    style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: kTabularFigures)),
              ] else
                Text('Chưa đấu xếp hạng',
                    style: text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              if (best != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Kỷ lục $best',
                      style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: kTabularFigures)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
