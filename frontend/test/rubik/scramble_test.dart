import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/models/difficulty.dart';
import 'package:mobile_rubik/features/rubik/model/cube_model.dart';
import 'package:mobile_rubik/features/rubik/practice/practice_controller.dart';
import 'package:mobile_rubik/features/rubik/services/scramble.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('cùng seed → cùng chuỗi xáo (hai người chơi thách đấu nhận cùng đề)', () {
    final a = generateScramble(22, random: math.Random(4242));
    final b = generateScramble(22, random: math.Random(4242));
    final c = generateScramble(22, random: math.Random(4243));
    expect(a, b);
    expect(a, isNot(c));
  });

  test('chuỗi xáo hợp lệ: không 2 nước liên tiếp cùng mặt, không 3 nước cùng trục', () {
    final s = generateScramble(200, random: math.Random(1));
    for (var i = 1; i < s.length; i++) {
      expect(s[i][0], isNot(s[i - 1][0]));
      if (i >= 2) {
        final axes = [s[i - 2], s[i - 1], s[i]].map((m) => CubeMove.tryParse(m)!.axis).toSet();
        expect(axes.length, greaterThan(1));
      }
    }
  });

  test('chế độ thách đấu (persist = false) không ghi ván đang lưu', () async {
    SharedPreferences.setMockInitialValues({});
    final c = PracticeController(persist: false);
    c.newGame(Difficulty.easy, random: math.Random(7));
    c.finishScramble();
    await c.save();
    expect(await PracticeController.hasSavedGame(), isFalse);
    c.dispose();
  });
}
