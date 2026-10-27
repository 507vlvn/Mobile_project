import 'package:flutter/material.dart';

import '../core/network/models.dart';
import '../core/realtime/match_models.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/primary_button.dart';
import 'pvp_common.dart';

/// Chọn game để mời [friend] đấu giao hữu rồi gửi lời mời (chờ 30 giây).
/// Chọn game để mời [friend] đấu giao hữu rồi gửi lời mời (chờ 30 giây).
/// Khi bạn chấp nhận, màn trận tự mở (PvpNavigator).
Future<void> showInviteSheet(
  BuildContext context,
  UserSummary friend, {
  String initialGame = kGameCaro,
  int initialDifficulty = 2,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _InviteSheet(
      friend: friend,
      initialGame: initialGame,
      initialDifficulty: initialDifficulty,
    ),
  );
}

class _InviteSheet extends StatefulWidget {
  final UserSummary friend;
  final String initialGame;
  final int initialDifficulty;

  const _InviteSheet({
    required this.friend,
    this.initialGame = kGameCaro,
    this.initialDifficulty = 2,
  });

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  late String _game = widget.initialGame;
  late int _puzzleSize = widget.initialGame == kGamePuzzle ? widget.initialDifficulty : 1;
  late int _sudokuDiff = widget.initialGame == kGameSudoku ? widget.initialDifficulty : 2;
  bool _sending = false;

  int get _difficulty => switch (_game) {
        kGameCaro => kCaroOnlineDifficulty,
        kGamePuzzle => _puzzleSize,
        kGameSudoku => _sudokuDiff,
        _ => 1,
      };

  Future<void> _send() async {
    final s = maybeMatchSessionOf(context);
    if (s == null || _sending) return;
    setState(() => _sending = true);
    final ok = await s.invite(widget.friend, _game, _difficulty);
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
          Text(
            _game == kGameSudoku
                ? 'Sudoku Đồng Đội: 2 người cùng hợp tác giải 1 bảng số theo thời gian thực.'
                : 'Trận giao hữu, không tính rating. Lời mời hết hạn sau 30 giây.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: kGameCaro,
                icon: Icon(pvpGameIcon(kGameCaro)),
                label: const Text('Caro'),
              ),
              ButtonSegment(
                value: kGamePuzzle,
                icon: Icon(pvpGameIcon(kGamePuzzle)),
                label: const Text('Đua Xếp số'),
              ),
              ButtonSegment(
                value: kGameSudoku,
                icon: Icon(pvpGameIcon(kGameSudoku)),
                label: const Text('Sudoku'),
              ),
            ],
            selected: {_game},
            onSelectionChanged: (v) => setState(() => _game = v.first),
          ),
          if (_game == kGamePuzzle) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Kích thước bảng:', style: text.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final d in const [1, 2, 3]) ButtonSegment(value: d, label: Text(puzzleSizeLabel(d))),
              ],
              selected: {_puzzleSize},
              onSelectionChanged: (v) => setState(() => _puzzleSize = v.first),
            ),
          ] else if (_game == kGameSudoku) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Độ khó câu đố:', style: text.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            SudokuDifficultyChips(
              value: _sudokuDiff,
              onChanged: (d) => setState(() => _sudokuDiff = d),
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
