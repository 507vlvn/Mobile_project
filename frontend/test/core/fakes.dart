import 'package:flutter/foundation.dart';
import 'package:mobile_rubik/core/network/api_client.dart';
import 'package:mobile_rubik/core/network/api_exception.dart';
import 'package:mobile_rubik/core/network/models.dart';
import 'package:mobile_rubik/core/network/token_storage.dart';
import 'package:mobile_rubik/core/services/score_reporter.dart';

/// ApiClient giả: mỗi endpoint là một closure có thể thay đổi trong test.
class FakeApiClient implements ApiClient {
  @override
  VoidCallback? onUnauthorized;

  Future<AuthResult> Function()? onLogin;
  Future<AuthResult> Function()? onRegister;
  Future<AppUser> Function()? onMe;
  Future<AppUser> Function(String? fullName)? onUpdateMe;
  Future<SubmitResult> Function(GameRecord r)? onSubmit;
  Future<PagedResult<HistoryItem>> Function(String? game, int page, int size)?
      onHistory;
  Future<List<BoardEntry>> Function(BoardQuery q)? onLeaderboard;
  Future<BoardMe> Function(BoardQuery q)? onMyRank;
  Future<SeasonInfo> Function()? onSeason;

  // ---- friends / profile / pvp ----
  Future<List<FriendInfo>> Function()? onFriends;
  Future<FriendRequests> Function()? onFriendRequests;
  Future<void> Function(int userId)? onSendFriendRequest;
  Future<void> Function(int requestId)? onAcceptFriendRequest;
  Future<void> Function(int requestId)? onDeclineFriendRequest;
  Future<void> Function(int userId)? onRemoveFriend;
  Future<PlayerProfile> Function(int userId)? onUserProfile;
  Future<PagedResult<MatchHistoryItem>> Function(int page)? onMatches;
  Future<List<GameStats>> Function()? onMyRatings;

  // ---- social ----
  Future<List<UserSummary>> Function(String q)? onSearchUsers;
  Future<Challenge> Function(int opponentId, String gameCode, int difficulty)?
      onCreateChallenge;
  Future<List<Challenge>> Function(String box)? onChallenges;
  Future<Challenge> Function(int id)? onAccept;
  Future<Challenge> Function(int id)? onDecline;
  Future<List<Conversation>> Function()? onConversations;
  Future<List<ChatMessage>> Function(
      int userId, int? afterId, int? beforeId, int limit)? onMessages;
  Future<ChatMessage> Function(int userId, String content)? onSendMessage;
  Future<void> Function(int userId)? onMarkRead;
  Future<SocialSummary> Function()? onSocialSummary;

  int summaryCalls = 0;
  int leaderboardCalls = 0;
  int myRankCalls = 0;
  int seasonCalls = 0;
  int friendsCalls = 0;
  int friendRequestsCalls = 0;
  BoardQuery? lastBoardQuery;
  final List<GameRecord> submitted = [];

  @override
  Future<AuthResult> login(
          {required String usernameOrEmail, required String password}) =>
      onLogin!();

  @override
  Future<AuthResult> register(
          {required String username,
          required String email,
          required String password,
          String? fullName}) =>
      onRegister!();

  @override
  Future<AppUser> me() => onMe!();

  @override
  Future<AppUser> updateMe({String? fullName, String? avatarUrl}) =>
      onUpdateMe!(fullName);

  @override
  Future<List<UserSummary>> searchUsers(String q) async =>
      onSearchUsers == null ? <UserSummary>[] : await onSearchUsers!(q);

  @override
  Future<List<GameInfo>> games() async => [];

  @override
  Future<SubmitResult> submitHistory(GameRecord record) {
    submitted.add(record);
    return onSubmit!(record);
  }

  @override
  Future<PagedResult<HistoryItem>> myHistory(
          {String? gameCode, int page = 1, int pageSize = 20}) =>
      onHistory!(gameCode, page, pageSize);

  @override
  Future<List<BoardEntry>> leaderboard(BoardQuery query, {int top = 50}) {
    leaderboardCalls++;
    lastBoardQuery = query;
    return onLeaderboard == null
        ? Future.value(<BoardEntry>[])
        : onLeaderboard!(query);
  }

  @override
  Future<BoardMe> myRank(BoardQuery query) {
    myRankCalls++;
    return onMyRank!(query);
  }

  @override
  Future<SeasonInfo> season() {
    seasonCalls++;
    return onSeason == null
        ? Future.value(SeasonInfo(
            startsAt: DateTime.now().subtract(const Duration(days: 3)),
            endsAt: DateTime.now().add(const Duration(days: 3, hours: 4, minutes: 30))))
        : onSeason!();
  }

  @override
  Future<List<FriendInfo>> friends() async {
    friendsCalls++;
    return onFriends == null ? <FriendInfo>[] : await onFriends!();
  }

  @override
  Future<FriendRequests> friendRequests() async {
    friendRequestsCalls++;
    return onFriendRequests == null
        ? const FriendRequests()
        : await onFriendRequests!();
  }

  @override
  Future<void> sendFriendRequest(int userId) async {
    if (onSendFriendRequest != null) await onSendFriendRequest!(userId);
  }

  @override
  Future<void> acceptFriendRequest(int requestId) async {
    if (onAcceptFriendRequest != null) await onAcceptFriendRequest!(requestId);
  }

  @override
  Future<void> declineFriendRequest(int requestId) async {
    if (onDeclineFriendRequest != null) {
      await onDeclineFriendRequest!(requestId);
    }
  }

  @override
  Future<void> removeFriend(int userId) async {
    if (onRemoveFriend != null) await onRemoveFriend!(userId);
  }

  @override
  Future<PlayerProfile> userProfile(int userId) => onUserProfile == null
      ? Future.error(const ApiException('Chưa có dữ liệu hồ sơ', statusCode: 404))
      : onUserProfile!(userId);

  @override
  Future<PagedResult<MatchHistoryItem>> matches(
          {int page = 1, int pageSize = 20, int? myId}) async =>
      onMatches == null
          ? const PagedResult(items: [], page: 1, pageSize: 20, total: 0)
          : await onMatches!(page);

  @override
  Future<List<GameStats>> myRatings() async =>
      onMyRatings == null ? <GameStats>[] : await onMyRatings!();

  @override
  Future<Challenge> createChallenge(
          {required int opponentId,
          required String gameCode,
          required int difficulty}) =>
      onCreateChallenge!(opponentId, gameCode, difficulty);

  @override
  Future<List<Challenge>> challenges(String box) async =>
      onChallenges == null ? <Challenge>[] : await onChallenges!(box);

  @override
  Future<Challenge> acceptChallenge(int id) => onAccept!(id);

  @override
  Future<Challenge> declineChallenge(int id) => onDecline!(id);

  @override
  Future<List<Conversation>> conversations() async =>
      onConversations == null ? <Conversation>[] : await onConversations!();

  @override
  Future<List<ChatMessage>> messagesWith(int userId,
          {int? afterId, int? beforeId, int limit = 30}) async =>
      onMessages == null ? <ChatMessage>[] : await onMessages!(userId, afterId, beforeId, limit);

  @override
  Future<ChatMessage> sendMessage(int userId, String content) =>
      onSendMessage!(userId, content);

  @override
  Future<void> markRead(int userId) async {
    if (onMarkRead != null) await onMarkRead!(userId);
  }

  @override
  Future<SocialSummary> socialSummary() async {
    summaryCalls++;
    return onSocialSummary == null ? const SocialSummary() : await onSocialSummary!();
  }
}

class FakeTokenStorage implements TokenStorage {
  String? token;
  FakeTokenStorage([this.token]);

  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

const testUser = AppUser(
  userId: 7,
  username: 'an_nguyen',
  email: 'an@email.com',
  fullName: 'Nguyễn Văn An',
);

SubmitResult fakeSubmitResult(GameRecord r,
        {int score = 1234, bool best = true}) =>
    SubmitResult(
      isPersonalBest: best,
      record: HistoryItem(
        historyId: 1,
        gameCode: r.gameCode,
        gameName: r.gameCode,
        timeSpentSeconds: r.timeSeconds,
        mistakesCount: r.mistakes,
        result: r.outcome.apiValue,
        score: score,
        playedAt: DateTime(2026, 1, 1),
      ),
    );
