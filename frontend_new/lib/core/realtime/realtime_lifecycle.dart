import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../auth/auth_controller.dart';
import 'realtime_service.dart';

/// Gắn vòng đời của [RealtimeService] vào đăng nhập và trạng thái ứng dụng:
/// - đăng nhập (authenticated) -> kết nối; đăng xuất -> ngắt;
/// - ứng dụng ở nền quá [pauseGrace] (mặc định 2 phút) -> ngắt, quay lại -> kết nối lại.
class RealtimeLifecycle with WidgetsBindingObserver {
  RealtimeLifecycle({
    required this.service,
    required this.auth,
    this.pauseGrace = const Duration(minutes: 2),
  });

  final RealtimeService service;
  final AuthController auth;
  final Duration pauseGrace;

  Timer? _pauseTimer;
  bool _pausedLong = false;
  bool _attached = false;

  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
    auth.addListener(onAuthChanged);
    onAuthChanged();
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    WidgetsBinding.instance.removeObserver(this);
    auth.removeListener(onAuthChanged);
    _pauseTimer?.cancel();
  }

  @visibleForTesting
  void onAuthChanged() {
    if (auth.isAuthenticated) {
      if (!_pausedLong) unawaited(service.connect());
    } else {
      _pauseTimer?.cancel();
      _pausedLong = false;
      unawaited(service.disconnect());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      onLifecycle(state);

  @visibleForTesting
  void onLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (!auth.isAuthenticated) return;
        _pauseTimer ??= Timer(pauseGrace, () {
          _pausedLong = true;
          _pauseTimer = null;
          unawaited(service.disconnect());
        });
      case AppLifecycleState.resumed:
        _pauseTimer?.cancel();
        _pauseTimer = null;
        if (_pausedLong) {
          _pausedLong = false;
          if (auth.isAuthenticated) unawaited(service.connect());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }
}
