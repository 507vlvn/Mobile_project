import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/game_meta.dart' show relativeTimeVi;
import '../core/models/presence.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/models.dart';
import '../core/realtime/realtime_service.dart';

/// Trạng thái màn Bạn bè: danh sách bạn (có online), lời mời đến/đi.
///
/// Trạng thái online cập nhật tức thì từ [RealtimeService.presence]; REST chỉ
/// gọi khi mở màn / kéo làm mới / sau hành động / khi có lời mời mới hoặc vừa
/// kết nối lại. Các request gọi TUẦN TỰ (bạn bè rồi lời mời).
class FriendsController extends ChangeNotifier {
  FriendsController({
    required ApiClient api,
    RealtimeService? realtime,
    DateTime Function()? now,
  })  : _api = api,
        _now = now ?? DateTime.now {
    if (realtime != null) {
      _subs.addAll([
        realtime.presence.listen(_onPresence),
        realtime.friendRequests.listen((_) => unawaited(_refreshQuiet())),
        realtime.friendAccepted.listen((_) => unawaited(_refreshQuiet())),
        realtime.reconnected.listen((_) => unawaited(_refreshQuiet())),
      ]);
    }
  }

  final ApiClient _api;
  final DateTime Function() _now;
  final List<StreamSubscription<Object?>> _subs = [];

  List<FriendInfo> _friends = const [];
  FriendRequests _requests = const FriendRequests();
  bool _loading = true;
  String? _error;
  bool _disposed = false;
  bool _busy = false;
  String? _actionError;

  List<FriendInfo> get friends => _friends;
  List<FriendRequestItem> get incoming => _requests.incoming;
  List<FriendRequestItem> get outgoing => _requests.outgoing;
  bool get loading => _loading;
  String? get error => _error;

  /// Lỗi của hành động gần nhất (chấp nhận/hủy...).
  String? get actionError => _actionError;

  int get onlineCount => _friends.where((f) => f.presence.isOnline).length;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Quan hệ của mình với [userId] dựa trên dữ liệu đã tải.
  Relationship relationOf(int userId) {
    if (_friends.any((f) => f.userId == userId)) return Relationship.friends;
    if (_requests.outgoing.any((r) => r.user.userId == userId)) {
      return Relationship.pendingOut;
    }
    if (_requests.incoming.any((r) => r.user.userId == userId)) {
      return Relationship.pendingIn;
    }
    return Relationship.none;
  }

  FriendRequestItem? incomingFrom(int userId) {
    for (final r in _requests.incoming) {
      if (r.user.userId == userId) return r;
    }
    return null;
  }

  FriendRequestItem? outgoingTo(int userId) {
    for (final r in _requests.outgoing) {
      if (r.user.userId == userId) return r;
    }
    return null;
  }

  // ---------------------------------------------------------- tải

  Future<void> load() async {
    if (_friends.isEmpty && _requests.incoming.isEmpty) {
      _loading = true;
    }
    _error = null;
    _notify();
    try {
      final f = await _api.friends();
      final r = await _api.friendRequests();
      if (_disposed) return;
      _friends = sortFriends(f);
      _requests = r;
      _loading = false;
    } on ApiException catch (e) {
      if (_disposed) return;
      _error = e.message;
      _loading = false;
    }
    _notify();
  }

  Future<void> _refreshQuiet() async {
    try {
      final f = await _api.friends();
      final r = await _api.friendRequests();
      if (_disposed) return;
      _friends = sortFriends(f);
      _requests = r;
      _notify();
    } on ApiException {
      // Giữ dữ liệu cũ.
    }
  }

  void _onPresence(PresenceEvent e) {
    final i = _friends.indexWhere((f) => f.userId == e.userId);
    if (i < 0) return;
    final old = _friends[i];
    if (old.presence == e.status) return;
    final updated = old.withPresence(
      e.status,
      lastSeenAt: e.status == PresenceStatus.offline ? _now() : null,
    );
    _friends = sortFriends([
      for (var j = 0; j < _friends.length; j++) j == i ? updated : _friends[j],
    ]);
    _notify();
  }

  // ---------------------------------------------------------- hành động

  Future<bool> _run(Future<void> Function() action) async {
    if (_busy) return false;
    _busy = true;
    _actionError = null;
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      _actionError = e.message;
      _notify();
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<bool> accept(FriendRequestItem r) => _run(() async {
        await _api.acceptFriendRequest(r.requestId);
        await _refreshQuiet();
      });

  Future<bool> decline(FriendRequestItem r) => _run(() async {
        await _api.declineFriendRequest(r.requestId);
        _requests = FriendRequests(
          incoming: [
            for (final x in _requests.incoming)
              if (x.requestId != r.requestId) x
          ],
          outgoing: _requests.outgoing,
        );
        _notify();
      });

  /// Hủy lời mời đã gửi.
  Future<bool> cancelOutgoing(FriendRequestItem r) => _run(() async {
        await _api.removeFriend(r.user.userId);
        _requests = FriendRequests(
          incoming: _requests.incoming,
          outgoing: [
            for (final x in _requests.outgoing)
              if (x.requestId != r.requestId) x
          ],
        );
        _notify();
      });

  Future<bool> unfriend(FriendInfo f) => _run(() async {
        await _api.removeFriend(f.userId);
        _friends = [
          for (final x in _friends)
            if (x.userId != f.userId) x
        ];
        _notify();
      });

  Future<bool> sendRequest(UserSummary u) => _run(() async {
        await _api.sendFriendRequest(u.userId);
        await _refreshQuiet();
      });

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

/// Văn bản trạng thái của một người bạn: "Đang online" / "Đang trong trận" /
/// "Ngoại tuyến · 5 phút trước" / "Ngoại tuyến".
String presenceText(FriendInfo f, {DateTime? now}) {
  switch (f.presence) {
    case PresenceStatus.online:
      return 'Đang online';
    case PresenceStatus.inMatch:
      return 'Đang trong trận';
    case PresenceStatus.offline:
      final t = f.lastSeenAt;
      if (t == null) return 'Ngoại tuyến';
      return 'Ngoại tuyến · ${relativeTimeVi(t, now: now)}';
  }
}
