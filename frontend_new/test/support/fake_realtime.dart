import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:frontend_new/core/network/models.dart';
import 'package:frontend_new/core/realtime/realtime_service.dart';

/// RealtimeService giả cho test: đẩy sự kiện bằng các StreamController công khai,
/// ghi lại mọi lệnh gửi lên server vào [calls] (vd `'CaroMove abc 7 7'`).
class FakeRealtime extends ChangeNotifier implements RealtimeService {
  bool connected = true;

  /// Đặt khác null để lệnh kế tiếp ném lỗi này (giống HubException).
  String? failNext;
  String nextInviteId = 'inv1';
  final calls = <String>[];

  final reconnectedCtl = StreamController<void>.broadcast();
  final presenceCtl = StreamController<PresenceEvent>.broadcast();
  final requestsCtl = StreamController<void>.broadcast();
  final acceptedCtl = StreamController<void>.broadcast();
  final messagesCtl = StreamController<ChatMessage>.broadcast();
  final queueCtl = StreamController<QueueStatusEvent>.broadcast();
  final invitesCtl = StreamController<InviteReceivedEvent>.broadcast();
  final inviteResultsCtl = StreamController<InviteResultEvent>.broadcast();
  final matchStartedCtl = StreamController<MatchInfo>.broadcast();
  final matchStateCtl = StreamController<MatchInfo>.broadcast();
  final progressCtl = StreamController<OpponentProgressEvent>.broadcast();
  final connectionCtl = StreamController<OpponentConnectionEvent>.broadcast();
  final drawOfferedCtl = StreamController<MatchSignalEvent>.broadcast();
  final drawRespondedCtl = StreamController<DrawRespondedEvent>.broadcast();
  final rematchCtl = StreamController<MatchSignalEvent>.broadcast();
  final chatCtl = StreamController<MatchSignalEvent>.broadcast();
  final sudokuMovesCtl = StreamController<SudokuMoveEvent>.broadcast();
  final sudokuCursorsCtl = StreamController<SudokuCursorEvent>.broadcast();
  final matchEndedCtl = StreamController<MatchEndedEvent>.broadcast();

  void setConnected(bool v) {
    connected = v;
    notifyListeners();
  }

  @override
  RealtimeStatus get status => connected ? RealtimeStatus.connected : RealtimeStatus.disconnected;
  @override
  bool get isConnected => connected;
  @override
  Stream<void> get reconnected => reconnectedCtl.stream;
  @override
  Stream<PresenceEvent> get presence => presenceCtl.stream;
  @override
  Stream<void> get friendRequests => requestsCtl.stream;
  @override
  Stream<void> get friendAccepted => acceptedCtl.stream;
  @override
  Stream<ChatMessage> get messages => messagesCtl.stream;
  @override
  Stream<QueueStatusEvent> get queueStatus => queueCtl.stream;
  @override
  Stream<InviteReceivedEvent> get invitesReceived => invitesCtl.stream;
  @override
  Stream<InviteResultEvent> get inviteResults => inviteResultsCtl.stream;
  @override
  Stream<MatchInfo> get matchStarted => matchStartedCtl.stream;
  @override
  Stream<MatchInfo> get matchState => matchStateCtl.stream;
  @override
  Stream<OpponentProgressEvent> get opponentProgress => progressCtl.stream;
  @override
  Stream<OpponentConnectionEvent> get opponentConnection => connectionCtl.stream;
  @override
  Stream<MatchSignalEvent> get drawOffered => drawOfferedCtl.stream;
  @override
  Stream<DrawRespondedEvent> get drawResponded => drawRespondedCtl.stream;
  @override
  Stream<MatchSignalEvent> get rematchRequested => rematchCtl.stream;
  @override
  Stream<MatchSignalEvent> get quickChats => chatCtl.stream;
  @override
  Stream<SudokuMoveEvent> get sudokuMoves => sudokuMovesCtl.stream;
  @override
  Stream<SudokuCursorEvent> get sudokuCursors => sudokuCursorsCtl.stream;
  @override
  Stream<MatchEndedEvent> get matchEnded => matchEndedCtl.stream;

  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {}

  Future<void> _record(String call) async {
    calls.add(call);
    final err = failNext;
    if (err != null) {
      failNext = null;
      throw RealtimeException(err);
    }
  }

  @override
  Future<void> queueJoin(String gameCode, int difficulty) => _record('QueueJoin $gameCode $difficulty');
  @override
  Future<void> queueLeave() => _record('QueueLeave');
  @override
  Future<String> invite(int friendId, String gameCode, int difficulty) async {
    await _record('Invite $friendId $gameCode $difficulty');
    return nextInviteId;
  }

  @override
  Future<void> respondInvite(String inviteId, bool accept) => _record('RespondInvite $inviteId $accept');
  @override
  Future<void> caroMove(String matchId, int row, int col) => _record('CaroMove $matchId $row $col');
  @override
  Future<void> raceProgress(String matchId, int percent) => _record('RaceProgress $matchId $percent');
  @override
  Future<void> raceFinish(String matchId, int timeMs, int mistakes) =>
      _record('RaceFinish $matchId $timeMs $mistakes');
  @override
  Future<void> resign(String matchId) => _record('Resign $matchId');
  @override
  Future<void> offerDraw(String matchId) => _record('OfferDraw $matchId');
  @override
  Future<void> respondDraw(String matchId, bool accept) => _record('RespondDraw $matchId $accept');
  @override
  Future<void> rematch(String matchId) => _record('Rematch $matchId');
  @override
  Future<void> quickChat(String matchId, String code) => _record('QuickChat $matchId $code');
  @override
  Future<void> sudokuMove(String matchId, int row, int col, int val, bool isMistake) =>
      _record('SudokuMove $matchId $row $col $val $isMistake');
  @override
  Future<void> sudokuCursor(String matchId, int row, int col) =>
      _record('SudokuCursor $matchId $row $col');
  @override
  Future<void> sudokuFinish(String matchId, int timeSeconds) =>
      _record('SudokuFinish $matchId $timeSeconds');
  @override
  Future<void> rejoin(String matchId) => _record('Rejoin $matchId');
}

/// Payload trận giống hệt server gửi (MatchService.Payload) để dựng MatchInfo trong test.
Map<String, Object?> matchPayload({
  String matchId = 'm1',
  String gameCode = 'CARO',
  int difficulty = 2,
  String mode = 'RANKED',
  int seed = 42,
  String status = 'ACTIVE',
  int you = 7,
  int opponentId = 9,
  List<List<int>> moves = const [],
  int? currentTurnUserId,
  String? turnDeadlineUtc,
  int? drawOfferedBy,
  Map<int, int> progress = const {},
}) {
  final caro = gameCode == 'CARO';
  return {
    'matchId': matchId,
    'gameCode': gameCode,
    'difficulty': difficulty,
    'mode': mode,
    'kind': caro ? 'TURN' : 'RACE',
    'seed': seed,
    'status': status,
    'startedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'you': you,
    'players': [
      {'userId': you, 'username': 'binh', 'fullName': 'Thái Bình', 'avatarUrl': null, 'rating': 1200, 'tier': 'BRONZE', 'tierName': 'Đồng', 'connected': true},
      {'userId': opponentId, 'username': 'an', 'fullName': 'Nguyễn An', 'avatarUrl': null, 'rating': 1180, 'tier': 'BRONZE', 'tierName': 'Đồng', 'connected': true},
    ],
    'caro': caro
        ? {
            'size': 15,
            'moves': [for (final m in moves) {'row': m[0], 'col': m[1], 'userId': m[2]}],
            'currentTurnUserId': currentTurnUserId,
            'turnDeadlineUtc': turnDeadlineUtc ?? DateTime.now().toUtc().add(const Duration(seconds: 30)).toIso8601String(),
            'drawOfferedBy': drawOfferedBy,
          }
        : null,
    'race': caro
        ? null
        : {
            'progress': [
              {'userId': you, 'percent': progress[you] ?? 0},
              {'userId': opponentId, 'percent': progress[opponentId] ?? 0},
            ],
            'deadlineUtc': DateTime.now().toUtc().add(const Duration(minutes: 15)).toIso8601String(),
          },
  };
}

MatchInfo matchInfo({
  String matchId = 'm1',
  String gameCode = 'CARO',
  int difficulty = 2,
  String mode = 'RANKED',
  int seed = 42,
  String status = 'ACTIVE',
  List<List<int>> moves = const [],
  int? currentTurnUserId = 7,
  int? drawOfferedBy,
  Map<int, int> progress = const {},
}) =>
    MatchInfo.parse([
      matchPayload(
        matchId: matchId,
        gameCode: gameCode,
        difficulty: difficulty,
        mode: mode,
        seed: seed,
        status: status,
        moves: moves,
        currentTurnUserId: currentTurnUserId,
        drawOfferedBy: drawOfferedBy,
        progress: progress,
      )
    ])!;
