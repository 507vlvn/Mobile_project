import 'package:flutter/widgets.dart';

import '../realtime/realtime_models.dart';

/// Hàm mở màn hình trận đấu cho [match] (do phần Đối kháng đăng ký).
typedef MatchOpener = void Function(NavigatorState navigator, MatchInfo match);

/// Nơi đăng ký cách mở màn trận đấu — tránh để lớp core phụ thuộc vào màn
/// hình của từng game (giống [ChallengeLauncher]).
///
/// Lớp thông báo trong app gọi [open] khi một trận GIAO HỮU bắt đầu sau khi
/// chấp nhận / được chấp nhận lời mời. Trận XẾP HẠNG do sảnh Đối kháng tự mở.
abstract final class MatchLauncher {
  static MatchOpener? _opener;
  static final Set<String> _opened = {};

  static void register(MatchOpener opener) => _opener = opener;

  static bool get isRegistered => _opener != null;

  /// Quên trận đã mở (dùng trong test).
  static void reset() {
    _opener = null;
    _opened.clear();
  }

  /// Đánh dấu trận đã được mở để không mở hai lần. Trả về false nếu đã mở rồi.
  static bool markOpened(String matchId) => _opened.add(matchId);

  static bool wasOpened(String matchId) => _opened.contains(matchId);

  /// Mở màn trận đấu. Trả về false nếu chưa có ai đăng ký (người gọi nên hiện
  /// thông báo "Đang mở trận…").
  static bool open(NavigatorState navigator, MatchInfo match) {
    final opener = _opener;
    if (opener == null) return false;
    if (!markOpened(match.matchId)) return true;
    opener(navigator, match);
    return true;
  }
}
