import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/difficulty.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/models.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/difficulty_selector.dart';
import '../../core/widgets/primary_button.dart';
import '../auth/user_avatar.dart';
import '../history/game_meta.dart';

/// Kết quả đóng bottom sheet người chơi.
enum PlayerSheetResult { challengeSent, openChat }

Future<PlayerSheetResult?> showPlayerSheet(
  BuildContext context,
  UserSummary player,
) {
  return showModalBottomSheet<PlayerSheetResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => PlayerSheet(player: player),
  );
}

/// Thông tin người chơi + hành động: Thách đấu (chọn game và độ khó) / Nhắn tin.
class PlayerSheet extends StatefulWidget {
  final UserSummary player;
  final bool startInPicker;
  const PlayerSheet({super.key, required this.player, this.startInPicker = false});

  @override
  State<PlayerSheet> createState() => _PlayerSheetState();
}

class _PlayerSheetState extends State<PlayerSheet> {
  late bool _picking = widget.startInPicker;
  String _game = GameMeta.all.first.code;
  Difficulty _difficulty = Difficulty.medium;
  bool _sending = false;
  String? _error;

  String get _name {
    final p = widget.player;
    return (p.fullName != null && p.fullName!.trim().isNotEmpty)
        ? p.fullName!.trim()
        : p.username;
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<ApiClient>().createChallenge(
            opponentId: widget.player.userId,
            gameCode: _game,
            difficulty: _difficulty.value,
          );
      if (!mounted) return;
      Navigator.pop(context, PlayerSheetResult.challengeSent);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.xl + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UserAvatar(name: _name, size: 56),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleLarge),
                    Text('@${widget.player.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (!_picking) ..._actions(context) else ..._picker(context),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context) => [
        PrimaryButton(
          label: 'Thách đấu',
          icon: Icons.sports_esports_rounded,
          onPressed: () => setState(() => _picking = true),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(kMinTouchTarget),
            foregroundColor: Theme.of(context).colorScheme.secondary,
          ),
          onPressed: () => Navigator.pop(context, PlayerSheetResult.openChat),
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          label: const Text('Nhắn tin'),
        ),
      ];

  List<Widget> _picker(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return [
      Text('Chọn game', style: text.titleSmall),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final g in GameMeta.all)
            ChoiceChip(
              avatar: Icon(_game == g.code ? Icons.check_rounded : g.icon, size: 18),
              label: Text(g.name),
              selected: _game == g.code,
              showCheckmark: false,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onSelected: _sending ? null : (_) => setState(() => _game = g.code),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      Text('Độ khó', style: text.titleSmall),
      const SizedBox(height: AppSpacing.sm),
      DifficultySelector(
        value: _difficulty,
        onChanged: (d) {
          if (!_sending) setState(() => _difficulty = d);
        },
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Hai bạn cùng giải một đề. Người có điểm cao hơn sẽ thắng.',
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      if (_error != null) ...[
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_rounded, size: 18, color: scheme.error),
            const SizedBox(width: 6),
            Expanded(
              child: Text(_error!,
                  style: text.bodyMedium?.copyWith(color: scheme.error)),
            ),
          ],
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      PrimaryButton(
        label: 'Gửi lời thách',
        icon: Icons.send_rounded,
        loading: _sending,
        onPressed: _send,
      ),
      const SizedBox(height: AppSpacing.xs),
      TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(kMinTouchTarget),
          foregroundColor: scheme.secondary,
        ),
        onPressed: _sending ? null : () => setState(() => _picking = false),
        child: const Text('Quay lại'),
      ),
    ];
  }
}
