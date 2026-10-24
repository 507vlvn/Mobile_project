import 'dart:async';

import 'package:signalr_netcore/errors.dart';
import 'package:signalr_netcore/signalr_client.dart';

/// Lỗi trả về từ hub (HubException) hoặc lỗi kết nối, với thông điệp đã làm sạch
/// để hiển thị trực tiếp cho người dùng.
class RealtimeException implements Exception {
  final String message;
  const RealtimeException(this.message);

  @override
  String toString() => message;
}

/// Lớp mỏng bọc `HubConnection` để service có thể kiểm thử bằng bản giả.
abstract interface class HubGateway {
  /// Bắt đầu kết nối; ném lỗi nếu thất bại. Có thể gọi lại sau khi [stop].
  Future<void> start();
  Future<void> stop();

  /// Gọi hub method và chờ server hoàn tất. Lỗi ném ra là [RealtimeException].
  Future<Object?> invoke(String method, List<Object> args);

  /// Đăng ký handler cho sự kiện server đẩy xuống (không phân biệt hoa thường).
  void on(String method, void Function(List<Object?>? args) handler);

  /// Gọi khi kết nối đóng (cả khi mình chủ động [stop]).
  void setOnClosed(void Function(Object? error)? callback);
}

typedef HubGatewayFactory = HubGateway Function(
    String url, Future<String> Function() accessToken);

/// Bản thật dùng `signalr_netcore`: transport tự chọn (WebSocket, lùi về
/// long-polling), KHÔNG dùng tự kết nối lại của thư viện — vòng lặp kết nối lại
/// với backoff nằm ở `SignalRRealtimeService` để kiểm thử được.
class SignalRHubGateway implements HubGateway {
  SignalRHubGateway(String url, Future<String> Function() accessToken)
      : _connection = HubConnectionBuilder()
            .withUrl(
              url,
              options: HttpConnectionOptions(
                accessTokenFactory: accessToken,
                // Máy chủ miễn phí khởi động chậm: cho thương lượng tối đa 15 giây.
                requestTimeout: 15000,
              ),
            )
            .build();

  final HubConnection _connection;

  static String clean(Object error) => hubErrorMessage(error);

  @override
  Future<void> start() async {
    try {
      await _connection.start();
    } catch (e) {
      throw RealtimeException(clean(e));
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _connection.stop();
    } catch (_) {}
  }

  @override
  Future<Object?> invoke(String method, List<Object> args) async {
    try {
      return await _connection.invoke(method, args: args);
    } catch (e) {
      throw RealtimeException(clean(e));
    }
  }

  @override
  void on(String method, void Function(List<Object?>? args) handler) =>
      _connection.on(method, handler);

  @override
  void setOnClosed(void Function(Object? error)? callback) {
    _connection.onclose(({Exception? error}) => callback?.call(error));
  }
}

const String kConnectionLostMessage = 'Mất kết nối máy chủ, đang thử lại…';

/// Đổi lỗi gọi hub thành thông điệp hiển thị được. SignalR trả lỗi dạng
/// "An unexpected error occurred invoking 'X' on the server. HubException: `thông điệp`":
/// lấy phần sau "HubException: " cuối cùng; lỗi mạng/timeout -> [kConnectionLostMessage];
/// còn lại giữ nguyên thông điệp.
String hubErrorMessage(Object error) {
  var s = error is GeneralError
      ? (error.message ?? error.toString())
      : error.toString();
  const marker = 'HubException: ';
  final i = s.lastIndexOf(marker);
  if (i >= 0) {
    final m = s.substring(i + marker.length).trim();
    if (m.isNotEmpty) return m;
  }
  final lower = s.toLowerCase();
  const netHints = [
    'socketexception',
    'timeoutexception',
    'timed out',
    'timeout',
    'connection',
    'websocket',
    'failed host lookup',
    'network',
    'handshake',
    'connection is not in',
  ];
  if (netHints.any(lower.contains)) return kConnectionLostMessage;
  s = s.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  return s.isEmpty ? kConnectionLostMessage : s;
}
