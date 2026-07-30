import 'package:flutter/material.dart';

import '../../../core/profile/profile_preferences.dart';
import '../../../models/group.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/charts/prime_radial_progress.dart';
import '../components/prime_content_card.dart';
import '../tokens/kit_layout.dart';
import '../tokens/kit_typography.dart';
import 'home_waiting_companion.dart';

/// V5 groups search presentation — hero, scope toggle, vertical timeline.
class GateGroupsPresentation extends StatelessWidget {
  const GateGroupsPresentation({
    super.key,
    required this.habitName,
    this.found = 1,
    this.total = 6,
    this.confirmedCount,
    this.scopeLabel = 'По всей России',
    this.regionSearching = 0,
    this.skillSearching = 0,
    this.onlineInPool = 0,
    this.scopeIsRussia = true,
    this.canExpandSearch = false,
    this.expansionAvailableAt,
    this.expanding = false,
    this.status,
    this.checklist = const [],
    this.onExpandSearch,
    this.onStopSearch,
    this.onScopeCity,
    this.onScopeRussia,
    this.onChecklistTap,
    this.onEarlyStart,
    this.startingEarlyStart = false,
    this.showPageHeader = true,
  });

  final String habitName;
  final int found;
  final int total;
  final int? confirmedCount;
  final String scopeLabel;
  final int regionSearching;
  final int skillSearching;
  final int onlineInPool;
  final bool scopeIsRussia;
  final bool canExpandSearch;
  final DateTime? expansionAvailableAt;
  final bool expanding;
  final WaitingRoomStatus? status;
  final List<GateReadinessItem> checklist;
  final VoidCallback? onExpandSearch;
  final VoidCallback? onStopSearch;
  final VoidCallback? onScopeCity;
  final VoidCallback? onScopeRussia;
  final ValueChanged<GateReadinessItem>? onChecklistTap;
  final VoidCallback? onEarlyStart;
  final bool startingEarlyStart;
  final bool showPageHeader;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showPageHeader) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Мои группы',
                  style: AppTypography.pageTitle.copyWith(color: p.ink, fontSize: 28),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Команда из шести — ритм, поддержка и общий прогресс',
                  style: AppTypography.bodySecondary.copyWith(color: p.inkSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: PrimeContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ищем команду',
                  style: KitTypography.caption.copyWith(color: p.brand),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  habitName,
                  style: KitTypography.sectionTitle.copyWith(color: p.ink),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                _ScopeToggle(
                  scopeIsRussia: scopeIsRussia,
                  regionSearching: regionSearching,
                  skillSearching: skillSearching,
                  onScopeCity: onScopeCity,
                  onScopeRussia: onScopeRussia,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    PrimeRadialProgress(
                      progress: found / total,
                      valueLabel: '$found/$total',
                      size: 76,
                      stroke: 8,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Найдено $found из $total',
                            style: KitTypography.cardTitle.copyWith(color: p.ink),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$skillSearching ищут эту привычку · онлайн $onlineInPool',
                            style: KitTypography.caption.copyWith(color: p.inkMuted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (confirmedCount != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              '$confirmedCount/$total подтвердили участие',
                              style: KitTypography.caption.copyWith(color: p.mint),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _GateTeamSlotsRow(
                  total: total,
                  filled: found,
                  slots: status?.slots ?? const [],
                ),
                if (status?.canStartEarly == true) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _EarlyStartPanel(
                    waitingOthers: status!.earlyStartWaitingOthers,
                    pendingOthers: status!.earlyStartPending,
                    confirmedCount: status!.earlyStartConfirmedCount,
                    neededConfirmations: status!.earlyStartNeededConfirmations,
                    loading: startingEarlyStart,
                    onStart: onEarlyStart,
                  ),
                ] else if (status?.inQueue == true) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const _TeamSizeMotivationHint(),
                ],
                const SizedBox(height: AppSpacing.md),
                if (status != null) GateGroupsVerticalTimeline(status: status!),
                const SizedBox(height: AppSpacing.md),
                _ExpandRow(
                  canExpand: canExpandSearch,
                  expanding: expanding,
                  expansionAvailableAt: expansionAvailableAt,
                  scopeIsRussia: scopeIsRussia || (status?.allowOtherRegions ?? false),
                  regionSearching: regionSearching,
                  onExpand: onExpandSearch,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onStopSearch,
                        child: const Text('Остановить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: PrimeContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Что ускорит подбор',
                  style: KitTypography.sectionTitle.copyWith(color: p.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  'Каждый пункт повышает шанс собрать совместимую команду.',
                  style: KitTypography.caption.copyWith(color: p.inkSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...checklist.map(
                  (item) => _ChecklistRow(
                    item: item,
                    onTap: item.actionLabel != null || !item.done
                        ? () => onChecklistTap?.call(item)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: KitLayout.dockScrollTail(context)),
      ],
    );
  }
}

class _ScopeToggle extends StatelessWidget {
  const _ScopeToggle({
    required this.scopeIsRussia,
    required this.regionSearching,
    required this.skillSearching,
    this.onScopeCity,
    this.onScopeRussia,
  });

  final bool scopeIsRussia;
  final int regionSearching;
  final int skillSearching;
  final VoidCallback? onScopeCity;
  final VoidCallback? onScopeRussia;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ScopeChip(
              label: 'Мой город',
              count: regionSearching,
              selected: !scopeIsRussia,
              onTap: onScopeCity,
            ),
          ),
          Expanded(
            child: _ScopeChip(
              label: 'Вся Россия',
              count: skillSearching,
              selected: scopeIsRussia,
              onTap: onScopeRussia,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.count,
    required this.selected,
    this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Material(
      color: selected ? p.brandContainer.withValues(alpha: 0.55) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: KitTypography.caption.copyWith(
                  color: selected ? p.brand : p.inkSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '$count чел.',
                style: KitTypography.caption.copyWith(color: p.inkMuted, fontSize: 11),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandRow extends StatelessWidget {
  const _ExpandRow({
    required this.canExpand,
    required this.expanding,
    required this.scopeIsRussia,
    required this.regionSearching,
    this.expansionAvailableAt,
    this.onExpand,
  });

  final bool canExpand;
  final bool expanding;
  final bool scopeIsRussia;
  final int regionSearching;
  final DateTime? expansionAvailableAt;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    if (scopeIsRussia) {
      return Text(
        'Поиск уже идёт по всей России',
        style: KitTypography.caption.copyWith(color: p.inkMuted),
      );
    }
    if (canExpand && onExpand != null) {
      final lowPool = regionSearching < 3;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lowPool)
            Text(
              'В городе мало людей — можно расширить поиск раньше',
              style: KitTypography.caption.copyWith(color: p.inkSecondary),
            ),
          FilledButton(
            onPressed: expanding ? null : onExpand,
            child: expanding
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Расширить\nна всю Россию'),
          ),
        ],
      );
    }
    final at = expansionAvailableAt;
    if (at != null) {
      final diff = at.difference(DateTime.now());
      final label = diff.isNegative
          ? 'Скоро расширим поиск на всю Россию'
          : _formatExpansionCountdown(diff);
      return Text(
        label,
        style: KitTypography.caption.copyWith(color: p.inkMuted),
        maxLines: 2,
      );
    }
    return Text(
      'Поиск по всей России начнётся через 5 минут',
      style: KitTypography.caption.copyWith(color: p.inkMuted),
      maxLines: 2,
    );
  }
}

String _formatExpansionCountdown(Duration diff) {
  if (diff.isNegative) return 'Скоро расширим поиск на всю Россию';
  final min = diff.inMinutes;
  final sec = diff.inSeconds % 60;
  if (min >= 1) return 'Поиск по всей России через $min мин';
  if (sec > 0) return 'Поиск по всей России через $sec сек';
  return 'Скоро расширим поиск на всю Россию';
}

/// Maps live waiting-room state to V5 gate checklist rows.
List<GateReadinessItem> gateReadinessFromProfile({
  required bool aboutReady,
  Map<String, dynamic>? preferences,
}) {
  final rhythmReady = ProfilePreferences.rhythmSupportReady(preferences);
  return [
    GateReadinessItem(
      title: 'О себе',
      subtitle: aboutReady
          ? 'Заполнено — команда видит вас'
          : 'Кратко расскажите о себе',
      done: aboutReady,
      actionLabel: aboutReady ? 'Изменить' : 'Заполнить',
    ),
    GateReadinessItem(
      title: 'Ритм и поддержка',
      subtitle: ProfilePreferences.rhythmSupportSummary(preferences),
      done: rhythmReady,
      actionLabel: rhythmReady ? 'Изменить' : 'Выбрать',
    ),
    const GateReadinessItem(
      title: 'Пригласить друга',
      subtitle: 'Добавляет конкретного участника',
      done: false,
      actionLabel: 'Пригласить',
    ),
  ];
}

class GateReadinessItem {
  const GateReadinessItem({
    required this.title,
    required this.subtitle,
    required this.done,
    this.actionLabel,
  });

  final String title;
  final String subtitle;
  final bool done;
  final String? actionLabel;
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.item, this.onTap});

  final GateReadinessItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: item.done
            ? p.mint.withValues(alpha: 0.08)
            : p.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: item.done
                        ? p.mint.withValues(alpha: 0.18)
                        : p.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: item.done ? p.mint : p.hairline,
                    ),
                  ),
                  child: Icon(
                    item.done ? Icons.check_rounded : Icons.circle_outlined,
                    color: item.done ? p.mint : p.inkMuted,
                    size: 16,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: KitTypography.listTitle.copyWith(color: p.ink),
                      ),
                      Text(
                        item.subtitle,
                        style: KitTypography.caption.copyWith(color: p.inkSecondary),
                      ),
                    ],
                  ),
                ),
                if (item.actionLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: p.brandContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.actionLabel!,
                      style: KitTypography.caption.copyWith(
                        color: p.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Six-slot team grid during search — V6 pre-start visibility (Phase 3).
class _GateTeamSlotsRow extends StatelessWidget {
  const _GateTeamSlotsRow({
    required this.total,
    required this.filled,
    required this.slots,
  });

  final int total;
  final int filled;
  final List<WaitingRoomSlot> slots;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final count = total > 0 ? total : 6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Слоты команды',
          style: KitTypography.caption.copyWith(
            color: p.inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (var i = 0; i < count; i++)
              _GateTeamSlotChip(
                letter: i < slots.length ? slots[i].letter : null,
                filled: i < (slots.isNotEmpty ? slots.length : filled),
                index: i,
              ),
          ],
        ),
      ],
    );
  }
}

class _GateTeamSlotChip extends StatelessWidget {
  const _GateTeamSlotChip({
    required this.filled,
    required this.index,
    this.letter,
  });

  final bool filled;
  final int index;
  final String? letter;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    final label = filled ? (letter ?? String.fromCharCode(65 + index)) : '${index + 1}';
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? p.brandContainer.withValues(alpha: 0.65) : p.surfaceSoft,
        shape: BoxShape.circle,
        border: Border.all(
          color: filled ? p.brand.withValues(alpha: 0.45) : p.hairline,
          width: filled ? 1.5 : 1,
        ),
      ),
      child: Text(
        label,
        style: KitTypography.caption.copyWith(
          color: filled ? p.brand : p.inkMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EarlyStartPanel extends StatelessWidget {
  const _EarlyStartPanel({
    required this.waitingOthers,
    required this.pendingOthers,
    required this.confirmedCount,
    required this.neededConfirmations,
    required this.loading,
    this.onStart,
  });

  final bool waitingOthers;
  final bool pendingOthers;
  final int confirmedCount;
  final int neededConfirmations;
  final bool loading;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    if (waitingOthers) {
      final remaining = (neededConfirmations - confirmedCount).clamp(1, neededConfirmations);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: p.brandContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: p.brand.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.hourglass_top_rounded, size: 18, color: p.brand),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Вы подтвердили ранний старт. Ждём ещё $remaining '
                '${remaining == 1 ? 'подтверждение' : 'подтверждения'} в очереди.',
                style: KitTypography.caption.copyWith(
                  color: p.inkSecondary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (pendingOthers && onStart != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: p.warningContainer.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: p.warning.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.groups_outlined, size: 18, color: p.warning),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    confirmedCount >= neededConfirmations - 1
                        ? '$confirmedCount из $neededConfirmations подтвердили — осталось ваше подтверждение.'
                        : '$confirmedCount из $neededConfirmations подтвердили ранний старт. '
                            'Кто-то предложил старт втроём — подтвердите, чтобы начать.',
                    style: KitTypography.caption.copyWith(
                      color: p.inkSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: loading ? null : onStart,
              style: OutlinedButton.styleFrom(
                foregroundColor: p.warning,
                side: BorderSide(color: p.warning.withValues(alpha: 0.65)),
              ),
              child: loading
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: p.warning,
                      ),
                    )
                  : const Text('Подтвердить старт втроём'),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: p.errorContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: p.error.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.groups_outlined, size: 18, color: p.error),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  confirmedCount > 0
                      ? '$confirmedCount из $neededConfirmations подтвердили ранний старт.'
                      : 'В очереди 3+ человека. Можете начать втроём, не дожидаясь полной шестёрки.',
                  style: KitTypography.caption.copyWith(
                    color: p.inkSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: loading ? null : onStart,
            style: OutlinedButton.styleFrom(
              foregroundColor: p.error,
              side: BorderSide(color: p.error.withValues(alpha: 0.65)),
            ),
            child: loading
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.error,
                    ),
                  )
                : const Text('Старт втроём'),
          ),
        ],
      ),
    );
  }
}

class _TeamSizeMotivationHint extends StatelessWidget {
  const _TeamSizeMotivationHint();

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: p.errorContainer.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: p.error.withValues(alpha: 0.42)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: p.error),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Старт возможен от 3 человек, но для поддержания мотивации '
              'лучше полная команда из 6.',
              style: KitTypography.caption.copyWith(
                color: p.error.withValues(alpha: 0.92),
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
