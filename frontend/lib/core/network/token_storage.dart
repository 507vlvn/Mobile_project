import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lưu JWT trong kho an toàn của hệ điều hành. Không bao giờ ném lỗi.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth_token';
  final FlutterSecureStorage _storage;
  String? _cached;
  bool _loaded = false;

  Future<String?> read() async {
    if (_loaded) return _cached;
    try {
      _cached = await _storage.read(key: _key);
    } catch (_) {
      _cached = null;
    }
    _loaded = true;
    return _cached;
  }

  Future<void> write(String token) async {
    _cached = token;
    _loaded = true;
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {}
  }

  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
