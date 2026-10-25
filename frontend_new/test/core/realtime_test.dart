import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_new/core/models/presence.dart';
import 'package:frontend_new/core/network/api_client.dart';
import 'package:frontend_new/core/network/models.dart';
import 'package:frontend_new/core/network/token_storage.dart';
import 'package:frontend_new/core/realtime/hub_gateway.dart';
import 'package:frontend_new/core/realtime/realtime_service.dart';
import 'package:frontend_new/friends/chat_controller.dart';
import 'package:frontend_new/friends/friends_controller.dart';

import '../support/fake_realtime.dart';

/// Hub giả: điều khiển được start thành công/thất bại và đẩy sự kiện xuống.
class _FakeGateway implements HubGateway {
  int starts = 0;
  int stops = 0;
  int failNext = 0;
  final _handlers = <String, void Function(List<Object?>?)>{};
  void Function(Object?)? _onClosed;

  @override
  Future<void> start() async {
    starts++;
    if (failNext > 0) {
      failNext--;
      throw const RealtimeException('offline');
    }
  }

  @override
  Future<void> stop() async => stops++;

  final invoked = <String>[];
  Object? invokeResult;

  @override
  Future<Object?> invoke(String method, List<Object> args) async {
    invoked.add('$method ${args.join(' ')}'.trim());
    return invokeResult;
  }

  @override
  void on(String method, void Function(List<Object?>? args) handler) =>
      _handlers[method] = handler;

  @override
  void setOnClosed(void Function(Object? error)? callback) => _onClosed = callback;

  void push(String method, List<Object?> args) => _handlers[method]!(args);
  void drop() => _onClosed?.call(Exception('lost'));
}

/// ApiClient giả: chỉ các hàm bạn bè / tin nhắn mà controller gọi.
class _Api implements ApiClient {
  int friendCalls = 0;
  int markReadCalls = 0;
  List<FriendInfo> friendList = const [
    FriendInfo(userId: 9, username: 'an', fullName: 'Nguyễn An'),
  ];

  @override
  VoidCallback? onUnauthorized;

  @override
  Future<List<FriendInfo>> friends() async {
    friendCalls++;
    return friendList;
  }

  @override
  Future<FriendRequests> friendRequests() async => const FriendRequests();

  @override
  Future<List<ChatMessage>> messagesWith(int userId,
          {int? afterId, int? beforeId, int limit = 30}) async =>
      const [];

  @override
  Future<void> markRead(int userId) async => markReadCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

ChatMessage _msg(int id, int from, int to) => ChatMessage(
    messageId: id,
    senderId: from,
    receiverId: to,
    content: 'tin $id',
    isRead: false,
    sentAt: DateTime(2026, 10, 24, 10));

void main() {
  test('hubUrlFromApi bỏ /api và thêm /hubs/game', () {
    expect(hubUrlFromApi('http://1.2.3.4:5214/api'), 'http://1.2.3.4:5214/hubs/game');
    expect(hubUrlFromApi('http://1.2.3.4:5214/api/'), 'http://1.2.3.4:5214/hubs/game');
  });

  group('SignalRRealtimeService', () {
    late _FakeGateway gw;
    late SignalRRealtimeService rt;

    setUp(() {
      gw = _FakeGateway();
      rt = SignalRRealtimeService(
        tokens: TokenStorage(),
        hubUrl: 'http://x/hubs/game',
        gatewayFactory: (_, _) => gw,
        sleep: (_) async {},
      );
    });

    tearDown(() => rt.dispose());

    test('kết nối được thì trạng thái connected', () async {
      await rt.connect();
      expect(rt.isConnected, isTrue);
      expect(gw.starts, 1);
    });

    test('thử lại theo backoff khi start thất bại', () async {
      gw.failNext = 2;
      await rt.connect();
      expect(gw.starts, 3);
      expect(rt.isConnected, isTrue);
    });

    test('đọc sự kiện Presence, MessageReceived, FriendRequest', () async {
      await rt.connect();
      final presence = expectLater(
          rt.presence, emits(isA<PresenceEvent>()
              .having((e) => e.userId, 'userId', 9)
              .having((e) => e.status, 'status', PresenceStatus.online)));
      final message = expectLater(
          rt.messages, emits(isA<ChatMessage>().having((m) => m.content, 'content', 'chào')));
      final request = expectLater(rt.friendRequests, emits(null));

      gw.push('Presence', [9, 'online']);
      gw.push('MessageReceived', [
        {
          'messageId': 1,
          'senderId': 9,
          'receiverId': 7,
          'content': 'chào',
          'isRead': false,
          'sentAt': '2026-10-24T10:00:00',
        }
      ]);
      gw.push('FriendRequest', [const {}]);
      await Future.wait([presence, message, request]);
    });

    test('payload lạ bị bỏ qua, không ném lỗi', () async {
      await rt.connect();
      gw.push('Presence', ['không phải số']);
      gw.push('MessageReceived', [42]);
    });

    test('rớt kết nối thì tự nối lại và phát reconnected', () async {
      await rt.connect();
      final again = expectLater(rt.reconnected, emits(null));
      gw.drop();
      await again;
      expect(gw.starts, 2);
      expect(rt.isConnected, isTrue);
    });

    test('disconnect thì không tự nối lại', () async {
      await rt.connect();
      await rt.disconnect();
      gw.drop();
      await Future<void>.delayed(Duration.zero);
      expect(rt.status, RealtimeStatus.disconnected);
      expect(gw.starts, 1);
    });
  });

  group('FriendsController với realtime', () {
    test('sự kiện Presence đổi trạng thái online ngay, không gọi lại API', () async {
      final api = _Api();
      final rt = FakeRealtime();
      final c = FriendsController(api: api, realtime: rt);
      await c.load();
      expect(c.friends.single.presence, PresenceStatus.offline);
      final calls = api.friendCalls;

      rt.presenceCtl.add(const PresenceEvent(9, PresenceStatus.online));
      await Future<void>.delayed(Duration.zero);
      expect(c.friends.single.presence, PresenceStatus.online);
      expect(c.onlineCount, 1);
      expect(api.friendCalls, calls);
      c.dispose();
    });

    test('có lời mời mới thì tải lại danh sách', () async {
      final api = _Api();
      final rt = FakeRealtime();
      final c = FriendsController(api: api, realtime: rt);
      await c.load();
      final calls = api.friendCalls;

      rt.requestsCtl.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(api.friendCalls, calls + 1);
      c.dispose();
    });
  });

  group('ChatController với realtime', () {
    test('nhận tin của đúng cuộc trò chuyện và đánh dấu đã đọc', () async {
      final api = _Api();
      final rt = FakeRealtime();
      final c = ChatController(api: api, myId: 7, partnerId: 9, realtime: rt);
      await c.start();

      rt.messagesCtl.add(_msg(1, 9, 7)); // của đối phương
      rt.messagesCtl.add(_msg(2, 11, 7)); // người khác: bỏ qua
      await Future<void>.delayed(Duration.zero);
      expect(c.messages.map((m) => m.messageId), [1]);
      expect(api.markReadCalls, 1);
      c.dispose();
    });
  });
}
