import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/models/challenge_context.dart';
import 'package:mobile_rubik/core/models/difficulty.dart';
import 'package:mobile_rubik/core/services/score_reporter.dart';
import 'package:mobile_rubik/features/caro/caro_controller.dart';
import 'package:mobile_rubik/features/caro/logic/caro_ai.dart';
import 'package:mobile_rubik/features/caro/logic/caro_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const ctx = ChallengeContext(
      challengeId: 99, gameCode: 'CARO', difficulty: Difficulty.easy);

  Future<CaroController> play(List<CaroAiRequest> log) async {
    final c = CaroController(
      challenge: ctx,
      aiRunner: (r) async {
        log.add(r);
        return chooseCaroMove(r);
      },
      minThinkTime: Duration.zero,
    );
    // playerFirst=false bị bỏ qua: thách đấu luôn để người chơi đi trước.
    c.newGame(difficulty: Difficulty.hard, playerFirst: false);
    expect(c.playerFirst, isTrue);
    expect(c.difficulty, Difficulty.easy);
    c.placePlayer(caroIndex(7, 7));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return c;
  }

  test('cùng seed + cùng thế cờ → máy chọn cùng nước (Dễ); không autosave',
      () async {
    final la = <CaroAiRequest>[], lb = <CaroAiRequest>[];
    final a = await play(la);
    final b = await play(lb);
    expect(la.single.seed, lb.single.seed);
    expect(a.history, b.history);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
    expect(a.toRecord().challengeId, ctx.challengeId);
    final ab = a.toAbandonRecord();
    expect(ab.outcome, GameOutcome.lose);
    expect(ab.challengeId, ctx.challengeId);
    a.dispose();
    b.dispose();
  });
}
