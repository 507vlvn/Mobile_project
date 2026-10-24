import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/network/models.dart';
import 'package:mobile_rubik/features/social/logic/challenge_groups.dart';

import 'helpers.dart';

void main() {
  const me = 7;

  test('chia nhóm theo trạng thái và vai trò', () {
    final all = [
      challenge(1, status: ChallengeStatus.pending, challengerId: 2, opponentId: me),
      challenge(2, status: ChallengeStatus.pending, challengerId: me, opponentId: 3),
      challenge(3, status: ChallengeStatus.accepted),
      challenge(4, status: ChallengeStatus.completed),
      challenge(5, status: ChallengeStatus.declined),
      challenge(6, status: ChallengeStatus.expired),
      challenge(7, status: ChallengeStatus.pending, challengerId: 4, opponentId: me),
    ];
    final g = groupChallenges(all, me);
    expect(g.incoming.map((c) => c.id), [7, 1]); // mới nhất trước
    expect(g.outgoing.map((c) => c.id), [2]);
    expect(g.active.map((c) => c.id), [3]);
    expect(g.done.map((c) => c.id).toSet(), {4, 5, 6});
    expect(g.isEmpty, isFalse);
  });

  test('rỗng', () {
    expect(groupChallenges(const [], me).isEmpty, isTrue);
  });

  test('kết quả theo góc nhìn của tôi', () {
    expect(outcomeFor(challenge(1, winnerId: me), me), ChallengeOutcome.win);
    expect(outcomeFor(challenge(1, winnerId: 2), me), ChallengeOutcome.lose);
    expect(outcomeFor(challenge(1), me), ChallengeOutcome.draw);
  });

  test('seed bằng id thách đấu và parse JSON', () {
    final c = Challenge.fromJson({
      'id': 42,
      'gameCode': 'CARO',
      'gameName': 'Caro',
      'difficulty': 3,
      'status': 'ACCEPTED',
      'createdAt': '2026-10-14T01:00:00',
      'challenger': {'userId': 1, 'username': 'a'},
      'opponent': {'userId': 2, 'username': 'b', 'fullName': 'Bê'},
      'myResult': {'score': 900, 'timeSeconds': 60, 'mistakes': 1, 'result': 'WIN'},
      'theirResult': null,
      'winnerId': null,
      'seed': 42,
    });
    expect(c.seed, 42);
    expect(c.status, ChallengeStatus.accepted);
    expect(c.myResult!.score, 900);
    expect(c.theirResult, isNull);
    expect(c.otherOf(1).displayName, 'Bê');
    expect(c.createdAt.isUtc, isFalse); // chuyển về giờ máy
  });
}
