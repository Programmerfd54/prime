import 'package:flutter/material.dart';

import 'package:prime/core/home/home_state_types.dart';
import '../../ui/components/editorial/app_hero_module.dart';

/// Renders the editorial hero for the current [HomeStateSnapshot].
class HomeNextStepCard extends StatelessWidget {
  const HomeNextStepCard({
    super.key,
    required this.state,
    this.onPrimaryAction,
  });

  final HomeStateSnapshot state;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final hero = state.hero;
    return AppHeroModule(
      badge: hero.badge,
      title: hero.title,
      body: hero.body,
      artKind: hero.artKind,
      progress: hero.progress,
      progressLabel: hero.progressLabel,
      actionLabel: hero.actionLabel,
      onAction: hero.actionLabel == null ? null : onPrimaryAction,
    );
  }
}
