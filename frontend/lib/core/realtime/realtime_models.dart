// Mô hình dữ liệu cho các sự kiện server -> client của SignalR hub `/hubs/game`
// (TASKS_V2 §3). TOÀN BỘ phần đọc JSON nằm trong file này để dễ chỉnh khi
// hợp đồng với backend thay đổi.
//
// Quy ước đọc:
// - Tham số của hub method đến dưới dạng danh sách `args`. Mỗi sự kiện chấp nhận
//   cả dạng MỘT object (map) lẫn dạng tham số rời theo thứ tự trong §3.
// - Tên trường camelCase; chấp nhận một số tên thay thế (xem từng `fromJson`).
// - Mọi trường đều có thể thiếu/null: giá trị mặc định an toàn, không ném lỗi.
import '../models/presence.dart';
import '../models/rank.dart';
import '../network/models.dart';

// ------------------------------------------------------------ helpers

Map<String, dynamic>? asMap(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : null;

int? asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? asDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

String? asString(Object? v) => v?.toString();

bool? asBool(Object? v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase();
    if (s == 'true') return true;
    if (s == 'false') return false;
  }
  return null;
}

DateTime? asDate(Object? v) => v is String ? parseServerDate(v) : null;

/// Lấy trường đầu tiên có giá trị trong [keys].
Object? pick(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v != null) return v;
  }
  return null;
}

/// Phần tử [i] của [args] (null nếu không có).
Object? _arg(List<Object?>? args, int i) =>
    args != null && i < args.length ? args[i] : null;

/// Map payload của sự kiện: args[0] nếu là object, ngược lại rỗng.
Map<String, dynamic> _payload(List<Object?>? args) =>
    asMap(_arg(args, 0)) ?? const {};

// ------------------------------------------------------------ người chơi

/// Người chơi nhúng trong sự kiện (đối thủ, người mời, người gửi...).
class RtUser {
  final int userId;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final int? rating;
  final Tier? tier;

  /// Chỉ có trong `MatchInfo.players`: đang kết nối hub hay không.
  final bool? connected;

  const RtUser({
    required this.userId,
    this.username = '',
    this.fullName,
    this.avatarUrl,
    this.rating,
    this.tier,
    this.connected,
  });

  String get displayName => (fullName != null && fullName!.trim().isNotEmpty)
      ? fullName!.trim()
      : (username.isEmpty ? 'Người chơi' : username);

  UserSummary get summary => UserSummary(
        userId: userId,
        username: username,
        fullName: fullName,
        avatarUrl: avatarUrl,
      );

  /// Đọc từ map: `userId|id`, `username|userName`, `fullName|displayName|name`.
  static RtUser? tryParse(Object? v) {
    final m = asMap(v);
    if (m == null) return null;
    final id = asInt(pick(m, ['userId', 'id']));
    if (id == null) return null;
    final rating = asInt(m['rating']);
    return RtUser(
      userId: id,
      username: asString(pick(m, ['username', 'userName'])) ?? '',
      fullName: asString(pick(m, ['fullName', 'displayName', 'name'])),
      avatarUrl: asString(m['avatarUrl']),
      connected: asBool(m['connected']),
      rating: rating,
      tier: Tier.tryParse(asString(m['tier'])) ??
          (rating == null ? null : Tier.fromRating(rating)),
    );
  }

  /// Đọc người chơi nằm phẳng trong [m] với tiền tố, vd prefix 'from' đọc
  /// `fromUserId`, `fromUsername`, `fromFullName`.
  static RtUser? fromFlat(Map<String, dynamic> m, String prefix) {
    String k(String s) => '$prefix${s[0].toUpperCase()}${s.substring(1)}';
    final id = asInt(m[k('userId')]) ?? asInt(m['${prefix}Id']);
    if (id == null) return null;
    return RtUser(
      userId: id,
      username: asString(m[k('username')]) ?? '',
      fullName: asString(m[k('fullName')]) ?? asString(m[k('name')]),
      avatarUrl: asString(m[k('avatarUrl')]),
    );
  }
}

// ------------------------------------------------------------ sự kiện

/// `Presence(userId, status)` hoặc `Presence({userId, status, lastSeenAt})`.
class PresenceEvent {
  final int userId;
  final PresenceStatus status;
  final DateTime? lastSeenAt;
  const PresenceEvent(
      {required this.userId, required this.status, this.lastSeenAt});

  static PresenceEvent? parse(List<Object?>? args) {
    final m = asMap(_arg(args, 0));
    if (m != null) {
      final id = asInt(pick(m, ['userId', 'id']));
      if (id == null) return null;
      return PresenceEvent(
        userId: id,
        status: PresenceStatus.parse(pick(m, ['status', 'state'])),
        lastSeenAt: asDate(pick(m, ['lastSeenAt', 'lastSeen'])),
      );
    }
    final id = asInt(_arg(args, 0));
    if (id == null) return null;
    return PresenceEvent(
      userId: id,
      status: PresenceStatus.parse(_arg(args, 1)),
      lastSeenAt: asDate(_arg(args, 2)),
    );
  }
}

/// `FriendRequest({requestId|id|friendshipId, from:{userId,...} | fromUserId..., createdAt})`
class FriendRequestEvent {
  final int requestId;
  final RtUser from;
  final DateTime? createdAt;
  const FriendRequestEvent(
      {required this.requestId, required this.from, this.createdAt});

  static FriendRequestEvent? parse(List<Object?>? args) {
    final m = _payload(args);
    final from = RtUser.tryParse(pick(m, ['from', 'user', 'requester'])) ??
        RtUser.fromFlat(m, 'from') ??
        RtUser.fromFlat(m, 'requester') ??
        RtUser.tryParse(m);
    if (from == null) return null;
    return FriendRequestEvent(
      requestId: asInt(pick(m, ['requestId', 'friendshipId', 'id'])) ?? 0,
      from: from,
      createdAt: asDate(m['createdAt']),
    );
  }
}

/// `FriendAccepted({user:{...} | userId...})` — người kia đã chấp nhận lời mời của mình.
class FriendAcceptedEvent {
  final RtUser user;
  const FriendAcceptedEvent({required this.user});

  static FriendAcceptedEvent? parse(List<Object?>? args) {
    final m = _payload(args);
    final user = RtUser.tryParse(pick(m, ['user', 'friend', 'by', 'addressee'])) ??
        RtUser.fromFlat(m, 'user') ??
        RtUser.tryParse(m);
    return user == null ? null : FriendAcceptedEvent(user: user);
  }
}

/// `MessageReceived({messageId, senderId, receiverId, content, sentAt, isRead,
/// sender?:{...}})`; cũng chấp nhận bọc trong `message`.
class MessageReceivedEvent {
  final ChatMessage message;

  /// Người gửi (để hiện tên trên banner); null nếu server không kèm.
  final RtUser? sender;
  const MessageReceivedEvent({required this.message, this.sender});

  static MessageReceivedEvent? parse(List<Object?>? args) {
    var m = _payload(args);
    final inner = asMap(m['message']);
    final sender = RtUser.tryParse(m['sender']) ??
        RtUser.fromFlat(m, 'sender') ??
        RtUser.tryParse(m['from']);
    if (inner != null) m = inner;
    final id = asInt(pick(m, ['messageId', 'id']));
    final from = asInt(m['senderId']);
    final to = asInt(m['receiverId']);
    final content = asString(m['content']);
    if (id == null || from == null || to == null || content == null) {
      return null;
    }
    return MessageReceivedEvent(
      message: ChatMessage(
        messageId: id,
        senderId: from,
        receiverId: to,
        content: content,
        isRead: asBool(m['isRead']) ?? false,
        sentAt: m['sentAt'] == null
            ? DateTime.now()
            : parseServerDate(m['sentAt']),
      ),
      sender: sender,
    );
  }
}

/// Lời mời đấu giao hữu hiệu lực 30 giây.
class InviteReceivedEvent {
  /// int hoặc String — giữ nguyên kiểu để gửi lại cho `RespondInvite`.
  final String inviteId;
  final RtUser from;
  final String gameCode;
  final int difficulty;
  final DateTime receivedAt;

  /// Thời hạn tuyệt đối (nếu server gửi `expiresAt`).
  final DateTime? expiresAt;

  /// Số giây còn lại lúc nhận (`expiresInSec|ttlSec|remainingSec`; server gửi cả `expiresAtUtc`), mặc định 30.
  final int ttlSec;

  const InviteReceivedEvent({
    required this.inviteId,
    required this.from,
    required this.gameCode,
    required this.difficulty,
    required this.receivedAt,
    this.expiresAt,
    this.ttlSec = 30,
  });

  /// Giây còn lại tại thời điểm [now].
  int remainingSec(DateTime now) {
    final end = expiresAt ?? receivedAt.add(Duration(seconds: ttlSec));
    final s = end.difference(now).inMilliseconds / 1000;
    return s <= 0 ? 0 : s.ceil();
  }

  Duration get totalDuration => Duration(seconds: ttlSec);

  static InviteReceivedEvent? parse(List<Object?>? args, {DateTime? now}) {
    final m = _payload(args);
    final rawId = pick(m, ['inviteId', 'id']);
    final from = RtUser.tryParse(pick(m, ['from', 'inviter', 'sender'])) ??
        RtUser.fromFlat(m, 'from') ??
        RtUser.fromFlat(m, 'inviter');
    if (rawId == null || from == null) return null;
    final received = now ?? DateTime.now();
    final expires = asDate(pick(m, ['expiresAtUtc', 'expiresAt']));
    final ttlRaw = asInt(pick(m, ['expiresInSec', 'ttlSec', 'remainingSec']));
    final ttl = ttlRaw ??
        (expires == null
            ? 30
            : (expires.difference(received).inSeconds).clamp(1, 600));
    return InviteReceivedEvent(
      inviteId: rawId.toString(),
      from: from,
      gameCode: asString(m['gameCode']) ?? 'CARO',
      difficulty: asInt(m['difficulty']) ?? 2,
      receivedAt: received,
      // Ưu tiên số giây còn lại (không phụ thuộc lệch đồng hồ máy)
      expiresAt: ttlRaw == null ? expires : null,
      ttlSec: ttl,
    );
  }
}

enum InviteOutcome { accepted, declined, expired, cancelled }

/// `InviteResult({inviteId, status|result: ACCEPTED|DECLINED|EXPIRED|CANCELLED | accepted: bool,
/// matchId?, by?:{...}})` — kết quả lời mời MÌNH đã gửi.
class InviteResultEvent {
  final String? inviteId;
  final InviteOutcome outcome;
  final String? matchId;
  final String? message;
  const InviteResultEvent({
    required this.inviteId,
    required this.outcome,
    this.matchId,
    this.message,
  });

  static InviteResultEvent? parse(List<Object?>? args) {
    final m = _payload(args);
    if (m.isEmpty) return null;
    final accepted = asBool(m['accepted']);
    final s = (asString(pick(m, ['status', 'result', 'outcome'])) ?? '')
        .toLowerCase();
    final outcome = accepted == true || s.startsWith('accept')
        ? InviteOutcome.accepted
        : s.startsWith('expire') || s.contains('timeout')
            ? InviteOutcome.expired
            : s.startsWith('cancel')
                ? InviteOutcome.cancelled
                : InviteOutcome.declined;
    return InviteResultEvent(
      inviteId: asString(pick(m, ['inviteId', 'id'])),
      outcome: outcome,
      matchId: asString(m['matchId']),
      message: asString(m['message']),
    );
  }
}

/// `QueueStatus(searching, waitedSec, range)` hoặc một object cùng tên trường.
class QueueStatusEvent {
  final bool searching;
  final int waitedSec;

  /// Khoảng rating đang cho phép (±range); null = không giới hạn / không rõ.
  final int? range;
  const QueueStatusEvent(
      {required this.searching, this.waitedSec = 0, this.range});

  static QueueStatusEvent? parse(List<Object?>? args) {
    final m = asMap(_arg(args, 0));
    if (m != null) {
      return QueueStatusEvent(
        searching: asBool(m['searching']) ?? true,
        waitedSec: asInt(pick(m, ['waitedSec', 'waited'])) ?? 0,
        range: asInt(pick(m, ['range', 'ratingRange'])),
      );
    }
    final searching = asBool(_arg(args, 0));
    if (searching == null) return null;
    return QueueStatusEvent(
      searching: searching,
      waitedSec: asInt(_arg(args, 1)) ?? 0,
      range: asInt(_arg(args, 2)),
    );
  }
}

/// Một nước Caro: [player] 1 hoặc 2 (hoặc theo userId nếu có).
class CaroMoveInfo {
  final int row;
  final int col;
  final int? userId;
  final int? player;
  const CaroMoveInfo(
      {required this.row, required this.col, this.userId, this.player});

  static CaroMoveInfo? tryParse(Object? v) {
    final m = asMap(v);
    if (m == null) return null;
    final r = asInt(m['row']);
    final c = asInt(m['col']);
    if (r == null || c == null) return null;
    return CaroMoveInfo(
      row: r,
      col: c,
      userId: asInt(m['userId']),
      player: asInt(pick(m, ['player', 'mark', 'side'])),
    );
  }
}

enum MatchMode { ranked, friendly }

enum MatchKind { turn, race }

/// Trạng thái ván Caro (trong `MatchStarted/MatchState.caro`).
/// Sau mỗi nước đi server gửi lại TOÀN BỘ `MatchState` (không có sự kiện nước đi riêng).
class CaroState {
  final int size;
  final List<CaroMoveInfo> moves;

  /// null khi ván đã kết thúc.
  final int? currentTurnUserId;
  final DateTime? turnDeadline;

  /// userId người đang xin hòa (null nếu không có lời xin hòa).
  final int? drawOfferedBy;

  const CaroState({
    this.size = 15,
    this.moves = const [],
    this.currentTurnUserId,
    this.turnDeadline,
    this.drawOfferedBy,
  });

  static CaroState? tryParse(Object? v) {
    final m = asMap(v);
    if (m == null) return null;
    return CaroState(
      size: asInt(m['size']) ?? 15,
      moves: [
        for (final e in (m['moves'] as List? ?? const []))
          if (CaroMoveInfo.tryParse(e) != null) CaroMoveInfo.tryParse(e)!,
      ],
      currentTurnUserId: asInt(m['currentTurnUserId']),
      turnDeadline: asDate(m['turnDeadlineUtc']),
      drawOfferedBy: asInt(m['drawOfferedBy']),
    );
  }
}

/// Trạng thái trò đua (trong `MatchStarted/MatchState.race`).
class RaceState {
  /// userId -> phần trăm 0..100.
  final Map<int, double> progress;
  final DateTime? deadline;
  const RaceState({this.progress = const {}, this.deadline});

  static RaceState? tryParse(Object? v) {
    final m = asMap(v);
    if (m == null) return null;
    final p = <int, double>{};
    for (final e in (m['progress'] as List? ?? const [])) {
      final em = asMap(e);
      final id = asInt(em?['userId']);
      final pct = asDouble(em?['percent']);
      if (id != null && pct != null) p[id] = pct;
    }
    return RaceState(progress: p, deadline: asDate(m['deadlineUtc']));
  }
}

/// `MatchStarted(match)` / `MatchState(match)` — cùng một cấu trúc:
/// `{matchId, gameCode, difficulty, mode RANKED|FRIENDLY, kind TURN|RACE, seed, status,
/// startedAtUtc, you (userId của người nhận), players:[{userId,username,fullName,avatarUrl,
/// rating,tier,tierName,connected}], caro:{...}|null, race:{...}|null}`.
/// Toàn bộ payload gốc giữ trong [raw].
class MatchInfo {
  final String matchId;
  final String gameCode;
  final int difficulty;
  final MatchMode mode;
  final MatchKind kind;
  final int? seed;
  final String? status;
  final DateTime? startedAt;

  /// userId của người nhận sự kiện.
  final int? youId;
  final List<RtUser> players;
  final CaroState? caro;
  final RaceState? race;
  final Map<String, dynamic> raw;

  const MatchInfo({
    required this.matchId,
    required this.gameCode,
    this.difficulty = 2,
    this.mode = MatchMode.ranked,
    this.kind = MatchKind.turn,
    this.seed,
    this.status,
    this.startedAt,
    this.youId,
    this.players = const [],
    this.caro,
    this.race,
    this.raw = const {},
  });

  RtUser? get you {
    for (final p in players) {
      if (p.userId == youId) return p;
    }
    return null;
  }

  RtUser? get opponent {
    for (final p in players) {
      if (p.userId != youId) return p;
    }
    return null;
  }

  /// Nước đi Caro (rỗng nếu không phải Caro).
  List<CaroMoveInfo> get moves => caro?.moves ?? const [];

  static MatchInfo? parse(List<Object?>? args) {
    var m = _payload(args);
    final inner = asMap(m['match']);
    if (inner != null) m = {...m, ...inner};
    final id = asString(pick(m, ['matchId', 'id']));
    if (id == null) return null;
    final game = asString(m['gameCode']) ?? '';
    final kindStr = (asString(m['kind']) ?? '').toUpperCase();
    final modeStr = (asString(m['mode']) ?? '').toUpperCase();
    final youRaw = m['you'];
    return MatchInfo(
      matchId: id,
      gameCode: game,
      difficulty: asInt(m['difficulty']) ?? 2,
      mode: modeStr == 'FRIENDLY' ? MatchMode.friendly : MatchMode.ranked,
      kind: kindStr == 'RACE' || (kindStr.isEmpty && game != 'CARO')
          ? MatchKind.race
          : MatchKind.turn,
      seed: asInt(m['seed']),
      status: asString(m['status']),
      startedAt: asDate(m['startedAtUtc']),
      youId: asInt(youRaw) ?? asInt(asMap(youRaw)?['userId']),
      players: [
        for (final e in (m['players'] as List? ?? const []))
          if (RtUser.tryParse(e) != null) RtUser.tryParse(e)!,
      ],
      caro: CaroState.tryParse(m['caro']),
      race: RaceState.tryParse(m['race']),
      raw: m,
    );
  }
}

/// `DrawOffered({matchId, fromUserId})` — đối thủ xin hòa.
class DrawOfferedEvent {
  final String matchId;
  final int fromUserId;
  const DrawOfferedEvent({required this.matchId, required this.fromUserId});

  static DrawOfferedEvent? parse(List<Object?>? args) {
    final m = _payload(args);
    final id = asString(m['matchId']);
    final from = asInt(m['fromUserId']);
    return id == null || from == null
        ? null
        : DrawOfferedEvent(matchId: id, fromUserId: from);
  }
}

/// `DrawResponded({matchId, accepted, byUserId})` — kết quả lời xin hòa của mình
/// (server chỉ gửi khi bị từ chối; chấp nhận thì kết thúc bằng `MatchEnded` reason DRAW).
class DrawRespondedEvent {
  final String matchId;
  final bool accepted;
  final int byUserId;
  const DrawRespondedEvent(
      {required this.matchId, required this.accepted, required this.byUserId});

  static DrawRespondedEvent? parse(List<Object?>? args) {
    final m = _payload(args);
    final id = asString(m['matchId']);
    final by = asInt(m['byUserId']);
    return id == null || by == null
        ? null
        : DrawRespondedEvent(
            matchId: id, accepted: asBool(m['accepted']) ?? false, byUserId: by);
  }
}

/// `RematchRequested({matchId, fromUserId})` — đối thủ muốn tái đấu (matchId là trận CŨ).
class RematchRequestedEvent {
  final String matchId;
  final int fromUserId;
  const RematchRequestedEvent(
      {required this.matchId, required this.fromUserId});

  static RematchRequestedEvent? parse(List<Object?>? args) {
    final m = _payload(args);
    final id = asString(m['matchId']);
    final from = asInt(m['fromUserId']);
    return id == null || from == null
        ? null
        : RematchRequestedEvent(matchId: id, fromUserId: from);
  }
}

/// `OpponentProgress({matchId, percent})` hoặc `(matchId, percent)`. percent 0..100.
class OpponentProgressEvent {
  final String matchId;
  final double percent;
  const OpponentProgressEvent({required this.matchId, required this.percent});

  static OpponentProgressEvent? parse(List<Object?>? args) {
    final m = asMap(_arg(args, 0));
    final id = asString(m != null ? pick(m, ['matchId', 'id']) : _arg(args, 0));
    final p = asDouble(m != null ? pick(m, ['percent', 'progress']) : _arg(args, 1));
    if (id == null || p == null) return null;
    return OpponentProgressEvent(
        matchId: id, percent: p.clamp(0, 100).toDouble());
  }
}

/// `QuickChat({matchId, fromUserId, code})` hoặc `(matchId, fromUserId, code)`.
class QuickChatEvent {
  final String matchId;
  final int fromUserId;
  final String code;
  const QuickChatEvent(
      {required this.matchId, required this.fromUserId, required this.code});

  static QuickChatEvent? parse(List<Object?>? args) {
    final m = asMap(_arg(args, 0));
    final id = asString(m != null ? m['matchId'] : _arg(args, 0));
    final from = asInt(m != null
        ? pick(m, ['fromUserId', 'userId', 'senderId'])
        : _arg(args, 1));
    final code = asString(m != null ? m['code'] : _arg(args, 2));
    if (id == null || from == null || code == null) return null;
    return QuickChatEvent(matchId: id, fromUserId: from, code: code);
  }
}

/// `OpponentConnection({matchId?, connected, graceSec})` hoặc `(connected, graceSec)`.
class OpponentConnectionEvent {
  final String? matchId;
  final bool connected;
  final int graceSec;
  const OpponentConnectionEvent(
      {this.matchId, required this.connected, this.graceSec = 30});

  static OpponentConnectionEvent? parse(List<Object?>? args) {
    final m = asMap(_arg(args, 0));
    if (m != null) {
      final c = asBool(m['connected']);
      if (c == null) return null;
      return OpponentConnectionEvent(
        matchId: asString(m['matchId']),
        connected: c,
        graceSec: asInt(m['graceSec']) ?? 30,
      );
    }
    final c = asBool(_arg(args, 0));
    if (c == null) return null;
    return OpponentConnectionEvent(
        connected: c, graceSec: asInt(_arg(args, 1)) ?? 30);
  }
}

/// Thay đổi rating của một người sau trận.
class RatingChange {
  final int userId;
  final int before;
  final int after;
  const RatingChange(
      {required this.userId, required this.before, required this.after});
  int get delta => after - before;
}

/// `MatchEnded({matchId, winnerId?, reason, ratingChanges:[{userId,before,after,delta?}]})`.
/// `ratingChanges` cũng có thể là map `{ "<userId>": {before, after} }`.
/// `winnerId` null/0 = hòa (hoặc trận bị hủy: reason = "CANCELLED"/"SERVER_RESTART").
class MatchEndedEvent {
  final String matchId;
  final int? winnerId;
  final String reason;
  final Map<int, RatingChange> ratingChanges;

  /// userId -> kết quả server tính (`results:[{userId,result,score}]`).
  final Map<int, String> results;
  final String? mode;
  final Map<String, dynamic> raw;
  const MatchEndedEvent({
    required this.matchId,
    this.winnerId,
    this.reason = '',
    this.ratingChanges = const {},
    this.results = const {},
    this.mode,
    this.raw = const {},
  });

  bool get isDraw => winnerId == null;

  static MatchEndedEvent? parse(List<Object?>? args) {
    var m = _payload(args);
    final inner = asMap(m['result']);
    if (inner != null) m = {...m, ...inner};
    final id = asString(pick(m, ['matchId', 'id']));
    if (id == null) return null;
    final changes = <int, RatingChange>{};
    void add(int? uid, Map<String, dynamic> c) {
      final id = uid ?? asInt(c['userId']);
      final before = asInt(pick(c, ['before', 'ratingBefore', 'old']));
      var after = asInt(pick(c, ['after', 'ratingAfter', 'new']));
      final delta = asInt(c['delta']);
      if (id == null || before == null) return;
      after ??= delta == null ? null : before + delta;
      if (after == null) return;
      changes[id] = RatingChange(userId: id, before: before, after: after);
    }

    final rc = m['ratingChanges'];
    if (rc is List) {
      for (final e in rc) {
        final c = asMap(e);
        if (c != null) add(null, c);
      }
    } else if (rc is Map) {
      rc.forEach((k, v) {
        final c = asMap(v);
        if (c != null) add(asInt(k), c);
      });
    }
    final winner = asInt(pick(m, ['winnerId', 'winner']));
    return MatchEndedEvent(
      matchId: id,
      winnerId: (winner == null || winner <= 0) ? null : winner,
      reason: asString(m['reason']) ?? '',
      ratingChanges: changes,
      results: {
        for (final e in (m['results'] as List? ?? const []))
          if (asInt(asMap(e)?['userId']) != null)
            asInt(asMap(e)!['userId'])!:
                asString(asMap(e)!['result']) ?? '',
      },
      mode: asString(m['mode']),
      raw: m,
    );
  }
}
