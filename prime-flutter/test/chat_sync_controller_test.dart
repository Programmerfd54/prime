import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/sync/chat_sync_controller.dart';
import 'package:prime/data/api_client.dart';

void main() {
  test('chatOfflineVisible requires sustained failures when messages exist', () {
    expect(
      chatOfflineVisible(
        networkError: true,
        consecutiveNetworkFailures: 1,
        hasMessages: true,
      ),
      isFalse,
    );
    expect(
      chatOfflineVisible(
        networkError: true,
        consecutiveNetworkFailures: 2,
        hasMessages: true,
      ),
      isTrue,
    );
    expect(
      chatOfflineVisible(
        networkError: true,
        consecutiveNetworkFailures: 1,
        hasMessages: false,
      ),
      isTrue,
    );
    expect(
      chatOfflineVisible(
        networkError: false,
        consecutiveNetworkFailures: 5,
        hasMessages: true,
      ),
      isFalse,
    );
  });

  test('applyIncomingMessage merges live push and notifies listeners', () {
    final sync = ChatSyncController(ApiClient());
    var notified = 0;
    sync.addListener(() => notified++);

    sync.applyIncomingMessage({
      'id': 'm1',
      'body': 'Привет!',
      'sender_user_id': 'friend-1',
      'created_at': '2026-07-30T19:05:00.000Z',
      'timestamp': 1,
    });

    expect(sync.messages, hasLength(1));
    expect(sync.messages.first['body'], 'Привет!');
    expect(notified, greaterThan(0));
    sync.dispose();
  });

  test('applyPeerReadAt advances read watermark and notifies listeners', () {
    final sync = ChatSyncController(ApiClient());
    var notified = 0;
    sync.addListener(() => notified++);

    sync.applyPeerReadAt(DateTime.parse('2026-07-30T19:05:00.000Z'));
    expect(sync.peerLastReadAt, isNotNull);
    expect(notified, greaterThan(0));

    final earlier = sync.peerLastReadAt;
    sync.applyPeerReadAt(DateTime.parse('2026-07-30T19:04:00.000Z'));
    expect(sync.peerLastReadAt, earlier);
    sync.dispose();
  });
}
