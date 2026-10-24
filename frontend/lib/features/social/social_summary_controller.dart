import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/models.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/realtime/active_chat.dart';

/// Số liệu cho huy hiệu "Bạn bè" = lời mời kết bạn + tin chưa đọc + lời thách đến.
///
/// Cập nhật tức thì từ sự kiện realtime (tin nhắn mới, lời mời kết bạn); REST
/// `/social/summary` chỉ gọi khi đăng nhập / quay lại ứng dụng / kết nối lại
/// (mỗi lần cách nhau ít nhất [minGap]). Màn Bạn bè cũng đẩy số chính xác vào
/// đây sau khi tự tải danh sách ([setUnreadMessages], [setChallengeCounts],
/// [setIncomingFriendRequests]).
class SocialSummaryController extends ChangeNotifier {
  SocialSummaryController({
    required ApiClient api,
    DateTime Function()? now,
    this.minGap = const Duration(seconds: 30),
    RealtimeService? realtime,
    int? Function()? myId,
  })  : _api = api,
        _now = now ?? DateTime.now,
        _myId = myId {
    if (realtime != null) {
      _subs.addAll([
        realtime.messages.listen(_onMessage),
        realtime.friendRequests.listen((_) => _bump(friendRequests: 1)),
        realtime.reconnected.listen((_) => unawaited(refresh(force: true))),
      ]);
    }
  }

  final int? Function()? _myId;
  final List<StreamSubscription<Object?>> _subs = [];

  void _onMessage(MessageReceivedEvent e) {
    final m = e.message;
    if (m.senderId == _myId?.call()) return;
    if (ActiveChat.partnerId == m.senderId) return; // đang xem chính cuộc này
    _bump(messages: 1);
  }

  void _bump({int messages = 0, int friendRequests = 0}) {
    _summary = _summary.copyWith(
      unreadMessages: _summary.unreadMessages + messages,
      incomingFriendRequests: _summary.incomingFriendRequests + friendRequests,
    );
    _notify();
  }

  void setIncomingFriendRequests(int n) {
    if (n == _summary.incomingFriendRequests) return;
    _summary = _summary.copyWith(incomingFriendRequests: n);
    _notify();
  }

  final ApiClient _api;
  final DateTime Function() _now;
  final Duration minGap;

  SocialSummary _summary = const SocialSummary();
  DateTime? _lastFetch;
  bool _busy = false;
  bool _disposed = false;

  SocialSummary get summary => _summary;
  int get badgeCount => _summary.badgeCount;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Trả về true nếu thực sự đã gọi API.
  Future<bool> refresh({bool force = false}) async {
    if (_busy) return false;
    final last = _lastFetch;
    if (!force && last != null && _now().difference(last) < minGap) {
      return false;
    }
    _busy = true;
    _lastFetch = _now();
    try {
      _summary = await _api.socialSummary();
      _notify();
    } on ApiException {
      // Giữ số cũ; lần sau (>= minGap) sẽ thử lại.
    }
    _busy = false;
    return true;
  }

  void setUnreadMessages(int n) {
    if (n == _summary.unreadMessages) return;
    _summary = _summary.copyWith(unreadMessages: n);
    _notify();
  }

  void setChallengeCounts({required int incoming, required int active}) {
    if (incoming == _summary.incomingChallenges &&
        active == _summary.activeChallenges) {
      return;
    }
    _summary =
        _summary.copyWith(incomingChallenges: incoming, activeChallenges: active);
    _notify();
  }

  void clear() {
    _summary = const SocialSummary();
    _lastFetch = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
