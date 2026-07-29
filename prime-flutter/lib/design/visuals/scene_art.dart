import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../tokens.dart';
import 'habit_art.dart';

enum SceneKind {
  detox,
  focus,
  read,
  charge,
  social,
  sleep,
  generic,
  teamGathering,
  growth,
  achievement,
  recovery,
  empty,
  offline,
  welcome,
  reportDone,
}

String sceneAsset(SceneKind kind) => switch (kind) {
      SceneKind.detox => 'assets/illustrations/detox.svg',
      SceneKind.focus => 'assets/illustrations/focus.svg',
      SceneKind.read => 'assets/illustrations/read.svg',
      SceneKind.charge => 'assets/illustrations/charge.svg',
      SceneKind.social => 'assets/illustrations/social.svg',
      SceneKind.sleep => 'assets/illustrations/sleep.svg',
      SceneKind.generic => 'assets/illustrations/generic.svg',
      SceneKind.teamGathering => 'assets/illustrations/team_gathering.svg',
      SceneKind.growth => 'assets/illustrations/growth.svg',
      SceneKind.achievement => 'assets/illustrations/achievement.svg',
      SceneKind.recovery => 'assets/illustrations/recovery.svg',
      SceneKind.empty => 'assets/illustrations/empty.svg',
      SceneKind.offline => 'assets/illustrations/offline.svg',
      SceneKind.welcome => 'assets/illustrations/welcome.svg',
      SceneKind.reportDone => 'assets/illustrations/report_done.svg',
    };

SceneKind sceneFromHabit(HabitArtKind kind) => switch (kind) {
      HabitArtKind.detox => SceneKind.detox,
      HabitArtKind.focus => SceneKind.focus,
      HabitArtKind.read => SceneKind.read,
      HabitArtKind.charge => SceneKind.charge,
      HabitArtKind.social => SceneKind.social,
      HabitArtKind.sleep => SceneKind.sleep,
      HabitArtKind.generic => SceneKind.generic,
    };

/// Soft-3D SVG scene with CustomPainter fallback via [HabitArtObject] for habit kinds.
class SceneArt extends StatelessWidget {
  const SceneArt({
    super.key,
    required this.kind,
    this.size = 140,
  });

  final SceneKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        sceneAsset(kind),
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholderBuilder: (_) {
          final habit = switch (kind) {
            SceneKind.detox => HabitArtKind.detox,
            SceneKind.focus => HabitArtKind.focus,
            SceneKind.read => HabitArtKind.read,
            SceneKind.charge => HabitArtKind.charge,
            SceneKind.social => HabitArtKind.social,
            SceneKind.sleep => HabitArtKind.sleep,
            _ => HabitArtKind.generic,
          };
          return HabitArtObject(kind: habit, size: size);
        },
        errorBuilder: (_, __, ___) => Icon(
          Icons.image_outlined,
          size: size * 0.4,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
