import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/models.dart';
import 'logic/chat_format.dart';
import 'logic/message_merge.dart';

/// Trạng thái của một cuộc trò chuyện 1-1.
///
/// Chưa có realtime: khi màn chat đang mở (và app ở tiền cảnh) thì cứ
/// [pollInterval] hỏi tin mới một lần (`afterId` = id cuối, rất nhẹ). Ra nền thì
/// dừng hỏi; quay lại thì bù ngay. Cuộn lên để tải tin cũ hơn.
class ChatController extends ChangeNotifier {
  ChatController({
    required ApiClient api,
    required this.myId,
    required this.partnerId,
    this.pageSize = 30,
    this.pollInterval = const Duration(seconds: 5),
  }) : _api = api;

  final ApiClient _api;
  final int myId;
  final int partnerId;
  final int pageSize;
  final Duration pollInterval;

  static const maxLength = 1000;

  List<ChatMessage> _messages = const [];
  List<PendingMessage> _pending = const [];
  bool _loading = true;
  bool _loadingOlder = false;
  bool _hasMore = false;
  String? _error;
  bool _sending = false;

  Timer? _poll;
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

  /// Tải trang mới nhất, đánh dấu đã đọc và bắt đầu hỏi tin mới định kỳ.
  Future<void> start() async {
    _foreground = true;
    await _loadInitial();
    _startPolling();
  }

  void _startPolling() {
    _poll?.cancel();
    if (_disposed || !_foreground) return;
    _poll = Timer.periodic(pollInterval, (_) => unawaited(catchUp()));
  }

  Future<void> _loadInitial() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final list = await _api.messagesWith(partnerId, limit: pageSize);
      if (_disposed) return;
      _messages = mergeMessages(_messages, list);
      _hasMore = list.length >= pageSize;
      _loading = false;
      _notify();
      _markReadIfNeeded(list);
    } on ApiException catch (e) {
      if (_disposed) return;
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

  /// Hỏi tin sau id cuối. Trả về true nếu có tin mới.
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
      if (fresh.isNotEmpty && !_disposed) {
        hadNew = true;
        _messages = mergeMessages(_messages, fresh);
        _notify();
        _markReadIfNeeded(fresh);
      }
    } on ApiException {
      // Lỗi tạm thời: lần hỏi sau sẽ bù tiếp.
    }
    _catchingUp = false;
    return hadNew;
  }

  /// Ứng dụng ra nền: dừng hỏi tin.
  void pause() {
    _foreground = false;
    _poll?.cancel();
    _poll = null;
  }

  /// Quay lại: bù tin ngay rồi hỏi tiếp định kỳ.
  void resume() {
    if (_foreground || _disposed) return;
    _foreground = true;
    unawaited(catchUp());
    _startPolling();
  }

  void _markReadIfNeeded(List<ChatMessage> incoming) {
    if (!_foreground) return;
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
    _poll?.cancel();
    super.dispose();
  }
}
