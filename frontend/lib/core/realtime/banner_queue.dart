import 'package:flutter/foundation.dart';

import 'realtime_models.dart';

/// Loại thông báo nổi.
sealed class AppBanner {
  const AppBanner();

  /// Khóa dùng để chống trùng.
  String get key;

  /// Hết hạn tự đóng sau (null = chỉ đóng theo logic riêng, vd. đồng hồ lời mời).
  Duration? get autoDismiss;
}

class InviteBanner extends AppBanner {
  final InviteReceivedEvent invite;
  const InviteBanner(this.invite);

  @override
  String get key => 'invite:${invite.inviteId}';
  @override
  Duration? get autoDismiss => null;
}

class FriendRequestBanner extends AppBanner {
  final FriendRequestEvent request;
  const FriendRequestBanner(this.request);

  @override
  String get key => 'friend:${request.from.userId}';
  @override
  Duration? get autoDismiss => const Duration(seconds: 7);
}

class MessageBanner extends AppBanner {
  final MessageReceivedEvent message;
  const MessageBanner(this.message);

  @override
  String get key => 'msg:${message.message.senderId}';
  @override
  Duration? get autoDismiss => const Duration(seconds: 5);
}

/// Hàng đợi thông báo: tối đa MỘT cái hiển thị, các cái còn lại xếp hàng.
/// - Trùng khóa thì bỏ (tin mới của cùng một người thay thế tin đang chờ).
/// - Lời mời đấu được ưu tiên lên trước các thông báo khác trong hàng chờ.
/// - Lời mời đã hết hạn trong lúc chờ sẽ bị bỏ qua khi tới lượt.
class BannerQueue extends ChangeNotifier {
  BannerQueue({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final List<AppBanner> _waiting = [];
  AppBanner? _current;

  AppBanner? get current => _current;
  List<AppBanner> get waiting => List.unmodifiable(_waiting);

  void add(AppBanner banner) {
    final cur = _current;
    if (cur != null && cur.key == banner.key) {
      // Tin mới của cùng người đang hiển thị: thay nội dung tại chỗ.
      if (banner is MessageBanner) {
        _current = banner;
        notifyListeners();
      }
      return;
    }
    final i = _waiting.indexWhere((b) => b.key == banner.key);
    if (i >= 0) {
      _waiting[i] = banner;
      return;
    }
    if (cur == null) {
      _current = banner;
      notifyListeners();
      return;
    }
    if (banner is InviteBanner) {
      final firstNonInvite = _waiting.indexWhere((b) => b is! InviteBanner);
      _waiting.insert(firstNonInvite < 0 ? _waiting.length : firstNonInvite, banner);
    } else {
      _waiting.add(banner);
    }
  }

  /// Đóng thông báo hiện tại và chuyển sang cái kế tiếp còn hiệu lực.
  void dismissCurrent() {
    _current = null;
    while (_waiting.isNotEmpty) {
      final next = _waiting.removeAt(0);
      if (next is InviteBanner && next.invite.remainingSec(_now()) <= 0) {
        continue;
      }
      _current = next;
      break;
    }
    notifyListeners();
  }

  /// Đóng thông báo có khóa [key] (nếu đang hiển thị hoặc đang chờ).
  void dismissKey(String key) {
    _waiting.removeWhere((b) => b.key == key);
    if (_current?.key == key) dismissCurrent();
  }
}
