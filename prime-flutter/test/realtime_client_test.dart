import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/sync/realtime_client.dart';
import 'package:prime/data/api_client.dart';
import 'package:prime/models/notification.dart';

void main() {
  test('waiting_room_update SSE triggers callback', () {
    final client = RealtimeClient(ApiClient());
    var updates = 0;
    client.onWaitingRoomUpdate = () => updates++;

    const block = '''
event: waiting_room_update
data: {"skill_id":"reading-chapter"}
''';

    client.ingestSseBlockForTest(block);

    expect(updates, 1);
  });

  test('notification SSE applies item immediately without duplicate', () {
    final client = RealtimeClient(ApiClient());

    const block = '''
event: notification
data: {"id":"n1","type":"friend_request","title":"Alice","body":"хочет добавить вас в друзья","payload":{"request_id":"req-1"},"read":false,"created_at":"2026-07-30T18:53:00.000Z"}
''';

    client.ingestSseBlockForTest(block);
    client.ingestSseBlockForTest(block);

    expect(client.items.length, 1);
    expect(client.items.first.id, 'n1');
    expect(client.items.first.type, PrimeNotificationType.friendRequest);
    expect(client.unreadCount, 1);
  });

  test('direct_message SSE notifies listeners with payload', () {
    final client = RealtimeClient(ApiClient());
    DirectMessagePush? received;
    client.addDirectMessageListener((push) => received = push);

    client.ingestSseBlockForTest('''
event: direct_message
data: {"friend_id":"friend-1","message_id":"m1","message":{"id":"m1","body":"Привет!","sender_user_id":"friend-1","created_at":"2026-07-30T19:05:00.000Z"}}
''');

    expect(received?.friendId, 'friend-1');
    expect(received?.message?['body'], 'Привет!');
  });

  test('group_update SSE notifies group listeners', () {
    final client = RealtimeClient(ApiClient());
    GroupUpdatePush? received;
    client.addGroupUpdateListener((push) => received = push);
    var globalUpdates = 0;
    client.onGroupUpdate = (_) => globalUpdates++;

    client.ingestSseBlockForTest('''
event: group_update
data: {"group_id":"group-abc"}
''');

    expect(received?.groupId, 'group-abc');
    expect(globalUpdates, 1);
  });

  test('group_chat_update SSE notifies chat listeners', () {
    final client = RealtimeClient(ApiClient());
    GroupChatUpdatePush? received;
    client.addGroupChatUpdateListener((push) => received = push);

    client.ingestSseBlockForTest('''
event: group_chat_update
data: {"group_id":"group-abc"}
''');

    expect(received?.groupId, 'group-abc');
  });

  test('direct_chat_read SSE notifies read listeners', () {
    final client = RealtimeClient(ApiClient());
    DirectChatReadPush? received;
    client.addDirectChatReadListener((push) => received = push);

    client.ingestSseBlockForTest('''
event: direct_chat_read
data: {"friend_id":"friend-1","read_at":"2026-07-30T19:05:00.000Z"}
''');

    expect(received?.friendId, 'friend-1');
    expect(received?.readAt.toUtc(), DateTime.parse('2026-07-30T19:05:00.000Z').toUtc());
  });
}
