import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../friends/friends_screen.dart';
import '../hub/hub_screen.dart';
import '../profile/profile_screen.dart';

/// Khung chính với thanh điều hướng dưới (5 mục, có icon + chữ):
/// Trò chơi · Đối kháng · Xếp hạng · Bạn bè · Hồ sơ.
/// Dùng IndexedStack để giữ nguyên trạng thái từng tab khi chuyển qua lại.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _friendsIndex = 3;

  int _index = 0;
  bool _friendsVisited = false; // tab Bạn bè chỉ dựng (và gọi API) khi được mở

  @override
  Widget build(BuildContext context) {
    // Các tab chưa có chức năng tạm hiện màn chờ.
    final pages = <Widget>[
      const HubScreen(),
      const _ComingSoon(title: 'Đối kháng', icon: Icons.sports_mma_rounded),
      const _ComingSoon(title: 'Xếp hạng', icon: Icons.leaderboard_rounded),
      _friendsVisited
          ? FriendsScreen(active: _index == _friendsIndex)
          : const SizedBox.shrink(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          if (i == _friendsIndex) _friendsVisited = true;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Trò chơi',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_mma_outlined),
            selectedIcon: Icon(Icons.sports_mma_rounded),
            label: 'Đối kháng',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard_rounded),
            label: 'Xếp hạng',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Bạn bè',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  final String title;
  final IconData icon;
  const _ComingSoon({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Đang được phát triển',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
