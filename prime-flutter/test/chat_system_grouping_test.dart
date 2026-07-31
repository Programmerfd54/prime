import 'package:flutter_test/flutter_test.dart';
import 'package:prime/core/chat/chat_system_grouping.dart';

Map<String, dynamic> _system(String body) => {
      'msgtype': 'prime.system',
      'body': body,
    };

void main() {
  test('groups consecutive participation confirmations', () {
    final segments = buildChatDisplaySegments([
      _system('✅ @tes подтвердил участие'),
      _system('✅ @wrightags подтвердил участие'),
      {'msgtype': 'm.text', 'body': 'Привет'},
    ]);

    expect(segments, hasLength(2));
    expect(segments.first.isSystemGroup, isTrue);
    expect(segments.first.messages, hasLength(2));
    expect(segments.first.kind, ChatSystemGroupKind.participation);
    expect(segments.last.message?['body'], 'Привет');
  });

  test('does not group different system kinds', () {
    final segments = buildChatDisplaySegments([
      _system('✅ @tes подтвердил участие'),
      _system('🛡️ @wrightags принял командный договор'),
    ]);

    expect(segments, hasLength(2));
    expect(segments.every((segment) => !segment.isSystemGroup), isTrue);
  });

  test('extracts actor labels from system messages', () {
    expect(
      systemActorLabel(_system('✅ @tes подтвердил участие')),
      '@tes',
    );
  });
}
