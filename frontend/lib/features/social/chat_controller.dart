import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/models.dart';
import '../../core/realtime/active_chat.dart';
import '../../core/realtime/realtime_service.dart';
import 'logic/chat_format.dart';
import 'logic/message_merge.dart';

/// Trạng thái của một cuộc trò chuyện 1-1.
///
/// Tin mới đến qua realtime ([RealtimeService.messages]); REST chỉ dùng để
/// tải trang đầu khi mở, bù tin còn thiếu (`afterId`) khi vừa kết nối lại hoặc
/// quay lại ứng dụng, và tải tin cũ khi cuộn lên. KHÔNG có vòng hỏi theo giờ.
class ChatController extends ChangeNotifier {
  ChatController({
    required ApiClient api,
    required this.myId,
    required this.partnerId,
    RealtimeService? realtime,
    this.pageSize = 30,
  })  : _api = api,
        _realtime = realtime;

  final ApiClient _api;
  final RealtimeService? _realtime;
  final int myId;
  final int partnerId;
  final int pageSize;

  static const maxLength = 1000;

  List<ChatMessage> _messages = const [];
  List<PendingMessage> _pending = const [];
  bool _loading = true;
  bool _loadingOlder = false;
  bool _hasMore = false;
  String? _error;
  bool _sending = false;

  StreamSubscription<MessageReceivedEvent>? _msgSub;
  StreamSubscription<void>? _reconnectSub;
  bool _foreground = false;
  bool _catchingUp = false;
  bool _disposed = false;
  int _nextLocalId = 1;

  List<ChatMessage> get messages => _messages;
  List<PendingMessage> get pending => _pending;
  bool get loading => _loading;
  bool get loadingOlder => _loadingOlder;
  bool get hasMore => _hasMore;
  String? get error => _error;
  bool get sending => _sending;

  int? get _lastServerId => _messages.isEmpty ? null : _messages.last.messageId;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Tải trang mới nhất, đánh dấu đã đọc và bắt đầu nghe tin realtime.
  Future<void> start() async {
    _foreground = true;
    ActiveChat.partnerId = partnerId;
    _listen();
    await _loadInitial();
  }

  void _listen() {
    final rt = _realtime;
    if (rt == null || _msgSub != null) return;
    _msgSub = rt.messages.listen(_onRealtimeMessage);
    // Kết nối lại: có thể đã lỡ tin trong lúc mất mạng -> bù một lần.
    _reconnectSub = rt.reconnected.listen((_) => unawaited(catchUp()));
  }

  void _onRealtimeMessage(MessageReceivedEvent e) {
    final m = e.message;
    final fromPartner = m.senderId == partnerId && m.receiverId == myId;
    final fromMeElsewhere = m.senderId == myId && m.receiverId == partnerId;
    if (!fromPartner && !fromMeElsewhere) return;
    _messages = mergeMessages(_messages, [m]);
    _notify();
    if (fromPartner && !m.isRead && _foreground) _markReadIfNeeded([m]);
  }

  Future<void> _loadInitial() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final list = await _api.messagesWith(partnerId, limit: pageSize);
      _messages = mergeMessages(_messages, list);
      _hasMore = list.length >= pageSize;
      _loading = false;
      _notify();
      _markReadIfNeeded(list);
    } on ApiException catch (e) {
      _error = e.message;
      _loading = false;
      _notify();
    }
  }

  Future<void> retryInitial() => _loadInitial();

  /// Tải trang tin cũ hơn (khi cuộn lên đầu).
  Future<void> loadOlder() async {
    if (_loadingOlder || !_hasMore || _messages.isEmpty) return;
    _loadingOlder = true;
    _notify();
    try {
      final list = await _api.messagesWith(
        partnerId,
        beforeId: _messages.first.messageId,
        limit: pageSize,
      );
      _messages = mergeMessages(_messages, list);
      _hasMore = list.length >= pageSize;
    } on ApiException {
      // Giữ nguyên danh sách; người dùng cuộn lên để thử lại.
    }
    _loadingOlder = false;
    _notify();
  }

  // ---- bù tin ----

  /// Một lần hỏi tin sau id cuối (khi kết nối lại / quay lại ứng dụng).
  /// Trả về true nếu có tin mới.
  Future<bool> catchUp() async {
    if (_catchingUp || _disposed || _loading || _error != null) return false;
    _catchingUp = true;
    var hadNew = false;
    try {
      final list = await _api.messagesWith(
        partnerId,
        afterId: _lastServerId,
        limit: pageSize,
      );
      final known = _messages.map((m) => m.messageId).toSet();
      final fresh = list.where((m) => !known.contains(m.messageId)).toList();
      if (fresh.isNotEmpty) {
        hadNew = true;
        _messages = mergeMessages(_messages, fresh);
        _notify();
        _markReadIfNeeded(fresh);
      }
    } on ApiException {
      // Lỗi tạm thời: lần kết nối lại sau sẽ bù tiếp.
    }
    _catchingUp = false;
    return hadNew;
  }

  /// Ứng dụng ra nền / màn chat bị che.
  void pause() {
    _foreground = false;
  }

  /// Quay lại: bù tin một lần.
  void resume() {
    if (_foreground || _disposed) return;
    _foreground = true;
    unawaited(catchUp());
  }

  void _markReadIfNeeded(List<ChatMessage> incoming) {
    final needs = incoming.any((m) => m.senderId == partnerId && !m.isRead);
    if (needs) unawaited(_markRead());
  }

  Future<void> _markRead() async {
    try {
      await _api.markRead(partnerId);
    } on ApiException {
      // Sẽ đánh dấu lại ở lần mở sau.
    }
  }

  // ---- gửi tin ----

  /// Thêm tin vào danh sách chờ rồi gửi. Trả về false nếu nội dung không hợp lệ.
  Future<bool> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || text.length > maxLength) return false;
    final p = PendingMessage(
      localId: _nextLocalId++,
      text: text,
      time: DateTime.now(),
    );
    _pending = [..._pending, p];
    _notify();
    await _deliver(p.localId);
    return true;
  }

  Future<void> retry(int localId) async {
    final i = _pending.indexWhere((p) => p.localId == localId);
    if (i < 0 || !_pending[i].failed) return;
    _setPending(localId, (p) => p.copyWith(failed: false));
    await _deliver(localId);
  }

  void discard(int localId) {
    _pending = _pending.where((p) => p.localId != localId).toList();
    _notify();
  }

  Future<void> _deliver(int localId) async {
    final i = _pending.indexWhere((p) => p.localId == localId);
    if (i < 0) return;
    final text = _pending[i].text;
    _sending = true;
    _notify();
    try {
      final m = await _api.sendMessage(partnerId, text);
      _pending = _pending.where((p) => p.localId != localId).toList();
      _messages = mergeMessages(_messages, [m]);
    } on ApiException catch (e) {
      _setPending(localId, (p) => p.copyWith(failed: true, error: e.message));
    } catch (_) {
      _setPending(localId, (p) => p.copyWith(failed: true));
    }
    _sending = false;
    _notify();
  }

  void _setPending(int localId, PendingMessage Function(PendingMessage) f) {
    _pending = [for (final p in _pending) p.localId == localId ? f(p) : p];
  }

  @override
  void dispose() {
    _disposed = true;
    _foreground = false;
    if (ActiveChat.partnerId == partnerId) ActiveChat.partnerId = null;
    _msgSub?.cancel();
    _reconnectSub?.cancel();
    super.dispose();
  }
}
