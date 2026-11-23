import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../storage/settings/usage_guide_preference.dart';
import '../../../ui/bottom_sheet/bottom_sheet.dart';
import '../../../ui/widgets/guide_touch_indicator.dart';
import '../../onboarding/first_use_gesture_guide.dart';
import '../../onboarding/gesture_guide_spotlight.dart';
import 'now_playing_controls.dart';

class PlaybackGestureIntro extends StatelessWidget {
  const PlaybackGestureIntro({
    super.key,
    required this.enabled,
    required this.builder,
    required this.sheetDetent,
    required this.buildSheet,
  });

  final bool enabled;
  final BottomSheetDetentFraction sheetDetent;
  final Widget Function() buildSheet;
  final Widget Function(BuildContext, Animation<PlaybackPullPreview>? preview)
  builder;

  @override
  Widget build(BuildContext context) {
    final hasSheetHost = BottomSheetScope.maybeOf(context) != null;
    return FirstUseGestureGuide(
      intro: UsageGuideIntro.playback,
      enabled: enabled,
      duration: hasSheetHost ? _PullTimeline.duration : _PullTimeline.playback,
      holdFocus: hasSheetHost
          ? (cancelled) => _showSheet(DeskBottomSheet.of(context), cancelled)
          : null,
      builder: (context, intro) => builder(
        context,
        intro?.gesture.drive(
          _PullTimeline(
            AppLocalizations.of(context),
            intro,
            hasSheetHost ? sheetDetent : null,
          ),
        ),
      ),
    );
  }

  Future<void> _showSheet(DeskBottomSheet host, Future<void> cancelled) async {
    if (host.isPresented) return;
    final release = Completer<void>();
    final dismissed = Completer<void>();
    Timer? hold;

    void beginClosing() {
      if (!release.isCompleted) release.complete();
    }

    final id = host.present(
      Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => beginClosing(),
        child: ExcludeSemantics(child: AbsorbPointer(child: buildSheet())),
      ),
      BottomSheetOptions(
        mode: BottomSheetMode.push,
        pushDirection: PushDirection.bottom,
        snapPoints: [sheetDetent],
        index: 0,
        enableDynamicSizing: false,
        enableContentPanningGesture: false,
        showHandle: true,
        onChange: (_) {
          if (!release.isCompleted) {
            hold ??= Timer(const Duration(milliseconds: 1200), beginClosing);
          }
        },
        onDismiss: dismissed.complete,
      ),
    );

    await Future.any([release.future, dismissed.future, cancelled]);
    beginClosing();
    hold?.cancel();
    if (dismissed.isCompleted || host.topSheetId != id) return;
    if (host.topSheetController == null) {
      await WidgetsBinding.instance.endOfFrame;
    }
    if (host.topSheetId != id) return;
    host.dismiss(id);
    await Future.any([dismissed.future, cancelled]);
  }
}

class _PullTimeline extends Animatable<PlaybackPullPreview> {
  _PullTimeline(this.l10n, this.intro, this.detent);

  static const playback = Duration(milliseconds: 3600);
  static const _expand = Duration(milliseconds: 520);
  static final duration =
      playback + _expand + const Duration(milliseconds: 540);
  static final _expandStart = playback.inMilliseconds / duration.inMilliseconds;
  static final _swipeStart =
      (playback + _expand).inMilliseconds / duration.inMilliseconds;

  late final _expansion = intro.gesture.drive(
    CurveTween(
      curve: Interval(_expandStart, _swipeStart, curve: Curves.easeInOutCubic),
    ),
  );

  static final _ease = CurveTween(curve: Curves.easeInOutCubic);
  static final _drag = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 12),
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: -64.0).chain(_ease),
      weight: 8,
    ),
    TweenSequenceItem(
      tween: Tween(begin: -64.0, end: 0.0).chain(_ease),
      weight: 10,
    ),
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 15),
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 84.0).chain(_ease),
      weight: 13,
    ),
    TweenSequenceItem(tween: ConstantTween(84.0), weight: 24),
    TweenSequenceItem(
      tween: Tween(begin: 84.0, end: 0.0).chain(_ease),
      weight: 14,
    ),
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 4),
  ]);

  final AppLocalizations l10n;
  final GestureGuideAnimation intro;
  final BottomSheetDetentFraction? detent;

  Widget _decorateTarget(Widget target) => GestureGuideSpotlight(
    opacity: intro.opacity,
    focus: intro.focus,
    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 3),
    expansion: detent == null
        ? null
        : (progress: _expansion, shape: _sheetShape),
    caption: AnimatedBuilder(
      animation: intro.gesture,
      builder: (_, _) {
        final caption = detent != null && intro.gesture.value >= _expandStart
            ? l10n.usageGuideSwipeUpForSettings
            : l10n.usageGuidePlaybackControls;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(caption, key: ValueKey(caption)),
        );
      },
    ),
    child: target,
  );

  RRect _sheetShape(Size viewport) {
    final top = getDetentTranslateY(detent!, viewport.height, 0);
    return RRect.fromRectAndRadius(
      Rect.fromLTRB(0, top, viewport.width, viewport.height),
      const Radius.circular(kBottomSheetCornerRadius),
    );
  }

  @override
  PlaybackPullPreview transform(double timeline) {
    if (detent != null && timeline >= _expandStart) {
      final progress = Interval(_swipeStart, 1).transform(timeline);
      final lift = _ease.transform((progress / 0.78).clamp(0.0, 1.0));
      final release = ((progress - 0.78) / 0.22).clamp(0.0, 1.0);
      return (
        drag: Offset(0, -145 * lift * (1 - release)),
        title: null,
        icon: null,
        decorateTarget: _decorateTarget,
        indicator: progress > 0 && progress < 1
            ? _touch(Offset(0, -88 * lift), opacity: 1 - release)
            : null,
      );
    }
    final progress = detent == null ? timeline : timeline / _expandStart;
    final drag = _drag.transform(progress);
    final (title, icon) = switch (drag) {
      < 0 => (l10n.musicPreviousTrack, PhosphorIcons.skipBackFill),
      > 0 when progress >= 0.64 => (
        l10n.usageGuideDragFastForward,
        PhosphorIcons.fastForwardFill,
      ),
      > 0 => (l10n.musicNextTrack, PhosphorIcons.skipForwardFill),
      _ => (null, null),
    };
    final shortTouch = progress >= 0.08 && progress < 0.20;
    final longTouch = progress >= 0.41 && progress < 0.82;
    return (
      drag: Offset(drag, 0),
      title: title,
      icon: icon,
      decorateTarget: _decorateTarget,
      indicator: shortTouch || longTouch
          ? _touch(Offset((shortTouch ? -42 : 42) + drag / 3, 0))
          : null,
    );
  }

  Widget _touch(Offset offset, {double opacity = 1}) => Center(
    child: Transform.translate(
      offset: offset,
      child: Opacity(
        opacity: opacity,
        child: const GuideTouchIndicator(key: ValueKey('playback-intro-touch')),
      ),
    ),
  );
}
