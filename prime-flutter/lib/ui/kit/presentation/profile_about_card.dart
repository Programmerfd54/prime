import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../components/app_primary_button.dart';
import 'profile_editorial_widgets.dart';
import 'profile_icons.dart';
import 'profile_surfaces.dart';
import 'profile_typography.dart';
import 'profile_view_model.dart';

/// Rich «О себе» card with 2×2 facts grid (TZ §35).
class ProfileAboutCard extends StatelessWidget {
  const ProfileAboutCard({
    super.key,
    required this.data,
    this.onEdit,
    this.onFillProfile,
  });

  final ProfileAboutData data;
  final VoidCallback? onEdit;
  final VoidCallback? onFillProfile;

  @override
  Widget build(BuildContext context) {
    if (!data.hasVisibleContent && !data.isOwner) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: ProfileSurfaces.cardDecoration(
        fill: ProfileSurfaces.surfaceElevated,
        radius: 21,
        border: ProfileSurfaces.outlineStrong,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('О себе', style: _title()),
              const Spacer(),
              if (data.isOwner && onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  icon: ProfileIcon(ProfileIcons.edit, size: 20),
                  tooltip: 'Редактировать',
                )
              else if (!data.isOwner && data.isPartiallyPrivate)
                Text(
                  'Частично скрыто',
                  style: ProfileTypography.metricLabel.copyWith(
                    color: ProfilePalette.coolGrey,
                  ),
                ),
            ],
          ),
          if (data.isOwner && data.completenessPercent < 100) ...[
            const SizedBox(height: AppSpacing.xs),
            _CompletenessStrip(percent: data.completenessPercent),
          ],
          if (data.bio?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              data.bio!,
              style: ProfileTypography.bio.copyWith(
                color: ProfilePalette.offWhite.withValues(alpha: 0.92),
              ),
            ),
          ],
          if (data.currentFocus?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.md),
            _FocusBlock(
              focus: data.currentFocus!,
              habit: data.currentHabit,
              goal: data.cycleGoal,
            ),
          ],
          if (data.facts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _FactsGrid(facts: data.facts.take(4).toList()),
          ],
          if (data.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ProfileHabitTagsRow(tags: data.tags.take(4).toList()),
          ],
          if (data.teamStatus?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.sm),
            _TeamStatusChip(label: data.teamStatus!),
          ],
          if (data.isOwner && !data.hasVisibleContent) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Расскажите, какой ритм и поддержка вам подходят',
              style: ProfileTypography.secondary.copyWith(
                color: ProfilePalette.coolGrey,
              ),
            ),
            if (onFillProfile != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppPrimaryButton(
                label: 'Заполнить профиль',
                onPressed: onFillProfile,
              ),
            ],
          ],
        ],
      ),
    );
  }

  TextStyle _title() => ProfileTypography.sectionTitle.copyWith(
        color: ProfilePalette.offWhite,
        fontSize: 20,
      );
}

class _CompletenessStrip extends StatelessWidget {
  const _CompletenessStrip({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Профиль заполнен на $percent%',
          style: ProfileTypography.metricLabel.copyWith(
            color: ProfilePalette.brandSoft,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 5,
            backgroundColor: ProfilePalette.coolGrey.withValues(alpha: 0.15),
            color: ProfilePalette.brandSoft,
          ),
        ),
      ],
    );
  }
}

class _FocusBlock extends StatelessWidget {
  const _FocusBlock({
    required this.focus,
    this.habit,
    this.goal,
  });

  final String focus;
  final String? habit;
  final String? goal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: ProfileSurfaces.surfaceTinted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ProfileSurfaces.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Сейчас мой фокус',
            style: ProfileTypography.metricLabel.copyWith(
              color: ProfilePalette.brandSoft,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            focus,
            style: ProfileTypography.cardTitle.copyWith(
              color: ProfilePalette.offWhite,
              fontSize: 16,
            ),
          ),
          if (habit?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              'Привычка: $habit',
              style: ProfileTypography.secondary.copyWith(
                color: ProfilePalette.coolGrey,
              ),
            ),
          ],
          if (goal?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(
              goal!,
              style: ProfileTypography.secondary.copyWith(
                color: ProfilePalette.coolGrey,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FactsGrid extends StatelessWidget {
  const _FactsGrid({required this.facts});

  final List<ProfileAboutFact> facts;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.xs,
      crossAxisSpacing: AppSpacing.xs,
      childAspectRatio: 2.35,
      children: [
        for (final fact in facts) _FactCell(fact: fact),
      ],
    );
  }
}

class _FactCell extends StatelessWidget {
  const _FactCell({required this.fact});

  final ProfileAboutFact fact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: ProfileSurfaces.surfaceTinted.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProfileSurfaces.outlineStrong),
      ),
      child: Row(
        children: [
          ProfileIcon(fact.icon, size: 18, color: fact.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  fact.label,
                  style: ProfileTypography.metricLabel.copyWith(
                    color: ProfilePalette.coolGrey.withValues(alpha: 0.92),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  fact.value,
                  style: ProfileTypography.secondary.copyWith(
                    color: ProfilePalette.offWhite,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamStatusChip extends StatelessWidget {
  const _TeamStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: ProfileSurfaces.surfaceSuccess.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: ProfilePalette.mint.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          label,
          style: ProfileTypography.tag.copyWith(color: ProfilePalette.mint),
        ),
      ),
    );
  }
}
