import 'package:shared_preferences/shared_preferences.dart';

/// Lưu JWT trong bộ nhớ của app. Không bao giờ ném lỗi.
class TokenStorage {
  static const _key = 'auth_token';
  String? _cached;
  bool _loaded = false;

  Future<String?> read() async {
    if (_loaded) return _cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cached = prefs.getString(_key);
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, token);
    } catch (_) {}
  }

  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
