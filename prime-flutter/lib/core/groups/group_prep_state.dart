import '../../l10n/copy.dart';
import '../../models/group.dart';
import 'progress_labels.dart';

/// Unified prep-phase UX (introduction / rules_pending) for Home, Groups, Detail.
enum GroupPrepPhase {
  teamGathered,
  waitingOthersConfirm,
  readyForPact,
  waitingOthersPact,
  cycleStarted,
}

class GroupPrepPresentation {
  const GroupPrepPresentation({
    required this.phase,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.primaryEnabled,
    required this.showSecondaryChangeGroup,
    this.secondaryLabel,
    this.onSecondary,
    this.progressLabel,
    this.progressValue,
    this.progressTotal,
  });

  final GroupPrepPhase phase;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final bool primaryEnabled;
  final bool showSecondaryChangeGroup;
  final String? secondaryLabel;
  final void Function()? onSecondary;
  final String? progressLabel;
  final int? progressValue;
  final int? progressTotal;
}

abstract final class GroupPrepStateResolver {
  static GroupPrepPresentation resolve({
    required GroupModel group,
    required String? currentUserId,
    void Function()? onOpenChat,
  }) {
    final active = group.members.where((m) => m.active).toList();
    final total = group.maxMembers > 0 ? group.maxMembers : active.length;
    final confirmed =
        active.where((m) => m.confirmedParticipation).length;
    final accepted = active.where((m) => m.acceptedRules).length;
    MemberModel? me;
    if (currentUserId != null) {
      for (final member in active) {
        if (member.userId == currentUserId) {
          me = member;
          break;
        }
      }
    }
    final myConfirmed = me?.confirmedParticipation == true;
    final myAccepted = me?.acceptedRules == true;

    if (group.status == GroupStatus.active) {
      return GroupPrepPresentation(
        phase: GroupPrepPhase.cycleStarted,
        title: 'Цикл стартовал',
        subtitle: 'Первый день открыт — команда видит ваши отчёты',
        primaryLabel: 'Перейти к первому дню',
        primaryEnabled: true,
        showSecondaryChangeGroup: false,
        progressLabel: ProgressLabels.cycle(day: group.cycleDay),
        progressValue: group.cycleDay,
        progressTotal: 30,
      );
    }

    if (group.status == GroupStatus.rulesPending) {
      final allAccepted = total > 0 && accepted >= total;
      if (allAccepted) {
        return GroupPrepPresentation(
          phase: GroupPrepPhase.cycleStarted,
          title: 'Цикл стартовал',
          subtitle: 'Все приняли договор — можно начинать привычку',
          primaryLabel: 'Перейти к первому дню',
          primaryEnabled: true,
          showSecondaryChangeGroup: false,
          progressLabel: ProgressLabels.pact(accepted: accepted, total: total),
          progressValue: accepted,
          progressTotal: total,
        );
      }
      if (myAccepted) {
        final waiting = total - accepted;
        return GroupPrepPresentation(
          phase: GroupPrepPhase.waitingOthersPact,
          title: AppCopy.continueYourHabit,
          subtitle: 'Вы приняли договор · ждём $waiting из $total',
          primaryLabel: 'Договор принят',
          primaryEnabled: false,
          showSecondaryChangeGroup: true,
          secondaryLabel: onOpenChat != null ? 'Написать в чат' : null,
          onSecondary: onOpenChat,
          progressLabel: ProgressLabels.pact(accepted: accepted, total: total),
          progressValue: accepted,
          progressTotal: total,
        );
      }
      return GroupPrepPresentation(
        phase: GroupPrepPhase.readyForPact,
        title: AppCopy.continueYourHabit,
        subtitle: AppCopy.acceptPactToStartHabit,
        primaryLabel: AppCopy.teamPactTitle,
        primaryEnabled: true,
        showSecondaryChangeGroup: true,
        progressLabel: 'приняли договор',
        progressValue: accepted,
        progressTotal: total,
      );
    }

    // introduction
    final allConfirmed = total > 0 && confirmed >= total;
    if (allConfirmed) {
      return GroupPrepPresentation(
        phase: GroupPrepPhase.readyForPact,
        title: AppCopy.allConfirmedParticipation,
        subtitle: AppCopy.acceptPactToStartHabit,
        primaryLabel: AppCopy.teamPactTitle,
        primaryEnabled: true,
        showSecondaryChangeGroup: true,
        progressLabel: ProgressLabels.confirm(confirmed: confirmed, total: total),
        progressValue: confirmed,
        progressTotal: total,
      );
    }
    if (myConfirmed) {
      final waiting = total - confirmed;
      return GroupPrepPresentation(
        phase: GroupPrepPhase.waitingOthersConfirm,
        title: 'Вы подтвердили участие',
        subtitle: 'Ждём ещё $waiting из $total',
        primaryLabel: 'Участие подтверждено',
        primaryEnabled: false,
        showSecondaryChangeGroup: true,
        secondaryLabel: onOpenChat != null ? 'Написать в чат' : null,
        onSecondary: onOpenChat,
        progressLabel: ProgressLabels.confirm(confirmed: confirmed, total: total),
        progressValue: confirmed,
        progressTotal: total,
      );
    }
    return GroupPrepPresentation(
      phase: GroupPrepPhase.teamGathered,
      title: 'Познакомьтесь перед стартом',
      subtitle: AppCopy.teamReadyConfirm,
      primaryLabel: AppCopy.confirmParticipation,
      primaryEnabled: true,
      showSecondaryChangeGroup: true,
      progressLabel: 'подтвердили участие',
      progressValue: confirmed,
      progressTotal: total,
    );
  }
}
