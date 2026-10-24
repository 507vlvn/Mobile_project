import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/models/presence.dart';
import 'package:mobile_rubik/core/models/rank.dart';
import 'package:mobile_rubik/core/theme/app_theme.dart';
import 'package:mobile_rubik/core/theme/tier_colors.dart';
import 'package:mobile_rubik/core/widgets/player_card.dart';
import 'package:mobile_rubik/core/widgets/rank_badge.dart';

void main() {
  group('Tier thresholds (TASKS_V2 §2.3)', () {
    test('ranh giới các bậc', () {
      expect(Tier.fromRating(0), Tier.bronze);
      expect(Tier.fromRating(1000), Tier.bronze);
      expect(Tier.fromRating(1099), Tier.bronze);
      expect(Tier.fromRating(1100), Tier.silver);
      expect(Tier.fromRating(1249), Tier.silver);
      expect(Tier.fromRating(1250), Tier.gold);
      expect(Tier.fromRating(1399), Tier.gold);
      expect(Tier.fromRating(1400), Tier.platinum);
      expect(Tier.fromRating(1599), Tier.platinum);
      expect(Tier.fromRating(1600), Tier.diamond);
      expect(Tier.fromRating(2800), Tier.diamond);
    });

    test('tên tiếng Việt và mã server', () {
      expect(Tier.values.map((t) => t.label),
          ['Đồng', 'Bạc', 'Vàng', 'Bạch kim', 'Kim cương']);
      expect(Tier.tryParse('gold'), Tier.gold);
      expect(Tier.tryParse('DIAMOND'), Tier.diamond);
      expect(Tier.tryParse('x'), isNull);
      expect(Tier.diamond.next, isNull);
      expect(Tier.bronze.next, Tier.silver);
    });

    test('mỗi bậc có icon khác nhau và màu sáng/tối riêng', () {
      expect(Tier.values.map((t) => t.icon).toSet().length, 5);
      for (final t in Tier.values) {
        expect(TierColors.of(t, Brightness.light),
            isNot(TierColors.of(t, Brightness.dark)));
      }
    });
  });

  group('PresenceStatus.parse', () {
    test('chấp nhận nhiều cách viết', () {
      expect(PresenceStatus.parse('online'), PresenceStatus.online);
      expect(PresenceStatus.parse('in_match'), PresenceStatus.inMatch);
      expect(PresenceStatus.parse('InMatch'), PresenceStatus.inMatch);
      expect(PresenceStatus.parse('OFFLINE'), PresenceStatus.offline);
      expect(PresenceStatus.parse(null), PresenceStatus.offline);
    });
  });

  testWidgets('RankBadge và PlayerCard có Semantics và chữ tên bậc',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: const Scaffold(
        body: Column(children: [
          RankBadge(rating: 1620),
          PlayerCard(
            name: 'Lan Phạm',
            username: 'lan_pham',
            presence: PresenceStatus.online,
            rating: 1260,
          ),
        ]),
      ),
    ));
    expect(find.text('Kim cương · 1620'), findsOneWidget);
    expect(find.text('Vàng'), findsOneWidget);
    expect(find.bySemanticsLabel('Rank Kim cương, 1620 điểm'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Đang online')), findsWidgets);
    handle.dispose();
  });
}
