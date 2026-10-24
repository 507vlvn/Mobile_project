import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../services/score_reporter.dart';
import 'api_exception.dart';
import 'models.dart';
import 'token_storage.dart';

/// Giao diện gọi API — widget và controller chỉ phụ thuộc vào lớp này,
/// nên test có thể thay bằng bản giả (fake).
///
/// Quy tắc với DB host miễn phí: không gọi song song trong vòng lặp,
/// GET tự thử lại tối đa 2 lần (chỉ khi lỗi mạng), POST không bao giờ tự thử lại.
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
  Future<AppUser> updateMe({String? fullName, String? avatarUrl});
  Future<List<UserSummary>> searchUsers(String q);
  Future<List<GameInfo>> games();
  Future<SubmitResult> submitHistory(GameRecord record);
  Future<PagedResult<HistoryItem>> myHistory({
    String? gameCode,
    int page = 1,
    int pageSize = 20,
  });

  // ---- Xếp hạng v2 ----
  Future<List<BoardEntry>> leaderboard(BoardQuery query, {int top = 50});
  Future<BoardMe> myRank(BoardQuery query);
  Future<SeasonInfo> season();

  // ---- Bạn bè ----
  Future<List<FriendInfo>> friends();
  Future<FriendRequests> friendRequests();

  /// Gửi lời mời; nếu bên kia đã mời mình thì server tự kết bạn.
  Future<void> sendFriendRequest(int userId);
  Future<void> acceptFriendRequest(int requestId);
  Future<void> declineFriendRequest(int requestId);

  /// Hủy lời mời đã gửi (xóa lời mời đi). Dùng `DELETE /friends/{userId}`.
  Future<void> removeFriend(int userId);
  Future<PlayerProfile> userProfile(int userId);

  // ---- Đối kháng ----
  Future<PagedResult<MatchHistoryItem>> matches({
    int page = 1,
    int pageSize = 20,
    int? myId,
  });
  Future<List<GameStats>> myRatings();

  // ---- Thách đấu ----
  Future<Challenge> createChallenge({
    required int opponentId,
    required String gameCode,
    required int difficulty,
  });

  /// [box]: incoming | outgoing | active | done.
  Future<List<Challenge>> challenges(String box);
  Future<Challenge> acceptChallenge(int id);
  Future<Challenge> declineChallenge(int id);

  // ---- Tin nhắn ----
  Future<List<Conversation>> conversations();

  /// Tăng dần theo messageId. [afterId]: tin mới hơn; [beforeId]: tin cũ hơn.
  Future<List<ChatMessage>> messagesWith(
    int userId, {
    int? afterId,
    int? beforeId,
    int limit = 30,
  });
  Future<ChatMessage> sendMessage(int userId, String content);
  Future<void> markRead(int userId);
  Future<SocialSummary> socialSummary();
}

class DioApiClient implements ApiClient {
  DioApiClient({
    required TokenStorage tokens,
    String? baseUrl,
    Dio? dio,
    List<Duration> retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
    ],
  })  : _tokens = tokens,
        _retryDelays = retryDelays,
        _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl ?? AppConfig.apiBaseUrl
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 15)
      ..headers['Accept'] = 'application/json';
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokens.read();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) {
        final sentToken = e.requestOptions.headers.containsKey('Authorization');
        if (e.response?.statusCode == 401 && sentToken) {
          onUnauthorized?.call();
        }
        handler.next(e);
      },
    ));
  }

  final Dio _dio;
  final TokenStorage _tokens;
  final List<Duration> _retryDelays;

  @override
  VoidCallback? onUnauthorized;

  Future<Object?> _get(String path, {Map<String, dynamic>? query}) async {
    var attempt = 0;
    while (true) {
      try {
        final r = await _dio.get<Object?>(path, queryParameters: query);
        return r.data;
      } on DioException catch (e) {
        final ex = ApiException.fromDio(e);
        // Chỉ thử lại khi lỗi mạng (không thử lại timeout/4xx/5xx để khỏi dồn tải)
        if (ex.isNetwork && attempt < _retryDelays.length) {
          await Future<void>.delayed(_retryDelays[attempt++]);
          continue;
        }
        throw ex;
      }
    }
  }

  Future<Object?> _send(String method, String path, Object? body) async {
    try {
      final r = await _dio.request<Object?>(
        path,
        data: body,
        options: Options(method: method),
      );
      return r.data;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Map<String, dynamic> _map(Object? d) => (d as Map).cast<String, dynamic>();

  @override
  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
  }) async =>
      AuthResult.fromJson(_map(await _send('POST', '/auth/register', {
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
      AuthResult.fromJson(_map(await _send('POST', '/auth/login', {
        'usernameOrEmail': usernameOrEmail,
        'password': password,
      })));

  @override
  Future<AppUser> me() async => AppUser.fromJson(_map(await _get('/users/me')));

  @override
  Future<AppUser> updateMe({String? fullName, String? avatarUrl}) async =>
      AppUser.fromJson(_map(await _send('PUT', '/users/me', {
        if (fullName != null) 'fullName': fullName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      })));

  @override
  Future<List<UserSummary>> searchUsers(String q) async {
    final d = await _get('/users/search', query: {'q': q}) as List;
    return [for (final e in d) UserSummary.fromJson(_map(e))];
  }

  @override
  Future<List<GameInfo>> games() async {
    final d = await _get('/games') as List;
    return [for (final e in d) GameInfo.fromJson(_map(e))];
  }

  @override
  Future<SubmitResult> submitHistory(GameRecord record) async =>
      SubmitResult.fromJson(
          _map(await _send('POST', '/history', record.toJson())));

  @override
  Future<PagedResult<HistoryItem>> myHistory({
    String? gameCode,
    int page = 1,
    int pageSize = 20,
  }) async =>
      PagedResult.fromJson(
        _map(await _get('/history/me', query: {
          if (gameCode != null) 'gameCode': gameCode,
          'page': page,
          'pageSize': pageSize,
        })),
        HistoryItem.fromJson,
      );

  @override
  Future<List<BoardEntry>> leaderboard(BoardQuery query, {int top = 50}) async {
    final d = await _get('/leaderboard', query: {...query.toQuery(), 'top': top});
    return [
      for (final e in extractList(d, ['entries', 'items', 'data']))
        BoardEntry.fromJson(e, board: query.board),
    ];
  }

  @override
  Future<BoardMe> myRank(BoardQuery query) async => BoardMe.fromJson(
      _map(await _get('/leaderboard/me', query: query.toQuery())),
      board: query.board);

  @override
  Future<SeasonInfo> season() async =>
      SeasonInfo.fromJson(_map(await _get('/leaderboard/season')));

  @override
  Future<List<FriendInfo>> friends() async => [
        for (final e in extractList(await _get('/friends'), ['friends', 'items']))
          FriendInfo.fromJson(e),
      ];

  @override
  Future<FriendRequests> friendRequests() async =>
      FriendRequests.fromJson(await _get('/friends/requests'));

  @override
  Future<void> sendFriendRequest(int userId) async {
    await _send('POST', '/friends/requests', {'userId': userId});
  }

  @override
  Future<void> acceptFriendRequest(int requestId) async {
    await _send('POST', '/friends/requests/$requestId/accept', null);
  }

  @override
  Future<void> declineFriendRequest(int requestId) async {
    await _send('POST', '/friends/requests/$requestId/decline', null);
  }

  @override
  Future<void> removeFriend(int userId) async {
    await _send('DELETE', '/friends/$userId', null);
  }

  @override
  Future<PlayerProfile> userProfile(int userId) async =>
      PlayerProfile.fromJson(_map(await _get('/users/$userId/profile')));

  @override
  Future<PagedResult<MatchHistoryItem>> matches({
    int page = 1,
    int pageSize = 20,
    int? myId,
  }) async =>
      parseMatchPage(
        await _get('/matches', query: {'page': page, 'pageSize': pageSize}),
        myId: myId,
        page: page,
      );

  @override
  Future<List<GameStats>> myRatings() async =>
      parseRatings(await _get('/ratings/me'));

  @override
  Future<Challenge> createChallenge({
    required int opponentId,
    required String gameCode,
    required int difficulty,
  }) async =>
      Challenge.fromJson(_map(await _send('POST', '/challenges', {
        'opponentId': opponentId,
        'gameCode': gameCode,
        'difficulty': difficulty,
      })));

  @override
  Future<List<Challenge>> challenges(String box) async {
    final d = await _get('/challenges', query: {'box': box}) as List;
    return [for (final e in d) Challenge.fromJson(_map(e))];
  }

  @override
  Future<Challenge> acceptChallenge(int id) async => Challenge.fromJson(
      _map(await _send('POST', '/challenges/$id/accept', null)));

  @override
  Future<Challenge> declineChallenge(int id) async => Challenge.fromJson(
      _map(await _send('POST', '/challenges/$id/decline', null)));

  @override
  Future<List<Conversation>> conversations() async {
    final d = await _get('/messages/conversations') as List;
    return [for (final e in d) Conversation.fromJson(_map(e))];
  }

  @override
  Future<List<ChatMessage>> messagesWith(
    int userId, {
    int? afterId,
    int? beforeId,
    int limit = 30,
  }) async {
    final d = await _get('/messages/with/$userId', query: {
      if (afterId != null) 'afterId': afterId,
      if (beforeId != null) 'beforeId': beforeId,
      'limit': limit,
    }) as List;
    return [for (final e in d) ChatMessage.fromJson(_map(e))];
  }

  @override
  Future<ChatMessage> sendMessage(int userId, String content) async =>
      ChatMessage.fromJson(_map(
          await _send('POST', '/messages/with/$userId', {'content': content})));

  @override
  Future<void> markRead(int userId) async {
    await _send('POST', '/messages/with/$userId/read', null);
  }

  @override
  Future<SocialSummary> socialSummary() async =>
      SocialSummary.fromJson(_map(await _get('/social/summary')));
}
