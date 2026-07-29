import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/ambient_and_progress.dart';
import '../../../design/visuals/habit_art.dart';
import '../../../models/group.dart';
import '../app_primary_button.dart';

/// Living team formation module — not a generic bordered card.
class AppTeamFormationHero extends StatelessWidget {
  const AppTeamFormationHero({
    super.key,
    required this.title,
    required this.body,
    this.filled = 0,
    this.total = 6,
    this.statusLine,
    this.regionLine,
    this.medianLine,
    this.anonymousSlots = const [],
    this.actionChips = const [],
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.loading = false,
  });

  final String title;
  final String body;
  final int filled;
  final int total;
  final String? statusLine;
  final String? regionLine;
  final String? medianLine;
  final List<WaitingRoomSlot> anonymousSlots;
  final List<AppTeamFormationActionChip> actionChips;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? filled / total : 0.0;
    final useAnonymousSlots = anonymousSlots.isNotEmpty;

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
              AppColors.habitSocial.withValues(alpha: 0.14),
              AppColors.surface,
              AppColors.elevatedSurface,
            ],
          ),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.title1,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        body,
                        style: AppTypography.bodySecondary,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                HabitArtObject(
                  kind: HabitArtKind.social,
                  size: 88,
                ),
              ],
            ),
            if (statusLine != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                statusLine!,
                style: AppTypography.caption.copyWith(
                  color: AppColors.primarySoft,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (regionLine != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                regionLine!,
                style: AppTypography.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (medianLine != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                medianLine!,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                AppProgressRing(
                  progress: progress.clamp(0.0, 1.0),
                  label: '$filled',
                  subtitle: 'из $total',
                  size: 72,
                  stroke: 5,
                  color: AppColors.habitSocial,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (useAnonymousSlots)
                        for (var i = 0; i < total; i++)
                          _AnonymousTeamSlot(
                            slot: i < anonymousSlots.length
                                ? anonymousSlots[i]
                                : null,
                          )
                      else
                        for (var i = 0; i < total; i++)
                          _TeamSlot(filled: i < filled),
                    ],
                  ),
                ),
              ],
            ),
            if (actionChips.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final chip in actionChips)
                    ActionChip(
                      label: Text(
                        chip.label,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      backgroundColor:
                          AppColors.primaryContainer.withValues(alpha: 0.55),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.35),
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: chip.onTap,
                    ),
                ],
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppPrimaryButton(
                label: actionLabel!,
                loading: loading,
                onPressed: onAction,
              ),
            ],
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class AppWaitingRoomEventTicker extends StatefulWidget {
  const AppWaitingRoomEventTicker({super.key, required this.events});

  final List<WaitingRoomEvent> events;

  @override
  State<AppWaitingRoomEventTicker> createState() =>
      _AppWaitingRoomEventTickerState();
}

class _AppWaitingRoomEventTickerState extends State<AppWaitingRoomEventTicker> {
  int _index = 0;

  @override
  void didUpdateWidget(covariant AppWaitingRoomEventTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.events.length) {
      _index = 0;
    }
  }

  String _formatAgo(int seconds) {
    if (seconds < 60) return '$seconds сек назад';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes мин назад';
    final hours = minutes ~/ 60;
    return '$hours ч назад';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) return const SizedBox.shrink();

    final event = widget.events[_index % widget.events.length];
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: widget.events.length > 1
          ? () => setState(() => _index = (_index + 1) % widget.events.length)
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(
              event.type == 'left'
                  ? Icons.logout_rounded
                  : Icons.person_add_alt_1_rounded,
              size: 16,
              color: AppColors.primarySoft,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                '${event.text} · ${_formatAgo(event.agoSeconds)}',
                style: AppTypography.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.events.length > 1)
              Text(
                '${_index + 1}/${widget.events.length}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AppTeamFormationActionChip {
  const AppTeamFormationActionChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;
}

class _TeamSlot extends StatelessWidget {
  const _TeamSlot({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.normal,
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled
            ? AppColors.habitSocial.withValues(alpha: 0.35)
            : AppColors.primaryContainer.withValues(alpha: 0.4),
        border: Border.all(
          color: filled
              ? AppColors.habitSocial.withValues(alpha: 0.7)
              : AppColors.borderStrong,
        ),
      ),
      child: filled
          ? Icon(Icons.person, size: 18, color: AppColors.textPrimary)
          : null,
    );
  }
}

class _AnonymousTeamSlot extends StatelessWidget {
  const _AnonymousTeamSlot({this.slot});

  final WaitingRoomSlot? slot;

  Color _slotColor() {
    if (slot == null) {
      return AppColors.primaryContainer.withValues(alpha: 0.4);
    }
    final hue = (slot!.regionColorSeed % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.45, 0.42).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final filled = slot != null;
    return AnimatedContainer(
      duration: AppDurations.normal,
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled
            ? _slotColor().withValues(alpha: 0.35)
            : AppColors.primaryContainer.withValues(alpha: 0.25),
        border: Border.all(
          color: filled ? _slotColor() : AppColors.borderStrong,
        ),
      ),
      alignment: Alignment.center,
      child: filled
          ? Text(
              slot!.letter,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            )
          : null,
    );
  }
}
