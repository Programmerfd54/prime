import 'package:flutter/material.dart';

import '../../../core/media/media_urls.dart';
import '../../../core/metrics/calendar_metrics.dart';
import '../../../l10n/copy.dart';
import '../../../design/tokens.dart';
import '../../../design/visuals/charts/charts.dart';
import '../../../models/report.dart';
import '../../components/profile/verified_email_badge.dart';
import 'profile_surfaces.dart';
import 'profile_typography.dart';
import 'profile_icons.dart';

/// Profile color system — TZ §5.2 (local to profile screens).
abstract final class ProfilePalette {
  static const warmYellow = Color(0xFFFFD65A);
  static const charcoal = Color(0xFF262628);
  static const chartSurface = Color(0xFF262628);
  static const contentSurface = Color(0xFF2A282E);
  static const cardSurface = contentSurface;
  static const chartGold = warmYellow;
  static const taupe = Color(0xFF3D3835);
  static const dustyLavender = Color(0xFF4A4458);
  static const coolGrey = Color(0xFFC7CDD4);
  static const mint = Color(0xFF58D6B2);
  static const coral = Color(0xFFFF7A72);
  static const offWhite = Color(0xFFFAF9FC);
  static const brand = Color(0xFF8B5CF6);
  static const brandSoft = Color(0xFFA78BFA);
  static const primaryAction = Color(0xFF6D28D9);

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
    this.moreButtonKey,
    this.statusBadge,
    this.showVerifiedBadge = false,
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
  final GlobalKey? moreButtonKey;
  final String? statusBadge;
  final bool showVerifiedBadge;

  static const cardRadius = ProfileSurfaces.shellRadius;
  static const photoHeightWithPhoto = 280.0;
  static const photoHeightNoPhoto = 220.0;
  static const portraitAspectRatio = 5 / 4;
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
    final buckets = profileRhythmBuckets(widget.calendar);
    final visibleTags = widget.tags.take(3).toList();
    final extraTags = widget.tags.length - visibleTags.length;
    final hasPhoto =
        widget.photoUrl != null && widget.photoUrl!.trim().isNotEmpty;
    final parallax = MediaQuery.disableAnimationsOf(context)
        ? 0.0
        : widget.scrollOffset.clamp(0.0, 80.0) * 0.1;
    final shell = ProfileSurfaces.profileShell;
    final aboutText = widget.about?.trim();

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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ProfileSurfaces.shellRadius),
              child: DecoratedBox(
                decoration: ProfileSurfaces.heroShellDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: ProfileHeroCard.portraitAspectRatio,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (hasPhoto)
                            Transform.translate(
                              offset: Offset(0, parallax),
                              child: ProfileHeroImage(
                                photoUrl: widget.photoUrl,
                                displayName: widget.displayName,
                                alignment: Alignment.topCenter,
                              ),
                            )
                          else
                            ProfileHeroImage(
                              photoUrl: null,
                              displayName: widget.displayName,
                              compact: true,
                            ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: ProfileSurfaces.photoOverlayGradient,
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: ProfileSurfaces.photoToShellGradient(
                                shell,
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
                            moreButtonKey: widget.moreButtonKey,
                          ),
                          Positioned(
                            left: ProfileSurfaces.heroContentPadding,
                            right: ProfileSurfaces.heroContentPadding,
                            bottom: AppSpacing.md,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  widget.displayName,
                                  style: ProfileTypography.displayName.copyWith(
                                    color: ProfilePalette.offWhite,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w600,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.4),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                if (widget.subtitle?.isNotEmpty == true) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          widget.subtitle!,
                                          style: ProfileTypography.subtitle.copyWith(
                                            color: ProfilePalette.offWhite
                                                .withValues(alpha: 0.9),
                                            fontWeight: FontWeight.w400,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      if (widget.showVerifiedBadge) ...[
                                        const SizedBox(width: 4),
                                        const VerifiedEmailBadge(size: 18),
                                      ],
                                    ],
                                  ),
                                ],
                                if (widget.statusBadge?.isNotEmpty == true) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ProfilePalette.warmYellow
                                          .withValues(alpha: 0.24),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: ProfilePalette.warmYellow
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Text(
                                      widget.statusBadge!,
                                      style: ProfileTypography.tag.copyWith(
                                        color: ProfilePalette.warmYellow,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        ProfileSurfaces.heroContentPadding,
                        AppSpacing.sm,
                        ProfileSurfaces.heroContentPadding,
                        ProfileSurfaces.heroContentPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (visibleTags.isNotEmpty) ...[
                            ProfileHabitTagsRow(
                              tags: visibleTags,
                              extraCount: extraTags,
                              centered: true,
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          if (aboutText?.isNotEmpty == true) ...[
                            _ProfileHeroBio(text: aboutText!),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          if (widget.statusLine?.isNotEmpty == true) ...[
                            Text(
                              widget.statusLine!,
                              style: ProfileTypography.secondary.copyWith(
                                color: ProfilePalette.offWhite
                                    .withValues(alpha: 0.82),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          if (widget.metrics.isNotEmpty) ...[
                            ProfileMetricPillsRow(
                              metrics: widget.metrics,
                              onHero: true,
                            ),
                          ],
                          if (widget.showChart && widget.metrics.isNotEmpty)
                            const SizedBox(height: AppSpacing.md),
                          if (widget.showChart)
                            ProfileTrendChart(buckets: buckets),
                        ],
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

class _ProfileHeroBio extends StatelessWidget {
  const _ProfileHeroBio({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: ProfileTypography.bio.copyWith(
        color: ProfilePalette.offWhite.withValues(alpha: 0.82),
        fontSize: 14,
        height: 1.45,
      ),
      textAlign: TextAlign.center,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
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

/// Team / cohort comparison line for hero rhythm chart (TZ §7.7).
List<double> profileRhythmComparison(List<WeekDayBucket> buckets) {
  if (buckets.isEmpty) return const [];
  final mean = buckets.map((b) => b.intensity).reduce((a, b) => a + b) /
      buckets.length;
  return [
    for (final b in buckets)
      ((mean * 0.72) + (b.intensity * 0.12)).clamp(0.05, 0.95),
  ];
}

class ProfileTrendChart extends StatelessWidget {
  const ProfileTrendChart({super.key, required this.buckets});

  final List<WeekDayBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final values = buckets.map((b) => b.intensity).toList();
    final labels = buckets.map((b) => b.label).toList();
    final comparison = profileRhythmComparison(buckets);
    final hasChart = values.where((v) => v > 0).length >= 2;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ProfileSurfaces.surfaceElevated,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: ProfileSurfaces.outlineStrong),
      ),
      constraints: const BoxConstraints(minHeight: 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ритм за 30 дней',
            style: ProfileTypography.cardTitle.copyWith(
              color: ProfilePalette.offWhite,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xxs,
            children: [
              _LegendDot(
                color: ProfilePalette.warmYellow,
                label: 'Вы',
              ),
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
                      color: ProfilePalette.coolGrey.withValues(alpha: 0.88),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            PrimeNeonLineChart(
              values: values,
              secondaryValues: comparison,
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
    this.displayName,
    this.alignment = Alignment.topCenter,
    this.compact = false,
  });

  final String? photoUrl;
  final String? displayName;
  final Alignment alignment;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final url = absolutePhotoUrl(photoUrl);
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        alignment: alignment,
        errorBuilder: (_, __, ___) => _HeroPlaceholder(
          displayName: displayName ?? '',
          compact: compact,
        ),
      );
    }
    return _HeroPlaceholder(
      displayName: displayName ?? '',
      compact: compact,
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder({
    required this.displayName,
    this.compact = false,
  });

  final String displayName;
  final bool compact;

  String get _initials {
    final cleaned = displayName.replaceAll('@', '').trim();
    if (cleaned.isEmpty) return '?';
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final list = parts.toList();
    if (list.length >= 2) {
      return '${list[0][0]}${list[1][0]}'.toUpperCase();
    }
    final single = list.first;
    return (single.length >= 2
            ? single.substring(0, 2)
            : single.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final monogramSize = compact ? 120.0 : 128.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ProfilePalette.dustyLavender.withValues(alpha: 0.55),
            ProfilePalette.taupe,
            ProfilePalette.contentSurface,
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _SubtleMeshPainter(seed: displayName)),
          ),
          Container(
            width: monogramSize,
            height: monogramSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ProfilePalette.charcoal.withValues(alpha: 0.72),
              border: Border.all(
                color: ProfilePalette.offWhite.withValues(alpha: 0.14),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              _initials,
              style: ProfileTypography.displayName.copyWith(
                fontSize: compact ? 40 : 44,
                fontWeight: FontWeight.w600,
                color: ProfilePalette.offWhite.withValues(alpha: 0.92),
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtleMeshPainter extends CustomPainter {
  const _SubtleMeshPainter({required this.seed});

  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final hash = seed.hashCode.abs();
    final paint = Paint()
      ..color = ProfilePalette.brandSoft.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    final cx = size.width * (0.25 + (hash % 50) / 100);
    final cy = size.height * 0.35;
    canvas.drawCircle(Offset(cx, cy), size.width * 0.35, paint);
    paint.color = ProfilePalette.warmYellow.withValues(alpha: 0.04);
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.55),
      size.width * 0.28,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SubtleMeshPainter oldDelegate) =>
      oldDelegate.seed != seed;
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
    this.moreButtonKey,
  });

  final ProfileHeroMode mode;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;
  final VoidCallback? onEdit;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onMessage;
  final VoidCallback? onMore;
  final GlobalKey? moreButtonKey;

  @override
  Widget build(BuildContext context) {
    final topInset = mode == ProfileHeroMode.public
        ? MediaQuery.paddingOf(context).top + AppSpacing.xs
        : AppSpacing.md;

    return Positioned(
      top: topInset,
      left: AppSpacing.md,
      right: AppSpacing.md,
      child: Row(
        children: [
          if (mode == ProfileHeroMode.public)
            ProfileGlassAction(
              icon: ProfileIcons.back,
              onPressed: onBack ?? () => Navigator.maybePop(context),
              semanticsLabel: 'Назад',
            )
          else
            const SizedBox(width: 44),
          const Spacer(),
          if (mode == ProfileHeroMode.public) ...[
            if (onMessage != null) ...[
              ProfileGlassAction(
                icon: ProfileIcons.message,
                onPressed: onMessage,
                semanticsLabel: 'Написать',
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (onMore != null)
              ProfileGlassAction(
                key: moreButtonKey,
                icon: ProfileIcons.more,
                onPressed: onMore,
                semanticsLabel: 'Ещё',
              ),
          ],
          if (mode == ProfileHeroMode.own) ...[
            if (onEdit != null || onAvatarTap != null) ...[
              ProfileGlassAction(
                icon: ProfileIcons.edit,
                onPressed: onEdit ?? onAvatarTap,
                semanticsLabel: 'Редактировать',
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (onSettings != null)
              ProfileGlassAction(
                icon: ProfileIcons.settings,
                onPressed: onSettings,
                semanticsLabel: 'Настройки',
              ),
          ],
        ],
      ),
    );
  }
}

enum ProfileGlassActionVariant { onPhoto, onSurface }

class ProfileGlassAction extends StatelessWidget {
  const ProfileGlassAction({
    super.key,
    required this.icon,
    this.onPressed,
    this.semanticsLabel,
    this.variant = ProfileGlassActionVariant.onPhoto,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? semanticsLabel;
  final ProfileGlassActionVariant variant;

  static const _size = 44.0;
  static const _radius = 14.0;

  @override
  Widget build(BuildContext context) {
    final fill = ProfileSurfaces.surfaceElevated.withValues(alpha: 0.82);
    final border = ProfileSurfaces.outlineStrong;
    final iconColor = ProfilePalette.offWhite.withValues(alpha: 0.94);

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(_radius),
          child: Ink(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              color: fill,
              border: Border.all(color: border),
            ),
            child: ProfileIcon(
              icon,
              size: AppIconSizes.sm,
              color: iconColor,
            ),
          ),
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
    this.centered = false,
  });

  final List<ProfileHabitTag> tags;
  final int extraCount;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      for (final tag in tags) ProfileTag(label: tag.label, accent: tag.accent),
      if (extraCount > 0)
        ProfileTag(label: '+$extraCount', accent: ProfilePalette.coolGrey),
    ];

    if (centered) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: chips,
      );
    }

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) => chips[i],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.72),
            Color.alphaBlend(
              Colors.white.withValues(alpha: 0.12),
              accent.withValues(alpha: 0.58),
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: ProfileTypography.tag.copyWith(
          color: ProfilePalette.offWhite.withValues(alpha: 0.95),
          fontWeight: FontWeight.w600,
        ),
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

  static const _pillRadius = 16.0;
  static const _pillHeight = 58.0;

  final ProfileMetricPill metric;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final labelColor = onHero
        ? ProfilePalette.offWhite.withValues(alpha: 0.92)
        : ProfilePalette.coolGrey.withValues(alpha: 0.95);
    final (valueColor, decoration) = _pillStyle(metric.variant, onHero: onHero);

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
        constraints: const BoxConstraints(minHeight: _pillHeight),
        decoration: decoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_pillRadius),
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
      constraints: const BoxConstraints(minHeight: _pillHeight),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: decoration,
      child: text,
    );
  }

  (Color, BoxDecoration) _pillStyle(
    ProfileMetricPillVariant variant, {
    required bool onHero,
  }) {
    switch (variant) {
      case ProfileMetricPillVariant.gold:
        return (
          ProfilePalette.charcoal,
          BoxDecoration(
            color: ProfilePalette.warmYellow,
            borderRadius: BorderRadius.circular(_pillRadius),
            border: onHero
                ? Border.all(
                    color: ProfilePalette.warmYellow.withValues(alpha: 0.55),
                  )
                : null,
            boxShadow: onHero
                ? [
                    BoxShadow(
                      color: ProfilePalette.warmYellow.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
        );
      case ProfileMetricPillVariant.charcoal:
        return (
          ProfilePalette.offWhite,
          BoxDecoration(
            color: onHero
                ? ProfileSurfaces.surfaceElevated
                : ProfilePalette.charcoal,
            borderRadius: BorderRadius.circular(_pillRadius),
            border: Border.all(
              color: onHero
                  ? ProfileSurfaces.outlineStrong
                  : ProfileSurfaces.outlineSoft,
            ),
          ),
        );
      case ProfileMetricPillVariant.hatched:
        return (
          ProfilePalette.offWhite,
          BoxDecoration(
            color: onHero
                ? ProfileSurfaces.surfaceTinted
                : const Color(0xFF3A3840),
            borderRadius: BorderRadius.circular(_pillRadius),
            border: Border.all(color: ProfileSurfaces.outlineStrong),
          ),
        );
      case ProfileMetricPillVariant.glass:
        return (
          ProfilePalette.offWhite,
          BoxDecoration(
            color: onHero
                ? ProfileSurfaces.surfaceElevated.withValues(alpha: 0.88)
                : ProfilePalette.coolGrey.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(_pillRadius),
            border: Border.all(
              color: onHero
                  ? ProfilePalette.brandSoft.withValues(alpha: 0.42)
                  : ProfilePalette.coolGrey.withValues(alpha: 0.28),
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
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
      label: AppCopy.profileProgressLabel,
      value: successfulDays != null && successfulDays > 0
          ? '${successfulDays % 30}/30'
          : AppCopy.profileProgressEmpty,
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
