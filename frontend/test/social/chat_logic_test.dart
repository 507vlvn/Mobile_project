import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/features/social/logic/chat_format.dart';
import 'package:mobile_rubik/features/social/logic/message_merge.dart';

import 'helpers.dart';

void main() {
  group('mergeMessages', () {
    test('loại trùng theo id và sắp tăng dần', () {
      final merged = mergeMessages(
        [msg(3), msg(1)],
        [msg(2), msg(3, text: 'bản mới'), msg(4)],
      );
      expect(merged.map((m) => m.messageId), [1, 2, 3, 4]);
      expect(merged[2].content, 'bản mới');
    });

    test('danh sách rỗng và trùng trong cùng đợt', () {
      expect(mergeMessages(const [], const []), isEmpty);
      expect(mergeMessages(const [], [msg(5), msg(5)]).length, 1);
    });

    test('cập nhật trạng thái đã đọc', () {
      final merged = mergeMessages([msg(1)], [msg(1, read: true)]);
      expect(merged.single.isRead, isTrue);
    });
  });

  group('buildChatRows', () {
    test('chèn dải ngày khi sang ngày mới, tin chờ gửi nằm cuối', () {
      final a = msg(1, at: DateTime(2026, 10, 13, 23, 0));
      final b = msg(2, at: DateTime(2026, 10, 14, 8, 0));
      final c = msg(3, at: DateTime(2026, 10, 14, 9, 0));
      final rows = buildChatRows(
        [a, b, c],
        [PendingMessage(localId: 1, text: 'x', time: DateTime(2026, 10, 14, 9, 5))],
      );
      expect(rows.map((r) => r.runtimeType.toString()), [
        'DaySeparatorRow',
        'MessageRow',
        'DaySeparatorRow',
        'MessageRow',
        'MessageRow',
        'PendingRow',
      ]);
    });

    test('nhãn ngày và giờ', () {
      final now = DateTime(2026, 10, 14, 12);
      expect(dayLabel(DateTime(2026, 10, 14, 1), now: now), 'Hôm nay');
      expect(dayLabel(DateTime(2026, 10, 13, 23), now: now), 'Hôm qua');
      expect(dayLabel(DateTime(2026, 10, 3), now: now), '03/10/2026');
      expect(formatClock(DateTime(2026, 1, 1, 9, 5)), '09:05');
    });
  });
}
