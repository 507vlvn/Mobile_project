import 'package:flutter/material.dart';

import '../core/network/models.dart';
import '../core/realtime/match_models.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/primary_button.dart';
import 'pvp_common.dart';

/// Chọn game để mời [friend] đấu giao hữu rồi gửi lời mời (chờ 30 giây).
/// Khi bạn chấp nhận, màn trận tự mở (PvpNavigator).
Future<void> showInviteSheet(BuildContext context, UserSummary friend) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _InviteSheet(friend: friend),
  );
}

class _InviteSheet extends StatefulWidget {
  final UserSummary friend;
  const _InviteSheet({required this.friend});

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  String _game = kGameCaro;
  int _size = 1;
  bool _sending = false;

  Future<void> _send() async {
    final s = maybeMatchSessionOf(context);
    if (s == null || _sending) return;
    setState(() => _sending = true);
    final ok = await s.invite(widget.friend, _game, _game == kGameCaro ? kCaroOnlineDifficulty : _size);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        content: Text('Đã mời ${widget.friend.displayName} — đang chờ trả lời (30 giây)'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Mời ${widget.friend.displayName} đấu', style: text.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('Trận giao hữu, không tính rating. Lời mời hết hạn sau 30 giây.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: kGameCaro, icon: Icon(pvpGameIcon(kGameCaro)), label: const Text('Caro')),
              ButtonSegment(
                  value: kGamePuzzle, icon: Icon(pvpGameIcon(kGamePuzzle)), label: const Text('Đua Xếp số')),
            ],
            selected: {_game},
            onSelectionChanged: (v) => setState(() => _game = v.first),
          ),
          if (_game == kGamePuzzle) ...[
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final d in const [1, 2, 3]) ButtonSegment(value: d, label: Text(puzzleSizeLabel(d))),
              ],
              selected: {_size},
              onSelectionChanged: (v) => setState(() => _size = v.first),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Gửi lời mời',
            icon: Icons.send_rounded,
            loading: _sending,
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}
