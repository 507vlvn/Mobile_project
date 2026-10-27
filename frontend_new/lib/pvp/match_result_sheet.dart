import 'package:flutter/material.dart';

import '../core/realtime/match_models.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import 'match_session.dart';

/// Bảng kết quả trận (Thắng / Thua / Hòa, lý do, thay đổi rating) với nút
/// Tái đấu và Về sảnh. Trả về true nếu người chơi chọn "Về sảnh".
/// [rematchAfterResign] = false: trận kết thúc vì đầu hàng thì chỉ còn "Về sảnh".
Future<bool?> showMatchResultSheet(BuildContext context, MatchSession session, {bool rematchAfterResign = true}) {
  return showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    builder: (_) => ListenableBuilder(
      listenable: session,
      builder: (context, _) => _ResultBody(session: session, rematchAfterResign: rematchAfterResign),
    ),
  );
}

class _ResultBody extends StatelessWidget {
  final MatchSession session;
  final bool rematchAfterResign;
  const _ResultBody({required this.session, required this.rematchAfterResign});

  @override
  Widget build(BuildContext context) {
    final e = session.ended;
    final m = session.match;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    if (e == null || m == null) return const SizedBox(height: 120);

    final me = m.you;
    final won = e.winnerId == me;
    final draw = e.isDraw;
    final cancelled = e.reason == 'SERVER_RESTART';
    final (title, color, icon) = cancelled
        ? ('Trận bị hủy', scheme.onSurfaceVariant, Icons.cloud_off_rounded)
        : draw
            ? ('Hòa', scheme.onSurfaceVariant, Icons.handshake_rounded)
            : won
                ? ('Chiến thắng!', palette.success, Icons.emoji_events_rounded)
                : ('Thất bại', scheme.error, Icons.sentiment_dissatisfied_rounded);
    final change = e.ratingChanges[me];
    final score = e.scores[me];
    final canRematch = !cancelled && (rematchAfterResign || e.reason != 'RESIGN');

    // Cuộn được để không tràn khi màn hình thấp (điện thoại xoay ngang).
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 56, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(title, textAlign: TextAlign.center, style: text.headlineSmall?.copyWith(color: color)),
          const SizedBox(height: AppSpacing.xs),
          Text(matchEndReasonVi(e, me),
              textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          if (e.ranked && change != null && !cancelled) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Rating ${change.before} → ${change.after}  ', style: text.titleMedium),
                Text(
                  change.delta > 0 ? '+${change.delta}' : (change.delta < 0 ? '−${-change.delta}' : '±0'),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: change.delta > 0
                        ? palette.success
                        : (change.delta < 0 ? scheme.error : scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ] else if (!e.ranked && !cancelled) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Trận giao hữu — không tính rating',
                textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          if (score != null && score > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Điểm: $score', textAlign: TextAlign.center, style: text.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.xl),
          if (canRematch) ...[
            if (session.rematchRequestedByOpponent && !session.rematchSent)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text('Đối thủ muốn tái đấu!',
                    textAlign: TextAlign.center,
                    style: text.titleSmall?.copyWith(color: palette.success)),
              ),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(kMinTouchTarget)),
              onPressed: session.rematchSent ? null : session.rematch,
              icon: const Icon(Icons.replay_rounded),
              label: Text(session.rematchSent ? 'Đang chờ đối thủ…' : 'Tái đấu'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(kMinTouchTarget)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Về sảnh'),
          ),
        ],
      ),
    );
  }
}
