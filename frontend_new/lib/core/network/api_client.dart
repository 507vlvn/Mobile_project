import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import 'api_exception.dart';
import 'models.dart';
import 'token_storage.dart';

/// Giao diện gọi API — widget và controller chỉ phụ thuộc vào lớp này,
/// nên test có thể thay bằng bản giả (fake).
abstract interface class ApiClient {
  /// Được gọi khi một request CÓ gắn token bị server trả 401.
  VoidCallback? get onUnauthorized;
  set onUnauthorized(VoidCallback? cb);

  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
  });
  Future<AuthResult> login({
    required String usernameOrEmail,
    required String password,
  });
  Future<AppUser> me();
  Future<AppUser> updateMe({String? fullName});

  /// Thống kê từng game trong hồ sơ công khai (có kỷ lục chơi đơn).
  Future<List<GameStats>> profileStats(int userId);
  Future<List<GameStats>> myRatings();
  Future<PagedResult<MatchHistoryItem>> matches({int page = 1, int pageSize = 20});
}

class HttpApiClient implements ApiClient {
  HttpApiClient({
    required TokenStorage tokens,
    String? baseUrl,
    http.Client? client,
  })  : _tokens = tokens,
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
        _http = client ?? http.Client();

  static const _timeout = Duration(seconds: 15);

  final TokenStorage _tokens;
  final String _baseUrl;
  final http.Client _http;

  @override
  VoidCallback? onUnauthorized;

  Future<Object?> _send(String method, String path,
      {Map<String, dynamic>? query, Object? body}) async {
    if (_baseUrl.isEmpty) throw const ApiException(AppConfig.notConfiguredMessage);
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, '$v')),
    );
    final token = await _tokens.read();
    final hasToken = token != null && token.isNotEmpty;
    final req = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (hasToken) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }

    final http.Response res;
    try {
      res = await http.Response.fromStream(
          await _http.send(req).timeout(_timeout));
    } on TimeoutException {
      throw const ApiException(ApiException.timeoutMessage, isTimeout: true);
    } on SocketException {
      throw const ApiException(ApiException.networkMessage, isNetwork: true);
    } on http.ClientException {
      throw const ApiException(ApiException.networkMessage, isNetwork: true);
    }

    Object? data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes));
      } on FormatException {
        data = null;
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    if (res.statusCode == 401 && hasToken) onUnauthorized?.call();
    throw ApiException.fromProblem(res.statusCode, data);
  }

  Map<String, dynamic> _map(Object? d) => (d as Map).cast<String, dynamic>();

  @override
  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
  }) async =>
      AuthResult.fromJson(_map(await _send('POST', '/auth/register', body: {
        'username': username,
        'email': email,
        'password': password,
        if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
      })));

  @override
  Future<AuthResult> login({
    required String usernameOrEmail,
    required String password,
  }) async =>
      AuthResult.fromJson(_map(await _send('POST', '/auth/login', body: {
        'usernameOrEmail': usernameOrEmail,
        'password': password,
      })));

  @override
  Future<AppUser> me() async => AppUser.fromJson(_map(await _send('GET', '/users/me')));

  @override
  Future<AppUser> updateMe({String? fullName}) async =>
      AppUser.fromJson(_map(await _send('PUT', '/users/me', body: {
        'fullName': fullName,
      })));

  @override
  Future<List<GameStats>> profileStats(int userId) async {
    final d = _map(await _send('GET', '/users/$userId/profile'));
    return [
      for (final e in (d['stats'] as List? ?? const []))
        GameStats.fromJson((e as Map).cast<String, dynamic>()),
    ];
  }

  @override
  Future<List<GameStats>> myRatings() async => [
        for (final e in (await _send('GET', '/ratings/me') as List? ?? const []))
          GameStats.fromJson((e as Map).cast<String, dynamic>()),
      ];

  @override
  Future<PagedResult<MatchHistoryItem>> matches({int page = 1, int pageSize = 20}) async =>
      PagedResult.fromJson(
        _map(await _send('GET', '/matches',
            query: {'page': page, 'pageSize': pageSize})),
        MatchHistoryItem.fromJson,
      );
}
