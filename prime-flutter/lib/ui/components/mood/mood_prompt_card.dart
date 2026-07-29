import 'package:flutter/material.dart';

import '../../../core/mood/mood_state.dart';
import '../cards/prime_action_card.dart';
import 'mood_check_sheet.dart';
import 'mood_creature.dart';

/// Dashboard CTA — opens mood check-in and returns selected mood.
class MoodPromptCard extends StatelessWidget {
  const MoodPromptCard({
    super.key,
    required this.name,
    this.onMoodSelected,
  });

  final String name;
  final ValueChanged<MoodKind>? onMoodSelected;

  Future<void> _open(BuildContext context) async {
    final mood = await MoodCheckSheet.show(context, name: name);
    if (mood != null) {
      onMoodSelected?.call(mood);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrimeActionCard(
      title: 'Не знаешь, *с чего* начать сегодня?',
      body: 'Отметьте настроение — подберём привычку под ваш ресурс.',
      actionLabel: 'Подобрать',
      onAction: () => _open(context),
      illustration: const MoodCreature(
        mood: MoodKind.balanced,
        size: 80,
      ),
    );
  }
}
