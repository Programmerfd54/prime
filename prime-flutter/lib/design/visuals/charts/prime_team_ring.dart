import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../lottie_registry.dart';
import '../../motion.dart';
import '../../tokens.dart';
import '../../typography.dart';
import '../../../ui/components/profile/app_avatar.dart';

class TeamRingSlot {
  const TeamRingSlot({
    this.name,
    this.photoUrl,
    this.assetPath,
    this.checkedIn = false,
    this.filled = false,
  });

  final String? name;
  final String? photoUrl;
  final String? assetPath;
  final bool checkedIn;
  final bool filled;
}

/// Six avatar slots around a ring — dashed empties, glow for check-ins.
/// Slow infinite rotation on the dashed track + pulse on checked-in avatars.
class PrimeTeamRing extends StatefulWidget {
  const PrimeTeamRing({
    super.key,
    required this.slots,
    this.size = 220,
    this.centerLabel,
    this.centerSubtitle,
    this.slotCount = 6,
    this.animate = true,
  });

  final List<TeamRingSlot> slots;
  final double size;
  final String? centerLabel;
  final String? centerSubtitle;
  final int slotCount;

  /// When false (tests / reduce-motion), ring stays static.
  final bool animate;

  @override
  State<PrimeTeamRing> createState() => _PrimeTeamRingState();
}

class _PrimeTeamRingState extends State<PrimeTeamRing>
    with TickerProviderStateMixin {
  late AnimationController _spin;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.animate || AppMotion.reduce(context)) {
        _spin.value = 0;
        _pulse.value = 0.5;
        return;
      }
      _spin.repeat();
      _pulse.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalized = List<TeamRingSlot>.generate(widget.slotCount, (i) {
      if (i < widget.slots.length) return widget.slots[i];
      return const TeamRingSlot();
    });
    final checked = normalized.where((s) => s.checkedIn).length;
    final filled = normalized.where((s) => s.filled).length;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_spin, _pulse]),
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: _spin.value * 2 * math.pi,
                child: CustomPaint(
                  size: Size.square(widget.size),
                  painter: _RingTrackPainter(
                    slotCount: widget.slotCount,
                    checkedFlags:
                        normalized.map((s) => s.checkedIn).toList(),
                  ),
                ),
              ),
              for (var i = 0; i < widget.slotCount; i++)
                _SlotAvatar(
                  index: i,
                  total: widget.slotCount,
                  ringSize: widget.size,
                  slot: normalized[i],
                  pulse: normalized[i].checkedIn ? _pulse.value : 0,
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.centerLabel ?? '$checked из ${widget.slotCount}',
                    style: AppTypography.numericSm,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    widget.centerSubtitle ??
                        (filled == 0
                            ? 'слотов в команде'
                            : 'отметились сегодня'),
                    style: AppTypography.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SlotAvatar extends StatelessWidget {
  const _SlotAvatar({
    required this.index,
    required this.total,
    required this.ringSize,
    required this.slot,
    required this.pulse,
  });

  final int index;
  final int total;
  final double ringSize;
  final TeamRingSlot slot;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final angle = -math.pi / 2 + (2 * math.pi * index / total);
    final radius = ringSize * 0.38;
    final avatarR = ringSize * 0.09;
    final dx = math.cos(angle) * radius;
    final dy = math.sin(angle) * radius;
    final scale = slot.checkedIn ? 1.0 + (pulse * 0.08) : 1.0;

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.scale(
        scale: scale,
        child: slot.filled
            ? Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: slot.checkedIn
                      ? [
                          BoxShadow(
                            color: AppColors.mint
                                .withValues(alpha: 0.45 + pulse * 0.25),
                            blurRadius: 10 + pulse * 8,
                          ),
                        ]
                      : null,
                  border: Border.all(
                    color: slot.checkedIn
                        ? AppColors.mint
                        : AppColors.primarySoft,
                    width: 2.5,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AppAvatar(
                      photoUrl: slot.photoUrl,
                      assetPath: slot.assetPath,
                      name: slot.name,
                      radius: avatarR,
                    ),
                    if (slot.checkedIn)
                      Positioned(
                        right: -avatarR * 0.15,
                        bottom: -avatarR * 0.15,
                        child: IgnorePointer(
                          child: PrimeLottie(
                            slot: PrimeLottieSlot.success,
                            width: avatarR * 1.1,
                            height: avatarR * 1.1,
                            repeat: false,
                          ),
                        ),
                      ),
                  ],
                ),
              )
            : Container(
                width: avatarR * 2,
                height: avatarR * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.elevatedSurface.withValues(alpha: 0.4),
                  border: Border.all(
                    color: AppColors.borderStrong,
                    width: 1.5,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: CustomPaint(painter: _DashedCirclePainter()),
              ),
      ),
    );
  }
}

class _RingTrackPainter extends CustomPainter {
  _RingTrackPainter({required this.slotCount, required this.checkedFlags});

  final int slotCount;
  final List<bool> checkedFlags;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.38;

    // Rotating dashed outer ring.
    final dash = Paint()
      ..color = AppColors.primarySoft.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dashes = 36;
    for (var i = 0; i < dashes; i++) {
      final a0 = 2 * math.pi * i / dashes;
      final a1 = a0 + math.pi / dashes * 0.55;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r + 10),
        a0,
        a1 - a0,
        false,
        dash,
      );
    }

    final track = Paint()
      ..color = AppColors.primaryContainer.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(c, r, track);

    final seg = 2 * math.pi / slotCount;
    for (var i = 0; i < slotCount; i++) {
      if (!checkedFlags[i]) continue;
      final paint = Paint()
        ..color = AppColors.mint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2 + seg * i + 0.12,
        seg - 0.24,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingTrackPainter oldDelegate) => true;
}

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dashes = 12;
    final r = size.shortestSide / 2 - 1;
    final c = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < dashes; i++) {
      final a0 = 2 * math.pi * i / dashes;
      final a1 = a0 + math.pi / dashes * 0.55;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        a0,
        a1 - a0,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
