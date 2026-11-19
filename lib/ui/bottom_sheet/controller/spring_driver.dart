// 文件职责：底部弹层的状态、布局、手势与动画引擎。

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../types.dart';

/// 封装或定义弹簧driver相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
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

  /// 协调动画进度与状态过渡，用于底部弹层的状态、布局、手势与动画引擎。
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

  /// 控制流程的开始、暂停、取消或结束，用于底部弹层的状态、布局、手势与动画引擎。
  void stop() {
    _controller.stop();
    _onComplete = null;
  }

  /// 执行当前模块中的jumpto操作，用于底部弹层的状态、布局、手势与动画引擎。
  void jumpTo(double target) {
    stop();
    _controller.value = target;
    value.value = target;
  }

  /// 释放控制器、订阅、动画及其他持有资源，用于底部弹层的状态、布局、手势与动画引擎。
  void dispose() {
    _controller
      ..removeListener(_onTick)
      ..dispose();
  }
}
