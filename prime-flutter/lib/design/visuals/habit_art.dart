import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../tokens.dart';

enum HabitArtKind {
  detox,
  focus,
  read,
  charge,
  social,
  sleep,
  generic,
}

HabitArtKind habitArtKindFor(String value) {
  final n = value.toLowerCase();
  if (n.contains('детокс') || n.contains('digital') || n.contains('phone')) {
    return HabitArtKind.detox;
  }
  if (n.contains('фокус') || n.contains('morning') || n.contains('утрен')) {
    return HabitArtKind.focus;
  }
  if (n.contains('чтен') ||
      n.contains('book') ||
      n.contains('глава') ||
      n.contains('chapter') ||
      n.contains('read')) {
    return HabitArtKind.read;
  }
  if (n.contains('заряд') || n.contains('body') || n.contains('fitness')) {
    return HabitArtKind.charge;
  }
  if (n.contains('общен') || n.contains('live') || n.contains('forum')) {
    return HabitArtKind.social;
  }
  if (n.contains('сон') || n.contains('ритуал') || n.contains('evening')) {
    return HabitArtKind.sleep;
  }
  return HabitArtKind.generic;
}

Color habitArtAccent(HabitArtKind kind) => switch (kind) {
      HabitArtKind.detox => AppColors.habitDetox,
      HabitArtKind.focus => AppColors.habitFocus,
      HabitArtKind.read => AppColors.habitRead,
      HabitArtKind.charge => AppColors.habitCharge,
      HabitArtKind.social => AppColors.habitSocial,
      HabitArtKind.sleep => AppColors.habitSleep,
      HabitArtKind.generic => AppColors.primary,
    };

/// Accent color from skill id/name — replaces legacy habitAccentFor.
Color habitAccentFor(String value) => habitArtAccent(habitArtKindFor(value));

String habitPromise(HabitArtKind kind) => switch (kind) {
      HabitArtKind.detox => 'Меньше шума — больше ясности',
      HabitArtKind.focus => 'Утренний фокус без суеты',
      HabitArtKind.read => 'Одна глава — каждый день',
      HabitArtKind.charge => 'Тело просыпается вместе с тобой',
      HabitArtKind.social => 'Живое общение вместо ленты',
      HabitArtKind.sleep => 'Спокойный вечер — сильное утро',
      HabitArtKind.generic => 'Один шаг каждый день',
    };

String habitIllustrationAsset(HabitArtKind kind) => switch (kind) {
      HabitArtKind.detox => 'assets/illustrations/detox.svg',
      HabitArtKind.focus => 'assets/illustrations/focus.svg',
      HabitArtKind.read => 'assets/illustrations/read.svg',
      HabitArtKind.charge => 'assets/illustrations/charge.svg',
      HabitArtKind.social => 'assets/illustrations/social.svg',
      HabitArtKind.sleep => 'assets/illustrations/sleep.svg',
      HabitArtKind.generic => 'assets/illustrations/generic.svg',
    };

/// Lifestyle photo for onboarding program cards / summary.
String habitPhotoAsset(HabitArtKind kind) => switch (kind) {
      HabitArtKind.detox => 'assets/photos/programs/detox.jpg',
      HabitArtKind.focus => 'assets/photos/programs/focus.jpg',
      HabitArtKind.read => 'assets/photos/programs/read.jpg',
      HabitArtKind.charge => 'assets/photos/programs/charge.jpg',
      HabitArtKind.social => 'assets/photos/programs/social.jpg',
      HabitArtKind.sleep => 'assets/photos/programs/evening.jpg',
      HabitArtKind.generic => 'assets/photos/programs/focus.jpg',
    };

String habitPhotoAssetFor(String skillIdOrName) =>
    habitPhotoAsset(habitArtKindFor(skillIdOrName));

/// Habit illustration — SVG asset with CustomPainter fallback.
class HabitArtObject extends StatelessWidget {
  const HabitArtObject({
    super.key,
    required this.kind,
    this.size = 120,
  });

  final HabitArtKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = habitArtAccent(kind);
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        habitIllustrationAsset(kind),
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => CustomPaint(
          painter: _HabitArtPainter(kind: kind, accent: accent),
        ),
      ),
    );
  }
}

class _HabitArtPainter extends CustomPainter {
  _HabitArtPainter({required this.kind, required this.accent});

  final HabitArtKind kind;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.42;

    void glow(Offset o, double rad) {
      canvas.drawCircle(
        o,
        rad,
        Paint()
          ..shader = RadialGradient(
            colors: [
              accent.withValues(alpha: 0.35),
              accent.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: o, radius: rad)),
      );
    }

    glow(c, r * 1.1);

    switch (kind) {
      case HabitArtKind.detox:
        _drawOrbit(canvas, c, r, accent);
      case HabitArtKind.focus:
        _drawSun(canvas, c, r, accent);
      case HabitArtKind.read:
        _drawPages(canvas, c, r, accent);
      case HabitArtKind.charge:
        _drawWave(canvas, c, r, accent);
      case HabitArtKind.social:
        _drawCluster(canvas, c, r, accent);
      case HabitArtKind.sleep:
        _drawMoon(canvas, c, r, accent);
      case HabitArtKind.generic:
        _drawOrb(canvas, c, r, accent);
    }
  }

  void _drawOrb(Canvas canvas, Offset c, double r, Color accent) {
    canvas.drawCircle(
      c,
      r * 0.55,
      Paint()
        ..shader = RadialGradient(
          colors: [accent.withValues(alpha: 0.9), accent.withValues(alpha: 0.2)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.55)),
    );
  }

  void _drawOrbit(Canvas canvas, Offset c, double r, Color accent) {
    final ring = Paint()
      ..color = accent.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(c, r * 0.62, ring);
    for (var i = 0; i < 3; i++) {
      final a = i * 2 * math.pi / 3 - math.pi / 2;
      final p = c + Offset(math.cos(a), math.sin(a)) * r * 0.62;
      canvas.drawCircle(p, r * 0.12, Paint()..color = accent.withValues(alpha: 0.85));
    }
    canvas.drawCircle(c, r * 0.18, Paint()..color = AppColors.textPrimary.withValues(alpha: 0.9));
  }

  void _drawSun(Canvas canvas, Offset c, double r, Color accent) {
    canvas.drawCircle(c, r * 0.38, Paint()..color = accent.withValues(alpha: 0.85));
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final p1 = c + Offset(math.cos(a), math.sin(a)) * r * 0.45;
      final p2 = c + Offset(math.cos(a), math.sin(a)) * r * 0.72;
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = accent.withValues(alpha: 0.55)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawPages(Canvas canvas, Offset c, double r, Color accent) {
    for (var i = 0; i < 3; i++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c + Offset(i * 8.0 - 8, i * -4.0),
          width: r * 0.75,
          height: r * 0.95,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = accent.withValues(alpha: 0.25 + i * 0.18),
      );
    }
  }

  void _drawWave(Canvas canvas, Offset c, double r, Color accent) {
    final path = Path();
    path.moveTo(c.dx - r, c.dy);
    for (var x = -r; x <= r; x += r / 4) {
      path.quadraticBezierTo(
        c.dx + x + r / 8,
        c.dy - (x % (r / 2) == 0 ? r * 0.25 : -r * 0.18),
        c.dx + x + r / 4,
        c.dy,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawCluster(Canvas canvas, Offset c, double r, Color accent) {
    final offsets = [
      Offset.zero,
      Offset(-r * 0.35, r * 0.12),
      Offset(r * 0.32, r * 0.08),
      Offset(r * 0.05, -r * 0.28),
    ];
    for (final o in offsets) {
      canvas.drawCircle(
        c + o,
        r * 0.2,
        Paint()..color = accent.withValues(alpha: o == Offset.zero ? 0.95 : 0.55),
      );
    }
  }

  void _drawMoon(Canvas canvas, Offset c, double r, Color accent) {
    canvas.drawCircle(c, r * 0.48, Paint()..color = accent.withValues(alpha: 0.35));
    canvas.drawCircle(
      c + Offset(r * 0.18, -r * 0.08),
      r * 0.42,
      Paint()..color = AppColors.background.withValues(alpha: 0.92),
    );
  }

  @override
  bool shouldRepaint(covariant _HabitArtPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
