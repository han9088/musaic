import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../types.dart';

/// Drives a [ValueNotifier] with a spring simulation matching RN withSpring.
class SpringDriver {
  SpringDriver({required TickerProvider vsync, required this.value})
    : _controller = AnimationController.unbounded(vsync: vsync) {
    _controller.addListener(_onTick);
  }

  final ValueNotifier<double> value;
  final AnimationController _controller;
  VoidCallback? _onComplete;

  void _onTick() {
    value.value = _controller.value;
  }

  void animateTo(
    double target, {
    required BottomSheetSpringOptions spring,
    double velocity = 0,
    VoidCallback? onComplete,
  }) {
    _onComplete = onComplete;
    final description = spring.toSpringDescription();
    final simulation = SpringSimulation(
      description,
      value.value,
      target,
      velocity,
    );
    _controller.animateWith(simulation).whenComplete(() {
      if (_controller.isAnimating) return;
      final cb = _onComplete;
      _onComplete = null;
      cb?.call();
    });
  }

  void stop() {
    _controller.stop();
    _onComplete = null;
  }

  void jumpTo(double target) {
    stop();
    _controller.value = target;
    value.value = target;
  }

  void dispose() {
    _controller
      ..removeListener(_onTick)
      ..dispose();
  }
}
