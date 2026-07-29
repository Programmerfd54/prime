import 'package:flutter/material.dart';

import '../../../core/mood/mood_state.dart';
import '../../../design/haptics.dart';
import '../../../design/liquid/liquid_glass.dart';
import '../../../design/shapes/prime_squircle.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../app_primary_button.dart';
import '../app_text_button.dart';
import 'mood_creature.dart';

/// Full-screen mood check-in — returns selected [MoodKind] on confirm.
class MoodCheckSheet extends StatefulWidget {
  const MoodCheckSheet({
    super.key,
    required this.name,
    this.initialMood = MoodKind.balanced,
  });

  final String name;
  final MoodKind initialMood;

  static Future<MoodKind?> show(
    BuildContext context, {
    required String name,
    MoodKind? initialMood,
  }) {
    return showModalBottomSheet<MoodKind>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.background.withValues(alpha: 0.72),
      builder: (ctx) => MoodCheckSheet(
        name: name,
        initialMood: initialMood ?? MoodKind.balanced,
      ),
    );
  }

  @override
  State<MoodCheckSheet> createState() => _MoodCheckSheetState();
}

class _MoodCheckSheetState extends State<MoodCheckSheet> {
  late final PageController _pageController;
  late int _index;

  MoodKind get _selected => MoodKind.values[_index];

  @override
  void initState() {
    super.initState();
    _index = MoodKind.values.indexOf(widget.initialMood);
    _pageController = PageController(
      initialPage: _index,
      viewportFraction: 0.38,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    if (page == _index) return;
    AppHaptics.selection();
    setState(() => _index = page);
  }

  Future<void> _confirm() async {
    await MoodState.logToday(_selected);
    if (!mounted) return;
    Navigator.of(context).pop(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height;

    return Padding(
      padding: EdgeInsets.only(top: height * 0.06),
      child: PrimeSquircleClip(
        radius: AppRadius.xl,
        child: LiquidGlass(
          radius: AppRadius.xl,
          fillOpacity: 0.18,
          allowBlurOnWeb: true,
          forceTier: LiquidTier.full,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: height * 0.94,
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppTextButton(
                    label: 'Закрыть',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: AppTypography.accentText(
                    '${widget.name.isEmpty ? 'Друг' : widget.name}, как ты себя *чувствуешь* сейчас?',
                    style: AppTypography.titleSerif.copyWith(fontSize: 26),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                MoodCreature(mood: _selected, size: 168),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 44,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: MoodKind.values.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) {
                      final mood = MoodKind.values[index];
                      final active = index == _index;
                      return Center(
                        child: AnimatedDefaultTextStyle(
                          duration: AppDurations.fast,
                          style: AppTypography.title2.copyWith(
                            color: active
                                ? mood.color
                                : AppColors.textMuted,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                          ),
                          child: Text(mood.label),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: LiquidGlass(
                    radius: AppRadius.lg,
                    fillOpacity: 0.12,
                    forceTier: LiquidTier.lite,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: AnimatedSwitcher(
                      duration: AppDurations.normal,
                      child: Text(
                        _selected.description,
                        key: ValueKey(_selected),
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySecondary.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    bottomInset + AppSpacing.lg,
                  ),
                  child: AppPrimaryButton(
                    label: 'Подобрать привычку',
                    onPressed: _confirm,
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
