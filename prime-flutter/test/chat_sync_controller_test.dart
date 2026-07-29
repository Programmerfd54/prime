import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/sync/chat_sync_controller.dart';

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
}
