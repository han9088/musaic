// 文件职责：专辑墙无限画布的布局、视口与交互状态。

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../services/diagnostics/diagnostic_log.dart';
import '../../ui/bottom_sheet/bottom_sheet.dart';

/// 封装或定义纵向倾斜动效相关类型与行为，负责专辑墙无限画布的布局、视口与交互状态。
class PortraitTiltMotion {
  static const maxAngle = 12 * math.pi / 180;
  Offset? _neutral;
  Offset _smoothedTarget = Offset.zero;
  Offset _filtered = Offset.zero;

  /// Returns null when the reading is unsuitable for estimating gravity.
  Offset? update(double x, double y, double z) {
    if (!x.isFinite || !y.isFinite || !z.isFinite) return null;
    final gravity = math.sqrt(x * x + y * y + z * z);
    if (gravity < 7 || gravity > 13) return null;
    final angles = Offset(
      math.atan2(y, z),
      math.atan2(x, math.sqrt(y * y + z * z)),
    );
    final neutral = _neutral;
    if (neutral == null) {
      _neutral = angles;
      return Offset.zero;
    }
    final pitch = angles.dx - neutral.dx;
    var target =
        Offset(
          math.atan2(math.sin(pitch), math.cos(pitch)),
          -(angles.dy - neutral.dy),
        ) *
        0.38;
    // Approach the limit smoothly so large tilts still respond to movement.
    final normalizedAngle = target.distance / maxAngle;
    target /= math.sqrt(1 + normalizedAngle * normalizedAngle);
    if (target.distance < 0.001) target = Offset.zero;
    // Dampen brief accelerometer shake before it moves the canvas perspective.
    _smoothedTarget = Offset.lerp(_smoothedTarget, target, 0.27)!;
    _filtered = Offset.lerp(_filtered, _smoothedTarget, 0.25)!;
    return _filtered;
  }

  /// 移除、清理或重置相关状态与资源，用于专辑墙无限画布的布局、视口与交互状态。
  void reset() {
    _neutral = null;
    _smoothedTarget = Offset.zero;
    _filtered = Offset.zero;
  }
}

/// 封装或定义纵向倾斜相关类型与行为，负责专辑墙无限画布的布局、视口与交互状态。
class PortraitTilt extends StatefulWidget {
  const PortraitTilt({
    super.key,
    required this.child,
    this.events,
    this.paused = false,
    this.onProjection,
  });

  // 先额外绘制视口周边的专辑，再执行倾斜投影；只在屏幕边界进行裁剪。
  /// 执行当前模块中的overscan操作，用于专辑墙无限画布的布局、视口与交互状态。
  static double overscan(Size size) => size.longestSide * 0.15 + 16;

  static double _perspective(Size size) =>
      math.min(0.0007, 0.6 / size.longestSide);

  /// Bounds the inverse projection for every supported tilt angle.
  static Offset viewportPadding(Size size) {
    if (size.isEmpty) return Offset.zero;
    final half = size.center(Offset.zero);
    final maxAngle = PortraitTiltMotion.maxAngle;
    final inverseCosine = 1 / math.cos(maxAngle);
    final tangent = math.tan(maxAngle);
    // Inverse projection divides by 1 minus a linear function of screen x/y.
    final depth = Offset(half.dx * inverseCosine, half.dy).distance * tangent;
    final inverseW = 1 / (1 - _perspective(size) * depth);
    return Offset(
      half.dx * inverseCosine * inverseW - half.dx,
      (half.dy * inverseCosine + half.dx * tangent * tangent / 2) * inverseW -
          half.dy,
    );
  }

  /// 执行当前模块中的projection操作，用于专辑墙无限画布的布局、视口与交互状态。
  static Matrix4 projection(Offset angle, Size size) => Matrix4.identity()
    ..setEntry(3, 2, _perspective(size))
    ..rotateX(angle.dx)
    ..rotateY(angle.dy);

  final Widget child;
  final Stream<AccelerometerEvent>? events;
  final bool paused;
  final ValueChanged<Matrix4?>? onProjection;

  @override
  State<PortraitTilt> createState() => _PortraitTiltState();
}

/// 封装或定义纵向倾斜状态相关类型与行为，负责专辑墙无限画布的布局、视口与交互状态。
class _PortraitTiltState extends State<PortraitTilt>
    with WidgetsBindingObserver {
  static const _sampleWindow = Duration(milliseconds: 500);
  static const _steadyAngle = 0.14 * math.pi / 180;

  final _motion = PortraitTiltMotion();
  StreamSubscription<AccelerometerEvent>? _subscription;
  Timer? _sampleWatchdog;
  bool _receivedEvent = false;
  bool _receivedUsableSample = false;
  bool _hasUsableSamples = false;
  bool _canReconnect = true;
  Offset _target = Offset.zero;
  bool _resumed = true;
  bool _enabled = false;
  bool _unavailable = false;
  bool _routeCurrent = true;
  bool _covered = false;
  bool _sheetPresented = false;
  bool _waitingForMotionAfterReturn = false;
  BottomSheetSheetStore? _sheets;
  DiagnosticEvent? _lastSampleIssue;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled =
        !MediaQuery.disableAnimationsOf(context) &&
        MediaQuery.orientationOf(context) == Orientation.portrait;
    _routeCurrent = ModalRoute.isCurrentOf(context) != false;
    final sheets = BottomSheetScope.maybeOf(context)?.sheetStore;
    if (sheets != _sheets) {
      _sheets?.removeListener(_syncCoverage);
      _sheets = sheets;
      _sheets?.addListener(_syncCoverage);
    }
    _syncCoverage();
    _syncSensor();
  }

  void _syncCoverage() {
    final sheetPresented = _sheets?.snapshot.isPresented == true;
    final covered = !_routeCurrent || sheetPresented;
    final revealed = _covered && !covered;
    if (covered != _covered &&
        _enabled &&
        _resumed &&
        (_subscription != null || _unavailable)) {
      _waitingForMotionAfterReturn = revealed;
      diagnosticLog.record(switch ((
        covered,
        covered ? sheetPresented : _sheetPresented,
      )) {
        (true, true) => DiagnosticEvent.canvasTiltSheetOpened,
        (false, true) => DiagnosticEvent.canvasTiltSheetClosed,
        (true, false) => DiagnosticEvent.canvasTiltRouteCovered,
        (false, false) => DiagnosticEvent.canvasTiltRouteRevealed,
      });
    }
    _sheetPresented = sheetPresented;
    _covered = covered;
    if (!revealed || !_enabled || !_resumed) return;
    if (_hasUsableSamples) return;
    // A return to the canvas can recover a failed stream or a spent retry.
    diagnosticLog.record(DiagnosticEvent.canvasTiltReturnRetry);
    _unavailable = false;
    _canReconnect = true;
    _stop();
    _syncSensor();
  }

  @override
  void didUpdateWidget(covariant PortraitTilt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events) {
      _stop();
      _unavailable = false;
      _canReconnect = true;
      _syncSensor();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed && !_resumed) {
      _unavailable = false;
      _canReconnect = true;
    }
    _resumed = resumed;
    _syncSensor();
  }

  void _syncSensor() {
    final supported =
        widget.events != null ||
        (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.android));
    if (!_enabled || !_resumed || !supported) {
      _stop();
      return;
    }
    if (_subscription != null || _unavailable) return;
    final generation = ++_generation;
    void sensorUnavailable([Object? error, StackTrace? stack]) {
      if (!mounted || generation != _generation) return;
      diagnosticLog.record(
        error == null
            ? DiagnosticEvent.canvasTiltStreamEnded
            : DiagnosticEvent.canvasTiltStreamFailed,
        error: error,
        stack: stack,
      );
      _unavailable = true;
      _stop();
    }

    final events =
        widget.events ??
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 32),
        );
    _subscription = events.listen(
      (event) {
        if (!mounted || generation != _generation) return;
        _receivedEvent = true;
        _watchSamples();
        final next = _motion.update(event.x, event.y, event.z);
        if (next == null) return;
        if (!_hasUsableSamples) {
          diagnosticLog.record(DiagnosticEvent.canvasTiltSamplesReady);
        }
        _lastSampleIssue = null;
        _receivedUsableSample = true;
        _hasUsableSamples = true;
        _canReconnect = true;
        if (!widget.paused) _updateTarget(next);
      },
      onError: (Object error, StackTrace stack) =>
          sensorUnavailable(error, stack),
      onDone: sensorUnavailable,
    );
    diagnosticLog.record(DiagnosticEvent.canvasTiltSubscribed);
    _watchSamples();
  }

  void _updateTarget(Offset next) {
    if (next.distance <= _steadyAngle) {
      if (_target != Offset.zero) _setTarget(Offset.zero);
      return;
    }

    // Follow only the motion outside the band around the current tilt.
    final delta = next - _target;
    final distance = delta.distance;
    if (distance <= _steadyAngle + 0.0002) return;
    _setTarget(next - delta * (_steadyAngle / distance));
  }

  void _setTarget(Offset target) {
    if (_waitingForMotionAfterReturn && !_covered) {
      _waitingForMotionAfterReturn = false;
      diagnosticLog.record(DiagnosticEvent.canvasTiltMotionAfterReturn);
    }
    setState(() => _target = target);
  }

  void _watchSamples() {
    _sampleWatchdog ??= Timer.periodic(_sampleWindow, (timer) {
      final receivedEvent = _receivedEvent;
      final receivedUsableSample = _receivedUsableSample;
      _receivedEvent = false;
      _receivedUsableSample = false;
      if (receivedUsableSample) return;
      _hasUsableSamples = false;
      final issue = receivedEvent
          ? DiagnosticEvent.canvasTiltSamplesInvalid
          : DiagnosticEvent.canvasTiltSamplesSilent;
      if (_lastSampleIssue != issue) {
        _lastSampleIssue = issue;
        diagnosticLog.record(issue);
      }

      // Reopen a silent native stream once, then wait for data before retrying.
      if (!receivedEvent && _canReconnect && widget.events == null) {
        diagnosticLog.record(DiagnosticEvent.canvasTiltWatchdogRetry);
        _canReconnect = false;
        _stop();
        _syncSensor();
        return;
      }
      if (!receivedEvent) {
        timer.cancel();
        _sampleWatchdog = null;
      }
      _resetTilt();
    });
  }

  void _resetTilt() {
    _motion.reset();
    if (_target != Offset.zero && mounted) {
      setState(() => _target = Offset.zero);
    }
  }

  /// 控制流程的开始、暂停、取消或结束，用于专辑墙无限画布的布局、视口与交互状态。
  void _stop() {
    _generation++;
    _sampleWatchdog?.cancel();
    _sampleWatchdog = null;
    _receivedEvent = false;
    _receivedUsableSample = false;
    _hasUsableSamples = false;
    _lastSampleIssue = null;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _resetTilt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sheets?.removeListener(_syncCoverage);
    _generation++;
    _sampleWatchdog?.cancel();
    final subscription = _subscription;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) => TweenAnimationBuilder<Offset>(
          tween: Tween(begin: Offset.zero, end: _target),
          duration: _enabled && _resumed
              ? const Duration(milliseconds: 160)
              : Duration.zero,
          curve: Curves.easeOutCubic,
          child: _TiltHitArea(child: RepaintBoundary(child: widget.child)),
          builder: (context, angle, child) {
            final projection = PortraitTilt.projection(
              angle,
              constraints.biggest,
            );
            final onProjection = widget.onProjection;
            if (onProjection != null) {
              final center = constraints.biggest.center(Offset.zero);
              onProjection(
                angle == Offset.zero
                    ? null
                    : (Matrix4.translationValues(center.dx, center.dy, 0)
                        ..multiply(projection)
                        ..translateByDouble(-center.dx, -center.dy, 0, 1)),
              );
            }
            return Transform(
              key: const ValueKey('portrait-sensor-plane'),
              alignment: Alignment.center,
              transform: projection,
              child: child,
            );
          },
        ),
      ),
    );
  }
}

class _TiltHitArea extends SingleChildRenderObjectWidget {
  const _TiltHitArea({required super.child});

  @override
  RenderProxyBox createRenderObject(BuildContext context) =>
      _RenderTiltHitArea();
}

class _RenderTiltHitArea extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.contains(position)) {
      return super.hitTest(result, position: position);
    }
    if (size.shortestSide <= precisionErrorTolerance) return false;
    final inside = Offset(
      position.dx.clamp(0.0, size.width - precisionErrorTolerance),
      position.dy.clamp(0.0, size.height - precisionErrorTolerance),
    );
    // Enter the viewport's gesture recognizer without changing event coordinates.
    return super.hitTest(
      TiltEdgeHitTestResult(result, position - inside),
      position: inside,
    );
  }
}

class TiltEdgeHitTestResult extends BoxHitTestResult {
  TiltEdgeHitTestResult(super.result, this.viewportDelta) : super.wrap();

  final Offset viewportDelta;
}
