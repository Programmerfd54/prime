import 'package:flutter_test/flutter_test.dart';
import 'package:prime/models/chat_message.dart';

void main() {
  test('ChatMessageModel.fromJson tolerates missing optional fields', () {
    final model = ChatMessageModel.fromJson({
      'id': 'msg-1',
      'sender_user_id': 'user-a',
      'body': 'Привет',
      'created_at': '2026-07-27T10:00:00Z',
    });

    expect(model.id, 'msg-1');
    expect(model.body, 'Привет');
    expect(model.msgtype, 'm.text');
    expect(model.reactions, isEmpty);
    expect(model.deleted, isFalse);
    expect(model.replyToId, isNull);
    expect(model.deliveryStatus, ChatDeliveryStatus.sent);
  });

  test('ChatMessageModel marks own message read when peer_last_read covers it', () {
    final model = ChatMessageModel.fromJson(
      {
        'id': 'msg-2',
        'sender_user_id': 'me',
        'body': 'Done',
        'created_at': '2026-07-27T09:00:00Z',
      },
      currentUserId: 'me',
      peerLastReadAt: DateTime.parse('2026-07-27T12:00:00Z'),
    );

    expect(model.deliveryStatus, ChatDeliveryStatus.read);
    expect(model.readByPeer, isTrue);
  });

  test('ChatMessageModel detects report messages', () {
    final fromType = ChatMessageModel.fromJson({
      'msgtype': 'prime.report',
      'body': '✅ Отчёт готов\nСделал зарядку',
    });
    expect(fromType.isReportMessage, isTrue);
  });

  test('directQuickReplies contains expected chips', () {
    expect(directQuickReplies, contains('Отчёт готов'));
    expect(directQuickReplies, contains('Поддерживаю'));
    expect(directQuickReplies, hasLength(3));
  });
}
