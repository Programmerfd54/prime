import 'package:flutter/material.dart';

import '../design/theme/prime_theme_context.dart';
import '../design/tokens.dart';
import '../design/visuals/ambient_and_progress.dart';
import '../ui/kit/components/prime_empty_state.dart';

class TournamentsScreen extends StatelessWidget {
  const TournamentsScreen({super.key});

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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.bottomNavClearance,
            ),
            child: const PrimeEmptyState(
              title: 'Страница в разработке',
              body: 'Следите за новостями',
            ),
          ),
        ),
      ),
    );
  }
}
