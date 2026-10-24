import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/network/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/player_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/rank_badge.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_widgets.dart';
import '../auth/login_screen.dart';
import '../history/game_meta.dart';
import '../history/history_screen.dart';
import 'game_stat_tile.dart';
import 'profile_controller.dart';

class ProfileScreen extends StatefulWidget {
  /// Cho test/ảnh chụp truyền sẵn controller.
  @visibleForTesting
  final ProfileController? controllerOverride;

  const ProfileScreen({super.key, this.controllerOverride});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileController? _pc;
  int? _pcUserId;
  bool _visibleOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthController>(context);
    final uid = auth.isAuthenticated ? auth.currentUser?.userId : null;
    final visible = TickerMode.valuesOf(context).enabled;
    if (uid != _pcUserId) {
      if (widget.controllerOverride == null) _pc?.dispose();
      _pc = null;
      _pcUserId = uid;
      _visibleOnce = false;
    }
    if (uid != null && _pc == null) {
      _pc = widget.controllerOverride ??
          ProfileController(api: context.read<ApiClient>(), myId: uid);
    }
    // Chỉ tải khi tab hiển thị lần đầu (IndexedStack tắt ticker của tab ẩn).
    if (_pc != null && visible && !_visibleOnce) {
      _visibleOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pc?.load();
      });
    }
  }

  @override
  void dispose() {
    if (widget.controllerOverride == null) _pc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final themeController = context.watch<ThemeController>();
    final auth = context.watch<AuthController>();
    final loggedIn = auth.isAuthenticated;

    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          if (loggedIn) _UserCard(auth: auth, pc: _pc) else const _GuestCard(),
          if (loggedIn && _pc != null) ...[
            const SizedBox(height: AppSpacing.xl),
            _StatsSection(pc: _pc!),
          ],
          if (loggedIn) ...[
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Column(
                children: [
                  ListTile(
                    minTileHeight: kMinTouchTarget + 8,
                    leading: const Icon(Icons.edit_rounded),
                    title: const Text('Sửa tên hiển thị'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _editName(context, auth),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  ListTile(
                    minTileHeight: kMinTouchTarget + 8,
                    leading: const Icon(Icons.history_rounded),
                    title: const Text('Lịch sử chơi'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const HistoryScreen())),
                  ),
                ],
              ),
            ),
          ],
          if (loggedIn && _pc != null) ...[
            const SizedBox(height: AppSpacing.xl),
            _MatchHistorySection(pc: _pc!),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text('Giao diện', style: text.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_rounded),
                label: Text('Hệ thống'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_rounded),
                label: Text('Sáng'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_rounded),
                label: Text('Tối'),
              ),
            ],
            selected: {themeController.mode},
            onSelectionChanged: (s) => themeController.setMode(s.first),
          ),
          if (loggedIn) ...[
            const SizedBox(height: AppSpacing.xxl),
            Divider(color: scheme.outlineVariant),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error),
                minimumSize: const Size.fromHeight(kMinTouchTarget),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Đăng xuất'),
              onPressed: () => _logout(context, auth),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context, AuthController auth) async {
    final ok = await confirmExit(
      context,
      title: 'Đăng xuất?',
      message:
          'Bạn vẫn chơi được với tư cách khách, nhưng điểm sẽ không được lưu lên bảng xếp hạng.',
      confirmLabel: 'Đăng xuất',
      cancelLabel: 'Ở lại',
    );
    if (ok) await auth.logout();
  }

  Future<void> _editName(BuildContext context, AuthController auth) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          _EditNameDialog(initial: auth.currentUser?.fullName ?? ''),
    );
    if (name == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await auth.updateProfile(name);
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Đã cập nhật tên hiển thị'
          : (auth.lastError ?? 'Không cập nhật được, thử lại sau')),
    ));
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.person_rounded,
                      size: 30, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Khách', style: text.titleMedium),
                      Text(
                        'Đăng nhập để lưu điểm và lên bảng xếp hạng',
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Đăng nhập / Đăng ký',
              icon: Icons.login_rounded,
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const LoginScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final AuthController auth;
  final ProfileController? pc;
  const _UserCard({required this.auth, required this.pc});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final user = auth.currentUser;
    final name = user?.displayName ?? 'Tài khoản';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlayerCard(
              name: name,
              username: user?.username,
              avatarSize: 56,
            ),
            if (user != null && user.email.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(user.email,
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            const SizedBox(height: AppSpacing.md),
            if (pc != null)
              ListenableBuilder(
                listenable: pc!,
                builder: (context, _) {
                  final best = pc!.best;
                  if (best == null) {
                    return Text(
                      pc!.loading
                          ? 'Đang tải rank…'
                          : 'Chưa có trận xếp hạng. Vào Đối kháng để lên rank!',
                      style: text.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    );
                  }
                  return Row(
                    children: [
                      RankBadge(rating: best.rating, tier: best.tier),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Cao nhất · ${GameMeta.of(best.gameCode).name}',
                          style: text.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  );
                },
              ),
            if (auth.isOffline) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(Icons.cloud_off_rounded,
                      size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Đang ngoại tuyến — thông tin có thể chưa mới nhất',
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final ProfileController pc;
  const _StatsSection({required this.pc});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: pc,
      builder: (context, _) {
        final tiles = [
          for (final g in GameMeta.all)
            GameStatTile(meta: g, stats: pc.statsFor(g.code)),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Thống kê', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            if (pc.error != null && pc.matches.isEmpty)
              ErrorState(message: pc.error!, onRetry: pc.load)
            else ...[
              IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Expanded(child: tiles[0]),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: tiles[1]),
                  ])),
              const SizedBox(height: AppSpacing.sm),
              IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Expanded(child: tiles[2]),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: tiles[3]),
                  ])),
            ],
          ],
        );
      },
    );
  }
}

class _MatchHistorySection extends StatelessWidget {
  final ProfileController pc;
  const _MatchHistorySection({required this.pc});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: pc,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Lịch sử trận', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            if (pc.loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (pc.matches.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  'Chưa có trận đối kháng nào. Các trận bạn đấu trực tiếp sẽ hiện ở đây.',
                  style:
                      text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              )
            else ...[
              for (final m in pc.matches) MatchHistoryTile(match: m),
              if (pc.hasMoreMatches)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(kMinTouchTarget),
                      foregroundColor: scheme.secondary,
                    ),
                    onPressed: pc.loadingMore ? null : pc.loadMore,
                    child: pc.loadingMore
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('Xem thêm'),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Một trận trong lịch sử: đối thủ, game, kết quả (icon + chữ), +/- rating (có dấu và màu).
class MatchHistoryTile extends StatelessWidget {
  final MatchHistoryItem match;
  const MatchHistoryTile({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final m = match;
    final game = GameMeta.of(m.gameCode);

    final (IconData icon, String label, Color tone) = switch (m.result) {
      MatchResult.win => (Icons.check_circle_rounded, 'Thắng', palette.success),
      MatchResult.lose => (Icons.cancel_rounded, 'Thua', scheme.error),
      MatchResult.draw => (
          Icons.remove_circle_rounded,
          'Hòa',
          scheme.onSurfaceVariant
        ),
    };
    // Pha màu về phía màu chữ để đạt tương phản đọc được trên nền surface.
    Color legible(Color c) => Color.lerp(c, scheme.onSurface, 0.35)!;

    final delta = m.ratingDelta;
    final deltaText = delta == null
        ? null
        : delta > 0
            ? '+$delta'
            : delta < 0
                ? '−${-delta}'
                : '0';
    final deltaTone = delta == null || delta == 0
        ? scheme.onSurfaceVariant
        : delta > 0
            ? palette.success
            : scheme.error;

    final when = m.endedAt == null ? '' : ' · ${relativeTimeVi(m.endedAt!)}';
    final sub = '${game.name} · ${m.ranked ? 'Xếp hạng' : 'Giao hữu'}$when';

    return Semantics(
      container: true,
      label:
          '$label trước ${m.opponentName}, $sub${deltaText == null ? '' : ', rating $deltaText'}',
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(game.icon, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('vs ${m.opponentName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: legible(tone)),
                      const SizedBox(width: 4),
                      Text(label,
                          style: text.labelLarge?.copyWith(
                              color: legible(tone),
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  if (deltaText != null)
                    Text(deltaText,
                        style: text.titleSmall?.copyWith(
                            color: legible(deltaTone),
                            fontWeight: FontWeight.w700,
                            fontFeatures: kTabularFigures)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  final String initial;
  const _EditNameDialog({required this.initial});

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sửa tên hiển thị'),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            labelText: 'Tên hiển thị',
            helperText: 'Tên này hiện trên bảng xếp hạng',
            focusedErrorBorder: focusedErrorBorderOf(context),
          ),
          validator: (v) {
            final s = (v ?? '').trim();
            if (s.isEmpty) return 'Vui lòng nhập tên hiển thị';
            if (s.length > 100) return 'Tên hiển thị tối đa 100 ký tự';
            return null;
          },
          onFieldSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _save, child: const Text('Lưu')),
      ],
    );
  }

  void _save() {
    if (_form.currentState?.validate() ?? false) {
      Navigator.pop(context, _controller.text.trim());
    }
  }
}
