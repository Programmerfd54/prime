import '../../models/group.dart';

class GroupMemberTodayStatus {
  const GroupMemberTodayStatus({
    required this.label,
    required this.tone,
    required this.needsSupport,
    required this.reportReady,
  });

  final String label;
  final GroupMemberTodayTone tone;
  final bool needsSupport;
  final bool reportReady;

  static GroupMemberTodayStatus resolve(MemberModel member) {
    if (member.reportStatus == 'ready') {
      return const GroupMemberTodayStatus(
        label: 'Отчёт готов',
        tone: GroupMemberTodayTone.complete,
        needsSupport: false,
        reportReady: true,
      );
    }
    return switch (member.checkInKind) {
      'starting' => GroupMemberTodayStatus(
          label: _startingLabel(member.checkInAt),
          tone: GroupMemberTodayTone.inProgress,
          needsSupport: false,
          reportReady: false,
        ),
      'done' => const GroupMemberTodayStatus(
          label: 'Выполнил · готовит отчёт',
          tone: GroupMemberTodayTone.inProgress,
          needsSupport: false,
          reportReady: false,
        ),
      'support' => const GroupMemberTodayStatus(
          label: 'Нужна поддержка',
          tone: GroupMemberTodayTone.support,
          needsSupport: true,
          reportReady: false,
        ),
      'hard' => const GroupMemberTodayStatus(
          label: 'Сегодня сложно',
          tone: GroupMemberTodayTone.support,
          needsSupport: true,
          reportReady: false,
        ),
      _ => const GroupMemberTodayStatus(
          label: 'Сегодня без отметки',
          tone: GroupMemberTodayTone.idle,
          needsSupport: false,
          reportReady: false,
        ),
    };
  }

  static String _startingLabel(DateTime? at) {
    if (at == null) return 'Выполняет';
    final minutes = DateTime.now().difference(at.toLocal()).inMinutes;
    if (minutes <= 0) return 'Начал только что';
    if (minutes < 60) return 'Начал $minutes мин назад';
    return 'Выполняет';
  }
}

enum GroupMemberTodayTone { complete, inProgress, support, idle }
