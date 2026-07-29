import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

/// Semantic Lottie slots with SVG fallbacks when `.json` assets are missing.
enum PrimeLottieSlot {
  success,
  teamSearch,
  empty,
  loading,
  studyDiscussion,
  imageNotPreview,
}

/// Filenames under `assets/lottie/`:
/// - success.json
/// - team_search.json
/// - empty.json
/// - loading.json
/// - study_discussion.json
/// - image_not_preview.json
abstract final class LottieRegistry {
  static const Map<PrimeLottieSlot, String> _paths = {
    PrimeLottieSlot.success: 'assets/lottie/success.json',
    PrimeLottieSlot.teamSearch: 'assets/lottie/team_search.json',
    PrimeLottieSlot.empty: 'assets/lottie/empty.json',
    PrimeLottieSlot.loading: 'assets/lottie/loading.json',
    PrimeLottieSlot.studyDiscussion: 'assets/lottie/study_discussion.json',
    PrimeLottieSlot.imageNotPreview: 'assets/lottie/image_not_preview.json',
  };

  static const Map<PrimeLottieSlot, String> _svgFallbacks = {
    PrimeLottieSlot.success: 'assets/illustrations/report_done.svg',
    PrimeLottieSlot.teamSearch: 'assets/illustrations/team_gathering.svg',
    PrimeLottieSlot.empty: 'assets/illustrations/empty.svg',
    PrimeLottieSlot.loading: 'assets/illustrations/generic.svg',
    PrimeLottieSlot.studyDiscussion: 'assets/illustrations/read.svg',
    PrimeLottieSlot.imageNotPreview: 'assets/illustrations/generic.svg',
  };

  static String pathFor(PrimeLottieSlot slot) => _paths[slot]!;

  static String svgFallbackFor(PrimeLottieSlot slot) => _svgFallbacks[slot]!;
}

/// Renders a Lottie asset when present; otherwise falls back to the SVG.
///
/// On Flutter web (CanvasKit), Lottie path metrics can stack-overflow on
/// complex fills — use the SVG fallback there. Same for reduce-motion /
/// [MediaQuery.disableAnimationsOf] so tests can [pumpAndSettle].
class PrimeLottie extends StatelessWidget {
  const PrimeLottie({
    super.key,
    required this.slot,
    this.width = 120,
    this.height = 120,
    this.repeat = true,
  });

  final PrimeLottieSlot slot;
  final double width;
  final double height;
  final bool repeat;

  Widget _svg() {
    return SvgPicture.asset(
      LottieRegistry.svgFallbackFor(slot),
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    // Web CanvasKit: PathMetrics on some Lottie fills recurse until SOE.
    if (kIsWeb || reduce) {
      return SizedBox(width: width, height: height, child: _svg());
    }

    return SizedBox(
      width: width,
      height: height,
      child: Lottie.asset(
        LottieRegistry.pathFor(slot),
        width: width,
        height: height,
        repeat: repeat,
        animate: true,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _svg(),
      ),
    );
  }
}
