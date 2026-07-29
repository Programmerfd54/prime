import 'package:flutter/material.dart';

import '../design/glass.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../design/visuals/habit_art.dart';

class TournamentsScreen extends StatelessWidget {
  final VoidCallback onShowMessage;

  const TournamentsScreen({
    super.key,
    required this.onShowMessage,
  });

  static const _mockLeaderboard = [
    ('Аня К.', 128),
    ('Игорь М.', 114),
    ('Вы', 96),
    ('Мила С.', 88),
    ('Саша П.', 72),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Турниры'),
        backgroundColor: AppColors.background,
      ),
      body: AmbientCanvas(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.bottomNavClearance,
          ),
          children: [
            Text(
              'Турниры',
              style: AppTypography.largeTitle.copyWith(fontSize: 28),
            ),
            const SizedBox(height: AppSpacing.lg),
            GlassContainer(
              padding: const EdgeInsets.all(AppSpacing.lg),
              borderRadius: BorderRadius.circular(AppRadius.bentoOuter),
              fillOpacity: 0.06,
              glow: AppGlow.violet(opacity: 0.15),
              child: Column(
                children: [
                  const HabitArtObject(kind: HabitArtKind.generic, size: 96),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Сезон «Весенний ритм»',
                    style: AppTypography.title1,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Рейтинг по Праймам за 30 дней — без токсичного соревнования.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Лидерборд (демо)', style: AppTypography.title2),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < _mockLeaderboard.length; i++)
              GlassContainer(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                fillOpacity: i == 2 ? 0.08 : 0.04,
                glow: i == 2 ? AppGlow.violet(opacity: 0.12) : null,
                child: Row(
                  children: [
                    Text(
                      '${i + 1}',
                      style: AppTypography.title2.copyWith(
                        color: AppColors.primarySoft,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        _mockLeaderboard[i].$1,
                        style: AppTypography.body,
                      ),
                    ),
                    Text(
                      '${_mockLeaderboard[i].$2} ⭐',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: onShowMessage,
              child: const Text('Уведомить о старте'),
            ),
          ],
        ),
      ),
    );
  }
}
