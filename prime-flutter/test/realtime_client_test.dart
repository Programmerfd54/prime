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

  test('removeNotificationLocally drops item from list', () {
    final client = RealtimeClient(ApiClient());
    client.ingestSseBlockForTest('''
event: notification
data: {"id":"n1","type":"system","title":"A","body":"b","payload":{},"read":false,"created_at":"2026-07-30T18:53:00.000Z"}
''');
    client.removeNotificationLocally('n1');
    expect(client.items, isEmpty);
    expect(client.unreadCount, 0);
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

  test('group_phase notification triggers group update listeners', () {
    final client = RealtimeClient(ApiClient());
    GroupUpdatePush? received;
    client.addGroupUpdateListener((push) => received = push);
    var globalUpdates = 0;
    client.onGroupUpdate = (_) => globalUpdates++;

    client.ingestSseBlockForTest('''
event: notification
data: {"id":"n-phase","type":"group_phase","title":"Первый день открыт","body":"Договор принят","payload":{"group_id":"group-abc","phase":"active"},"read":false,"created_at":"2026-07-30T18:53:00.000Z"}
''');

    expect(received?.groupId, 'group-abc');
    expect(received?.phase, 'active');
    expect(received?.reason, 'cycle_started');
    expect(globalUpdates, 1);
  });

  test('group_update ignores stale and duplicate revisions', () {
    final client = RealtimeClient(ApiClient());
    final received = <GroupUpdatePush>[];
    client.addGroupUpdateListener(received.add);

    client.ingestSseBlockForTest('''
event: group_update
data: {"group_id":"group-abc","revision":7,"phase":"rules_pending","reason":"rules_accepted"}
''');
    client.ingestSseBlockForTest('''
event: group_update
data: {"group_id":"group-abc","revision":6,"phase":"introduction","reason":"stale"}
''');
    client.ingestSseBlockForTest('''
event: group_update
data: {"group_id":"group-abc","revision":7,"phase":"rules_pending","reason":"duplicate"}
''');
    client.ingestSseBlockForTest('''
event: group_update
data: {"group_id":"group-abc","revision":7,"phase":"active","reason":"cycle_started"}
''');
    client.ingestSseBlockForTest('''
event: group_update
data: {"group_id":"group-abc","revision":8,"phase":"active","reason":"cycle_started"}
''');

    expect(received, hasLength(3));
    expect(received.first.revision, 7);
    expect(received.first.phase, 'rules_pending');
    expect(received[1].revision, 7);
    expect(received[1].phase, 'active');
    expect(received[1].reason, 'cycle_started');
    expect(received.last.revision, 8);
    expect(received.last.phase, 'active');
    expect(received.last.reason, 'cycle_started');
  });

  test('early-start notification refreshes waiting room immediately', () {
    final client = RealtimeClient(ApiClient());
    var waitingRoomUpdates = 0;
    client.onWaitingRoomUpdate = () => waitingRoomUpdates++;

    client.ingestSseBlockForTest('''
event: notification
data: {"id":"n-early","type":"early_start_request","title":"Старт втроём","body":"Подтвердите старт","payload":{"request_id":"request-1"},"read":false,"created_at":"2026-07-30T18:53:00.000Z"}
''');

    expect(waitingRoomUpdates, 1);
    expect(client.items.single.rawType, 'early_start_request');
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
    expect(received?.readAt.toUtc(),
        DateTime.parse('2026-07-30T19:05:00.000Z').toUtc());
  });
}
