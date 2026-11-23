import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../storage/settings/usage_guide_preference.dart';

typedef GestureGuideAnimation = ({
  Animation<double> opacity,
  Animation<double> focus,
  Animation<double> gesture,
});

/// Runs a visual gesture preview once, and yields to real input immediately.
class FirstUseGestureGuide extends StatefulWidget {
  const FirstUseGestureGuide({
    super.key,
    required this.intro,
    required this.enabled,
    required this.duration,
    required this.builder,
    this.holdFocus,
  });

  final UsageGuideIntro intro;
  final bool enabled;
  final Duration duration;
  final Widget Function(BuildContext, GestureGuideAnimation? preview) builder;
  final Future<void> Function(Future<void> cancelled)? holdFocus;

  @override
  State<FirstUseGestureGuide> createState() => _FirstUseGestureGuideState();
}

class _FirstUseGestureGuideState extends State<FirstUseGestureGuide>
    with SingleTickerProviderStateMixin {
  static const _focusDuration = Duration(milliseconds: 680);
  static const _fadeDuration = Duration(milliseconds: 220);
  late final _totalDuration = _focusDuration * 2 + widget.duration;
  late final _gestureStart =
      _focusDuration.inMilliseconds / _totalDuration.inMilliseconds;
  late final _gestureEnd = 1 - _gestureStart;
  late final _animation = AnimationController(
    vsync: this,
    duration: _totalDuration,
  );
  late final GestureGuideAnimation _preview = (
    opacity: _animation.drive(
      TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: 0.0,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: _fadeDuration.inMilliseconds.toDouble(),
        ),
        TweenSequenceItem(
          tween: ConstantTween(1.0),
          weight: (_totalDuration - _fadeDuration * 2).inMilliseconds
              .toDouble(),
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: 1.0,
            end: 0.0,
          ).chain(CurveTween(curve: Curves.easeOut.flipped)),
          weight: _fadeDuration.inMilliseconds.toDouble(),
        ),
      ]),
    ),
    focus: _animation.drive(
      TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: 0.0,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: _focusDuration.inMilliseconds.toDouble(),
        ),
        TweenSequenceItem(
          tween: ConstantTween(1.0),
          weight: widget.duration.inMilliseconds.toDouble(),
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: 1.0,
            end: 0.0,
          ).chain(CurveTween(curve: Curves.easeOutCubic.flipped)),
          weight: _focusDuration.inMilliseconds.toDouble(),
        ),
      ]),
    ),
    gesture: _animation.drive(
      CurveTween(curve: Interval(_gestureStart, _gestureEnd)),
    ),
  );
  late final AppLifecycleListener _lifecycle;
  Timer? _startTimer;
  Completer<void>? _cancelFocusHold;
  bool _eligible = false;
  bool _interrupted = false;
  bool _playing = false;

  bool get _canPlay {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return widget.enabled &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.accessibleNavigationOf(context) &&
        (ModalRoute.isCurrentOf(context) ?? true);
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: (_) => _schedule());
    UsageGuidePreference.introReset.addListener(_onIntroReset);
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final revision = UsageGuidePreference.introReset.value;
    final eligible = await UsageGuidePreference.shouldPlayIntro(widget.intro);
    if (!mounted ||
        _interrupted ||
        revision != UsageGuidePreference.introReset.value) {
      return;
    }
    _eligible = eligible;
    _schedule();
  }

  void _onIntroReset() {
    _interrupt();
    _interrupted = false;
    unawaited(_restore());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(FirstUseGestureGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    if (!_canPlay) {
      _startTimer?.cancel();
      _startTimer = null;
      _stop();
    } else if (_eligible) {
      _startTimer ??= Timer(const Duration(milliseconds: 1800), _play);
    }
  }

  void _play() {
    _startTimer = null;
    if (!_eligible || !_canPlay) return;
    _eligible = false;
    unawaited(UsageGuidePreference.markIntroSeen(widget.intro));
    setState(() => _playing = true);
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      if (widget.holdFocus case final hold?) {
        final cancelled = _cancelFocusHold = Completer<void>();
        _animation.value = 0;
        await _animation
            .animateTo(_gestureEnd, duration: _totalDuration - _focusDuration)
            .orCancel;
        if (cancelled.isCompleted) return;
        await hold(cancelled.future);
        if (cancelled.isCompleted) return;
        await _animation.forward().orCancel;
      } else {
        await _animation.forward(from: 0).orCancel;
      }
      if (mounted) _stop();
    } on TickerCanceled {
      // Pointer input or disposal already stopped the guide.
    }
  }

  void _interrupt() {
    _interrupted = true;
    _eligible = false;
    _startTimer?.cancel();
    _startTimer = null;
    _stop();
  }

  void _stop() {
    if (!_playing) return;
    _cancelFocusHold?.complete();
    _cancelFocusHold = null;
    _animation.stop();
    setState(() => _playing = false);
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _cancelFocusHold?.complete();
    UsageGuidePreference.introReset.removeListener(_onIntroReset);
    _lifecycle.dispose();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _handleInput,
    onPointerSignal: _handleInput,
    onPointerPanZoomStart: _handleInput,
    child: widget.builder(context, _playing ? _preview : null),
  );

  void _handleInput(PointerEvent _) {
    if (_playing || _canPlay) _interrupt();
  }
}
