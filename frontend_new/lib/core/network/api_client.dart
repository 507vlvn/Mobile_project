import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../services/score_reporter.dart';
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
  Future<List<UserSummary>> searchUsers(String q);

  /// Hồ sơ công khai: quan hệ với mình + thống kê từng game (có kỷ lục chơi đơn).
  Future<PlayerProfile> userProfile(int userId);
  Future<List<GameStats>> myRatings();
  Future<PagedResult<MatchHistoryItem>> matches({int page = 1, int pageSize = 20});

  /// Nộp kết quả một ván chơi đơn (POST /history).
  Future<SubmitResult> submitHistory(GameRecord record);

  // ---- Bảng xếp hạng ----
  Future<List<LeaderboardEntry>> leaderboard(LeaderboardQuery query, {int top = 50});

  /// Hạng của mình trong bảng (cần đăng nhập).
  Future<MyRank> myRank(LeaderboardQuery query);
  Future<SeasonInfo> season();

  // ---- Bạn bè ----
  Future<List<FriendInfo>> friends();
  Future<FriendRequests> friendRequests();

  /// Gửi lời mời; nếu bên kia đã mời mình thì server tự kết bạn.
  Future<void> sendFriendRequest(int userId);
  Future<void> acceptFriendRequest(int requestId);
  Future<void> declineFriendRequest(int requestId);

  /// Hủy kết bạn hoặc hủy lời mời đã gửi (`DELETE /friends/{userId}`).
  Future<void> removeFriend(int userId);

  // ---- Tin nhắn ----
  Future<List<Conversation>> conversations();

  /// Tin với một người, tăng dần theo id. [afterId]: tin mới hơn;
  /// [beforeId]: tin cũ hơn; không truyền: trang mới nhất.
  Future<List<ChatMessage>> messagesWith(
    int userId, {
    int? afterId,
    int? beforeId,
    int limit = 30,
  });
  Future<ChatMessage> sendMessage(int userId, String content);
  Future<void> markRead(int userId);

  // ---- Sudoku ----
  Future<SudokuProgressSummary> getSudokuProgress();
  Future<UpdateSudokuProgressResponse> recordSudokuProgress({
    required int level,
    required int timeSpentSeconds,
    int mistakes = 0,
  });
  Future<SudokuSavedGame?> getSudokuSavedGame({String mode = 'CLASSIC'});
  Future<SudokuSavedGame> saveSudokuGame({
    required String gameMode,
    int? level,
    required int difficulty,
    required int seed,
    required String boardCurrent,
    String? notesData,
    int mistakes = 0,
    int elapsedSeconds = 0,
  });
  Future<bool> deleteSudokuSavedGame({String mode = 'CLASSIC'});
  Future<List<DifficultyStats>> getSudokuDifficultyStats();
  Future<DifficultyStats> recordSudokuDifficultyStat({
    required int difficulty,
    bool isGameStarted = false,
    bool isWin = false,
    int elapsedSeconds = 0,
    int mistakes = 0,
  });
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

  List<Map<String, dynamic>> _list(Object? d) => [
        for (final e in (d as List? ?? const []))
          (e as Map).cast<String, dynamic>(),
      ];

  @override
  Future<List<UserSummary>> searchUsers(String q) async => [
        for (final e in _list(await _send('GET', '/users/search', query: {'q': q})))
          UserSummary.fromJson(e),
      ];

  @override
  Future<PlayerProfile> userProfile(int userId) async =>
      PlayerProfile.fromJson(_map(await _send('GET', '/users/$userId/profile')));

  @override
  Future<List<GameStats>> myRatings() async => [
        for (final e in _list(await _send('GET', '/ratings/me')))
          GameStats.fromJson(e),
      ];

  @override
  Future<PagedResult<MatchHistoryItem>> matches({int page = 1, int pageSize = 20}) async =>
      PagedResult.fromJson(
        _map(await _send('GET', '/matches',
            query: {'page': page, 'pageSize': pageSize})),
        MatchHistoryItem.fromJson,
      );

  @override
  Future<List<LeaderboardEntry>> leaderboard(LeaderboardQuery query, {int top = 50}) async => [
        for (final e in _list(await _send('GET', '/leaderboard', query: {...query.toQuery(), 'top': top})))
          LeaderboardEntry.fromJson(e),
      ];

  @override
  Future<MyRank> myRank(LeaderboardQuery query) async =>
      MyRank.fromJson(_map(await _send('GET', '/leaderboard/me', query: query.toQuery())));

  @override
  Future<SeasonInfo> season() async => SeasonInfo.fromJson(_map(await _send('GET', '/leaderboard/season')));

  @override
  Future<SubmitResult> submitHistory(GameRecord record) async =>
      SubmitResult.fromJson(
          _map(await _send('POST', '/history', body: record.toJson())));

  @override
  Future<List<FriendInfo>> friends() async => [
        for (final e in _list(await _send('GET', '/friends'))) FriendInfo.fromJson(e),
      ];

  @override
  Future<FriendRequests> friendRequests() async =>
      FriendRequests.fromJson(_map(await _send('GET', '/friends/requests')));

  @override
  Future<void> sendFriendRequest(int userId) async {
    await _send('POST', '/friends/requests', body: {'userId': userId});
  }

  @override
  Future<void> acceptFriendRequest(int requestId) async {
    await _send('POST', '/friends/requests/$requestId/accept');
  }

  @override
  Future<void> declineFriendRequest(int requestId) async {
    await _send('POST', '/friends/requests/$requestId/decline');
  }

  @override
  Future<void> removeFriend(int userId) async {
    await _send('DELETE', '/friends/$userId');
  }

  @override
  Future<List<Conversation>> conversations() async => [
        for (final e in _list(await _send('GET', '/messages/conversations')))
          Conversation.fromJson(e),
      ];

  @override
  Future<List<ChatMessage>> messagesWith(
    int userId, {
    int? afterId,
    int? beforeId,
    int limit = 30,
  }) async =>
      [
        for (final e in _list(await _send('GET', '/messages/with/$userId', query: {
          'limit': limit,
          'afterId': ?afterId,
          'beforeId': ?beforeId,
        })))
          ChatMessage.fromJson(e),
      ];

  @override
  Future<ChatMessage> sendMessage(int userId, String content) async =>
      ChatMessage.fromJson(_map(await _send('POST', '/messages/with/$userId',
          body: {'content': content})));

  @override
  Future<void> markRead(int userId) async {
    await _send('POST', '/messages/with/$userId/read');
  }

  // ---- Sudoku ----
  @override
  Future<SudokuProgressSummary> getSudokuProgress() async =>
      SudokuProgressSummary.fromJson(
          _map(await _send('GET', '/sudoku/progress')));

  @override
  Future<UpdateSudokuProgressResponse> recordSudokuProgress({
    required int level,
    required int timeSpentSeconds,
    int mistakes = 0,
  }) async =>
      UpdateSudokuProgressResponse.fromJson(_map(await _send(
        'POST',
        '/sudoku/progress',
        body: {
          'level': level,
          'timeSpentSeconds': timeSpentSeconds,
          'mistakes': mistakes,
        },
      )));

  @override
  Future<SudokuSavedGame?> getSudokuSavedGame({String mode = 'CLASSIC'}) async {
    final d = await _send('GET', '/sudoku/saved-game', query: {'mode': mode});
    if (d == null) return null;
    return SudokuSavedGame.fromJson(_map(d));
  }

  @override
  Future<SudokuSavedGame> saveSudokuGame({
    required String gameMode,
    int? level,
    required int difficulty,
    required int seed,
    required String boardCurrent,
    String? notesData,
    int mistakes = 0,
    int elapsedSeconds = 0,
  }) async =>
      SudokuSavedGame.fromJson(_map(await _send(
        'POST',
        '/sudoku/save-game',
        body: {
          'gameMode': gameMode,
          if (level != null) 'level': level,
          'difficulty': difficulty,
          'seed': seed,
          'boardCurrent': boardCurrent,
          if (notesData != null) 'notesData': notesData,
          'mistakes': mistakes,
          'elapsedSeconds': elapsedSeconds,
        },
      )));

  @override
  Future<bool> deleteSudokuSavedGame({String mode = 'CLASSIC'}) async {
    final d = await _send('DELETE', '/sudoku/saved-game', query: {'mode': mode});
    if (d is Map && d['success'] == true) return true;
    return false;
  }

  @override
  Future<List<DifficultyStats>> getSudokuDifficultyStats() async {
    final d = await _send('GET', '/sudoku/stats');
    return [
      for (final e in _list(d)) DifficultyStats.fromJson(_map(e)),
    ];
  }

  @override
  Future<DifficultyStats> recordSudokuDifficultyStat({
    required int difficulty,
    bool isGameStarted = false,
    bool isWin = false,
    int elapsedSeconds = 0,
    int mistakes = 0,
  }) async {
    final d = await _send(
      'POST',
      '/sudoku/stats/record',
      body: {
        'difficulty': difficulty,
        'isGameStarted': isGameStarted,
        'isWin': isWin,
        'elapsedSeconds': elapsedSeconds,
        'mistakes': mistakes,
      },
    );
    return DifficultyStats.fromJson(_map(d));
  }
}
