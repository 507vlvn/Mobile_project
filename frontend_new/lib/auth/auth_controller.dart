import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/models.dart';
import '../core/network/token_storage.dart';

enum AuthStatus { unknown, guest, authenticated }

/// Trạng thái đăng nhập của ứng dụng.
class AuthController extends ChangeNotifier {
  AuthController({required ApiClient api, required TokenStorage tokens})
      : _api = api,
        _tokens = tokens;

  static const _userKey = 'cached_user';

  final ApiClient _api;
  final TokenStorage _tokens;

  /// Gọi sau khi đăng nhập / khôi phục phiên thành công (vd: gửi hàng đợi điểm).
  VoidCallback? onSignedIn;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  bool _busy = false;
  bool _offline = false;
  String? _lastError;

  AuthStatus get status => _status;
  AppUser? get currentUser => _user;
  bool get busy => _busy;

  /// Đang dùng phiên đã lưu nhưng chưa xác thực được với server (mất mạng).
  bool get isOffline => _offline;
  String? get lastError => _lastError;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isGuest => _status == AuthStatus.guest;

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  /// Khôi phục phiên khi mở app. Không ném lỗi.
  Future<void> restore() async {
    final token = await _tokens.read();
    if (token == null || token.isEmpty) {
      _status = AuthStatus.guest;
      notifyListeners();
      return;
    }
    try {
      final user = await _api.me();
      await _setUser(user);
      _status = AuthStatus.authenticated;
      _offline = false;
      notifyListeners();
      onSignedIn?.call();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _clearSession();
        _status = AuthStatus.guest;
      } else {
        // Mất mạng / server lỗi: giữ token, dùng thông tin đã lưu.
        _user = await _readCachedUser();
        _status = AuthStatus.authenticated;
        _offline = true;
      }
      notifyListeners();
    } catch (_) {
      _user = await _readCachedUser();
      _status = AuthStatus.authenticated;
      _offline = true;
      notifyListeners();
    }
  }

  Future<bool> login(String usernameOrEmail, String password) => _authenticate(
        () => _api.login(
          usernameOrEmail: usernameOrEmail.trim(),
          password: password,
        ),
      );

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
  }) =>
      _authenticate(
        () => _api.register(
          username: username.trim(),
          email: email.trim(),
          password: password,
          fullName: fullName?.trim(),
        ),
      );

  Future<bool> _authenticate(Future<AuthResult> Function() call) async {
    if (_busy) return false;
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      final r = await call();
      await _tokens.write(r.token);
      await _setUser(r.user);
      _status = AuthStatus.authenticated;
      _offline = false;
      _busy = false;
      notifyListeners();
      onSignedIn?.call();
      return true;
    } on ApiException catch (e) {
      _lastError = e.message;
    } catch (_) {
      _lastError = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
    }
    _busy = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await _clearSession();
    _status = AuthStatus.guest;
    _offline = false;
    _lastError = null;
    notifyListeners();
  }

  /// Token bị server từ chối (hết hạn / tài khoản bị khóa).
  void handleUnauthorized() {
    if (_status != AuthStatus.authenticated) return;
    unawaited(_clearSession().then((_) {
      _status = AuthStatus.guest;
      _offline = false;
      _lastError = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      notifyListeners();
    }));
  }

  Future<bool> updateProfile(String fullName) async {
    if (_busy) return false;
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      final user = await _api.updateMe(fullName: fullName.trim());
      await _setUser(user);
      _busy = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _lastError = e.message;
    } catch (_) {
      _lastError = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
    }
    _busy = false;
    notifyListeners();
    return false;
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    if (_busy) return false;
    _busy = true;
    _lastError = null;
    notifyListeners();
    var ok = false;
    try {
      await _api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      ok = true;
    } on ApiException catch (e) {
      _lastError = e.message;
    } catch (_) {
      _lastError = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
    }
    _busy = false;
    notifyListeners();
    return ok;
  }

  // ---- lưu trữ ----

  Future<void> _setUser(AppUser user) async {
    _user = user;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  Future<AppUser?> _readCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_userKey);
      if (raw == null) return null;
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearSession() async {
    await _tokens.clear();
    _user = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
    } catch (_) {}
  }
}
