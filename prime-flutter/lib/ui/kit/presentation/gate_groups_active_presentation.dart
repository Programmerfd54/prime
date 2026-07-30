import 'package:flutter/material.dart';

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

/// V4 — active cycle team-day pulse card.
class GateGroupsActiveCycleCard extends StatelessWidget {
  const GateGroupsActiveCycleCard({
    super.key,
    required this.ready,
    required this.total,
    required this.complete,
    required this.remaining,
    this.waitingNames,
    required this.onReport,
    this.onNudge,
  });

  final int ready;
  final int total;
  final bool complete;
  final int remaining;
  final String? waitingNames;
  final VoidCallback onReport;
  final VoidCallback? onNudge;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final progress = total > 0 ? (ready / total).clamp(0.0, 1.0) : 0.0;
    return PrimeContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PrimeRadialProgress(
                progress: progress,
                valueLabel: '$ready/$total',
                size: 72,
                stroke: 8,
                color: complete ? p.mint : p.brand,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppCopy.dayClosesTogether,
                      style: KitTypography.sectionTitle.copyWith(color: p.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      complete
                          ? 'Командный день закрыт'
                          : AppCopy.waitingReports(remaining),
                      style: KitTypography.caption.copyWith(
                        color: complete ? p.mint : p.brandSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      complete
                          ? AppCopy.primesForTeamDay
                          : waitingNames != null && waitingNames!.isNotEmpty
                              ? 'Ждём: $waitingNames'
                              : AppCopy.howDayCounts,
                      style: KitTypography.caption.copyWith(color: p.inkMuted),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
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
