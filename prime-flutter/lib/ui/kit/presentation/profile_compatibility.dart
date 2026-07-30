import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import 'profile_editorial_widgets.dart';
import 'profile_icons.dart';
import 'profile_surfaces.dart';
import 'profile_typography.dart';
import 'profile_view_model.dart';

/// Explainable compatibility — no random percentages (TZ §38.1).
class ProfileCompatibilitySection extends StatelessWidget {
  const ProfileCompatibilitySection({
    super.key,
    required this.compatibility,
  });

  final ProfileCompatibility compatibility;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Совместимость',
          style: ProfileTypography.sectionTitle.copyWith(
            color: ProfilePalette.offWhite,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: ProfileSurfaces.cardDecoration(
            fill: ProfileSurfaces.surfaceTinted,
            radius: 21,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ProfilePalette.primaryAction.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      compatibility.summaryLabel,
                      style: ProfileTypography.cardTitle.copyWith(
                        color: ProfilePalette.offWhite,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (compatibility.reasons.isEmpty)
                Text(
                  'Пока мало данных — начните общаться или пригласите в команду, '
                  'чтобы увидеть совпадения.',
                  style: ProfileTypography.secondary.copyWith(
                    color: ProfilePalette.coolGrey,
                  ),
                )
              else
                ...compatibility.reasons.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _ReasonRow(reason: r),
                  ),
                ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: ProfilePalette.brandSoft,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Как это рассчитано'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileIcon(
          ProfileIcons.cycle,
          size: 18,
          color: ProfilePalette.mint,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            reason,
            style: ProfileTypography.secondary.copyWith(
              color: ProfilePalette.offWhite.withValues(alpha: 0.88),
            ),
          ),
        ),
      ],
    );
  }
}

/// Three compact public stat cards (TZ §37).
class ProfilePublicStatsRow extends StatelessWidget {
  const ProfilePublicStatsRow({super.key, required this.stats});

  final List<ProfilePublicStat> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _StatCard(
              stat: stats[i],
              elevated: i == 1 && stats.length == 3,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat, this.elevated = false});

  final ProfilePublicStat stat;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: elevated ? const Offset(0, -4) : Offset.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: ProfileSurfaces.cardDecoration(
          fill: elevated
              ? ProfileSurfaces.surfaceElevated
              : ProfileSurfaces.surfaceNeutral,
          radius: 16,
          border: elevated ? ProfileSurfaces.outlineStrong : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stat.label,
              style: ProfileTypography.metricLabel.copyWith(
                color: ProfilePalette.coolGrey,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              stat.value,
              style: ProfileTypography.metricValue.copyWith(
                fontSize: 18,
                color: ProfilePalette.offWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status badge for public profile (TZ §37, §38.2).
class ProfileStatusBadge extends StatelessWidget {
  const ProfileStatusBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: ProfilePalette.warmYellow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ProfilePalette.warmYellow.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        label,
        style: ProfileTypography.tag.copyWith(
          color: ProfilePalette.warmYellow,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Metadata rows for public overview (TZ §37).
class ProfileInfoRows extends StatelessWidget {
  const ProfileInfoRows({super.key, required this.rows});

  final List<ProfileInfoRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: ProfileSurfaces.cardDecoration(
        fill: ProfileSurfaces.surfaceNeutral,
        radius: 18,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: ProfileSurfaces.outlineSoft,
                indent: AppSpacing.md,
                endIndent: AppSpacing.md,
              ),
            _InfoRow(row: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.row});

  final ProfileInfoRow row;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            ProfileIcon(row.icon, size: 20, color: ProfilePalette.brandSoft),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                row.label,
                style: ProfileTypography.secondary.copyWith(
                  color: ProfilePalette.coolGrey,
                ),
              ),
            ),
            Flexible(
              child: Text(
                row.value,
                style: ProfileTypography.secondary.copyWith(
                  color: ProfilePalette.offWhite,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
