import '../../../core/network/models.dart';

/// Gộp tin mới vào danh sách hiện có: loại trùng theo messageId (bản mới ghi đè
/// để cập nhật trạng thái đã đọc) và luôn sắp tăng dần theo messageId.
List<ChatMessage> mergeMessages(
  List<ChatMessage> existing,
  Iterable<ChatMessage> incoming,
) {
  final byId = <int, ChatMessage>{
    for (final m in existing) m.messageId: m,
  };
  for (final m in incoming) {
    byId[m.messageId] = m;
  }
  return byId.values.toList()
    ..sort((a, b) => a.messageId.compareTo(b.messageId));
}
