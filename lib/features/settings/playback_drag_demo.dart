import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../ui/widgets/frosted_control_surface.dart';
import '../../ui/widgets/guide_touch_indicator.dart';
import 'usage_guide_demo_card.dart';

class PlaybackDragDemo extends StatelessWidget {
  const PlaybackDragDemo({super.key});

  static const _reachForPill = 8.0;
  static const _shortPull = 11.0;
  static const _showSkip = 8.0;
  static const _shortRelease = 11.0;
  static const _betweenPulls = 8.0;
  static const _longPull = 20.0;
  static const _holdForSeek = 20.0;
  static const _longRelease = 10.0;
  static const _pause = 4.0;
  static const _shortReleaseStart = _reachForPill + _shortPull + _showSkip;
  static const _longPullStart =
      _shortReleaseStart + _shortRelease + _betweenPulls;
  static const _seekStart = _longPullStart + _longPull;
  static const _longReleaseStart = _seekStart + _holdForSeek;

  static final _ease = CurveTween(curve: Curves.easeInOutCubic);
  static final _stretch = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(0.0), weight: _reachForPill),
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 0.42).chain(_ease),
      weight: _shortPull,
    ),
    TweenSequenceItem(tween: ConstantTween(0.42), weight: _showSkip),
    TweenSequenceItem(
      tween: Tween(begin: 0.42, end: 0.0).chain(_ease),
      weight: _shortRelease,
    ),
    TweenSequenceItem(tween: ConstantTween(0.0), weight: _betweenPulls),
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 1.0).chain(_ease),
      weight: _longPull,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: _holdForSeek),
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.0).chain(_ease),
      weight: _longRelease,
    ),
    TweenSequenceItem(tween: ConstantTween(0.0), weight: _pause),
  ]);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return UsageGuideDemoCard(
      duration: const Duration(milliseconds: 6400),
      label: l10n.usageGuideDragHint,
      builder: (context, animation) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: SizedBox(
          height: 68,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final pillWidth = math.min(146.0, width * 0.60);
              final pillLeft = (width - pillWidth) / 2;
              final maxStretch = math.min(68.0, math.max(0.0, pillLeft - 14));
              return AnimatedBuilder(
                animation: animation,
                builder: (context, _) => _buildPill(
                  l10n,
                  animation.value,
                  pillLeft: pillLeft,
                  pillWidth: pillWidth,
                  maxStretch: maxStretch,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPill(
    AppLocalizations l10n,
    double value, {
    required double pillLeft,
    required double pillWidth,
    required double maxStretch,
  }) {
    const pillHeight = FrostedControlSurface.compactHeight;
    const pillTop = 15.0;
    final pullingLeft = value >= 0.5;
    final progress = value * 2 - (pullingLeft ? 1 : 0);
    final extension = maxStretch * _stretch.transform(progress);
    final left = pillLeft - (pullingLeft ? extension : 0);
    final width = pillWidth + extension;
    final elapsed = progress * 100;
    final isShortGesture = elapsed < _longPullStart;
    final held = isShortGesture
        ? elapsed >= _reachForPill && elapsed < _shortReleaseStart
        : elapsed < _longReleaseStart;
    final isSeeking = elapsed >= _seekStart;
    final hasFeedback = extension > 0 && (isShortGesture || isSeeking);
    final (label, icon) = switch ((hasFeedback, pullingLeft, isSeeking)) {
      (false, _, _) => (l10n.usageGuidePlaybackBar, PhosphorIcons.pauseFill),
      (true, false, false) => (
        l10n.musicNextTrack,
        PhosphorIcons.skipForwardFill,
      ),
      (true, true, false) => (
        l10n.musicPreviousTrack,
        PhosphorIcons.skipBackFill,
      ),
      (true, false, true) => (
        l10n.usageGuideDragFastForward,
        PhosphorIcons.fastForwardFill,
      ),
      (true, true, true) => (
        l10n.usageGuideDragRewind,
        PhosphorIcons.rewindFill,
      ),
    };

    return Stack(
      children: [
        Positioned(
          left: left,
          top: pillTop,
          width: width,
          height: pillHeight,
          child: const DecoratedBox(
            key: ValueKey('playback-drag-pill'),
            decoration: ShapeDecoration(
              color: Color(0xFF2A2A2D),
              shape: StadiumBorder(),
            ),
          ),
        ),
        Positioned(
          left: pillLeft,
          top: pillTop,
          width: pillWidth,
          height: pillHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(icon, size: 15, color: Colors.white),
              ],
            ),
          ),
        ),
        if (held)
          Positioned(
            left:
                (pullingLeft ? left + 5 : left + width - 5) -
                GuideTouchIndicator.diameter / 2,
            top: pillTop + (pillHeight - GuideTouchIndicator.diameter) / 2,
            child: const GuideTouchIndicator(
              key: ValueKey('playback-drag-touch'),
            ),
          ),
      ],
    );
  }
}
