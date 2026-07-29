import 'package:flutter/material.dart';

import '../../../design/lottie_registry.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/ambient_and_progress.dart';
import '../../../design/visuals/charts/charts.dart';
import '../../../design/visuals/habit_art.dart';
import '../../../l10n/copy.dart';
import '../../../models/group.dart';
import '../app_primary_button.dart';
import '../app_secondary_button.dart';
import '../profile/app_avatar.dart';

/// Empty groups state — team ring preview so mechanics are visible.
class AppGroupEmptyState extends StatelessWidget {
  const AppGroupEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentSurface.withValues(alpha: 0.4),
            AppColors.surfaceSoft,
          ],
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const PrimeLottie(
            slot: PrimeLottieSlot.teamSearch,
            width: 120,
            height: 120,
          ),
          const SizedBox(height: AppSpacing.md),
          const PrimeTeamRing(
            size: 200,
            slots: [],
            centerLabel: '0 из 6',
            centerSubtitle: 'слотов ждут вас',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Команда ждёт вас',
            style: AppTypography.title1,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Выберите ${AppCopy.habit} во вкладке «${AppCopy.habits}» и нажмите «${AppCopy.findTeam}». Здесь появится живой поиск и orbit участников.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySecondary,
          ),
        ],
      ),
    );
  }
}

/// Team ready banner for groups list.
class AppGroupMatchedBanner extends StatelessWidget {
  const AppGroupMatchedBanner({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.mint.withValues(alpha: 0.12),
              AppColors.surface,
            ],
          ),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppProgressRing(
                  progress: 1,
                  label: '6',
                  subtitle: 'из 6',
                  size: 64,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppCopy.teamReadyConfirm,
                        style: AppTypography.title2.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      const Text(
                        'Подтвердите участие и перейдите к правилам',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppPrimaryButton(
              label: AppCopy.confirmParticipation,
              icon: Icons.groups_2,
              success: true,
              onPressed: onOpen,
            ),
          ],
        ),
      ),
    );
  }
}

/// Group detail hero — habit, status, progress ring.
class AppGroupDetailHero extends StatelessWidget {
  const AppGroupDetailHero({
    super.key,
    required this.group,
  });

  final GroupModel group;

  @override
  Widget build(BuildContext context) {
    final kind = habitArtKindFor(group.skillName ?? group.name);
    final accent = habitArtAccent(kind);
    final confirmed =
        group.members.where((m) => m.confirmedParticipation).length;
    final progress = group.maxMembers == 0 ? 0.0 : confirmed / group.maxMembers;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.14),
              AppColors.heroSurfaceEnd,
            ],
          ),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.skillName ?? group.name,
                    style: AppTypography.largeTitle.copyWith(fontSize: 22),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _statusLabel(group.status),
                    style: AppTypography.caption.copyWith(color: accent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (group.isPrivate && group.inviteCode != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        'Код: ${group.inviteCode}',
                        style: AppTypography.caption,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      AppProgressRing(
                        progress: progress.clamp(0.0, 1.0),
                        label: '$confirmed',
                        subtitle: '/${group.maxMembers}',
                        size: 68,
                        color: accent,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '${group.membersCount} участников в команде',
                          style: AppTypography.bodySecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            HabitArtObject(kind: kind, size: 88),
          ],
        ),
      ),
    );
  }

  String _statusLabel(GroupStatus status) {
    return switch (status) {
      GroupStatus.forming => 'Набор участников',
      GroupStatus.introduction => 'Этап знакомства',
      GroupStatus.rulesPending => 'Принятие правил',
      GroupStatus.active => 'Трекер активен',
      GroupStatus.rotating => 'Режим добора',
      GroupStatus.voting => 'Голосование за продолжение',
      GroupStatus.completed => 'Цикл завершён',
    };
  }
}

/// Active group daily actions — report + chat.
class AppGroupDailyActions extends StatelessWidget {
  const AppGroupDailyActions({
    super.key,
    required this.reportSending,
    required this.reportAlreadySent,
    required this.canOpenChat,
    required this.onReport,
    required this.onChat,
  });

  final bool reportSending;
  final bool reportAlreadySent;
  final bool canOpenChat;
  final VoidCallback onReport;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Сегодня', style: AppTypography.title2),
          const SizedBox(height: AppSpacing.xxs),
          const Text(
            'Отправьте отчёт и поддержите команду в чате',
            style: AppTypography.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: reportSending
                ? 'Отправка…'
                : reportAlreadySent
                    ? 'Поправить отчёт'
                    : 'Заполнить отчёт',
            icon: Icons.edit_note,
            loading: reportSending,
            onPressed: reportSending ? null : onReport,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSecondaryButton(
            label: 'Открыть чат',
            icon: Icons.chat_bubble_outline,
            onPressed: canOpenChat ? onChat : null,
          ),
        ],
      ),
    );
  }
}

/// Member row with avatar for group detail.
class AppGroupMemberRow extends StatelessWidget {
  const AppGroupMemberRow({
    super.key,
    required this.member,
    this.onTap,
  });

  final MemberModel member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final profile = member.profile;
    final name = profile?.name.isNotEmpty == true
        ? profile!.name
        : (profile?.nickname.isNotEmpty == true
            ? '@${profile!.nickname}'
            : 'Участник');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: AppColors.surface.withValues(alpha: 0.6),
          ),
          child: Row(
            children: [
              AppAvatar(
                photoUrl: profile?.photoUrl,
                radius: 22,
                name: name,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.title2.copyWith(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (profile?.nickname.isNotEmpty == true)
                      Text(
                        '@${profile!.nickname}',
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(
                member.confirmedParticipation
                    ? Icons.check_circle_rounded
                    : Icons.hourglass_empty_rounded,
                color: member.confirmedParticipation
                    ? AppColors.success
                    : AppColors.textMuted,
                size: AppIconSizes.sm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Intro phase — team matched, confirm participation.
class AppGroupIntroPanel extends StatelessWidget {
  const AppGroupIntroPanel({
    super.key,
    required this.group,
    required this.onOpenProfile,
  });

  final GroupModel group;
  final void Function(MemberModel member) onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final confirmed =
        group.members.where((m) => m.confirmedParticipation).length;
    final progress =
        group.maxMembers == 0 ? 0.0 : confirmed / group.maxMembers;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.mint.withValues(alpha: 0.1),
            AppColors.surfaceSoft,
          ],
        ),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withValues(alpha: 0.14),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  color: AppColors.success,
                  size: AppIconSizes.sm,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Команда найдена',
                  style: AppTypography.title2.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Команда готова. Познакомьтесь с участниками и подтвердите участие — затем откроются правила.',
            style: AppTypography.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.elevatedSurface,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Готовы продолжить: $confirmed/${group.maxMembers}',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          ...group.members.map(
            (member) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppGroupIntroParticipantTile(
                member: member,
                onTap: member.profile == null
                    ? null
                    : () => onOpenProfile(member),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rich participant tile for intro phase.
class AppGroupIntroParticipantTile extends StatelessWidget {
  const AppGroupIntroParticipantTile({
    super.key,
    required this.member,
    this.onTap,
  });

  final MemberModel member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final profile = member.profile;
    final name = profile?.name.isNotEmpty == true
        ? profile!.name
        : 'Участник';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: AppColors.surface.withValues(alpha: 0.65),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(
                photoUrl: profile?.photoUrl,
                radius: 24,
                name: name,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: AppTypography.title2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          member.confirmedParticipation
                              ? Icons.check_circle_rounded
                              : Icons.hourglass_empty_rounded,
                          color: member.confirmedParticipation
                              ? AppColors.success
                              : AppColors.textMuted,
                          size: 18,
                        ),
                      ],
                    ),
                    if (profile?.nickname.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@${profile!.nickname}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primarySoft,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (profile?.city != null || profile?.age != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (profile?.city != null) profile!.city,
                          if (profile?.age != null) '${profile!.age} лет',
                        ].join(' · '),
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (profile?.about.isNotEmpty == true) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        profile!.about,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySecondary,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rules acceptance panel — scroll-friendly editorial block.
class AppGroupRulesPanel extends StatelessWidget {
  const AppGroupRulesPanel({super.key});

  static const _principles = [
    'Ежедневный отчёт о выполненных действиях.',
    'Абсолютная честность с собой и группой.',
    'Поддержка единомышленников каждый день (реакции, эмодзи, текст).',
    'Доверие и экологичное общение (без политики, религии, обсуждения доходов).',
    'Фокус на личном развитии.',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        color: AppColors.surfaceSoft.withValues(alpha: 0.7),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Главное правило ПРАЙМА',
            style: AppTypography.title2.copyWith(color: AppColors.primarySoft),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Если ты согласен взять на себя ответственность перед самим собой '
            'и перед группой, то с момента старта развития важной и полезной '
            'для тебя привычки твоё слово имеет огромную ценность для тебя '
            'и как минимум для данной группы единомышленников.\n\n'
            'Помни: если кто-то проявил слабость и нарушил своё слово — '
            'то есть перестал отправлять отчёты без уважительной причины — '
            'то ты должен понять, что в этом мире есть люди слабее тебя, '
            'а ответственность за будущее всегда была, есть и будет в руках '
            'сильных людей. За тех, кто всегда в Прайме.',
            style: AppTypography.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '5 принципов группы',
            style: AppTypography.title2.copyWith(color: AppColors.primarySoft),
          ),
          const SizedBox(height: AppSpacing.xs),
          ..._principles.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.key + 1}. ',
                        style: AppTypography.bodySecondary.copyWith(
                          color: AppColors.primarySoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: AppTypography.bodySecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.accentSurface.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: const Text(
              'Чат группы будет доступен только после того, как все 6 участников '
              'проскроллят правила до конца и нажмут «Принять».',
              style: AppTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// End-of-cycle voting panel.
class AppGroupVotingPanel extends StatelessWidget {
  const AppGroupVotingPanel({
    super.key,
    required this.onContinueTogether,
    required this.onNewSkill,
  });

  final VoidCallback onContinueTogether;
  final VoidCallback onNewSkill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          colors: [
            AppColors.accentSurface.withValues(alpha: 0.45),
            AppColors.surface,
          ],
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Итоги 30-дневного цикла',
            style: AppTypography.title2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppPrimaryButton(
            label: 'Остаться текущим составом',
            onPressed: onContinueTogether,
          ),
          const SizedBox(height: AppSpacing.xs),
          AppSecondaryButton(
            label: 'Выйти и развивать новую привычку',
            onPressed: onNewSkill,
          ),
        ],
      ),
    );
  }
}

/// Active cycle hero — single active group with day progress.
class AppGroupActiveCycleHero extends StatelessWidget {
  const AppGroupActiveCycleHero({
    super.key,
    required this.group,
    required this.onTap,
  });

  final GroupModel group;
  final VoidCallback onTap;

  static int? cycleDayFromStart(DateTime? cycleStartAt) {
    if (cycleStartAt == null) return null;
    final elapsed = DateTime.now().difference(cycleStartAt).inDays + 1;
    return elapsed.clamp(1, 30);
  }

  @override
  Widget build(BuildContext context) {
    final kind = habitArtKindFor(group.skillName ?? group.name);
    final accent = habitArtAccent(kind);
    final cycleDay = cycleDayFromStart(group.cycleStartAt);
    final progress =
        cycleDay != null ? (cycleDay / 30).clamp(0.0, 1.0) : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.16),
                AppColors.surface,
                AppColors.elevatedSurface,
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.skillName ?? group.name,
                        style: AppTypography.title1,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Активный цикл · ${group.membersCount}/${group.maxMembers}',
                        style: AppTypography.caption.copyWith(color: accent),
                      ),
                      if (cycleDay != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            AppProgressRing(
                              progress: progress!,
                              label: '$cycleDay',
                              subtitle: 'из 30',
                              size: 68,
                              color: accent,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'День $cycleDay',
                                    style: AppTypography.title2.copyWith(
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppCopy.cycleDays,
                                    style: AppTypography.caption,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                HabitArtObject(kind: kind, size: 72),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact chip for switching between active search queues.
class AppSearchQueueChip extends StatelessWidget {
  const AppSearchQueueChip({
    super.key,
    required this.label,
    required this.filled,
    required this.needed,
    required this.selected,
    required this.onTap,
    this.expanded = false,
  });

  final String label;
  final int filled;
  final int needed;
  final bool selected;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryContainer.withValues(alpha: 0.85)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : expanded
                      ? AppColors.mint.withValues(alpha: 0.45)
                      : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.primarySoft : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                '$filled/$needed',
                style: AppTypography.caption.copyWith(
                  color: selected
                      ? AppColors.primarySoft
                      : AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (expanded) ...[
                const SizedBox(width: AppSpacing.xxs),
                Icon(
                  Icons.public_rounded,
                  size: 14,
                  color: AppColors.mint.withValues(alpha: 0.9),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Unified search timeline: сейчас → expansion → partial start.
class AppSearchTimeline extends StatelessWidget {
  const AppSearchTimeline({super.key, required this.status});

  final WaitingRoomStatus status;

  static String _formatDuration(Duration d) {
    if (d.isNegative) return '0 мин';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours > 0 && minutes > 0) return '$hours ч $minutes мин';
    if (hours > 0) return '$hours ч';
    if (minutes > 0) return '$minutes мин';
    return '${d.inSeconds} сек';
  }

  static (DateTime start, DateTime end) _bounds(WaitingRoomStatus status) {
    final partial = status.partialStartAvailableAt;
    if (partial != null) {
      return (partial.subtract(const Duration(hours: 12)), partial);
    }
    final expansion = status.expansionAvailableAt;
    if (expansion != null) {
      final end = expansion.add(const Duration(hours: 11));
      final start = expansion.subtract(
        Duration(
          minutes: (expansion.difference(DateTime.now()).inMinutes)
              .clamp(1, 720),
        ),
      );
      if (start.isBefore(end)) return (start, end);
      return (expansion, end);
    }
    final now = DateTime.now();
    return (now, now.add(const Duration(hours: 12)));
  }

  @override
  Widget build(BuildContext context) {
    final minMembers = status.minMembers;
    final showExpansion = status.expansionAvailableAt != null ||
        status.canExpandSearch ||
        status.allowOtherRegions;

    return StreamBuilder<DateTime>(
      stream: Stream.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now(),
      ),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final (start, end) = _bounds(status);
        final totalMs = end.difference(start).inMilliseconds;
        final progress = totalMs <= 0
            ? 1.0
            : (now.difference(start).inMilliseconds / totalMs).clamp(0.0, 1.0);

        final expansionAt = status.expansionAvailableAt;
        double? expansionFraction;
        String expansionCaption = 'расширение на Россию';
        if (showExpansion && expansionAt != null) {
          expansionFraction = totalMs <= 0
              ? 0.5
              : (expansionAt.difference(start).inMilliseconds / totalMs)
                  .clamp(0.05, 0.95);
          final untilExpansion = expansionAt.difference(now);
          if (status.allowOtherRegions || status.canExpandSearch) {
            expansionCaption = 'расширение на Россию';
          } else if (untilExpansion.isNegative) {
            expansionCaption = 'расширение на Россию';
          } else {
            expansionCaption =
                'расширение через ${_formatDuration(untilExpansion)}';
          }
        } else if (showExpansion) {
          expansionFraction = 0.45;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 28,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 12,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.elevatedSurface,
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 12,
                        width: (trackWidth * progress).clamp(0.0, trackWidth),
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.75),
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      ),
                      if (expansionFraction != null)
                        Positioned(
                          left: (trackWidth * expansionFraction - 4)
                              .clamp(0.0, trackWidth - 8),
                          top: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: status.allowOtherRegions ||
                                      status.canExpandSearch
                                  ? AppColors.mint
                                  : AppColors.textMuted,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: (trackWidth * progress - 6)
                            .clamp(0.0, trackWidth - 12),
                        top: 6,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.45),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: progress >= 0.98
                                ? AppColors.warningSoft
                                : AppColors.textMuted,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'сейчас',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primarySoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (showExpansion)
                      Expanded(
                        child: Text(
                          expansionCaption,
                          textAlign: TextAlign.center,
                          style: AppTypography.caption.copyWith(
                            color: status.allowOtherRegions ||
                                    status.canExpandSearch
                                ? AppColors.mint
                                : null,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        'частичный старт от $minMembers',
                        textAlign: TextAlign.end,
                        style: AppTypography.caption,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Если за 12 часов не соберётся полная команда, группа может стартовать от $minMembers человек.',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Active team search summary on groups list.
class AppGroupActiveSearchesBanner extends StatelessWidget {
  const AppGroupActiveSearchesBanner({
    super.key,
    required this.queues,
  });

  final List<WaitingRoomStatus> queues;

  @override
  Widget build(BuildContext context) {
    final count = queues.length;
    final title = count >= 6
        ? 'Ищем команду по всем $count привычкам'
        : count == 1
            ? 'Ищем команду по 1 привычке'
            : 'Ищем команду по $count привычкам';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.surfaceSoft,
          ],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HabitArtObject(kind: HabitArtKind.social, size: 48),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.title2,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Можно искать сразу несколько привычек — каждая очередь идёт отдельно.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final queue in queues)
                _SearchSkillChip(
                  label: queue.skillName ?? queue.skillId ?? 'Привычка',
                  expanded: queue.allowOtherRegions,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Group list row — replaces legacy AppGroupCard.
class AppGroupListRow extends StatelessWidget {
  const AppGroupListRow({
    super.key,
    required this.title,
    required this.statusLabel,
    required this.membersCount,
    required this.maxMembers,
    this.onTap,
    this.active = false,
  });

  final String title;
  final String statusLabel;
  final int membersCount;
  final int maxMembers;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final kind = habitArtKindFor(title);
    final accent = habitArtAccent(kind);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: active
                ? AppColors.selectedSurface.withValues(alpha: 0.75)
                : AppColors.surfaceSoft.withValues(alpha: 0.55),
            border: Border.all(
              color: active
                  ? accent.withValues(alpha: 0.45)
                  : AppColors.border,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                HabitArtObject(kind: kind, size: 44),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.title2.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$statusLabel · $membersCount/$maxMembers участников',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: active ? accent : null,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: AppIconSizes.md,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchSkillChip extends StatelessWidget {
  const _SearchSkillChip({
    required this.label,
    required this.expanded,
  });

  final String label;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: expanded
              ? AppColors.mint.withValues(alpha: 0.45)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.caption),
          if (expanded) ...[
            const SizedBox(width: AppSpacing.xxs),
            Icon(
              Icons.public_rounded,
              size: 14,
              color: AppColors.mint.withValues(alpha: 0.9),
            ),
          ],
        ],
      ),
    );
  }
}
