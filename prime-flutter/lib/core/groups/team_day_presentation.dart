import '../../models/group.dart';
import 'progress_labels.dart';

class TeamDayGroupLine {
  const TeamDayGroupLine({
    required this.groupId,
    required this.label,
    required this.ready,
    required this.total,
    required this.waitingNames,
    required this.complete,
  });

  final String groupId;
  final String label;
  final int ready;
  final int total;
  final List<String> waitingNames;
  final bool complete;
}

class AggregatedTeamDayPresentation {
  const AggregatedTeamDayPresentation({
    required this.combined,
    required this.groups,
  });

  final TeamDayPresentation combined;
  final List<TeamDayGroupLine> groups;
}

class TeamDayPresentation {
  const TeamDayPresentation({
    required this.ready,
    required this.total,
    required this.status,
    required this.label,
    required this.waitingNames,
    this.closesAtLabel,
  });

  final int ready;
  final int total;
  final String status;
  final String label;
  final List<String> waitingNames;
  final String? closesAtLabel;

  bool get isComplete => status == 'complete';
}

abstract final class TeamDayPresentationResolver {
  static TeamDayPresentation resolve(GroupModel group) {
    final teamDay = group.teamDay;
    final pulse = group.teamPulse;
    final active = group.members.where((m) => m.active).toList();
    final readyFromMembers =
        active.where((m) => m.reportStatus == 'ready').length;
    final ready = teamDay?.readyCount ??
        pulse?.completedToday ??
        readyFromMembers;
    final total = teamDay?.memberCount ??
        pulse?.totalActive ??
        (active.isNotEmpty ? active.length : group.membersCount);
    final status = teamDay?.status ?? pulse?.dayStatus ?? 'pending';
    final waiting = teamDay?.waitingFor
            .map((w) => w.nickname.isNotEmpty ? '@${w.nickname}' : w.name)
            .where((name) => name.isNotEmpty)
            .toList() ??
        pulse?.waitingFor
            .map((w) => w.nickname.isNotEmpty ? '@${w.nickname}' : w.name)
            .where((name) => name.isNotEmpty)
            .toList() ??
        const <String>[];

    String? closesAtLabel;
    final closesAt = teamDay?.closesAt;
    if (closesAt != null && status != 'complete') {
      final remaining = closesAt.toLocal().difference(DateTime.now());
      if (!remaining.isNegative) {
        final hours = remaining.inHours;
        final minutes = remaining.inMinutes % 60;
        closesAtLabel = hours > 0 ? 'до ${hours}ч ${minutes}м' : 'до ${minutes}м';
      }
    }

    return TeamDayPresentation(
      ready: ready,
      total: total,
      status: status,
      label: ProgressLabels.report(ready: ready, total: total),
      waitingNames: waiting,
      closesAtLabel: closesAtLabel,
    );
  }

  static AggregatedTeamDayPresentation aggregate(List<GroupModel> groups) {
    if (groups.isEmpty) {
      return AggregatedTeamDayPresentation(
        combined: const TeamDayPresentation(
          ready: 0,
          total: 0,
          status: 'pending',
          label: 'Отчёты сегодня · 0 из 0',
          waitingNames: [],
        ),
        groups: const [],
      );
    }

    final lines = <TeamDayGroupLine>[];
    var readySum = 0;
    var totalSum = 0;
    final waitingUnion = <String>{};
    var allComplete = true;

    for (final group in groups) {
      final day = resolve(group);
      readySum += day.ready;
      totalSum += day.total;
      waitingUnion.addAll(day.waitingNames);
      if (!day.isComplete) allComplete = false;
      lines.add(
        TeamDayGroupLine(
          groupId: group.id,
          label: group.skillName ?? group.name,
          ready: day.ready,
          total: day.total,
          waitingNames: day.waitingNames,
          complete: day.isComplete,
        ),
      );
    }

    final status = allComplete ? 'complete' : 'pending';
    return AggregatedTeamDayPresentation(
      combined: TeamDayPresentation(
        ready: readySum,
        total: totalSum,
        status: status,
        label: ProgressLabels.report(ready: readySum, total: totalSum),
        waitingNames: waitingUnion.toList(),
      ),
      groups: lines,
    );
  }

  /// First active group where the user still needs to submit today's report.
  static GroupModel? groupNeedingReport(
    List<GroupModel> groups, {
    String? currentUserId,
  }) {
    for (final group in groups) {
      if (group.myTodayReport?.reported != true) return group;
      if (currentUserId != null) {
        for (final member in group.members) {
          if (member.userId == currentUserId &&
              member.reportStatus != 'ready') {
            return group;
          }
        }
      }
    }
    return groups.isNotEmpty ? groups.first : null;
  }

  static List<GroupModel> groupsNeedingNudge(List<GroupModel> groups) =>
      groups.where((group) => !resolve(group).isComplete).toList();
}
