import 'package:flutter/material.dart';

import '../../../design/lottie_registry.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/charts/charts.dart';
import '../../../design/visuals/habit_art.dart';
import '../../../l10n/copy.dart';
import '../../../core/groups/group_member_today_status.dart';
import '../../../models/group.dart';
import '../../kit/components/prime_content_card.dart';
import '../../kit/tokens/kit_surfaces.dart';
import '../../kit/tokens/kit_typography.dart';
import '../app_primary_button.dart';
import '../app_secondary_button.dart';
import '../profile/app_avatar.dart';

/// Empty groups state — team ring preview so mechanics are visible.
class AppGroupEmptyState extends StatelessWidget {
  const AppGroupEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return PrimeContentCard(
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
            style: AppTypography.title1.copyWith(color: p.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Выберите ${AppCopy.habit} во вкладке «${AppCopy.habits}» и нажмите «${AppCopy.findTeam}». Здесь появится живой поиск и orbit участников.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySecondary.copyWith(color: p.inkSecondary),
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
    final p = context.prime;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: kitSurfaceDecoration(
        context,
        PrimeSurfaceLevel.accent,
        radius: AppRadius.xl,
        accent: KitAccent.mint,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PrimeRadialProgress(
                progress: 1,
                valueLabel: '6/6',
                size: 64,
                stroke: 7,
                color: p.mint,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppCopy.teamReadyConfirm,
                      style: KitTypography.sectionTitle.copyWith(color: p.mint),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Подтвердите участие и перейдите к правилам',
                      style:
                          KitTypography.caption.copyWith(color: p.inkSecondary),
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
    final p = context.prime;
    final kind = habitArtKindFor(
      '${group.skillId} ${group.skillName ?? group.name}',
    );
    final accent = habitArtAccent(kind);
    final confirmed =
        group.members.where((m) => m.confirmedParticipation).length;
    final activeMembers =
        group.members.where((member) => member.active).toList();
    final reported =
        activeMembers.where((member) => member.reportStatus == 'ready').length;
    final isActive = group.status == GroupStatus.active;
    final progressTotal = isActive ? activeMembers.length : group.maxMembers;
    final progressValue = isActive ? reported : confirmed;
    final progress = progressTotal == 0 ? 0.0 : progressValue / progressTotal;

    return PrimeContentCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.skillName ?? group.name,
                  style: AppTypography.largeTitle.copyWith(
                    fontSize: 22,
                    color: p.ink,
                  ),
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
                      color: p.surfaceSoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: p.hairline),
                    ),
                    child: Text(
                      'Код: ${group.inviteCode}',
                      style: AppTypography.caption.copyWith(color: p.inkMuted),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    PrimeRadialProgress(
                      progress: progress.clamp(0.0, 1.0),
                      valueLabel: '$progressValue/$progressTotal',
                      caption: isActive ? 'отчётов сегодня' : 'подтвердили',
                      size: 68,
                      stroke: 7,
                      color: accent,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        isActive
                            ? 'День ${group.cycleDay} из 30 · команда видит общий ритм'
                            : '${group.membersCount} участников в команде',
                        style: AppTypography.bodySecondary.copyWith(
                          color: p.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Image.asset(
              habitPhotoAsset(kind),
              width: 88,
              height: 88,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(GroupStatus status) {
    return switch (status) {
      GroupStatus.forming => 'Набор участников',
      GroupStatus.introduction => 'Этап знакомства',
      GroupStatus.rulesPending => 'Командный договор',
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
    final p = context.prime;
    return PrimeContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Сегодня', style: AppTypography.title2.copyWith(color: p.ink)),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Отправьте отчёт и поддержите команду в чате',
            style: AppTypography.bodySecondary.copyWith(color: p.inkSecondary),
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
    this.statusPhase,
  });

  final MemberModel member;
  final VoidCallback? onTap;

  /// When set, controls which confirmation flag drives the status icon.
  final GroupStatus? statusPhase;

  bool get _isReady {
    if (statusPhase == GroupStatus.rulesPending) {
      return member.acceptedRules;
    }
    if (statusPhase == null) {
      return member.reportStatus == 'ready';
    }
    return member.confirmedParticipation;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
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
            color: p.surfaceElevated,
            border: Border.all(color: p.hairline, width: 0.5),
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
                      style: AppTypography.title2.copyWith(
                        fontSize: 16,
                        color: p.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (statusPhase == null ||
                        profile?.nickname.isNotEmpty == true)
                      Text(
                        statusPhase == null
                            ? _activeStatus(member)
                            : '@${profile!.nickname}',
                        style:
                            AppTypography.caption.copyWith(color: p.inkMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(
                _isReady
                    ? Icons.check_circle_rounded
                    : Icons.hourglass_empty_rounded,
                color: _isReady ? p.mint : p.inkMuted,
                size: AppIconSizes.sm,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _activeStatus(MemberModel member) =>
      GroupMemberTodayStatus.resolve(member).label;
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
    final p = context.prime;
    final confirmed =
        group.members.where((m) => m.confirmedParticipation).length;
    final progress = group.maxMembers == 0 ? 0.0 : confirmed / group.maxMembers;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: kitSurfaceDecoration(
        context,
        PrimeSurfaceLevel.accent,
        radius: AppRadius.xl,
        accent: KitAccent.mint,
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
                  color: p.mint.withValues(alpha: 0.14),
                  border: Border.all(color: p.mint.withValues(alpha: 0.4)),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  color: p.mint,
                  size: AppIconSizes.sm,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Команда найдена',
                  style: AppTypography.title2.copyWith(color: p.mint),
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
          _TimezoneContractRow(group: group),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: p.surfaceSoft,
              color: p.mint,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Готовы продолжить: $confirmed/${group.maxMembers}',
            style: AppTypography.caption.copyWith(color: p.inkSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          ...group.members.map(
            (member) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppGroupIntroParticipantTile(
                member: member,
                onTap:
                    member.profile == null ? null : () => onOpenProfile(member),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimezoneContractRow extends StatelessWidget {
  const _TimezoneContractRow({required this.group});

  final GroupModel group;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final teamDay = group.teamDay;
    final tz = teamDay?.referenceTimezone;
    final closesAt = teamDay?.closesAt?.toLocal();
    final label = tz != null && tz.isNotEmpty
        ? closesAt != null
            ? 'Командный день · $tz · закрывается ${_formatCloseTime(closesAt)}'
            : 'Командный день синхронизирован по $tz'
        : 'Отчёты отправляются вечером по командному дню группы';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: p.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule_rounded, size: 18, color: p.brand),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: p.inkSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCloseTime(DateTime closesAt) {
    final h = closesAt.hour.toString().padLeft(2, '0');
    final m = closesAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
    final p = context.prime;
    final profile = member.profile;
    final name = profile?.name.isNotEmpty == true ? profile!.name : 'Участник';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: p.surfaceElevated,
            border: Border.all(color: p.hairline, width: 0.5),
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
                            style: AppTypography.title2.copyWith(color: p.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          member.confirmedParticipation
                              ? Icons.check_circle_rounded
                              : Icons.hourglass_empty_rounded,
                          color: member.confirmedParticipation
                              ? p.mint
                              : p.inkMuted,
                          size: 18,
                        ),
                      ],
                    ),
                    if (profile?.nickname.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@${profile!.nickname}',
                        style: AppTypography.caption.copyWith(
                          color: p.brandSoft,
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
                        style:
                            AppTypography.caption.copyWith(color: p.inkMuted),
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
                        style: AppTypography.bodySecondary.copyWith(
                          color: p.inkSecondary,
                        ),
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

/// Team pact acceptance — V6 supportive contract (replaces shame-based rules).
class AppGroupRulesPanel extends StatelessWidget {
  const AppGroupRulesPanel({super.key});

  static const _principles = [
    'Ежедневный отчёт о сделанном действии — коротко и честно.',
    'Поддержка участников: реакции и слова, которые помогают вернуться в ритм.',
    'Уважительное общение — без политики, религии и сравнения доходов.',
    'Фокус на личном росте, а не на оценке других.',
    'Пропуск дня не означает провал — важно вернуться на следующий.',
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return PrimeContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppCopy.teamPactTitle,
            style: AppTypography.title2.copyWith(color: p.brandSoft),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppCopy.teamPactLead,
            style: AppTypography.bodySecondary.copyWith(color: p.inkSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '5 принципов команды',
            style: AppTypography.title2.copyWith(color: p.brandSoft),
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
                          color: p.brandSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: AppTypography.bodySecondary.copyWith(
                            color: p.inkSecondary,
                          ),
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
              color: p.surfaceSoft,
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: Border.all(color: p.hairline),
            ),
            child: Text(
              AppCopy.teamPactChatGate,
              style: AppTypography.caption.copyWith(color: p.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// End-of-cycle summary before continuation vote (Phase 5).
class AppGroupCycleCompletionPanel extends StatelessWidget {
  const AppGroupCycleCompletionPanel({
    super.key,
    required this.group,
    this.onContinueTogether,
    this.onNewSkill,
    this.onHarder,
    this.onRecovery,
  });

  final GroupModel group;
  final VoidCallback? onContinueTogether;
  final VoidCallback? onNewSkill;
  final VoidCallback? onHarder;
  final VoidCallback? onRecovery;

  int get _cycleDays {
    final start = group.cycleStartAt;
    if (start == null) return 30;
    final days = DateTime.now().difference(start).inDays + 1;
    return days.clamp(1, 30);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final bestStreak =
        group.members.map((m) => m.bestStreak).fold(0, (a, b) => a > b ? a : b);
    return PrimeContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Первый цикл завершён',
            style: AppTypography.title2.copyWith(color: p.mint),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${group.skillName ?? 'Привычка'} · $_cycleDays ${AppCopy.cycleDays}',
            style: AppTypography.caption.copyWith(color: p.inkSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Вы прошли первый цикл вместе. Это результат команды — не только личной силы воли.',
            style: AppTypography.bodySecondary.copyWith(color: p.inkSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CompletionStat(
                label: 'Участников',
                value: '${group.membersCount}',
              ),
              _CompletionStat(
                label: 'Лучшая серия',
                value: '$bestStreak',
              ),
              const _CompletionStat(
                label: 'Цикл',
                value: '30',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (onContinueTogether != null)
            AppPrimaryButton(
              label: 'Продолжить с этой командой',
              icon: Icons.groups_rounded,
              onPressed: onContinueTogether,
            ),
          if (onNewSkill != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppSecondaryButton(
              label: 'Выбрать новую привычку',
              icon: Icons.psychology_alt_outlined,
              onPressed: onNewSkill,
            ),
          ],
          if (onHarder != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppSecondaryButton(
              label: 'Сделать следующий цикл сложнее',
              icon: Icons.trending_up_rounded,
              onPressed: onHarder,
            ),
          ],
          if (onRecovery != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppSecondaryButton(
              label: 'Взять неделю восстановления',
              icon: Icons.spa_outlined,
              onPressed: onRecovery,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            AppCopy.cycleContinuationFootnote,
            style: AppTypography.caption.copyWith(
              color: p.inkSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CompletionStat extends StatelessWidget {
  const _CompletionStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.title1.copyWith(color: p.brand),
        ),
        Text(label, style: AppTypography.caption.copyWith(color: p.inkMuted)),
      ],
    );
  }
}

/// End-of-cycle voting panel.
class AppGroupVotingPanel extends StatelessWidget {
  const AppGroupVotingPanel({
    super.key,
    required this.onContinueTogether,
    required this.onNewSkill,
    required this.onHarder,
    required this.onRecovery,
  });

  final VoidCallback onContinueTogether;
  final VoidCallback onNewSkill;
  final VoidCallback onHarder;
  final VoidCallback onRecovery;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return PrimeContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Итоги 30-дневного цикла',
            style: AppTypography.title2.copyWith(color: p.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppCopy.cycleContinuationFootnote,
            style: AppTypography.caption.copyWith(color: p.inkSecondary),
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
          const SizedBox(height: AppSpacing.xs),
          AppSecondaryButton(
            label: 'Повысить сложность',
            onPressed: onHarder,
          ),
          const SizedBox(height: AppSpacing.xs),
          AppSecondaryButton(
            label: 'Неделя восстановления',
            onPressed: onRecovery,
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
    final p = context.prime;
    final kind = habitArtKindFor(
      '${group.skillId} ${group.skillName ?? group.name}',
    );
    final accent = habitArtAccent(kind);
    final cycleDay = cycleDayFromStart(group.cycleStartAt);
    final progress = cycleDay != null ? (cycleDay / 30).clamp(0.0, 1.0) : null;

    return PrimeContentCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.skillName ?? group.name,
                  style: AppTypography.title1.copyWith(color: p.ink),
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
                      PrimeRadialProgress(
                        progress: progress!,
                        valueLabel: '$cycleDay/30',
                        caption: 'день цикла',
                        size: 68,
                        stroke: 7,
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
                                color: p.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppCopy.cycleDays,
                              style: AppTypography.caption.copyWith(
                                color: p.inkMuted,
                              ),
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
          const SizedBox(width: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Image.asset(
              habitPhotoAsset(kind),
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
        ],
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
                  color: selected ? AppColors.primarySoft : AppColors.textMuted,
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
          minutes:
              (expansion.difference(DateTime.now()).inMinutes).clamp(1, 720),
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
                            borderRadius: BorderRadius.circular(AppRadius.pill),
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
                            borderRadius: BorderRadius.circular(AppRadius.pill),
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
              const HabitArtObject(kind: HabitArtKind.social, size: 48),
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
              color: active ? accent.withValues(alpha: 0.45) : AppColors.border,
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
