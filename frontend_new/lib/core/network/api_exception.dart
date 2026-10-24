/// Lỗi gọi API với thông điệp tiếng Việt sẵn để hiển thị.
class ApiException implements Exception {
  final int? statusCode;
  final String message;

  /// Không kết nối được máy chủ (mất mạng, sai địa chỉ...).
  final bool isNetwork;

  /// Quá thời gian chờ.
  final bool isTimeout;

  const ApiException(
    this.message, {
    this.statusCode,
    this.isNetwork = false,
    this.isTimeout = false,
  });

  static const networkMessage =
      'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.';
  static const timeoutMessage =
      'Máy chủ phản hồi quá lâu. Vui lòng thử lại sau ít phút.';

  bool get isUnauthorized => statusCode == 401;

  /// Dựng từ phản hồi lỗi HTTP (ProblemDetails). Ưu tiên thông báo đầu tiên
  /// trong `errors` (lỗi kiểm tra dữ liệu), sau đó tới `title`.
  factory ApiException.fromProblem(int? status, Object? data) {
    String? msg;
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map) {
        for (final v in errors.values) {
          if (v is List && v.isNotEmpty && v.first is String) {
            msg = v.first as String;
            break;
          }
          if (v is String && v.isNotEmpty) {
            msg = v;
            break;
          }
        }
      }
      final title = data['title'];
      if (msg == null && title is String && title.trim().isNotEmpty) {
        msg = title.trim();
      }
    }
    msg ??= switch (status) {
      401 => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      429 => 'Bạn thao tác quá nhanh, vui lòng thử lại sau ít phút.',
      final s? when s >= 500 => 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.',
      _ => 'Yêu cầu không thành công. Vui lòng thử lại.',
    };
    return ApiException(msg, statusCode: status);
  }

  @override
  String toString() => 'ApiException($statusCode, $message)';
}
