import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme/app_radius.dart';
import '../../ui/widgets/frosted_control_surface.dart';

class PlaybackDragDemo extends StatefulWidget {
  const PlaybackDragDemo({super.key});

  @override
  State<PlaybackDragDemo> createState() => _PlaybackDragDemoState();
}

class _PlaybackDragDemoState extends State<PlaybackDragDemo>
    with SingleTickerProviderStateMixin {
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

  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.reset();
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: l10n.usageGuideDragHint,
      hint: reduceMotion ? null : l10n.usageGuideReplayDemo,
      child: Material(
        color: const Color(0xFF141416),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: reduceMotion
              ? null
              : () {
                  _animation.reset();
                  _animation.repeat();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: ExcludeSemantics(
              child: SizedBox(
                height: 68,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final pillWidth = math.min(146.0, width * 0.60);
                    final pillLeft = (width - pillWidth) / 2;
                    final maxStretch = math.min(
                      68.0,
                      math.max(0.0, pillLeft - 14),
                    );
                    return AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) => _buildPill(
                        l10n,
                        pillLeft: pillLeft,
                        pillWidth: pillWidth,
                        maxStretch: maxStretch,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPill(
    AppLocalizations l10n, {
    required double pillLeft,
    required double pillWidth,
    required double maxStretch,
  }) {
    const pillHeight = FrostedControlSurface.compactHeight;
    const pillTop = 15.0;
    final pullingLeft = _animation.value >= 0.5;
    final progress = _animation.value * 2 - (pullingLeft ? 1 : 0);
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
            left: (pullingLeft ? left + 5 : left + width - 5) - 12,
            top: pillTop + (pillHeight - 24) / 2,
            child: const SizedBox.square(
              key: ValueKey('playback-drag-touch'),
              dimension: 24,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x4DFFFFFF),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
