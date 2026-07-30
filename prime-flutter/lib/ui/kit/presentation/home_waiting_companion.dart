import 'package:flutter/material.dart';

import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/charts/prime_radial_progress.dart';
import '../../../models/group.dart';
import '../components/prime_content_card.dart';
import '../tokens/kit_layout.dart';
import '../tokens/kit_typography.dart';

/// V5 home companion while searching for a team.
class HomeWaitingCompanion extends StatelessWidget {
  const HomeWaitingCompanion({
    super.key,
    required this.skillName,
    required this.peopleWaiting,
    required this.needed,
    this.regionSearching = 0,
    this.skillSearching = 0,
    this.onlineInPool = 0,
    this.regionLabel = 'вашем городе',
    this.scopeIsRussia = false,
    this.onOpenGroups,
    this.onOpenChats,
    this.onFindFriends,
    this.showFriendsCta = false,
  });

  final String skillName;
  final int peopleWaiting;
  final int needed;
  final int regionSearching;
  final int skillSearching;
  final int onlineInPool;
  final String regionLabel;
  final bool scopeIsRussia;
  final VoidCallback? onOpenGroups;
  final VoidCallback? onOpenChats;
  final VoidCallback? onFindFriends;
  final bool showFriendsCta;

  static const _prepItems = [
    'Заполните «О себе» — команда увидит вас в подборе',
    'Выберите удобное окно дня в настройках',
    'Пригласите друга — он попадёт в вашу очередь',
  ];

  static const _motivationQuotes = [
    'Шестёрка держит ритм: когда отчитываются все, серия не срывается.',
    'Маленькие ежедневные шаги в команде дают больше, чем редкие рывки в одиночку.',
    'Поддержка команды снимает нагрузку «делать идеально» — достаточно быть в процессе.',
  ];

  String get _quote =>
      _motivationQuotes[DateTime.now().day % _motivationQuotes.length];

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final progress = needed > 0 ? peopleWaiting / needed : 0.0;
    final scope = scopeIsRussia ? 'Вся Россия' : 'Мой город';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimeContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Поиск в $regionLabel',
                style: KitTypography.sectionTitle.copyWith(color: p.ink),
              ),
              const SizedBox(height: 4),
              Text(
                '$scope · $skillSearching ищут «$skillName» · онлайн $onlineInPool',
                style: KitTypography.caption.copyWith(color: p.inkSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  PrimeRadialProgress(
                    progress: progress,
                    valueLabel: '$peopleWaiting/$needed',
                    size: 68,
                    stroke: 7,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'В регионе сейчас $regionSearching человек в очереди. '
                      'Поиск идёт в фоне — можно закрыть экран.',
                      style: KitTypography.bodySecondary.copyWith(color: p.inkSecondary),
                    ),
                  ),
                ],
              ),
              if (onOpenGroups != null) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: onOpenGroups,
                  child: const Text('Открыть экран групп'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimeContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Пока ждёте',
                style: KitTypography.sectionTitle.copyWith(color: p.ink),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final item in _prepItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline, size: 18, color: p.brand),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          item,
                          style: AppTypography.bodySecondary.copyWith(color: p.inkSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimeContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Почему шестёрка работает',
                style: KitTypography.cardTitle.copyWith(color: p.ink),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _quote,
                style: AppTypography.bodySecondary.copyWith(color: p.inkSecondary),
              ),
            ],
          ),
        ),
        if (showFriendsCta && onFindFriends != null) ...[
          const SizedBox(height: AppSpacing.md),
          PrimeContentCard(
            onTap: onFindFriends,
            child: Row(
              children: [
                Icon(Icons.people_outline, color: p.brand),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Добавьте друзей и двигайтесь вместе',
                        style: KitTypography.cardTitle.copyWith(color: p.ink, fontSize: 15),
                      ),
                      Text(
                        'Найдите человека по никнейму',
                        style: KitTypography.caption.copyWith(color: p.inkMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.inkMuted),
              ],
            ),
          ),
        ],
        if (onOpenChats != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onOpenChats,
            child: Text(
              'Перейти в чаты',
              style: AppTypography.button.copyWith(color: p.brand),
            ),
          ),
        ],
        SizedBox(height: KitLayout.dockScrollTail(context)),
      ],
    );
  }
}

/// Vertical search timeline for groups V5.
class GateGroupsVerticalTimeline extends StatelessWidget {
  const GateGroupsVerticalTimeline({super.key, required this.status});

  final WaitingRoomStatus status;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final steps = <_TimelineStep>[
      const _TimelineStep(
        title: 'Сейчас',
        body: 'Ищем участников в вашем регионе',
        active: true,
        done: true,
      ),
      _TimelineStep(
        title: 'Расширение',
        body: status.allowOtherRegions
            ? 'Поиск по всей России'
            : status.canExpandSearch
                ? 'Можно расширить на всю Россию'
                : _expansionCaption(status),
        active: status.canExpandSearch || status.allowOtherRegions,
        done: status.allowOtherRegions,
      ),
      _TimelineStep(
        title: 'Сбор команды',
        body: status.earlyStartConfirmedCount > 0
            ? '${status.earlyStartConfirmedCount} из ${status.earlyStartNeededConfirmations} '
                'подтвердили ранний старт'
            : status.canStartEarly
                ? 'В очереди 3+ — можно стартовать втроём или ждать полную шестёрку'
                : '${status.peopleWaiting} из ${status.needed > 0 ? status.needed : 6} в очереди',
        active: status.peopleWaiting > 0 || status.canStartEarly,
        done: status.canStartEarly && status.earlyStartConfirmedCount == 0,
      ),
      const _TimelineStep(
        title: 'Подтверждение',
        body: 'Все шесть подтверждают участие',
        active: false,
        done: false,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _VerticalStepRow(
            step: steps[i],
            isLast: i == steps.length - 1,
            accent: p.brand,
            muted: p.inkMuted,
            ink: p.ink,
          ),
      ],
    );
  }

  static String _expansionCaption(WaitingRoomStatus status) {
    final at = status.expansionAvailableAt;
    if (at == null) return 'Поиск по всей России через 5 минут';
    final diff = at.difference(DateTime.now());
    if (diff.isNegative) return 'Скоро расширим поиск на всю Россию';
    final min = diff.inMinutes;
    final sec = diff.inSeconds % 60;
    if (min >= 1) return 'Поиск по всей России через $min мин';
    if (sec > 0) return 'Поиск по всей России через $sec сек';
    return 'Скоро расширим поиск на всю Россию';
  }
}

class _TimelineStep {
  const _TimelineStep({
    required this.title,
    required this.body,
    required this.active,
    required this.done,
  });

  final String title;
  final String body;
  final bool active;
  final bool done;
}

class _VerticalStepRow extends StatelessWidget {
  const _VerticalStepRow({
    required this.step,
    required this.isLast,
    required this.accent,
    required this.muted,
    required this.ink,
  });

  final _TimelineStep step;
  final bool isLast;
  final Color accent;
  final Color muted;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final dotColor = step.done
        ? accent
        : step.active
            ? accent.withValues(alpha: 0.85)
            : muted.withValues(alpha: 0.35);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: step.active ? accent : muted.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: muted.withValues(alpha: 0.25),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: KitTypography.cardTitle.copyWith(color: ink, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.body,
                    style: KitTypography.caption.copyWith(color: muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
