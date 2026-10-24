import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_rubik/core/network/api_exception.dart';
import 'package:mobile_rubik/core/network/models.dart';
import 'package:mobile_rubik/features/social/chat_controller.dart';
import 'package:mobile_rubik/features/social/social_summary_controller.dart';

import '../core/fake_realtime.dart';
import '../core/fakes.dart';
import 'package:mobile_rubik/core/realtime/active_chat.dart';
import 'package:mobile_rubik/core/realtime/realtime_service.dart';
import 'helpers.dart';

const _me = 7;
const _partner = 2;

void main() {
  late FakeApiClient api;
  late FakeRealtimeService rt;
  late List<ChatMessage> server;
  late List<(int? after, int? before)> calls;
  var markReadCalls = 0;

  setUp(() {
    api = FakeApiClient();
    rt = FakeRealtimeService();
    server = [msg(1), msg(2, from: _me, to: _partner)];
    calls = [];
    markReadCalls = 0;
    api.onMessages = (uid, after, before, limit) async {
      calls.add((after, before));
      if (after != null) {
        return server.where((m) => m.messageId > after).toList();
      }
      if (before != null) {
        return server.where((m) => m.messageId < before).toList();
      }
      return List.of(server);
    };
    api.onMarkRead = (uid) async => markReadCalls++;
  });

  ChatController make({int pageSize = 30}) => ChatController(
        api: api,
        myId: _me,
        partnerId: _partner,
        realtime: rt,
        pageSize: pageSize,
      );

  testWidgets('mở màn: tải tin và đánh dấu đã đọc', (tester) async {
    final c = make();
    await c.start();
    expect(c.messages.map((m) => m.messageId), [1, 2]);
    expect(c.loading, isFalse);
    await tester.pump();
    expect(markReadCalls, 1); // tin 1 là tin đến chưa đọc
    c.dispose();
  });

  MessageReceivedEvent ev(ChatMessage m) => MessageReceivedEvent(message: m);

  testWidgets('tin realtime của đối phương được thêm, không hỏi REST',
      (tester) async {
    final c = make();
    await c.start();
    final before = calls.length;
    rt.emitMessage(ev(msg(3, text: 'mới')));
    await tester.pump();
    expect(c.messages.map((m) => m.messageId), [1, 2, 3]);
    expect(calls.length, before); // không gọi lại REST
    await tester.pump(); // markRead cho tin đến
    expect(markReadCalls, 2);
    // 60 giây trôi qua cũng không có vòng hỏi nào
    await tester.pump(const Duration(seconds: 60));
    expect(calls.length, before);
    c.dispose();
  });

  testWidgets('tin realtime trùng id hoặc của cuộc trò chuyện khác bị bỏ',
      (tester) async {
    final c = make();
    await c.start();
    rt.emitMessage(ev(msg(2, from: _me, to: _partner)));
    rt.emitMessage(ev(msg(3, from: 99, to: _me)));
    rt.emitMessage(ev(msg(4, from: _me, to: 99)));
    await tester.pump();
    expect(c.messages.map((m) => m.messageId), [1, 2]);
    // Tin mình gửi từ thiết bị khác thì nhận
    rt.emitMessage(ev(msg(5, from: _me, to: _partner)));
    await tester.pump();
    expect(c.messages.last.messageId, 5);
    c.dispose();
  });

  testWidgets('tin realtime đến trước khi tải xong trang đầu vẫn được gộp',
      (tester) async {
    final c = make();
    final started = c.start();
    rt.emitMessage(ev(msg(3)));
    await started;
    await tester.pump();
    expect(c.messages.map((m) => m.messageId), [1, 2, 3]);
    c.dispose();
  });

  testWidgets('kết nối lại: bù tin một lần theo afterId', (tester) async {
    final c = make();
    await c.start();
    server.add(msg(3));
    final before = calls.length;
    rt.simulateReconnect();
    await tester.pump();
    expect(calls.length, before + 1);
    expect(calls.last.$1, 2);
    expect(c.messages.map((m) => m.messageId), [1, 2, 3]);
    c.dispose();
  });

  testWidgets('tạm dừng rồi quay lại: bù tin một lần, không có hẹn giờ',
      (tester) async {
    final c = make();
    await c.start();
    c.pause();
    final before = calls.length;
    await tester.pump(const Duration(seconds: 60));
    expect(calls.length, before);

    c.resume();
    await tester.pump();
    expect(calls.length, before + 1);
    c.dispose();
  });

  testWidgets('đang mở chat: ActiveChat trỏ tới người đối thoại',
      (tester) async {
    final c = make();
    await c.start();
    expect(ActiveChat.partnerId, _partner);
    c.dispose();
    expect(ActiveChat.partnerId, isNull);
  });

  testWidgets('tải tin cũ khi còn trang trước', (tester) async {
    server = [for (var i = 1; i <= 5; i++) msg(i)];
    api.onMessages = (uid, after, before, limit) async {
      calls.add((after, before));
      final list = server
          .where((m) =>
              (after == null || m.messageId > after) &&
              (before == null || m.messageId < before))
          .toList();
      return list.length > limit ? list.sublist(list.length - limit) : list;
    };
    final c = make(pageSize: 2);
    await c.start();
    expect(c.messages.map((m) => m.messageId), [4, 5]);
    expect(c.hasMore, isTrue);
    await c.loadOlder();
    expect(c.messages.map((m) => m.messageId), [2, 3, 4, 5]);
    expect(calls.last.$2, 4);
    await c.loadOlder();
    expect(c.messages.map((m) => m.messageId), [1, 2, 3, 4, 5]);
    expect(c.hasMore, isFalse);
    c.dispose();
  });

  testWidgets('gửi lỗi giữ bong bóng và thử lại được', (tester) async {
    final c = make();
    await c.start();
    var attempt = 0;
    api.onSendMessage = (uid, text) async {
      attempt++;
      if (attempt == 1) throw const ApiException('Mất mạng', isNetwork: true);
      return msg(10, from: _me, to: uid, text: text);
    };

    expect(await c.send('  chào  '), isTrue);
    expect(c.pending.single.failed, isTrue);
    expect(c.pending.single.text, 'chào');
    expect(c.pending.single.error, 'Mất mạng');
    expect(c.messages.any((m) => m.messageId == 10), isFalse);

    await c.retry(c.pending.single.localId);
    expect(c.pending, isEmpty);
    expect(c.messages.last.messageId, 10);
    c.dispose();
  });

  testWidgets('không gửi tin rỗng hoặc quá 1000 ký tự', (tester) async {
    final c = make();
    await c.start();
    expect(await c.send('   '), isFalse);
    expect(await c.send('a' * 1001), isFalse);
    expect(c.pending, isEmpty);
    c.dispose();
  });

  test('huy hiệu: tối thiểu 30 giây giữa hai lần gọi', () async {
    var now = DateTime(2026, 10, 14, 9);
    api.onSocialSummary = () async => const SocialSummary(
        unreadMessages: 2, incomingChallenges: 1, activeChallenges: 3);
    final s = SocialSummaryController(api: api, now: () => now);
    expect(await s.refresh(), isTrue);
    expect(s.badgeCount, 3);
    now = now.add(const Duration(seconds: 10));
    expect(await s.refresh(), isFalse);
    now = now.add(const Duration(seconds: 25));
    expect(await s.refresh(), isTrue);
    expect(api.summaryCalls, 2);
    expect(await s.refresh(force: true), isTrue);
    s.setUnreadMessages(0);
    expect(s.badgeCount, 1);
    s.dispose();
  });
}
