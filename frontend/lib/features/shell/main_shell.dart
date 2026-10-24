import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/services/shell_navigation.dart';
import '../auth/auth_controller.dart';
import '../hub/hub_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../profile/profile_screen.dart';
import '../pvp/pvp_lobby_screen.dart';
import '../social/social_screen.dart';
import '../social/social_summary_controller.dart';

/// Khung chính với thanh điều hướng dưới (5 mục, có icon + chữ):
/// Trò chơi · Đối kháng · Xếp hạng · Bạn bè · Hồ sơ.
/// Dùng IndexedStack để giữ nguyên trạng thái từng tab khi chuyển qua lại.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  static final _socialIndex = ShellTab.friends.index;
  final _socialKey = GlobalKey<SocialScreenState>();

  int _index = 0;
  bool _socialVisited = false; // tab Bạn bè chỉ dựng (và gọi API) khi được mở

  static final Listenable _none = ValueNotifier<int>(0);

  SocialSummaryController? _summary;
  AuthController? _auth;
  ShellNavigation? _nav;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_summary != null) return;
    // Không bắt buộc có provider (vd: ảnh chụp màn hình dựng khung riêng).
    try {
      final auth = context.read<AuthController>();
      RealtimeService? rt;
      try {
        rt = context.read<RealtimeService>();
      } catch (_) {}
      _summary = SocialSummaryController(
        api: context.read<ApiClient>(),
        realtime: rt,
        myId: () => auth.currentUser?.userId,
      );
      _auth = auth;
      try {
        _nav = context.read<ShellNavigation>()..addListener(_onNavRequest);
      } catch (_) {}
    } catch (_) {
      _summary = null;
      _auth = null;
      return;
    }
    _auth!.addListener(_onAuthChanged);
    _wasAuthenticated = _auth!.isAuthenticated;
    if (_wasAuthenticated) _summary!.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth?.removeListener(_onAuthChanged);
    _nav?.removeListener(_onNavRequest);
    _summary?.dispose();
    super.dispose();
  }

  bool _wasAuthenticated = false;

  /// Thông báo / màn khác yêu cầu mở một tab (vd. "Xem" lời mời kết bạn).
  void _onNavRequest() {
    final nav = _nav;
    final tab = nav?.requestedTab;
    if (nav == null || tab == null) return;
    final segment = nav.requestedSegment;
    nav.consume();
    _select(tab.index);
    if (segment != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _socialKey.show(segment));
    }
  }

  void _onAuthChanged() {
    final now = _auth?.isAuthenticated ?? false;
    if (now == _wasAuthenticated) return;
    _wasAuthenticated = now;
    if (now) {
      _summary?.refresh(force: true);
    } else {
      _summary?.clear();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quay lại ứng dụng: làm mới huy hiệu (tối thiểu 30 giây một lần).
    if (state == AppLifecycleState.resumed && (_auth?.isAuthenticated ?? false)) {
      _summary?.refresh();
    }
  }

  void _select(int i) {
    setState(() {
      _index = i;
      if (i == _socialIndex) _socialVisited = true;
    });
    if (i == _socialIndex && (_auth?.isAuthenticated ?? false)) {
      _summary?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HubScreen(),
      const PvpLobbyScreen(),
      const LeaderboardScreen(),
      _socialVisited
          ? SocialScreen(key: _socialKey, active: _index == _socialIndex)
          : const SizedBox.shrink(),
      const ProfileScreen(),
    ];
    final scaffold = ListenableBuilder(
      listenable: _summary ?? _none,
      builder: (context, _) {
        final n = (_auth?.isAuthenticated ?? false) ? (_summary?.badgeCount ?? 0) : 0;
        return Scaffold(
          body: IndexedStack(index: _index, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'Trò chơi',
              ),
              const NavigationDestination(
                icon: Icon(Icons.sports_mma_outlined),
                selectedIcon: Icon(Icons.sports_mma_rounded),
                label: 'Đối kháng',
              ),
              const NavigationDestination(
                icon: Icon(Icons.leaderboard_outlined),
                selectedIcon: Icon(Icons.leaderboard_rounded),
                label: 'Xếp hạng',
              ),
              NavigationDestination(
                icon: _FriendsIcon(count: n, icon: Icons.people_outline_rounded),
                selectedIcon: _FriendsIcon(count: n, icon: Icons.people_rounded),
                label: 'Bạn bè',
                tooltip: n > 0 ? 'Bạn bè, $n mục mới' : 'Bạn bè',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Hồ sơ',
              ),
            ],
          ),
        );
      },
    );
    final s = _summary;
    return s == null
        ? scaffold
        : ChangeNotifierProvider<SocialSummaryController>.value(
            value: s,
            child: scaffold,
          );
  }
}

class _FriendsIcon extends StatelessWidget {
  final int count;
  final IconData icon;
  const _FriendsIcon({required this.count, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: Icon(icon),
    );
  }
}
