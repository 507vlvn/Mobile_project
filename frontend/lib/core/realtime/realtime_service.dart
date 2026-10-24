import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../network/token_storage.dart';
import 'hub_gateway.dart';
import 'realtime_models.dart';

export 'hub_gateway.dart' show RealtimeException, hubErrorMessage, kConnectionLostMessage;
export 'realtime_models.dart';

/// Trạng thái kết nối tới hub.
enum RealtimeStatus { disconnected, connecting, connected, reconnecting }

/// Đường dẫn hub suy ra từ địa chỉ API: bỏ hậu tố `/api`, thêm `/hubs/game`.
String hubUrlFromApi(String apiBase) {
  var b = apiBase.trim();
  while (b.endsWith('/')) {
    b = b.substring(0, b.length - 1);
  }
  if (b.endsWith('/api')) b = b.substring(0, b.length - 4);
  return '$b/hubs/game';
}

/// Giao diện realtime mà widget/controller phụ thuộc — test dùng `FakeRealtimeService`.
///
/// Các phương thức client -> server trả về Future hoàn tất khi server xử lý xong;
/// lỗi của hub (HubException) hoặc mất kết nối ném ra [RealtimeException] với
/// thông điệp đã có thể hiển thị cho người dùng.
abstract interface class RealtimeService implements Listenable {
  RealtimeStatus get status;
  bool get isConnected;

  /// Phát một lần mỗi khi kết nối lại thành công SAU một lần mất kết nối.
  Stream<void> get reconnected;

  // ---- server -> client ----
  Stream<PresenceEvent> get presence;
  Stream<FriendRequestEvent> get friendRequests;
  Stream<FriendAcceptedEvent> get friendAccepted;
  Stream<MessageReceivedEvent> get messages;
  Stream<InviteReceivedEvent> get invitesReceived;
  Stream<InviteResultEvent> get inviteResults;
  Stream<QueueStatusEvent> get queueStatus;
  Stream<MatchInfo> get matchStarted;
  Stream<MatchInfo> get matchState;
  Stream<OpponentProgressEvent> get opponentProgress;
  Stream<QuickChatEvent> get quickChats;
  Stream<OpponentConnectionEvent> get opponentConnection;
  Stream<MatchEndedEvent> get matchEnded;
  Stream<DrawOfferedEvent> get drawOffered;
  Stream<DrawRespondedEvent> get drawResponded;
  Stream<RematchRequestedEvent> get rematchRequested;

  // ---- vòng đời ----
  Future<void> connect();
  Future<void> disconnect();

  // ---- client -> server ----
  Future<void> queueJoin(String gameCode, int difficulty);
  Future<void> queueLeave();
  
  /// Trả về khi server đã nhận lời mời (inviteId hex 32 ký tự nằm trong `InviteResult` sau đó).
  Future<void> invite(int friendId, String gameCode, int difficulty);
  Future<void> respondInvite(String inviteId, bool accept);
  Future<void> caroMove(String matchId, int row, int col);
  Future<void> raceProgress(String matchId, int percent);
  Future<void> raceFinish(String matchId, int timeMs, int mistakes);
  Future<void> resign(String matchId);
  Future<void> offerDraw(String matchId);
  Future<void> respondDraw(String matchId, bool accept);
  Future<void> rematch(String matchId);
  Future<void> quickChat(String matchId, String code);
  Future<void> rejoin(String matchId);
}

/// Dãy chờ giữa các lần thử kết nối lại (TASKS_V2 Q2.1): 0, 2, 5, 10, 30 giây
/// rồi lặp lại 30 giây.
const List<Duration> kReconnectBackoff = [
  Duration.zero,
  Duration(seconds: 2),
  Duration(seconds: 5),
  Duration(seconds: 10),
  Duration(seconds: 30),
];

/// Triển khai thật trên SignalR.
class SignalRRealtimeService extends ChangeNotifier implements RealtimeService {
  SignalRRealtimeService({
    required TokenStorage tokens,
    String? hubUrl,
    HubGatewayFactory? gatewayFactory,
    this.backoff = kReconnectBackoff,
    Future<void> Function(Duration)? sleep,
  })  : _sleep = sleep ?? Future<void>.delayed {
    final url = hubUrl ?? hubUrlFromApi(AppConfig.apiBaseUrl);
    final factory = gatewayFactory ?? SignalRHubGateway.new;
    _gateway = factory(url, () async => (await tokens.read()) ?? '');
    _wire();
  }

  final List<Duration> backoff;
  final Future<void> Function(Duration) _sleep;
  late final HubGateway _gateway;

  RealtimeStatus _status = RealtimeStatus.disconnected;
  bool _wanted = false;
  bool _hadConnection = false;
  bool _looping = false;
  bool _disposed = false;

  /// Số lần thử liên tiếp thất bại (đặt lại khi kết nối được).
  int _attempt = 0;

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

  // ---------------------------------------------------------- nối dây

  void _wire() {
    void listen<T>(String name, T? Function(List<Object?>?) parse,
        StreamController<T> sink) {
      _gateway.on(name, (args) {
        if (_disposed) return;
        T? event;
        try {
          event = parse(args);
        } catch (_) {
          event = null; // payload lạ: bỏ qua, không làm sập kết nối
        }
        if (event != null) sink.add(event);
      });
    }

    listen('Presence', PresenceEvent.parse, _presence);
    listen('FriendRequest', FriendRequestEvent.parse, _friendRequests);
    listen('FriendAccepted', FriendAcceptedEvent.parse, _friendAccepted);
    listen('MessageReceived', MessageReceivedEvent.parse, _messages);
    listen('InviteReceived', (a) => InviteReceivedEvent.parse(a),
        _invitesReceived);
    listen('InviteResult', InviteResultEvent.parse, _inviteResults);
    listen('QueueStatus', QueueStatusEvent.parse, _queueStatus);
    listen('MatchStarted', MatchInfo.parse, _matchStarted);
    listen('MatchState', MatchInfo.parse, _matchState);
    listen('OpponentProgress', OpponentProgressEvent.parse, _opponentProgress);
    listen('QuickChat', QuickChatEvent.parse, _quickChats);
    listen('OpponentConnection', OpponentConnectionEvent.parse,
        _opponentConnection);
    listen('MatchEnded', MatchEndedEvent.parse, _matchEnded);
    listen('DrawOffered', DrawOfferedEvent.parse, _drawOffered);
    listen('DrawResponded', DrawRespondedEvent.parse, _drawResponded);
    listen('RematchRequested', RematchRequestedEvent.parse, _rematchRequested);

    _gateway.setOnClosed((_) {
      if (_disposed || !_wanted) return;
      // Mất kết nối ngoài ý muốn: thử lại theo backoff.
      if (_status == RealtimeStatus.connected) {
        _setStatus(RealtimeStatus.reconnecting);
      }
      unawaited(_loop());
    });
  }

  void _setStatus(RealtimeStatus s) {
    if (_status == s || _disposed) return;
    _status = s;
    notifyListeners();
  }

  // ---------------------------------------------------------- vòng đời

  @override
  Future<void> connect() async {
    if (_disposed || _wanted) return;
    _wanted = true;
    _attempt = 0;
    _setStatus(_hadConnection
        ? RealtimeStatus.reconnecting
        : RealtimeStatus.connecting);
    await _loop();
  }

  @override
  Future<void> disconnect() async {
    if (!_wanted && _status == RealtimeStatus.disconnected) return;
    _wanted = false;
    _hadConnection = false;
    _attempt = 0;
    _setStatus(RealtimeStatus.disconnected);
    await _gateway.stop();
  }

  /// Thử kết nối cho tới khi được (hoặc bị [disconnect]).
  Future<void> _loop() async {
    if (_looping) return;
    _looping = true;
    try {
      while (_wanted && !_disposed) {
        try {
          await _gateway.start();
          if (!_wanted || _disposed) {
            await _gateway.stop();
            return;
          }
          final recovered = _hadConnection;
          _hadConnection = true;
          _attempt = 0;
          _setStatus(RealtimeStatus.connected);
          if (recovered) _reconnected.add(null);
          return;
        } catch (_) {
          if (!_wanted || _disposed) return;
          final delay = backoff[_attempt < backoff.length
              ? _attempt
              : backoff.length - 1];
          _attempt++;
          if (_hadConnection) _setStatus(RealtimeStatus.reconnecting);
          await _sleep(delay);
        }
      }
    } finally {
      _looping = false;
    }
  }

  // ---------------------------------------------------------- gọi lên server

  Future<void> _call(String method, List<Object> args) async {
    if (!isConnected) {
      throw const RealtimeException(
          'Chưa kết nối tới máy chủ. Vui lòng thử lại sau giây lát.');
    }
    try {
      await _gateway.invoke(method, args);
    } on RealtimeException {
      rethrow;
    } catch (e) {
      throw RealtimeException(SignalRHubGateway.clean(e));
    }
  }

  @override
  Future<void> queueJoin(String gameCode, int difficulty) =>
      _call('QueueJoin', [gameCode, difficulty]);
  @override
  Future<void> queueLeave() => _call('QueueLeave', const []);
  @override
  Future<void> invite(int friendId, String gameCode, int difficulty) =>
      _call('Invite', [friendId, gameCode, difficulty]);
  @override
  Future<void> respondInvite(String inviteId, bool accept) =>
      _call('RespondInvite', [inviteId, accept]);
  @override
  Future<void> caroMove(String matchId, int row, int col) =>
      _call('CaroMove', [matchId, row, col]);
  @override
  Future<void> raceProgress(String matchId, int percent) =>
      _call('RaceProgress', [matchId, percent]);
  @override
  Future<void> raceFinish(String matchId, int timeMs, int mistakes) =>
      _call('RaceFinish', [matchId, timeMs, mistakes]);
  @override
  Future<void> resign(String matchId) => _call('Resign', [matchId]);
  @override
  Future<void> offerDraw(String matchId) =>
      _call('OfferDraw', [matchId]);
  @override
  Future<void> respondDraw(String matchId, bool accept) =>
      _call('RespondDraw', [matchId, accept]);
  @override
  Future<void> rematch(String matchId) => _call('Rematch', [matchId]);
  @override
  Future<void> quickChat(String matchId, String code) =>
      _call('QuickChat', [matchId, code]);
  @override
  Future<void> rejoin(String matchId) => _call('Rejoin', [matchId]);

  @override
  void dispose() {
    _disposed = true;
    _wanted = false;
    unawaited(_gateway.stop());
    for (final c in [
      _reconnected,
      _presence,
      _friendRequests,
      _friendAccepted,
      _messages,
      _invitesReceived,
      _inviteResults,
      _queueStatus,
      _matchStarted,
      _matchState,
      _opponentProgress,
      _quickChats,
      _opponentConnection,
      _matchEnded,
      _drawOffered,
      _drawResponded,
      _rematchRequested,
    ]) {
      unawaited(c.close());
    }
    super.dispose();
  }
}
