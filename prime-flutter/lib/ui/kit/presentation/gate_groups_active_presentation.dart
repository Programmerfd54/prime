import 'package:flutter/material.dart';

import '../../../core/groups/group_prep_state.dart';
import '../../../core/groups/team_day_presentation.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/visuals/charts/prime_radial_progress.dart';
import '../../../design/visuals/habit_art.dart';
import '../../../l10n/copy.dart';
import '../../../models/group.dart';
import '../../components/app_primary_button.dart';
import '../../components/app_secondary_button.dart';
import '../components/prime_content_card.dart';
import '../tokens/kit_typography.dart';

/// V4 — team matched, awaiting confirmation (6/6).
class GateGroupsConfirmationCard extends StatelessWidget {
  const GateGroupsConfirmationCard({
    super.key,
    required this.onConfirm,
    this.skillName,
    this.confirmedCount,
    this.total = 6,
    this.userConfirmed = false,
  });

  final VoidCallback onConfirm;
  final String? skillName;
  final int? confirmedCount;
  final int total;
  final bool userConfirmed;

  factory GateGroupsConfirmationCard.fromPresentation({
    required GroupPrepPresentation prep,
    required VoidCallback onConfirm,
    String? skillName,
    bool userConfirmed = false,
  }) {
    final total = prep.progressTotal ?? 6;
    final confirmed = prep.progressValue ?? 0;
    return GateGroupsConfirmationCard(
      onConfirm: onConfirm,
      skillName: skillName,
      confirmedCount: confirmed,
      total: total,
      userConfirmed: userConfirmed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final confirmed = confirmedCount ?? 0;
    final progress = total > 0 ? confirmed / total : 0.0;
    final allConfirmed = total > 0 && confirmed >= total;
    final title = allConfirmed
        ? AppCopy.allConfirmedParticipation
        : AppCopy.teamReadyConfirm;
    final subtitle = allConfirmed
        ? AppCopy.acceptPactToStartHabit
        : skillName != null
            ? '$skillName · $confirmed из $total подтвердили'
            : '$confirmed из $total подтвердили участие';
    final buttonLabel = allConfirmed
        ? AppCopy.teamPactTitle
        : userConfirmed
            ? 'Открыть группу'
            : AppCopy.confirmParticipation;

    return PrimeContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PrimeRadialProgress(
                progress: progress.clamp(0.0, 1.0),
                valueLabel: '$confirmed/$total',
                size: 64,
                stroke: 7,
                color: allConfirmed ? p.mint : p.brand,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: KitTypography.sectionTitle.copyWith(
                        color: allConfirmed ? p.mint : p.mint,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: KitTypography.caption.copyWith(color: p.inkSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: buttonLabel,
            icon: allConfirmed
                ? Icons.verified_user_outlined
                : Icons.groups_2_outlined,
            success: allConfirmed || userConfirmed,
            onPressed: onConfirm,
          ),
        ],
      ),
    );
  }
}

/// V4 — all confirmed participation; awaiting team pact acceptance.
class GateGroupsRulesPendingCard extends StatelessWidget {
  const GateGroupsRulesPendingCard({
    super.key,
    required this.onOpen,
    this.skillName,
    this.acceptedCount,
    this.total = 6,
    this.userAccepted = false,
  });

  final VoidCallback onOpen;
  final String? skillName;
  final int? acceptedCount;
  final int total;
  final bool userAccepted;

  factory GateGroupsRulesPendingCard.fromPresentation({
    required GroupPrepPresentation prep,
    required VoidCallback onOpen,
    String? skillName,
    bool userAccepted = false,
  }) {
    final total = prep.progressTotal ?? 6;
    final accepted = prep.progressValue ?? 0;
    return GateGroupsRulesPendingCard(
      onOpen: onOpen,
      skillName: skillName,
      acceptedCount: accepted,
      total: total,
      userAccepted: userAccepted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final accepted = acceptedCount ?? 0;
    final progress = total > 0 ? accepted / total : 0.0;
    final allAccepted = total > 0 && accepted >= total;

    return PrimeContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PrimeRadialProgress(
                progress: progress.clamp(0.0, 1.0),
                valueLabel: '$accepted/$total',
                size: 64,
                stroke: 7,
                color: allAccepted ? p.mint : p.brand,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppCopy.continueYourHabit,
                      style: KitTypography.sectionTitle.copyWith(color: p.mint),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      skillName != null
                          ? '$skillName · $accepted из $total приняли договор'
                          : '$accepted из $total приняли договор',
                      style: KitTypography.caption.copyWith(color: p.inkSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppCopy.acceptPactToStartHabit,
                      style: KitTypography.caption.copyWith(color: p.inkMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: userAccepted ? 'Договор принят' : AppCopy.teamPactTitle,
            icon: Icons.verified_user_outlined,
            success: userAccepted,
            onPressed: userAccepted ? null : onOpen,
          ),
          if (userAccepted && !allAccepted) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Ждём остальных · $accepted из $total',
              textAlign: TextAlign.center,
              style: KitTypography.caption.copyWith(color: p.inkSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// V4 — one active habit with team-day progress and report actions.
class GateGroupsActiveHabitCard extends StatelessWidget {
  const GateGroupsActiveHabitCard({
    super.key,
    required this.title,
    required this.ready,
    required this.total,
    required this.complete,
    this.skillId,
    this.waitingNames = const [],
    required this.onReport,
    this.onNudge,
    this.onOpen,
  });

  final String title;
  final int ready;
  final int total;
  final bool complete;
  final String? skillId;
  final List<String> waitingNames;
  final VoidCallback onReport;
  final VoidCallback? onNudge;
  final VoidCallback? onOpen;

  factory GateGroupsActiveHabitCard.fromGroup({
    required GroupModel group,
    required VoidCallback onReport,
    VoidCallback? onNudge,
    VoidCallback? onOpen,
  }) {
    final day = TeamDayPresentationResolver.resolve(group);
    return GateGroupsActiveHabitCard(
      title: group.skillName ?? group.name,
      ready: day.ready,
      total: day.total,
      complete: day.isComplete,
      skillId: group.skillId,
      waitingNames: day.waitingNames,
      onReport: onReport,
      onNudge: day.isComplete ? null : onNudge,
      onOpen: onOpen,
    );
  }

  static String statusLine({
    required int ready,
    required int total,
    required bool complete,
    required List<String> waitingNames,
  }) {
    if (complete) {
      return '$ready/$total · день закрыт';
    }
    final waiting = waitingNames.take(3).join(', ');
    if (waiting.isNotEmpty) {
      return '$ready/$total · Ждём: $waiting';
    }
    return '$ready/$total';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final progress = total > 0 ? (ready / total).clamp(0.0, 1.0) : 0.0;
    final kind = habitArtKindFor('$skillId $title');
    final status = statusLine(
      ready: ready,
      total: total,
      complete: complete,
      waitingNames: waitingNames,
    );

    return PrimeContentCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HabitArtObject(kind: kind, size: 44),
              const SizedBox(width: AppSpacing.sm),
              PrimeRadialProgress(
                progress: progress,
                valueLabel: '$ready/$total',
                size: 48,
                stroke: 6,
                color: complete ? p.mint : p.brand,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: KitTypography.cardTitle.copyWith(color: p.ink),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: KitTypography.caption.copyWith(
                        color: complete ? p.mint : p.inkMuted,
                        fontWeight: complete ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onOpen != null)
                Icon(Icons.chevron_right_rounded, color: p.inkMuted, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: 'Отправить отчёт',
            icon: Icons.edit_note_outlined,
            onPressed: onReport,
          ),
          if (!complete && onNudge != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppSecondaryButton(
              label: AppCopy.nudgeTeam,
              icon: Icons.notifications_active_outlined,
              onPressed: onNudge,
            ),
          ],
        ],
      ),
    );
  }
}

/// V4 — group row in cycle list (forming / intro / active).
class GateGroupsListTile extends StatelessWidget {
  const GateGroupsListTile({
    super.key,
    required this.title,
    required this.statusLabel,
    required this.membersCount,
    required this.maxMembers,
    this.skillId,
    this.active = false,
    this.onTap,
  });

  final String title;
  final String statusLabel;
  final int membersCount;
  final int maxMembers;
  final String? skillId;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final progress = maxMembers > 0 ? membersCount / maxMembers : 0.0;
    final kind = habitArtKindFor('${skillId ?? ''} $title');
    return PrimeContentCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          HabitArtObject(kind: kind, size: 44),
          const SizedBox(width: AppSpacing.sm),
          PrimeRadialProgress(
            progress: progress.clamp(0.0, 1.0),
            valueLabel: '$membersCount/$maxMembers',
            size: 48,
            stroke: 6,
            color: active ? p.mint : p.brand,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: KitTypography.cardTitle.copyWith(color: p.ink)),
                const SizedBox(height: 2),
                Text(
                  statusLabel,
                  style: KitTypography.caption.copyWith(
                    color: active ? p.mint : p.inkMuted,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.inkMuted, size: 20),
        ],
      ),
    );
  }
}

/// Status label helper for [GroupModel].
String gateGroupStatusLabel(GroupStatus status) => switch (status) {
      GroupStatus.forming => 'набор',
      GroupStatus.introduction => 'знакомство',
      GroupStatus.rulesPending => 'командный договор',
      GroupStatus.active => 'активна',
      GroupStatus.rotating => 'добор',
      GroupStatus.voting => 'голосование',
      GroupStatus.completed => 'завершена',
    };
