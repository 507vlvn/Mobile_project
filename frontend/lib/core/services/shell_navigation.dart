import 'package:flutter/foundation.dart';

/// Các tab của khung chính (thứ tự khớp thanh điều hướng).
enum ShellTab { games, pvp, leaderboard, friends, profile }

/// Phân đoạn trong tab Bạn bè.
enum FriendsSegment { friends, requests, messages, challenges }

/// Cho phép lớp thông báo (nằm ngoài khung chính) yêu cầu chuyển tab.
/// `MainShell` lắng nghe và thực hiện.
class ShellNavigation extends ChangeNotifier {
  ShellTab? _tab;
  FriendsSegment? _segment;

  /// Yêu cầu đang chờ (null nếu không có). Gọi [consume] sau khi xử lý.
  ShellTab? get requestedTab => _tab;
  FriendsSegment? get requestedSegment => _segment;

  void show(ShellTab tab, {FriendsSegment? segment}) {
    _tab = tab;
    _segment = segment;
    notifyListeners();
  }

  void consume() {
    _tab = null;
    _segment = null;
  }
}
