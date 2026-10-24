import '../../../core/network/models.dart';

String _two(int v) => v.toString().padLeft(2, '0');

/// "09:05"
String formatClock(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "Hôm nay" / "Hôm qua" / "03/10/2026"
String dayLabel(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  if (sameDay(t, n)) return 'Hôm nay';
  if (sameDay(t, n.subtract(const Duration(days: 1)))) return 'Hôm qua';
  return '${_two(t.day)}/${_two(t.month)}/${t.year}';
}

/// Tin đang gửi / gửi lỗi, chưa có messageId từ server.
class PendingMessage {
  final int localId;
  final String text;
  final DateTime time;
  final bool failed;
  final String? error;

  const PendingMessage({
    required this.localId,
    required this.text,
    required this.time,
    this.failed = false,
    this.error,
  });

  PendingMessage copyWith({bool? failed, String? error, DateTime? time}) =>
      PendingMessage(
        localId: localId,
        text: text,
        time: time ?? this.time,
        failed: failed ?? this.failed,
        error: error,
      );
}

/// Một dòng của danh sách chat (theo thứ tự thời gian tăng dần).
sealed class ChatRow {
  const ChatRow();
}

class DaySeparatorRow extends ChatRow {
  final DateTime day;
  const DaySeparatorRow(this.day);
}

class MessageRow extends ChatRow {
  final ChatMessage message;
  const MessageRow(this.message);
}

class PendingRow extends ChatRow {
  final PendingMessage pending;
  const PendingRow(this.pending);
}

/// Dựng các dòng chat: chèn dải ngày khi sang ngày mới, tin chờ gửi nằm cuối.
List<ChatRow> buildChatRows(
  List<ChatMessage> messages,
  List<PendingMessage> pending,
) {
  final rows = <ChatRow>[];
  DateTime? lastDay;
  void addDay(DateTime t) {
    if (lastDay == null || !sameDay(lastDay!, t)) {
      rows.add(DaySeparatorRow(t));
      lastDay = t;
    }
  }

  for (final m in messages) {
    addDay(m.sentAt);
    rows.add(MessageRow(m));
  }
  for (final p in pending) {
    addDay(p.time);
    rows.add(PendingRow(p));
  }
  return rows;
}
