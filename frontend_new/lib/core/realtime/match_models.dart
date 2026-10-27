// Model các sự kiện trận đấu của hub /hubs/game, đọc đúng theo payload trong
// backend/GameHub.Api/Services/MatchService.cs (SignalR JSON camelCase).
// Mọi hàm parse trả null khi payload sai dạng (không làm sập kết nối).

import '../models/rank.dart';
import '../network/models.dart';

const kGameCaro = 'CARO';
const kGamePuzzle = 'PUZZLE';
const kGameSudoku = 'SUDOKU';

/// Mã chat nhanh server chấp nhận (MatchService.QuickChatCodes).
const kQuickChatCodes = ['hello', 'nice', 'gg', 'rematch', 'oops', 'thanks'];

/// Nhãn hiển thị cho mã chat nhanh.
String quickChatLabel(String code) => switch (code) {
      'hello' => 'Xin chào 👋',
      'nice' => 'Hay đấy! 👍',
      'gg' => 'GG 🤝',
      'rematch' => 'Làm ván nữa? 🔁',
      'oops' => 'Ối! 😅',
      'thanks' => 'Cảm ơn 🙏',
      _ => code,
    };

Map<String, dynamic>? _map(Object? v) => v is Map ? v.cast<String, dynamic>() : null;
Object? _arg(List<Object?>? args, int i) => args != null && i < args.length ? args[i] : null;
int? _int(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
DateTime? _date(Object? v) => v is String ? parseServerDate(v) : null;

/// Một người chơi trong trận: `{userId, username, fullName, avatarUrl, rating, tier, tierName, connected}`.
class MatchPlayer {
  final int userId;
  final String username;
  final String? fullName;
  final int rating;
  final Tier tier;
  final bool connected;

  const MatchPlayer({
    required this.userId,
    required this.username,
    this.fullName,
    this.rating = Tier.startRating,
    this.tier = Tier.bronze,
    this.connected = true,
  });

  String get displayName =>
      (fullName != null && fullName!.trim().isNotEmpty) ? fullName!.trim() : username;

  UserSummary get summary => UserSummary(userId: userId, username: username, fullName: fullName);

  static MatchPlayer? parse(Object? v) {
    final m = _map(v);
    final id = _int(m?['userId']);
    if (m == null || id == null) return null;
    final rating = _int(m['rating']) ?? Tier.startRating;
    return MatchPlayer(
      userId: id,
      username: (m['username'] as String?) ?? '',
      fullName: m['fullName'] as String?,
      rating: rating,
      tier: Tier.tryParse(m['tier'] as String?) ?? Tier.fromRating(rating),
      connected: (m['connected'] as bool?) ?? true,
    );
  }
}

class CaroMoveInfo {
  final int row;
  final int col;
  final int userId;
  const CaroMoveInfo(this.row, this.col, this.userId);
}

/// `caro: {size, moves:[{row,col,userId}], currentTurnUserId, turnDeadlineUtc, drawOfferedBy}`.
class CaroState {
  final int size;
  final List<CaroMoveInfo> moves;
  final int? currentTurnUserId;
  final DateTime? turnDeadline;
  final int? drawOfferedBy;

  const CaroState({
    this.size = 15,
    this.moves = const [],
    this.currentTurnUserId,
    this.turnDeadline,
    this.drawOfferedBy,
  });

  static CaroState? parse(Object? v) {
    final m = _map(v);
    if (m == null) return null;
    return CaroState(
      size: _int(m['size']) ?? 15,
      moves: [
        for (final e in (m['moves'] as List? ?? const []))
          if (_map(e) case final x? when _int(x['row']) != null && _int(x['col']) != null)
            CaroMoveInfo(_int(x['row'])!, _int(x['col'])!, _int(x['userId']) ?? 0),
      ],
      currentTurnUserId: _int(m['currentTurnUserId']),
      turnDeadline: _date(m['turnDeadlineUtc']),
      drawOfferedBy: _int(m['drawOfferedBy']),
    );
  }
}

/// `race: {progress:[{userId, percent}], deadlineUtc}`.
class RaceState {
  final Map<int, int> progress;
  final DateTime? deadline;
  const RaceState({this.progress = const {}, this.deadline});

  static RaceState? parse(Object? v) {
    final m = _map(v);
    if (m == null) return null;
    return RaceState(
      progress: {
        for (final e in (m['progress'] as List? ?? const []))
          if (_map(e) case final x? when _int(x['userId']) != null)
            _int(x['userId'])!: _int(x['percent']) ?? 0,
      },
      deadline: _date(m['deadlineUtc']),
    );
  }
}

class CoopMoveInfo {
  final int row;
  final int col;
  final int value;
  final int userId;
  final bool isMistake;

  const CoopMoveInfo({
    required this.row,
    required this.col,
    required this.value,
    required this.userId,
    required this.isMistake,
  });
}

/// `coop: {mistakes, maxMistakes, currentTurnUserId, moves:[...]}`.
class CoopState {
  final int mistakes;
  final int maxMistakes;
  final int? currentTurnUserId;
  final List<CoopMoveInfo> moves;

  const CoopState({
    this.mistakes = 0,
    this.maxMistakes = 3,
    this.currentTurnUserId,
    this.moves = const [],
  });

  static CoopState? parse(Object? v) {
    final m = _map(v);
    if (m == null) return null;
    final rawMoves = m['moves'] as List? ?? const [];
    return CoopState(
      mistakes: _int(m['mistakes']) ?? 0,
      maxMistakes: _int(m['maxMistakes']) ?? 3,
      currentTurnUserId: _int(m['currentTurnUserId']),
      moves: [
        for (final e in rawMoves)
          if (_map(e) case final x? when _int(x['row']) != null && _int(x['col']) != null)
            CoopMoveInfo(
              row: _int(x['row'])!,
              col: _int(x['col'])!,
              value: _int(x['value']) ?? 0,
              userId: _int(x['userId']) ?? 0,
              isMistake: (x['isMistake'] as bool?) ?? false,
            ),
      ],
    );
  }
}

/// Payload `MatchStarted` / `MatchState`.
class MatchInfo {
  final String matchId;
  final String gameCode;
  final int difficulty;
  final bool ranked;
  final bool isTurn;
  final String kind;
  final int seed;
  final bool active;
  final DateTime? startedAt;
  final int you;
  final List<MatchPlayer> players;
  final CaroState? caro;
  final RaceState? race;
  final CoopState? coop;

  const MatchInfo({
    required this.matchId,
    required this.gameCode,
    required this.difficulty,
    required this.ranked,
    required this.isTurn,
    this.kind = '',
    required this.seed,
    required this.active,
    required this.you,
    required this.players,
    this.startedAt,
    this.caro,
    this.race,
    this.coop,
  });

  bool get isCoop => kind == 'COOP' || (gameCode == kGameSudoku && !ranked);

  MatchPlayer? get me => _player(you);
  MatchPlayer? get opponent {
    for (final p in players) {
      if (p.userId != you) return p;
    }
    return null;
  }

  MatchPlayer? _player(int id) {
    for (final p in players) {
      if (p.userId == id) return p;
    }
    return null;
  }

  bool get isMyTurn => caro?.currentTurnUserId == you;

  static MatchInfo? parse(List<Object?>? args) {
    final m = _map(_arg(args, 0));
    final id = m?['matchId'];
    if (m == null || id is! String) return null;
    return MatchInfo(
      matchId: id,
      gameCode: (m['gameCode'] as String?) ?? '',
      difficulty: _int(m['difficulty']) ?? 1,
      ranked: (m['mode'] as String?) == 'RANKED',
      isTurn: (m['kind'] as String?) == 'TURN',
      kind: (m['kind'] as String?) ?? '',
      seed: _int(m['seed']) ?? 0,
      active: (m['status'] as String?) != 'ENDED',
      startedAt: _date(m['startedAtUtc']),
      you: _int(m['you']) ?? 0,
      players: [
        for (final p in (m['players'] as List? ?? const [])) ?MatchPlayer.parse(p),
      ],
      caro: CaroState.parse(m['caro']),
      race: RaceState.parse(m['race']),
      coop: CoopState.parse(m['coop']),
    );
  }
}

/// `QueueStatus(inQueue, waitedSec, ratingRange)` — tham số rời.
class QueueStatusEvent {
  final bool inQueue;
  final int waitedSec;

  /// 0 = không giới hạn chênh lệch rating.
  final int ratingRange;
  const QueueStatusEvent(this.inQueue, this.waitedSec, this.ratingRange);

  static QueueStatusEvent? parse(List<Object?>? args) {
    final q = _arg(args, 0);
    if (q is! bool) return null;
    return QueueStatusEvent(q, _int(_arg(args, 1)) ?? 0, _int(_arg(args, 2)) ?? 0);
  }
}

/// `InviteReceived({inviteId, from:{userId,username,fullName,avatarUrl}, gameCode, difficulty, expiresAtUtc, expiresInSec})`.
class InviteReceivedEvent {
  final String inviteId;
  final UserSummary from;
  final String gameCode;
  final int difficulty;
  final int expiresInSec;
  final DateTime receivedAt;

  InviteReceivedEvent({
    required this.inviteId,
    required this.from,
    required this.gameCode,
    required this.difficulty,
    required this.expiresInSec,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  /// Hạn theo đồng hồ máy (tránh lệch giờ giữa máy và server).
  DateTime get expiresAt => receivedAt.add(Duration(seconds: expiresInSec));

  static InviteReceivedEvent? parse(List<Object?>? args) {
    final m = _map(_arg(args, 0));
    final f = _map(m?['from']);
    final id = m?['inviteId'];
    final fromId = _int(f?['userId']);
    if (m == null || f == null || id is! String || fromId == null) return null;
    return InviteReceivedEvent(
      inviteId: id,
      from: UserSummary(
        userId: fromId,
        username: (f['username'] as String?) ?? '',
        fullName: f['fullName'] as String?,
      ),
      gameCode: (m['gameCode'] as String?) ?? '',
      difficulty: _int(m['difficulty']) ?? 1,
      expiresInSec: _int(m['expiresInSec']) ?? 30,
    );
  }
}

enum InviteStatus { accepted, declined, expired }

/// `InviteResult({inviteId, status, userId, gameCode, difficulty, matchId})`.
/// Người mời nhận khi được chấp nhận / từ chối / hết hạn; người được mời nhận
/// `expired` khi lời mời bị hủy hoặc hết hạn.
class InviteResultEvent {
  final String inviteId;
  final InviteStatus status;
  final String? matchId;
  const InviteResultEvent(this.inviteId, this.status, this.matchId);

  static InviteResultEvent? parse(List<Object?>? args) {
    final m = _map(_arg(args, 0));
    final id = m?['inviteId'];
    if (m == null || id is! String) return null;
    final status = switch (m['status']) {
      'accepted' => InviteStatus.accepted,
      'declined' => InviteStatus.declined,
      _ => InviteStatus.expired,
    };
    return InviteResultEvent(id, status, m['matchId'] as String?);
  }
}

/// `OpponentProgress({matchId, userId, percent})`.
class OpponentProgressEvent {
  final String matchId;
  final int userId;
  final int percent;
  const OpponentProgressEvent(this.matchId, this.userId, this.percent);

  static OpponentProgressEvent? parse(List<Object?>? args) {
    final m = _map(_arg(args, 0));
    final id = m?['matchId'];
    if (m == null || id is! String) return null;
    return OpponentProgressEvent(id, _int(m['userId']) ?? 0, _int(m['percent']) ?? 0);
  }
}

/// `OpponentConnection(connected, graceSeconds)` — tham số rời.
class OpponentConnectionEvent {
  final bool connected;
  final int graceSeconds;
  const OpponentConnectionEvent(this.connected, this.graceSeconds);

  static OpponentConnectionEvent? parse(List<Object?>? args) {
    final c = _arg(args, 0);
    if (c is! bool) return null;
    return OpponentConnectionEvent(c, _int(_arg(args, 1)) ?? 0);
  }
}

/// `DrawOffered({matchId, fromUserId})`, `RematchRequested({matchId, fromUserId})`,
/// `QuickChat({matchId, fromUserId, code})`.
class MatchSignalEvent {
  final String matchId;
  final int fromUserId;
  final String? code;
  const MatchSignalEvent(this.matchId, this.fromUserId, [this.code]);

  static MatchSignalEvent? parse(List<Object?>? args) {
    final m = _map(_arg(args, 0));
    final id = m?['matchId'];
    if (m == null || id is! String) return null;
    return MatchSignalEvent(id, _int(m['fromUserId']) ?? 0, m['code'] as String?);
  }
}

/// `DrawResponded({matchId, accepted, byUserId})`.
class DrawRespondedEvent {
  final String matchId;
  final bool accepted;
  final int byUserId;
  const DrawRespondedEvent(this.matchId, this.accepted, this.byUserId);

  static DrawRespondedEvent? parse(List<Object?>? args) {
    final m = _map(_arg(args, 0));
    final id = m?['matchId'];
    if (m == null || id is! String) return null;
    return DrawRespondedEvent(id, (m['accepted'] as bool?) ?? false, _int(m['byUserId']) ?? 0);
  }
}

class RatingChange {
  final int userId;
  final int before;
  final int after;
  const RatingChange(this.userId, this.before, this.after);
  int get delta => after - before;
}

/// `MatchEnded({matchId, winnerId, reason, mode, ratingChanges:[{userId,before,after}], results:[{userId,result,score}]})`.
/// reason: WIN | DRAW | RESIGN | TIMEOUT | ABANDON | TIME_LIMIT | SERVER_RESTART.
class MatchEndedEvent {
  final String matchId;
  final int? winnerId;
  final String reason;
  final bool ranked;
  final Map<int, RatingChange> ratingChanges;
  final Map<int, int> scores;

  const MatchEndedEvent({
    required this.matchId,
    required this.winnerId,
    required this.reason,
    required this.ranked,
    this.ratingChanges = const {},
    this.scores = const {},
  });

  bool get isDraw => winnerId == null;

  static MatchEndedEvent? parse(List<Object?>? args) {
    final m = _map(_arg(args, 0));
    final id = m?['matchId'];
    if (m == null || id is! String) return null;
    return MatchEndedEvent(
      matchId: id,
      winnerId: _int(m['winnerId']),
      reason: (m['reason'] as String?) ?? '',
      ranked: (m['mode'] as String?) == 'RANKED',
      ratingChanges: {
        for (final e in (m['ratingChanges'] as List? ?? const []))
          if (_map(e) case final x? when _int(x['userId']) != null)
            _int(x['userId'])!: RatingChange(
                _int(x['userId'])!, _int(x['before']) ?? 0, _int(x['after']) ?? 0),
      },
      scores: {
        for (final e in (m['results'] as List? ?? const []))
          if (_map(e) case final x? when _int(x['userId']) != null)
            _int(x['userId'])!: _int(x['score']) ?? 0,
      },
    );
  }
}

/// Lý do kết thúc trận bằng tiếng Việt (theo góc nhìn của mình).
String matchEndReasonVi(MatchEndedEvent e, int me) {
  final iWon = e.winnerId == me;
  return switch (e.reason) {
    'WIN' => iWon ? 'Bạn đã chiến thắng' : 'Đối thủ đã chiến thắng',
    'DRAW' => 'Hai bên hòa',
    'COOP_WIN' => 'Chúc mừng! Hai bạn đã cùng giải xong câu đố Sudoku 🎉',
    'MISTAKES_LIMIT' => 'Đã hết 3 lượt lỗi cho phép',
    'RESIGN' => iWon ? 'Đối thủ đầu hàng' : 'Bạn đã đầu hàng',
    'TIMEOUT' => iWon ? 'Đối thủ hết thời gian suy nghĩ' : 'Bạn hết thời gian suy nghĩ',
    'ABANDON' => iWon ? 'Đối thủ rời trận' : 'Bạn mất kết nối quá lâu',
    'TIME_LIMIT' => 'Hết giờ trận đấu',
    'SERVER_RESTART' => 'Trận bị hủy do máy chủ khởi động lại',
    _ => '',
  };
}

class SudokuMoveEvent {
  final String matchId;
  final int row;
  final int col;
  final int value;
  final int byUserId;
  final bool isMistake;
  final int mistakes;
  final int movesCount;
  final int? nextTurnUserId;

  const SudokuMoveEvent({
    required this.matchId,
    required this.row,
    required this.col,
    required this.value,
    required this.byUserId,
    required this.isMistake,
    required this.mistakes,
    required this.movesCount,
    this.nextTurnUserId,
  });

  static SudokuMoveEvent? parse(List<Object?>? args) {
    final m = _map(_arg(args, 0));
    final id = m?['matchId'];
    if (m == null || id is! String) return null;
    return SudokuMoveEvent(
      matchId: id,
      row: _int(m['row']) ?? 0,
      col: _int(m['col']) ?? 0,
      value: _int(m['value']) ?? 0,
      byUserId: _int(m['byUserId']) ?? 0,
      isMistake: (m['isMistake'] as bool?) ?? false,
      mistakes: _int(m['mistakes']) ?? 0,
      movesCount: _int(m['movesCount']) ?? 0,
      nextTurnUserId: _int(m['nextTurnUserId']),
    );
  }
}

class SudokuCursorEvent {
  final String matchId;
  final int userId;
  final int row;
  final int col;

  const SudokuCursorEvent({
    required this.matchId,
    required this.userId,
    required this.row,
    required this.col,
  });

  static SudokuCursorEvent? parse(List<Object?>? args) {
    final m = _map(_arg(args, 0));
    final id = m?['matchId'];
    if (m == null || id is! String) return null;
    return SudokuCursorEvent(
      matchId: id,
      userId: _int(m['userId']) ?? 0,
      row: _int(m['row']) ?? 0,
      col: _int(m['col']) ?? 0,
    );
  }
}
