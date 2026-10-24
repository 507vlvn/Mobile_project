import 'package:flutter/material.dart';

import '../models/challenge_context.dart';

typedef ChallengeScreenBuilder = Widget Function(ChallengeContext context);

/// Đăng ký màn chơi cho từng game để mở một thách đấu mà không để màn Bạn bè
/// phụ thuộc trực tiếp vào code từng game.
abstract final class ChallengeLauncher {
  static final Map<String, ChallengeScreenBuilder> _builders = {};

  static void register(String gameCode, ChallengeScreenBuilder builder) {
    _builders[gameCode.toUpperCase()] = builder;
  }

  static bool isSupported(String gameCode) =>
      _builders.containsKey(gameCode.toUpperCase());

  /// Dùng trong test để dọn đăng ký.
  static void clear() => _builders.clear();

  /// Mở màn chơi của game; không có thì báo bằng SnackBar. Trả về true nếu đã mở.
  /// Future hoàn thành khi người dùng quay lại từ màn chơi.
  static Future<bool> open(BuildContext context, ChallengeContext challenge) async {
    final builder = _builders[challenge.gameCode.toUpperCase()];
    if (builder == null) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Game này chưa hỗ trợ thách đấu')),
        );
      return false;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => builder(challenge)),
    );
    return true;
  }
}
