import 'dart:async';

import 'package:flutter/material.dart';

import '../core/realtime/match_models.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/user_avatar.dart';
import 'caro_online_screen.dart';
import 'match_session.dart';
import 'pvp_common.dart';
import 'race_puzzle_screen.dart';
import 'sudoku_coop_screen.dart';

/// Navigator / ScaffoldMessenger của app, để mở màn trận và hiện thông báo
/// từ bất kỳ đâu (gắn vào MaterialApp trong main.dart).
final appNavigatorKey = GlobalKey<NavigatorState>();
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

bool _matchRouteOpen = false;

/// Chỉ dùng trong test: quên trạng thái "đang mở màn trận" giữa các test.
@visibleForTesting
void debugResetMatchRoute() => _matchRouteOpen = false;

/// Mở màn trận hiện tại (Caro theo lượt, đua Xếp số, hoặc Sudoku đồng đội). Không mở trùng.
void openMatchScreen(MatchSession session) {
  final nav = appNavigatorKey.currentState;
  final m = session.match;
  if (nav == null || m == null || _matchRouteOpen) return;
  _matchRouteOpen = true;

  final Widget screen;
  if (m.isCoop || m.gameCode == kGameSudoku) {
    screen = SudokuCoopScreen(session: session);
  } else if (m.isTurn) {
    screen = CaroOnlineScreen(session: session);
  } else {
    screen = RacePuzzleScreen(session: session);
  }

  nav
      .push(MaterialPageRoute<void>(builder: (_) => screen))
      .whenComplete(() => _matchRouteOpen = false);
}

/// Bọc ngoài toàn app: trận bắt đầu thì mở màn trận, hiện thông báo của
/// [MatchSession], và hiện hộp lời mời đấu ở mọi màn hình.
class PvpNavigator extends StatefulWidget {
  final Widget child;
  const PvpNavigator({super.key, required this.child});

  @override
  State<PvpNavigator> createState() => _PvpNavigatorState();
}

class _PvpNavigatorState extends State<PvpNavigator> {
  MatchSession? _session;
  final List<StreamSubscription<Object?>> _subs = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = maybeMatchSessionOf(context);
    if (identical(s, _session)) return;
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _session = s;
    if (s == null) return;
    _subs.addAll([
      s.starts.listen((_) => WidgetsBinding.instance.addPostFrameCallback((_) => openMatchScreen(s))),
      s.notices.listen((msg) => appMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)))),
    ]);
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    if (s == null) return widget.child;
    return Stack(
      children: [
        widget.child,
        ListenableBuilder(
          listenable: s,
          builder: (context, _) {
            final invites = s.incomingInvites;
            if (invites.isEmpty || s.phase == PvpPhase.active) return const SizedBox.shrink();
            final inv = invites.last;
            return Positioned(
              left: AppSpacing.screen,
              right: AppSpacing.screen,
              top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
              child: InviteCard(
                key: ValueKey(inv.inviteId),
                invite: inv,
                onAnswer: (accept) => s.respondInvite(inv, accept),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Hộp lời mời đấu: người mời, game, đếm ngược, Chấp nhận / Từ chối.
class InviteCard extends StatefulWidget {
  final InviteReceivedEvent invite;
  final ValueChanged<bool> onAnswer;
  const InviteCard({super.key, required this.invite, required this.onAnswer});

  @override
  State<InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<InviteCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invite;
    final left = inv.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 99);
    if (left <= 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      elevation: 8,
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                UserAvatar(name: inv.from.displayName, size: 40),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${inv.from.displayName} mời bạn đấu', style: text.titleSmall),
                      Text('${pvpGameLabel(inv.gameCode, inv.difficulty)} · giao hữu · còn ${left}s',
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(pvpGameIcon(inv.gameCode), color: scheme.primary),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => widget.onAnswer(false),
                    child: const Text('Từ chối'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => widget.onAnswer(true),
                    child: const Text('Chấp nhận'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
