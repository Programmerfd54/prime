import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../design/visuals/ambient_and_progress.dart';
import '../../../models/achievement.dart';

/// Editorial empty — motivating, not three zeros.
class AppAchievementEmptyState extends StatelessWidget {
  const AppAchievementEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.12),
              AppColors.surface,
            ],
          ),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          children: [
            const _AchievementMedalArt(size: 96, unlocked: false),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Коллекция ждёт первый шаг',
              style: AppTypography.title1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Выберите привычку — здесь появятся этапы, серия и значимые milestones.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Hero achievement — flagship milestone (e.g. Идеолог).
class AppAchievementHeroCard extends StatefulWidget {
  const AppAchievementHeroCard({
    super.key,
    required this.achievement,
    required this.successfulDays,
    this.premium = false,
  });

  final AchievementModel achievement;
  final int successfulDays;
  final bool premium;

  @override
  State<AppAchievementHeroCard> createState() => _AppAchievementHeroCardState();
}

class _AppAchievementHeroCardState extends State<AppAchievementHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.premium) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.achievement;
    final progress = a.requiredDays == 0
        ? 0.0
        : (widget.successfulDays / a.requiredDays).clamp(0.0, 1.0);
    final progressDays =
        widget.successfulDays.clamp(0, a.requiredDays);

    Widget card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: widget.premium
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.goldGradientA,
                  AppColors.goldGradientB,
                  AppColors.goldGradientC,
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.16),
                  AppColors.surface,
                ],
              ),
        border: Border.all(
          color: widget.premium
              ? AppColors.goldDeep.withValues(alpha: 0.7)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.premium ? 'Флагман' : 'Ближайшая цель',
                  style: AppTypography.caption.copyWith(
                    color: widget.premium
                        ? AppColors.goldAccent
                        : AppColors.primarySoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(a.name, style: AppTypography.title1),
                if (a.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    a.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySecondary,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppProgressRing(
                  progress: progress,
                  label: '$progressDays',
                  subtitle: '/${a.requiredDays}',
                  size: 72,
                  stroke: 5,
                  color: widget.premium
                      ? AppColors.goldAccent
                      : AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _AchievementMedalArt(
            size: 88,
            unlocked: a.unlocked,
            premium: widget.premium,
          ),
        ],
      ),
    );

    if (widget.premium) {
      card = AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final slide = MediaQuery.disableAnimationsOf(context)
              ? 0.5
              : _controller.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: [
                BoxShadow(
                  color: AppColors.goldSoft
                      .withValues(alpha: 0.08 + slide * 0.04),
                  blurRadius: 16,
                ),
              ],
            ),
            child: child,
          );
        },
        child: card,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: card,
    );
  }
}

/// Milestone row — progress card with distinct shape.
class AppAchievementMilestoneCard extends StatelessWidget {
  const AppAchievementMilestoneCard({
    super.key,
    required this.achievement,
    required this.successfulDays,
  });

  final AchievementModel achievement;
  final int successfulDays;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final progress = a.requiredDays == 0
        ? 0.0
        : (successfulDays / a.requiredDays).clamp(0.0, 1.0);
    final progressDays = successfulDays.clamp(0, a.requiredDays);
    final accent = a.unlocked ? AppColors.success : AppColors.primarySoft;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: a.unlocked
            ? AppColors.success.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: a.unlocked
                    ? AppColors.success.withValues(alpha: 0.35)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                _AchievementMedalArt(
                  size: 48,
                  unlocked: a.unlocked,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.title2,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: AppColors.primaryContainer,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '$progressDays/${a.requiredDays}',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bento collection orchestrator — vertical path timeline.
class AppAchievementCollection extends StatelessWidget {
  const AppAchievementCollection({
    super.key,
    required this.achievements,
    required this.successfulDays,
    this.showAll = false,
    this.onToggleShowAll,
  });

  final List<AchievementModel> achievements;
  final int successfulDays;
  final bool showAll;
  final VoidCallback? onToggleShowAll;

  AchievementModel? _nextUnlock(List<AchievementModel> sorted) {
    for (final a in sorted) {
      if (!a.unlocked) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return const AppAchievementEmptyState();
    }

    final sorted = [...achievements]
      ..sort((a, b) => a.requiredDays.compareTo(b.requiredDays));
    final next = _nextUnlock(sorted);
    final visible = showAll ? sorted : sorted.take(4).toList(growable: false);
    final hiddenCount = sorted.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (next != null) ...[
          AppAchievementHeroCard(
            achievement: next,
            successfulDays: successfulDays,
            premium: next.name.toLowerCase().contains('идеолог'),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Путь достижений', style: AppTypography.title2),
          const SizedBox(height: AppSpacing.sm),
        ],
        for (var i = 0; i < visible.length; i++) ...[
          _AchievementPathNode(
            achievement: visible[i],
            successfulDays: successfulDays,
            isNext: visible[i] == next,
            isLast: i == visible.length - 1 && hiddenCount == 0,
          ),
        ],
        if (hiddenCount > 0 && onToggleShowAll != null) ...[
          TextButton.icon(
            onPressed: onToggleShowAll,
            icon: Icon(
              showAll ? Icons.expand_less : Icons.expand_more,
              size: AppIconSizes.sm,
            ),
            label: Text(
              showAll
                  ? 'Скрыть достижения'
                  : 'Показать ещё $hiddenCount',
            ),
          ),
        ],
      ],
    );
  }
}

class _AchievementPathNode extends StatelessWidget {
  const _AchievementPathNode({
    required this.achievement,
    required this.successfulDays,
    required this.isNext,
    required this.isLast,
  });

  final AchievementModel achievement;
  final int successfulDays;
  final bool isNext;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final accent = a.unlocked
        ? AppColors.success
        : isNext
            ? AppColors.primary
            : AppColors.textMuted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                    border: isNext
                        ? Border.all(color: AppColors.primarySoft, width: 2)
                        : null,
                    boxShadow: isNext
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : AppSpacing.sm,
              ),
              child: AppAchievementMilestoneCard(
                achievement: a,
                successfulDays: successfulDays,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Abstract medal art — not a Material icon in a square.
class _AchievementMedalArt extends StatelessWidget {
  const _AchievementMedalArt({
    required this.size,
    required this.unlocked,
    this.premium = false,
  });

  final double size;
  final bool unlocked;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MedalPainter(
          unlocked: unlocked,
          premium: premium,
        ),
      ),
    );
  }
}

class _MedalPainter extends CustomPainter {
  _MedalPainter({required this.unlocked, required this.premium});

  final bool unlocked;
  final bool premium;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.42;
    final accent = premium
        ? AppColors.goldAccent
        : unlocked
            ? AppColors.primary
            : AppColors.textMuted;

    canvas.drawCircle(
      c,
      r * 1.15,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: unlocked ? 0.28 : 0.12),
            accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.15)),
    );

    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      final rad = i.isEven ? r : r * 0.72;
      final p = c + Offset(math.cos(a), math.sin(a)) * rad;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: unlocked ? 0.95 : 0.35),
            accent.withValues(alpha: unlocked ? 0.45 : 0.15),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    canvas.drawCircle(
      c,
      r * 0.28,
      Paint()..color = AppColors.background.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _MedalPainter oldDelegate) =>
      oldDelegate.unlocked != unlocked || oldDelegate.premium != premium;
}
