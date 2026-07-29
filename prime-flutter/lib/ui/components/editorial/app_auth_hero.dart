import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/ambient_and_progress.dart';

/// Brand hero for auth — not a plain title block.
class AppAuthHero extends StatelessWidget {
  const AppAuthHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: compact ? 140 : 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const _PrimeBrandArt(size: 160),
              if (!compact)
                Positioned(
                  bottom: 0,
                  child: Text(
                    'ПРАЙМ',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primarySoft,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: AppTypography.largeTitle),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: AppTypography.bodySecondary),
      ],
    );
  }
}

class _PrimeBrandArt extends StatelessWidget {
  const _PrimeBrandArt({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PrimeBrandPainter(),
      ),
    );
  }
}

class _PrimeBrandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.46;

    void orb(Offset o, double rad, Color color) {
      canvas.drawCircle(
        o,
        rad,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.35),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: o, radius: rad)),
      );
    }

    orb(c, r * 1.2, AppColors.primary);
    orb(c + Offset(-r * 0.3, r * 0.2), r * 0.5, AppColors.habitFocus);
    orb(c + Offset(r * 0.35, -r * 0.15), r * 0.4, AppColors.habitSocial);

    final ring = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(c, r * 0.72, ring);

    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 - math.pi / 2;
      final p = c + Offset(math.cos(a), math.sin(a)) * r * 0.72;
      canvas.drawCircle(
        p,
        r * 0.09,
        Paint()..color = AppColors.primarySoft.withValues(alpha: 0.75),
      );
    }

    canvas.drawCircle(
      c,
      r * 0.22,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.4),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.22)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Onboarding page hero — full visual module per slide.
class AppOnboardingHero extends StatelessWidget {
  const AppOnboardingHero({
    super.key,
    required this.visual,
  });

  final AppOnboardingVisual visual;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: SizedBox(
        width: double.infinity,
        height: 280,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _OnboardingBackdropPainter(visual: visual),
              size: Size.infinite,
            ),
            Center(child: _OnboardingVisualWidget(visual: visual)),
          ],
        ),
      ),
    );
  }
}

enum AppOnboardingVisual { problem, habit, team }

class _OnboardingBackdropPainter extends CustomPainter {
  _OnboardingBackdropPainter({required this.visual});

  final AppOnboardingVisual visual;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = switch (visual) {
      AppOnboardingVisual.problem => [
        AppColors.primary.withValues(alpha: 0.18),
        AppColors.surface,
        AppColors.background,
      ],
      AppOnboardingVisual.habit => [
        AppColors.habitFocus.withValues(alpha: 0.16),
        AppColors.surface,
        AppColors.background,
      ],
      AppOnboardingVisual.team => [
        AppColors.habitSocial.withValues(alpha: 0.16),
        AppColors.surface,
        AppColors.background,
      ],
    };

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(covariant _OnboardingBackdropPainter oldDelegate) =>
      oldDelegate.visual != visual;
}

class _OnboardingVisualWidget extends StatelessWidget {
  const _OnboardingVisualWidget({required this.visual});

  final AppOnboardingVisual visual;

  @override
  Widget build(BuildContext context) {
    return switch (visual) {
      AppOnboardingVisual.problem => const AppProgressRing(
          progress: 0.35,
          label: '1',
          subtitle: 'день',
          size: 120,
        ),
      AppOnboardingVisual.habit => const _HabitCycleArt(),
      AppOnboardingVisual.team => const _TeamClusterArt(),
    };
  }
}

class _HabitCycleArt extends StatelessWidget {
  const _HabitCycleArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: CustomPaint(painter: _CyclePainter()),
    );
  }
}

class _CyclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.4;
    for (var i = 0; i < 30; i++) {
      final a = i * 2 * math.pi / 30 - math.pi / 2;
      final filled = i < 12;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawCircle(
        p,
        4,
        Paint()
          ..color = filled
              ? AppColors.habitFocus.withValues(alpha: 0.9)
              : AppColors.primaryContainer,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TeamClusterArt extends StatelessWidget {
  const _TeamClusterArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 120,
      child: CustomPaint(painter: _ClusterPainter()),
    );
  }
}

class _ClusterPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.28;
    final offsets = [
      Offset.zero,
      Offset(-r * 1.1, r * 0.15),
      Offset(r * 1.05, r * 0.1),
      Offset(-r * 0.5, -r * 0.85),
      Offset(r * 0.45, -r * 0.9),
      Offset(0, r * 0.95),
    ];
    for (var i = 0; i < offsets.length; i++) {
      final o = offsets[i];
      canvas.drawCircle(
        c + o,
        r * 0.55,
        Paint()
          ..color = AppColors.habitSocial
              .withValues(alpha: i == 0 ? 0.95 : 0.45 + i * 0.06),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
