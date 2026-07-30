import 'package:flutter/material.dart';

import '../design/theme/prime_theme_context.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../design/visuals/habit_art.dart';
import '../ui/kit/components/prime_content_card.dart';

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
    final p = context.prime;
    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        title: Text('Турниры', style: TextStyle(color: p.ink)),
        backgroundColor: p.canvas,
        surfaceTintColor: Colors.transparent,
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
              style: AppTypography.largeTitle.copyWith(
                fontSize: 28,
                color: p.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimeContentCard(
              child: Column(
                children: [
                  const HabitArtObject(kind: HabitArtKind.generic, size: 96),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Сезон «Весенний ритм»',
                    style: AppTypography.title1.copyWith(color: p.ink),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Рейтинг по Праймам за 30 дней — без токсичного соревнования.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySecondary.copyWith(color: p.inkSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Лидерборд (демо)', style: AppTypography.title2.copyWith(color: p.ink)),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < _mockLeaderboard.length; i++)
              PrimeContentCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Text(
                      '${i + 1}',
                      style: AppTypography.title2.copyWith(
                        color: i == 2 ? p.brandSoft : p.inkMuted,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        _mockLeaderboard[i].$1,
                        style: AppTypography.body.copyWith(
                          color: i == 2 ? p.ink : p.inkSecondary,
                          fontWeight: i == 2 ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${_mockLeaderboard[i].$2}',
                      style: AppTypography.title2.copyWith(color: p.brandSoft),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: onShowMessage,
              style: OutlinedButton.styleFrom(
                foregroundColor: p.brand,
                side: BorderSide(color: p.hairlineStrong),
                minimumSize: const Size.fromHeight(AppControlHeights.button),
              ),
              child: const Text('Уведомить о старте'),
            ),
          ],
        ),
      ),
    );
  }
}
