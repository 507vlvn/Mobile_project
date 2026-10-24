/// Cấu hình build-time — mã nguồn KHÔNG chứa bất kỳ địa chỉ API nào.
///
/// Địa chỉ API chỉ lấy từ file `.env` ở thư mục gốc (không commit, xem `.env.example`):
///   flutter run --dart-define-from-file=.env
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// false khi build không truyền `.env` → app không gọi mạng, báo lỗi cấu hình.
  static bool get isConfigured => apiBaseUrl.isNotEmpty;

  static const String notConfiguredMessage =
      'Chưa cấu hình địa chỉ máy chủ. Hãy chạy app với --dart-define-from-file=.env';
}
