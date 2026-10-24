import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile_rubik/core/realtime/hub_gateway.dart';
import 'package:mobile_rubik/core/realtime/realtime_service.dart';

/// RealtimeService giả: test/ảnh chụp bơm sự kiện qua các phương thức `emit*`,
/// còn mọi lời gọi lên server được ghi vào [calls].
class FakeRealtimeService extends ChangeNotifier implements RealtimeService {
  RealtimeStatus _status = RealtimeStatus.connected;

  /// Lời gọi đã thực hiện, dạng "Invite(5, CARO, 2)".
  final List<String> calls = [];

  /// Nếu khác null, mọi lời gọi lên server ném lỗi này.
  RealtimeException? failWith;

  int connectCalls = 0;
  int disconnectCalls = 0;

  final _reconnected = StreamController<void>.broadcast();
  final _presence = StreamController<PresenceEvent>.broadcast();
  final _friendRequests = StreamController<FriendRequestEvent>.broadcast();
  final _friendAccepted = StreamController<FriendAcceptedEvent>.broadcast();
  final _messages = StreamController<MessageReceivedEvent>.broadcast();
  final _invitesReceived = StreamController<InviteReceivedEvent>.broadcast();
  final _inviteResults = StreamController<InviteResultEvent>.broadcast();
  final _queueStatus = StreamController<QueueStatusEvent>.broadcast();
  final _matchStarted = StreamController<MatchInfo>.broadcast();
  final _matchState = StreamController<MatchInfo>.broadcast();
  final _opponentProgress =
      StreamController<OpponentProgressEvent>.broadcast();
  final _quickChats = StreamController<QuickChatEvent>.broadcast();
  final _opponentConnection =
      StreamController<OpponentConnectionEvent>.broadcast();
  final _matchEnded = StreamController<MatchEndedEvent>.broadcast();
  final _drawOffered = StreamController<DrawOfferedEvent>.broadcast();
  final _drawResponded = StreamController<DrawRespondedEvent>.broadcast();
  final _rematchRequested =
      StreamController<RematchRequestedEvent>.broadcast();

  @override
  RealtimeStatus get status => _status;
  @override
  bool get isConnected => _status == RealtimeStatus.connected;

  void setStatus(RealtimeStatus s) {
    _status = s;
    notifyListeners();
  }

  /// Mô phỏng mất kết nối rồi kết nối lại.
  void simulateReconnect() {
    setStatus(RealtimeStatus.reconnecting);
    setStatus(RealtimeStatus.connected);
    _reconnected.add(null);
  }

  void emitPresence(PresenceEvent e) => _presence.add(e);
  void emitFriendRequest(FriendRequestEvent e) => _friendRequests.add(e);
  void emitFriendAccepted(FriendAcceptedEvent e) => _friendAccepted.add(e);
  void emitMessage(MessageReceivedEvent e) => _messages.add(e);
  void emitInvite(InviteReceivedEvent e) => _invitesReceived.add(e);
  void emitInviteResult(InviteResultEvent e) => _inviteResults.add(e);
  void emitQueueStatus(QueueStatusEvent e) => _queueStatus.add(e);
  void emitMatchStarted(MatchInfo e) => _matchStarted.add(e);
  void emitMatchState(MatchInfo e) => _matchState.add(e);
  void emitOpponentProgress(OpponentProgressEvent e) => _opponentProgress.add(e);
  void emitQuickChat(QuickChatEvent e) => _quickChats.add(e);
  void emitOpponentConnection(OpponentConnectionEvent e) =>
      _opponentConnection.add(e);
  void emitMatchEnded(MatchEndedEvent e) => _matchEnded.add(e);
  void emitDrawOffered(DrawOfferedEvent e) => _drawOffered.add(e);
  void emitDrawResponded(DrawRespondedEvent e) => _drawResponded.add(e);
  void emitRematchRequested(RematchRequestedEvent e) =>
      _rematchRequested.add(e);

  @override
  Stream<void> get reconnected => _reconnected.stream;
  @override
  Stream<PresenceEvent> get presence => _presence.stream;
  @override
  Stream<FriendRequestEvent> get friendRequests => _friendRequests.stream;
  @override
  Stream<FriendAcceptedEvent> get friendAccepted => _friendAccepted.stream;
  @override
  Stream<MessageReceivedEvent> get messages => _messages.stream;
  @override
  Stream<InviteReceivedEvent> get invitesReceived => _invitesReceived.stream;
  @override
  Stream<InviteResultEvent> get inviteResults => _inviteResults.stream;
  @override
  Stream<QueueStatusEvent> get queueStatus => _queueStatus.stream;
  @override
  Stream<MatchInfo> get matchStarted => _matchStarted.stream;
  @override
  Stream<MatchInfo> get matchState => _matchState.stream;
  @override
  Stream<OpponentProgressEvent> get opponentProgress =>
      _opponentProgress.stream;
  @override
  Stream<QuickChatEvent> get quickChats => _quickChats.stream;
  @override
  Stream<OpponentConnectionEvent> get opponentConnection =>
      _opponentConnection.stream;
  @override
  Stream<MatchEndedEvent> get matchEnded => _matchEnded.stream;
  @override
  Stream<DrawOfferedEvent> get drawOffered => _drawOffered.stream;
  @override
  Stream<DrawRespondedEvent> get drawResponded => _drawResponded.stream;
  @override
  Stream<RematchRequestedEvent> get rematchRequested =>
      _rematchRequested.stream;

  @override
  Future<void> connect() async {
    connectCalls++;
    setStatus(RealtimeStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    setStatus(RealtimeStatus.disconnected);
  }

  Future<void> _rec(String call) async {
    calls.add(call);
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> queueJoin(String gameCode, int difficulty) =>
      _rec('QueueJoin($gameCode, $difficulty)');
  @override
  Future<void> queueLeave() => _rec('QueueLeave()');
  @override
  Future<void> invite(int friendId, String gameCode, int difficulty) =>
      _rec('Invite($friendId, $gameCode, $difficulty)');
  @override
  Future<void> respondInvite(String inviteId, bool accept) =>
      _rec('RespondInvite($inviteId, $accept)');
  @override
  Future<void> caroMove(String matchId, int row, int col) =>
      _rec('CaroMove($matchId, $row, $col)');
  @override
  Future<void> raceProgress(String matchId, int percent) =>
      _rec('RaceProgress($matchId, $percent)');
  @override
  Future<void> raceFinish(String matchId, int timeMs, int mistakes) =>
      _rec('RaceFinish($matchId, $timeMs, $mistakes)');
  @override
  Future<void> resign(String matchId) => _rec('Resign($matchId)');
  @override
  Future<void> offerDraw(String matchId) => _rec('OfferDraw($matchId)');
  @override
  Future<void> respondDraw(String matchId, bool accept) =>
      _rec('RespondDraw($matchId, $accept)');
  @override
  Future<void> rematch(String matchId) => _rec('Rematch($matchId)');
  @override
  Future<void> quickChat(String matchId, String code) =>
      _rec('QuickChat($matchId, $code)');
  @override
  Future<void> rejoin(String matchId) => _rec('Rejoin($matchId)');
}

/// HubGateway giả cho test máy trạng thái kết nối của `SignalRRealtimeService`.
class FakeHubGateway implements HubGateway {
  /// Số lần `start()` đầu tiên sẽ thất bại.
  int failStarts = 0;
  int startCalls = 0;
  int stopCalls = 0;
  final List<String> invocations = [];
  RealtimeException? invokeError;

  final Map<String, void Function(List<Object?>?)> _handlers = {};
  void Function(Object?)? _onClosed;

  @override
  Future<void> start() async {
    startCalls++;
    if (failStarts > 0) {
      failStarts--;
      throw const RealtimeException('Không kết nối được');
    }
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _onClosed?.call(null);
  }

  @override
  Future<Object?> invoke(String method, List<Object> args) async {
    invocations.add('$method(${args.join(', ')})');
    if (invokeError != null) throw invokeError!;
    return null;
  }

  @override
  void on(String method, void Function(List<Object?>? args) handler) {
    _handlers[method.toLowerCase()] = handler;
  }

  @override
  void setOnClosed(void Function(Object? error)? callback) =>
      _onClosed = callback;

  /// Server đẩy một sự kiện xuống.
  void emit(String method, List<Object?>? args) =>
      _handlers[method.toLowerCase()]?.call(args);

  /// Mô phỏng đường truyền bị đứt.
  void dropConnection() => _onClosed?.call(Exception('closed'));
}
