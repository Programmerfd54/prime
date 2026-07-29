import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/theme/prime_theme_context.dart';
import '../../kit/presentation/profile_editorial_widgets.dart';
import '../../kit/presentation/profile_sections.dart';
import '../../kit/tokens/kit_surfaces.dart';

/// Public profile hero — read-only identity block.
@Deprecated('Use ProfileHeroCard with ProfileHeroMode.public instead.')
class AppPublicProfileHero extends StatelessWidget {
  const AppPublicProfileHero({
    super.key,
    required this.name,
    required this.nickname,
    this.photoUrl,
    this.location,
  });

  final String name;
  final String nickname;
  final String? photoUrl;
  final String? location;

  @override
  Widget build(BuildContext context) {
    final displayName = name.isNotEmpty ? name : '@$nickname';
    return ProfileHeroCard(
      displayName: displayName,
      subtitle: location,
      photoUrl: photoUrl,
      mode: ProfileHeroMode.public,
      onBack: () => Navigator.maybePop(context),
    );
  }
}

/// Bento-style public metrics — editorial pill row.
class AppPublicProfileMetrics extends StatelessWidget {
  const AppPublicProfileMetrics({
    super.key,
    this.primes,
    this.successfulDays,
    this.onHero = false,
  });

  final int? primes;
  final int? successfulDays;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final metrics = buildPublicProfileMetrics(
      primes: primes,
      successfulDays: successfulDays,
    );
    if (metrics.isEmpty) return const SizedBox.shrink();
    return ProfileMetricPillsRow(metrics: metrics, onHero: onHero);
  }
}

/// About section for public profiles.
@Deprecated('Bio is shown in ProfileHeroCard.')
class AppPublicProfileAbout extends StatelessWidget {
  const AppPublicProfileAbout({super.key, required this.about});

  final String about;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Shared context — what you have in common with this person.
class AppPublicProfileSharedCard extends StatelessWidget {
  const AppPublicProfileSharedCard({
    super.key,
    this.sharedHabits = const [],
    this.sharedGroups = const [],
  });

  final List<String> sharedHabits;
  final List<String> sharedGroups;

  @override
  Widget build(BuildContext context) {
    if (sharedHabits.isEmpty && sharedGroups.isEmpty) {
      return const SizedBox.shrink();
    }
    return ProfileSharedContextSection(
      sharedHabits: sharedHabits,
      sharedGroups: sharedGroups,
    );
  }
}

/// Group context status — report + rules acceptance.
class AppPublicProfileGroupStatus extends StatelessWidget {
  const AppPublicProfileGroupStatus({
    super.key,
    required this.reportReady,
    this.acceptedRules,
  });

  final bool reportReady;
  final bool? acceptedRules;

  @override
  Widget build(BuildContext context) {
    final p = context.prime;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: kitSurfaceDecoration(
        context,
        PrimeSurfaceLevel.solid,
      ).copyWith(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (reportReady ? AppColors.success : AppColors.textMuted)
                  .withValues(alpha: 0.14),
            ),
            child: Icon(
              reportReady
                  ? Icons.task_alt_rounded
                  : Icons.radio_button_unchecked,
              color: reportReady ? AppColors.success : AppColors.textMuted,
              size: AppIconSizes.sm,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reportReady
                      ? 'Отчёт за сегодня готов'
                      : 'Отчёт за сегодня не готов',
                  style: AppTypography.title2.copyWith(fontSize: 16),
                ),
                if (acceptedRules != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    acceptedRules == true
                        ? 'Правила приняты'
                        : 'Правила ещё не приняты',
                    style: AppTypography.caption.copyWith(color: p.inkMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
