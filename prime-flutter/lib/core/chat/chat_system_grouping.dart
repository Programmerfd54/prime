enum ChatSystemGroupKind {
  participation,
  rulesAcceptance,
  report,
  nudge,
  celebration,
  milestone,
  generic,
}

class ChatDisplaySegment {
  const ChatDisplaySegment.message(this.message)
      : messages = null,
        kind = null,
        separatorLabel = null;

  const ChatDisplaySegment.systemGroup(this.messages, this.kind)
      : message = null,
        separatorLabel = null;

  const ChatDisplaySegment.separator(this.separatorLabel)
      : message = null,
        messages = null,
        kind = null;

  final Map<String, dynamic>? message;
  final List<Map<String, dynamic>>? messages;
  final ChatSystemGroupKind? kind;
  final String? separatorLabel;

  bool get isSeparator => separatorLabel != null;
  bool get isSystemGroup => messages != null && messages!.length > 1;
}

bool isPrimeSystemMessage(Map<String, dynamic> message) {
  final msgtype = message['msgtype']?.toString() ?? '';
  final body = message['body']?.toString() ?? '';
  if (body.isEmpty) return false;
  return msgtype == 'prime.system' ||
      msgtype == 'prime.nudge' ||
      body.startsWith('🎉 День закрыт') ||
      body.startsWith('⏳ Осталось') ||
      body.startsWith('✅ ') ||
      body.startsWith('🛡️ ') ||
      body.startsWith('🚀 ') ||
      body.startsWith('💜 ') ||
      body.startsWith('✏️ Отчёт') ||
      (msgtype == 'prime.report' || body.startsWith('✅ Отчёт'));
}

ChatSystemGroupKind? systemGroupKind(Map<String, dynamic> message) {
  if (!isPrimeSystemMessage(message)) return null;
  final msgtype = message['msgtype']?.toString() ?? '';
  final body = message['body']?.toString() ?? '';
  if (body.contains('подтвердил участие')) {
    return ChatSystemGroupKind.participation;
  }
  if (body.contains('принял командный договор') ||
      body.contains('принял договор')) {
    return ChatSystemGroupKind.rulesAcceptance;
  }
  if (msgtype == 'prime.report' ||
      body.startsWith('✅ Отчёт') ||
      body.startsWith('✏️ Отчёт')) {
    return ChatSystemGroupKind.report;
  }
  if (msgtype == 'prime.nudge' || body.startsWith('⏳')) {
    return ChatSystemGroupKind.nudge;
  }
  if (body.startsWith('🎉') || body.contains('День закрыт')) {
    return ChatSystemGroupKind.celebration;
  }
  if (body.startsWith('🚀 ') || body.startsWith('💜 ')) {
    return ChatSystemGroupKind.milestone;
  }
  return ChatSystemGroupKind.generic;
}

bool canGroupSystemMessages(
  Map<String, dynamic> previous,
  Map<String, dynamic> next,
) {
  final prevKind = systemGroupKind(previous);
  final nextKind = systemGroupKind(next);
  if (prevKind == null || nextKind == null) return false;
  if (prevKind == ChatSystemGroupKind.generic ||
      nextKind == ChatSystemGroupKind.generic) {
    return false;
  }
  return prevKind == nextKind;
}

String? systemActorLabel(Map<String, dynamic> message) {
  final body = message['body']?.toString() ?? '';
  final match = RegExp(r'@([\w.-]+)').firstMatch(body);
  if (match != null) return '@${match.group(1)}';
  return null;
}

String systemGroupTitle(ChatSystemGroupKind kind, {required int count}) {
  return switch (kind) {
    ChatSystemGroupKind.participation => count > 1
        ? 'Подтвердили участие · $count'
        : 'Подтвердили участие',
    ChatSystemGroupKind.rulesAcceptance => count > 1
        ? 'Приняли договор · $count'
        : 'Приняли договор',
    ChatSystemGroupKind.report =>
      count > 1 ? 'Отчёты команды · $count' : 'Отчёт команды',
    ChatSystemGroupKind.nudge =>
      count > 1 ? 'Напоминания · $count' : 'Напоминание',
    ChatSystemGroupKind.celebration => 'День закрыт',
    ChatSystemGroupKind.milestone => 'Командное событие',
    ChatSystemGroupKind.generic => 'Обновление команды',
  };
}

List<ChatDisplaySegment> buildChatDisplaySegments(
  List<Map<String, dynamic>> messages, {
  bool includeDateSeparators = false,
  DateTime? Function(Map<String, dynamic> message)? messageDate,
  String Function(DateTime date)? dateSeparatorLabel,
}) {
  final segments = <ChatDisplaySegment>[];
  DateTime? lastDay;

  void flushSystemBuffer(List<Map<String, dynamic>> buffer) {
    if (buffer.isEmpty) return;
    if (buffer.length == 1) {
      segments.add(ChatDisplaySegment.message(buffer.first));
    } else {
      segments.add(
        ChatDisplaySegment.systemGroup(
          List<Map<String, dynamic>>.from(buffer),
          systemGroupKind(buffer.first) ?? ChatSystemGroupKind.generic,
        ),
      );
    }
    buffer.clear();
  }

  var systemBuffer = <Map<String, dynamic>>[];

  for (final message in messages) {
    if (includeDateSeparators && messageDate != null && dateSeparatorLabel != null) {
      final date = messageDate(message);
      if (date != null) {
        final day = DateTime(date.year, date.month, date.day);
        if (lastDay == null || day != lastDay) {
          flushSystemBuffer(systemBuffer);
          segments.add(ChatDisplaySegment.separator(dateSeparatorLabel(date)));
          lastDay = day;
        }
      }
    }

    final kind = systemGroupKind(message);
    if (kind != null && kind != ChatSystemGroupKind.generic) {
      if (systemBuffer.isNotEmpty &&
          !canGroupSystemMessages(systemBuffer.last, message)) {
        flushSystemBuffer(systemBuffer);
      }
      systemBuffer.add(message);
      continue;
    }

    flushSystemBuffer(systemBuffer);
    segments.add(ChatDisplaySegment.message(message));
  }

  flushSystemBuffer(systemBuffer);
  return segments;
}
