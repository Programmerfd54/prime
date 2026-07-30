import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'profile_editorial_widgets.dart';

/// Unified stroke icon set for profile screens (TZ §26).
abstract final class ProfileIcons {
  static const back = LucideIcons.arrowLeft;
  static const message = LucideIcons.messageCircle;
  static const more = LucideIcons.ellipsis;
  static const edit = LucideIcons.pencil;
  static const settings = LucideIcons.settings;
  static const flag = LucideIcons.flag;
  static const copy = LucideIcons.atSign;
  static const invite = LucideIcons.userPlus;
  static const block = LucideIcons.ban;
  static const trophy = LucideIcons.trophy;
  static const history = LucideIcons.history;
  static const chart = LucideIcons.lineChart;
  static const cycle = LucideIcons.zap;
  static const analytics = LucideIcons.barChart3;
  static const achievements = LucideIcons.award;
  static const about = LucideIcons.info;
  static const bookmark = LucideIcons.bookmark;
  static const share = LucideIcons.share2;
}

/// Renders a Lucide stroke icon with profile sizing defaults.
class ProfileIcon extends StatelessWidget {
  const ProfileIcon(
    this.icon, {
    super.key,
    this.size = 20,
    this.color,
    this.semanticsLabel,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: Icon(
        icon,
        size: size,
        color: color ?? ProfilePalette.offWhite.withValues(alpha: 0.92),
      ),
    );
  }
}

IconData achievementIconForCode(String code) {
  switch (code) {
    case 'student':
      return LucideIcons.graduationCap;
    case 'master':
      return LucideIcons.medal;
    case 'mentor':
      return LucideIcons.users;
    case 'prime_mentor':
      return LucideIcons.crown;
    case 'ideologist':
      return LucideIcons.sparkles;
    default:
      return LucideIcons.award;
  }
}
