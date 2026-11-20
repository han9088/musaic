// 文件职责：专辑墙无限画布的布局、视口与交互状态。

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// 封装或定义纵向倾斜动效相关类型与行为，负责专辑墙无限画布的布局、视口与交互状态。
class PortraitTiltMotion {
  static const maxAngle = 10 * math.pi / 180;
  Offset? _neutral;
  Offset _filtered = Offset.zero;

  /// 更新相关状态并同步依赖方，用于专辑墙无限画布的布局、视口与交互状态。
  Offset update(double x, double y, double z) {
    if (!x.isFinite || !y.isFinite || !z.isFinite) return _filtered;
    final gravity = math.sqrt(x * x + y * y + z * z);
    if (gravity < 7 || gravity > 13) return _filtered;
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
        0.32;
    // Approach the limit smoothly so large tilts still respond to movement.
    final normalizedAngle = target.distance / maxAngle;
    target /= math.sqrt(1 + normalizedAngle * normalizedAngle);
    if (target.distance < 0.001) target = Offset.zero;
    _filtered = Offset.lerp(_filtered, target, 0.25)!;
    return _filtered;
  }

  /// 移除、清理或重置相关状态与资源，用于专辑墙无限画布的布局、视口与交互状态。
  void reset() {
    _neutral = null;
    _filtered = Offset.zero;
  }
}

/// 封装或定义纵向倾斜相关类型与行为，负责专辑墙无限画布的布局、视口与交互状态。
class PortraitTilt extends StatefulWidget {
  const PortraitTilt({super.key, required this.child, this.events});

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

  @override
  State<PortraitTilt> createState() => _PortraitTiltState();
}

/// 封装或定义纵向倾斜状态相关类型与行为，负责专辑墙无限画布的布局、视口与交互状态。
class _PortraitTiltState extends State<PortraitTilt>
    with WidgetsBindingObserver {
  final _motion = PortraitTiltMotion();
  StreamSubscription<AccelerometerEvent>? _subscription;
  Offset _target = Offset.zero;
  bool _resumed = true;
  bool _enabled = false;
  bool _unavailable = false;
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
    _syncSensor();
  }

  @override
  void didUpdateWidget(covariant PortraitTilt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events) {
      _stop();
      _unavailable = false;
      _syncSensor();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
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
    final events =
        widget.events ??
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 32),
        );
    _subscription = events.listen(
      (event) {
        if (!mounted || generation != _generation) return;
        final next = _motion.update(event.x, event.y, event.z);
        if ((next - _target).distance < 0.0002) return;
        setState(() => _target = next);
      },
      onError: (Object error) {
        if (!mounted || generation != _generation) return;
        _unavailable = true;
        _stop();
      },
      cancelOnError: true,
    );
  }

  /// 控制流程的开始、暂停、取消或结束，用于专辑墙无限画布的布局、视口与交互状态。
  void _stop() {
    _generation++;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _motion.reset();
    if (_target != Offset.zero && mounted) {
      setState(() => _target = Offset.zero);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
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
          builder: (context, angle, child) => Transform(
            key: const ValueKey('portrait-sensor-plane'),
            alignment: Alignment.center,
            transform: PortraitTilt.projection(angle, constraints.biggest),
            child: child,
          ),
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
