import 'package:flutter/material.dart';

import '../../../core/mood/mood_state.dart';
import '../../../design/haptics.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../kit/components/prime_content_card.dart';
import '../app_dialog.dart';
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
    return showAppBottomSheet<MoodKind>(
      context: context,
      child: MoodCheckSheet(
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
    final height = MediaQuery.sizeOf(context).height * 0.82;

    return SizedBox(
      height: height,
      child: Column(
        children: [
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
                      color: active ? mood.color : AppColors.textMuted,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
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
            child: PrimeContentCard(
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
    );
  }
}
