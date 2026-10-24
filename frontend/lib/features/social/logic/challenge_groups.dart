import '../../../core/network/models.dart';

/// Các nhóm hiển thị của danh sách thách đấu.
class ChallengeGroups {
  /// Lời mời đến: PENDING, mình là người được thách.
  final List<Challenge> incoming;

  /// Đang chờ đối thủ: PENDING, mình là người thách.
  final List<Challenge> outgoing;

  /// Đang diễn ra: ACCEPTED.
  final List<Challenge> active;

  /// Đã kết thúc: COMPLETED / DECLINED / EXPIRED.
  final List<Challenge> done;

  const ChallengeGroups({
    this.incoming = const [],
    this.outgoing = const [],
    this.active = const [],
    this.done = const [],
  });

  bool get isEmpty =>
      incoming.isEmpty && outgoing.isEmpty && active.isEmpty && done.isEmpty;
}

/// Chia danh sách thách đấu thành 4 nhóm, mới nhất trước trong từng nhóm.
ChallengeGroups groupChallenges(List<Challenge> all, int myId) {
  final incoming = <Challenge>[];
  final outgoing = <Challenge>[];
  final active = <Challenge>[];
  final done = <Challenge>[];
  for (final c in all) {
    switch (c.status) {
      case ChallengeStatus.pending:
        (c.opponent.userId == myId ? incoming : outgoing).add(c);
      case ChallengeStatus.accepted:
        active.add(c);
      case ChallengeStatus.completed:
      case ChallengeStatus.declined:
      case ChallengeStatus.expired:
        done.add(c);
    }
  }
  int newestFirst(Challenge a, Challenge b) => b.createdAt.compareTo(a.createdAt);
  return ChallengeGroups(
    incoming: incoming..sort(newestFirst),
    outgoing: outgoing..sort(newestFirst),
    active: active..sort(newestFirst),
    done: done..sort((a, b) => (b.completedAt ?? b.createdAt)
        .compareTo(a.completedAt ?? a.createdAt)),
  );
}

enum ChallengeOutcome { win, lose, draw }

/// Kết quả của thách đấu COMPLETED theo góc nhìn của [myId].
ChallengeOutcome outcomeFor(Challenge c, int myId) {
  if (c.winnerId == null) return ChallengeOutcome.draw;
  return c.winnerId == myId ? ChallengeOutcome.win : ChallengeOutcome.lose;
}
