import 'package:flutter/material.dart';

import '../../../core/metrics/calendar_metrics.dart';
import '../../../design/liquid/liquid_glass.dart';
import '../../../design/tokens.dart';
import '../../../design/visuals/charts/charts.dart';
import '../../../models/report.dart';
import '../../components/app_icon_button.dart';
import 'profile_typography.dart';
import 'profile_utils.dart';

/// Profile color system — TZ §5.2 (local to profile screens).
abstract final class ProfilePalette {
  static const warmYellow = Color(0xFFFFD65A);
  static const charcoal = Color(0xFF262628);
  static const chartSurface = Color(0xFF262628);
  static const contentSurface = Color(0xFF353240);
  static const coolGrey = Color(0xFFC7CDD4);
  static const mint = Color(0xFF58D6B2);
  static const coral = Color(0xFFFF7A72);
  static const offWhite = Color(0xFFFAF9FC);
  static const brand = Color(0xFF8B5CF6);
  static const brandSoft = Color(0xFFA78BFA);

  static const tagPastels = [
    Color(0xFF9B7B8E),
    Color(0xFFB8A48C),
    Color(0xFF7B8FA8),
    Color(0xFF8A9B8E),
  ];

  static Color mutedTagFill(Color accent) => Color.alphaBlend(
        Colors.black.withValues(alpha: 0.12),
        accent.withValues(alpha: 0.52),
      );
}

class ProfileHabitTag {
  const ProfileHabitTag({required this.label, required this.accent});
  final String label;
  final Color accent;
}

List<ProfileHabitTag> profileHabitTagsFromNames(Iterable<String> names) {
  final seen = <String>{};
  final tags = <ProfileHabitTag>[];
  for (final raw in names) {
    final label = raw.trim();
    if (label.isEmpty || seen.contains(label)) continue;
    seen.add(label);
    tags.add(ProfileHabitTag(
      label: label,
      accent: ProfilePalette.tagPastels[tags.length % ProfilePalette.tagPastels.length],
    ));
  }
  return tags;
}

enum ProfileHeroMode { own, public }

enum ProfileMetricPillVariant { gold, charcoal, hatched, glass }

/// TZ §15 alias.
typedef ProfileStatPill = ProfileMetricPill;

class ProfileMetricPill {
  const ProfileMetricPill({
    required this.label,
    required this.value,
    this.variant = ProfileMetricPillVariant.gold,
  });
  final String label;
  final String value;
  final ProfileMetricPillVariant variant;
}

/// Unified hero card — photo, identity, tags, metrics, embedded chart (TZ §7).
class ProfileHeroCard extends StatefulWidget {
  const ProfileHeroCard({
    super.key,
    required this.displayName,
    this.subtitle,
    this.statusLine,
    this.photoUrl,
    this.about,
    this.tags = const [],
    this.metrics = const [],
    this.calendar,
    this.mode = ProfileHeroMode.own,
    this.showChart = true,
    this.onSettings,
    this.onEdit,
    this.onAvatarTap,
    this.onBack,
    this.onMessage,
    this.onMore,
    this.scrollOffset = 0,
  });

  final String displayName;
  final String? subtitle;
  final String? statusLine;
  final String? photoUrl;
  final String? about;
  final List<ProfileHabitTag> tags;
  final List<ProfileMetricPill> metrics;
  final CalendarOut? calendar;
  final ProfileHeroMode mode;
  final bool showChart;
  final VoidCallback? onSettings;
  final VoidCallback? onEdit;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onBack;
  final VoidCallback? onMessage;
  final VoidCallback? onMore;
  final double scrollOffset;

  static const cardRadius = 32.0;
  static const photoHeight = 380.0;
  static const horizontalMargin = 16.0;
  static const maxContentWidth = 560.0;

  @override
  State<ProfileHeroCard> createState() => _ProfileHeroCardState();
}

class _ProfileHeroCardState extends State<ProfileHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _enter.value = 1;
    } else if (_enter.status == AnimationStatus.dismissed) {
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bio = sanitizeProfileBio(widget.about);
    final buckets = profileRhythmBuckets(widget.calendar);
    final visibleTags = widget.tags.take(3).toList();
    final extraTags = widget.tags.length - visibleTags.length;
    final parallax = MediaQuery.disableAnimationsOf(context)
        ? 0.0
        : widget.scrollOffset.clamp(0.0, 80.0) * 0.15;

    return FadeTransition(
      opacity: _fade,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ProfileHeroCard.maxContentWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ProfileHeroCard.horizontalMargin,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ProfileHeroCard.cardRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(ProfileHeroCard.cardRadius),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: ProfileHeroCard.photoHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Transform.translate(
                            offset: Offset(0, parallax),
                            child: ProfileHeroImage(
                              photoUrl: widget.photoUrl,
                              alignment: Alignment.topCenter,
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.06),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.28),
                                  ProfilePalette.contentSurface
                                      .withValues(alpha: 0.92),
                                ],
                                stops: const [0.0, 0.35, 0.72, 1.0],
                              ),
                            ),
                          ),
                          _HeroActions(
                            mode: widget.mode,
                            onBack: widget.onBack,
                            onSettings: widget.onSettings,
                            onEdit: widget.onEdit,
                            onAvatarTap: widget.onAvatarTap,
                            onMessage: widget.onMessage,
                            onMore: widget.onMore,
                          ),
                          Positioned(
                            left: AppSpacing.lg,
                            right: AppSpacing.lg,
                            bottom: AppSpacing.md,
                            child: Column(
                              children: [
                                Text(
                                  widget.displayName,
                                  style: ProfileTypography.displayName.copyWith(
                                    color: ProfilePalette.offWhite,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (widget.subtitle != null &&
                                    widget.subtitle!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.subtitle!,
                                    style: ProfileTypography.subtitle.copyWith(
                                      color: ProfilePalette.offWhite
                                          .withValues(alpha: 0.82),
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (widget.statusLine != null &&
                                    widget.statusLine!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.statusLine!,
                                    style: ProfileTypography.secondary.copyWith(
                                      color: ProfilePalette.brandSoft,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ColoredBox(
                      color: ProfilePalette.contentSurface,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (visibleTags.isNotEmpty) ...[
                              ProfileHabitTagsRow(
                                tags: visibleTags,
                                extraCount: extraTags,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                            if (bio.isNotEmpty) ...[
                              _ProfileExpandableBio(text: bio),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            if (widget.metrics.isNotEmpty) ...[
                              ProfileMetricPillsRow(
                                metrics: widget.metrics,
                                onHero: true,
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            if (widget.showChart)
                              ProfileTrendChart(buckets: buckets),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileExpandableBio extends StatefulWidget {
  const _ProfileExpandableBio({required this.text});

  final String text;

  @override
  State<_ProfileExpandableBio> createState() => _ProfileExpandableBioState();
}

class _ProfileExpandableBioState extends State<_ProfileExpandableBio> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          widget.text,
          style: ProfileTypography.bio.copyWith(
            color: ProfilePalette.offWhite.withValues(alpha: 0.78),
          ),
          textAlign: TextAlign.center,
          maxLines: _expanded ? null : 3,
          overflow: _expanded ? null : TextOverflow.ellipsis,
        ),
        if (widget.text.length > 120 || widget.text.split('\n').length > 3)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              foregroundColor: ProfilePalette.brandSoft,
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _expanded ? 'Свернуть' : 'Показать полностью',
              style: ProfileTypography.cta.copyWith(fontSize: 14),
            ),
          ),
      ],
    );
  }
}

List<WeekDayBucket> profileRhythmBuckets(CalendarOut? calendar) {
  if (calendar == null || calendar.days.isEmpty) return const [];
  final today = DateTime(
    calendar.today.year,
    calendar.today.month,
    calendar.today.day,
  );
  final recent = calendar.days.length > 30
      ? calendar.days.sublist(calendar.days.length - 30)
      : calendar.days;
  if (recent.isEmpty) return const [];
  const segments = 6;
  final size = (recent.length / segments).ceil().clamp(1, 30);
  final buckets = <WeekDayBucket>[];
  for (var i = 0; i < segments; i++) {
    final start = i * size;
    if (start >= recent.length) break;
    final end = (start + size).clamp(0, recent.length);
    final slice = recent.sublist(start, end);
    final met = slice.where((d) => d.reported).length;
    final completed = slice.where((d) => d.completed).length;
    final lastDate = DateTime(
      slice.last.date.year,
      slice.last.date.month,
      slice.last.date.day,
    );
    buckets.add(WeekDayBucket(
      date: lastDate,
      label: '${i + 1}',
      completed: completed > 0,
      reported: met > 0,
      isToday: lastDate == today,
      isFuture: lastDate.isAfter(today),
    ));
  }
  return buckets;
}

class ProfileTrendChart extends StatelessWidget {
  const ProfileTrendChart({super.key, required this.buckets});

  final List<WeekDayBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final values = buckets.map((b) => b.intensity).toList();
    final labels = buckets.map((b) => b.label).toList();
    final hasChart = values.where((v) => v > 0).length >= 2;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ProfilePalette.chartSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      constraints: const BoxConstraints(minHeight: 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Ритм за 30 дней',
                style: ProfileTypography.cardTitle.copyWith(
                  color: ProfilePalette.offWhite,
                  fontSize: 17,
                ),
              ),
              const Spacer(),
              _LegendDot(
                color: ProfilePalette.warmYellow,
                label: 'Вы',
              ),
              const SizedBox(width: AppSpacing.sm),
              _LegendDot(
                color: ProfilePalette.coolGrey.withValues(alpha: 0.6),
                label: 'Среднее',
                dashed: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (!hasChart)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Column(
                children: [
                  Icon(
                    Icons.show_chart_rounded,
                    color: ProfilePalette.brandSoft.withValues(alpha: 0.45),
                    size: 32,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'График появится после нескольких отметок',
                    style: ProfileTypography.secondary.copyWith(
                      color: ProfilePalette.coolGrey.withValues(alpha: 0.65),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            PrimeNeonLineChart(
              values: values,
              labels: labels,
              height: 110,
              style: PrimeLineChartStyle.editorial,
            ),
        ],
      ),
    );
  }
}

class ProfileHeroImage extends StatelessWidget {
  const ProfileHeroImage({
    super.key,
    this.photoUrl,
    this.alignment = Alignment.topCenter,
  });

  final String? photoUrl;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return Image.network(
        photoUrl!,
        fit: BoxFit.cover,
        alignment: alignment,
        errorBuilder: (_, __, ___) => const _HeroPlaceholder(),
      );
    }
    return const _HeroPlaceholder();
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ProfilePalette.brand.withValues(alpha: 0.35),
            ProfilePalette.contentSurface,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person_outline_rounded,
          size: 72,
          color: ProfilePalette.offWhite.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _HeroActions extends StatelessWidget {
  const _HeroActions({
    required this.mode,
    this.onBack,
    this.onSettings,
    this.onEdit,
    this.onAvatarTap,
    this.onMessage,
    this.onMore,
  });

  final ProfileHeroMode mode;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;
  final VoidCallback? onEdit;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onMessage;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + AppSpacing.xs,
      left: AppSpacing.md,
      right: AppSpacing.md,
      child: Row(
        children: [
          if (mode == ProfileHeroMode.public)
            ProfileGlassAction(
              icon: Icons.arrow_back_rounded,
              onPressed: onBack ?? () => Navigator.maybePop(context),
              semanticsLabel: 'Назад',
            )
          else
            const SizedBox(width: 46),
          const Spacer(),
          if (mode == ProfileHeroMode.public) ...[
            if (onMessage != null) ...[
              ProfileGlassAction(
                icon: Icons.chat_bubble_outline_rounded,
                onPressed: onMessage,
                semanticsLabel: 'Написать',
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (onMore != null)
              ProfileGlassAction(
                icon: Icons.more_horiz_rounded,
                onPressed: onMore,
                semanticsLabel: 'Ещё',
              ),
          ],
          if (mode == ProfileHeroMode.own) ...[
            if (onEdit != null || onAvatarTap != null) ...[
              ProfileGlassAction(
                icon: Icons.edit_outlined,
                onPressed: onEdit ?? onAvatarTap,
                semanticsLabel: 'Редактировать',
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (onSettings != null)
              ProfileGlassAction(
                icon: Icons.settings_outlined,
                onPressed: onSettings,
                semanticsLabel: 'Настройки',
              ),
          ],
        ],
      ),
    );
  }
}

class ProfileGlassAction extends StatelessWidget {
  const ProfileGlassAction({
    super.key,
    required this.icon,
    this.onPressed,
    this.semanticsLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: LiquidGlass(
        forceTier: LiquidTier.full,
        allowBlurOnWeb: true,
        radius: 23,
        width: 46,
        height: 46,
        padding: EdgeInsets.zero,
        sigma: 20,
        fillOpacity: 0.14,
        child: AppIconButton(
          icon: icon,
          onPressed: onPressed,
          foregroundColor: ProfilePalette.offWhite,
          iconSize: AppIconSizes.sm,
        ),
      ),
    );
  }
}

class ProfileHabitTagsRow extends StatelessWidget {
  const ProfileHabitTagsRow({
    super.key,
    required this.tags,
    this.extraCount = 0,
  });

  final List<ProfileHabitTag> tags;
  final int extraCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: tags.length + (extraCount > 0 ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) {
          if (extraCount > 0 && i == tags.length) {
            return ProfileTag(label: '+$extraCount', accent: ProfilePalette.coolGrey);
          }
          final tag = tags[i];
          return ProfileTag(label: tag.label, accent: tag.accent);
        },
      ),
    );
  }
}

class ProfileTag extends StatelessWidget {
  const ProfileTag({super.key, required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: ProfilePalette.mutedTagFill(accent),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: ProfilePalette.offWhite,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: ProfileTypography.tag.copyWith(
              color: ProfilePalette.offWhite.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileMetricPillsRow extends StatelessWidget {
  const ProfileMetricPillsRow({
    super.key,
    required this.metrics,
    this.onHero = false,
  });

  final List<ProfileMetricPill> metrics;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid = constraints.maxWidth < 340 && metrics.length == 4;
        if (useGrid) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricPillCell(
                      metric: metrics[0],
                      onHero: onHero,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _MetricPillCell(
                      metric: metrics[1],
                      onHero: onHero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: _MetricPillCell(
                      metric: metrics[2],
                      onHero: onHero,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _MetricPillCell(
                      metric: metrics[3],
                      onHero: onHero,
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < metrics.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _MetricPillCell(metric: metrics[i], onHero: onHero),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _MetricPillCell extends StatelessWidget {
  const _MetricPillCell({required this.metric, required this.onHero});
  final ProfileMetricPill metric;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final labelColor = onHero
        ? ProfilePalette.offWhite.withValues(alpha: 0.85)
        : ProfilePalette.coolGrey;
    final (valueColor, decoration) = _pillStyle(metric.variant);

    return Column(
      children: [
        Text(
          metric.label,
          style: ProfileTypography.metricLabel.copyWith(color: labelColor),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        _buildPill(valueColor, decoration),
      ],
    );
  }

  Widget _buildPill(Color valueColor, BoxDecoration decoration) {
    final text = Text(
      metric.value,
      style: ProfileTypography.metricValue.copyWith(color: valueColor),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (metric.variant == ProfileMetricPillVariant.hatched) {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 36),
        decoration: decoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _DiagonalStripePainter()),
              ),
              text,
            ],
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 36),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: decoration,
      child: text,
    );
  }

  (Color, BoxDecoration) _pillStyle(ProfileMetricPillVariant variant) {
    switch (variant) {
      case ProfileMetricPillVariant.gold:
        return (
          ProfilePalette.charcoal,
          BoxDecoration(
            color: ProfilePalette.warmYellow,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
      case ProfileMetricPillVariant.charcoal:
        return (
          ProfilePalette.offWhite,
          BoxDecoration(
            color: ProfilePalette.charcoal,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
      case ProfileMetricPillVariant.hatched:
        return (
          ProfilePalette.offWhite,
          BoxDecoration(
            color: const Color(0xFF3A3840),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
      case ProfileMetricPillVariant.glass:
        return (
          ProfilePalette.offWhite,
          BoxDecoration(
            color: ProfilePalette.coolGrey.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: ProfilePalette.coolGrey.withValues(alpha: 0.28),
            ),
          ),
        );
    }
  }
}

class _DiagonalStripePainter extends CustomPainter {
  const _DiagonalStripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ProfilePalette.offWhite.withValues(alpha: 0.1)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const spacing = 7.0;
    for (var x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    this.dashed = false,
  });
  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: dashed ? Colors.transparent : color,
            shape: BoxShape.circle,
            border: dashed ? Border.all(color: color, width: 1) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: ProfileTypography.metricLabel.copyWith(
            color: ProfilePalette.coolGrey.withValues(alpha: 0.75),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

/// Compact dark navigation tile.
class ProfileLinkTile extends StatelessWidget {
  const ProfileLinkTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ProfilePalette.charcoal,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, color: ProfilePalette.brandSoft, size: AppIconSizes.sm),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: ProfileTypography.cardTitle.copyWith(
                    color: ProfilePalette.offWhite,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: ProfilePalette.coolGrey.withValues(alpha: 0.6),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Legacy aliases (migration) ─────────────────────────────────────────────

@Deprecated('Use ProfileHeroCard')
typedef ProfileEditorialHero = ProfileHeroCard;

@Deprecated('Use ProfileHeroCard with embedded metrics/chart')
class ProfileEditorialHeader extends StatelessWidget {
  const ProfileEditorialHeader({super.key, required this.hero, this.metrics});
  final ProfileHeroCard hero;
  final List<ProfileMetricPill>? metrics;
  static const metricsOverlap = 0.0;
  static const contentTopPadding = 0.0;
  @override
  Widget build(BuildContext context) => hero;
}

@Deprecated('Use ProfilePalette')
typedef ProfileEditorialPalette = ProfilePalette;

@Deprecated('Use ProfileHeroCard embedded chart')
class ProfileStatisticsCard extends StatelessWidget {
  const ProfileStatisticsCard({
    super.key,
    required this.title,
    required this.buckets,
    this.emptyMessage = '',
  });
  final String title;
  final List<WeekDayBucket> buckets;
  final String emptyMessage;
  @override
  Widget build(BuildContext context) => ProfileTrendChart(buckets: buckets);
}

List<ProfileMetricPill> buildPublicProfileMetrics({
  int? primes,
  int? successfulDays,
  int? consistency7,
}) {
  final metrics = <ProfileMetricPill>[];
  if (successfulDays != null) {
    metrics.add(ProfileMetricPill(
      label: 'Дней подряд',
      value: '$successfulDays дн.',
      variant: ProfileMetricPillVariant.gold,
    ));
  }
  if (primes != null) {
    metrics.add(ProfileMetricPill(
      label: 'Праймы',
      value: '$primes',
      variant: ProfileMetricPillVariant.charcoal,
    ));
  }
  if (metrics.isEmpty) return metrics;
  if (metrics.length < 3) {
    metrics.add(ProfileMetricPill(
      label: 'Циклы',
      value: successfulDays != null && successfulDays > 0
          ? '${successfulDays % 30}/30'
          : 'Нет цикла',
      variant: ProfileMetricPillVariant.hatched,
    ));
  }
  if (metrics.length < 4) {
    metrics.add(ProfileMetricPill(
      label: 'Стаб. 7д',
      value: consistency7 != null ? '$consistency7%' : '—',
      variant: ProfileMetricPillVariant.glass,
    ));
  }
  return metrics.take(4).toList();
}
