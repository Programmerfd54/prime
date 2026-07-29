import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/ambient_and_progress.dart';
import '../../../l10n/copy.dart';
import '../profile/app_avatar.dart';
import '../app_icon_button.dart';

/// Profile hero-space — identity + cycle progress.
class AppProfileHero extends StatelessWidget {
  const AppProfileHero({
    super.key,
    required this.name,
    required this.nickname,
    required this.initial,
    this.photoUrl,
    this.about,
    this.streak = 0,
    this.primes = 0,
    this.cycleDay = 0,
    this.onAvatarTap,
    this.onEdit,
  });

  final String name;
  final String nickname;
  final String initial;
  final String? photoUrl;
  final String? about;
  final int streak;
  final int primes;
  final int cycleDay;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onEdit;

  bool get _isNewUser => streak == 0 && primes == 0 && cycleDay == 0;

  @override
  Widget build(BuildContext context) {
    final cycleProgress =
        cycleDay > 0 ? cycleDay / 30.0 : (streak / 30.0).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.heroSurfaceStart,
              AppColors.surface,
            ],
          ),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Stack(
          children: [
            if (onEdit != null)
              Positioned(
                top: 0,
                right: 0,
                child: AppIconButton(
                  tooltip: 'Редактировать профиль',
                  icon: Icons.edit_outlined,
                  onPressed: onEdit,
                ),
              ),
            Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AppProgressRing(
                      progress: _isNewUser ? 0.08 : cycleProgress.clamp(0.0, 1.0),
                      label: '',
                      size: 128,
                      stroke: 4,
                      center: const SizedBox.shrink(),
                    ),
                    AppAvatar(
                      photoUrl: photoUrl,
                      radius: 48,
                      name: name.isNotEmpty ? name : nickname,
                      onTap: onAvatarTap,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  name.isNotEmpty ? name : '@$nickname',
                  style: AppTypography.largeTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (nickname.isNotEmpty && name.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '@$nickname',
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (about != null && about!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    about!,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySecondary,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                if (_isNewUser)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.accentSurface.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Начните первый цикл',
                          style: AppTypography.title2.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        const Text(
                          'Выберите привычку, найдите команду и отправьте первый отчёт',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _HeroStat(value: '$streak', label: AppCopy.streak),
                      _HeroStat(value: '$primes', label: AppCopy.primes),
                      _HeroStat(
                        value: cycleDay > 0 ? '$cycleDay/30' : '—',
                        label: 'Цикл',
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTypography.title1),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}
