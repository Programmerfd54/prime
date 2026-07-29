import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/sync/message_dedupe.dart';

void main() {
  test('merges new messages and updates duplicates by id', () {
    final existing = <Map<String, dynamic>>[
      {'id': '1', 'body': 'a', 'timestamp': 1},
      {'id': '2', 'body': 'b', 'timestamp': 2},
    ];
    final added = MessageDedupe.mergeInto(existing, [
      {'id': '2', 'body': 'b2', 'timestamp': 2},
      {'id': '3', 'body': 'c', 'timestamp': 3},
    ]);
    expect(added, isTrue);
    expect(existing.length, 3);
    expect(existing.firstWhere((m) => m['id'] == '2')['body'], 'b2');
    expect(existing.last['id'], '3');
  });

  test('prefers event_id then id then client_id', () {
    expect(MessageDedupe.idOf({'event_id': 'e1', 'id': 'i1'}), 'e1');
    expect(MessageDedupe.idOf({'id': 'i1'}), 'i1');
    expect(MessageDedupe.idOf({'client_id': 'c1'}), 'c1');
  });

  test('no add when only updates', () {
    final existing = <Map<String, dynamic>>[
      {'id': '1', 'body': 'a', 'timestamp': 1},
    ];
    final added = MessageDedupe.mergeInto(existing, [
      {'id': '1', 'body': 'a2', 'timestamp': 1},
    ]);
    expect(added, isFalse);
    expect(existing.single['body'], 'a2');
  });
}
