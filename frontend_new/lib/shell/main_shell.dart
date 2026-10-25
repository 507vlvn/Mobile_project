import 'package:flutter/material.dart';

import '../friends/friends_screen.dart';
import '../hub/hub_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../profile/profile_screen.dart';
import '../pvp/pvp_lobby_screen.dart';

/// Khung chính với thanh điều hướng dưới (5 mục, có icon + chữ):
/// Trò chơi · Đối kháng · Xếp hạng · Bạn bè · Hồ sơ.
/// Dùng IndexedStack để giữ nguyên trạng thái từng tab khi chuyển qua lại.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _leaderboardIndex = 2;
  static const _friendsIndex = 3;

  int _index = 0;
  // Tab Xếp hạng / Bạn bè chỉ dựng (và gọi API) khi được mở lần đầu.
  bool _leaderboardVisited = false;
  bool _friendsVisited = false;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HubScreen(),
      const PvpLobbyScreen(),
      _leaderboardVisited ? const LeaderboardScreen() : const SizedBox.shrink(),
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
          if (i == _leaderboardIndex) _leaderboardVisited = true;
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
