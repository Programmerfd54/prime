import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import 'profile_editorial_widgets.dart';
import 'profile_typography.dart';

/// Responsive profile dashboard layout (TZ §16).
class ProfilePageLayout extends StatelessWidget {
  const ProfilePageLayout({
    super.key,
    required this.hero,
    required this.sections,
    this.expandedMaxWidth = 1200,
  });

  final Widget hero;
  final Widget sections;
  final double expandedMaxWidth;

  static const mediumBreakpoint = 600.0;
  static const expandedBreakpoint = 1024.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= expandedBreakpoint) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: expandedMaxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: hero),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(flex: 9, child: sections),
                  ],
                ),
              ),
            ),
          );
        }
        if (width >= mediumBreakpoint) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ProfileHeroCard.maxContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  hero,
                  sections,
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hero,
            sections,
          ],
        );
      },
    );
  }
}

/// Shown when participant hid most profile fields (TZ §14).
class ProfileRestrictedBanner extends StatelessWidget {
  const ProfileRestrictedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ProfilePalette.charcoal,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ProfilePalette.coolGrey.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            color: ProfilePalette.coolGrey.withValues(alpha: 0.85),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Участник ограничил видимость профиля',
              style: ProfileTypography.secondary.copyWith(
                color: ProfilePalette.offWhite.withValues(alpha: 0.88),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
