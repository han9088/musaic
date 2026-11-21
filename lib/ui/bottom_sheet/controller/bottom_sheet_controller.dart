// 文件职责：底部弹层的状态、布局、手势与动画引擎。

import 'package:flutter/widgets.dart';

import '../detents.dart';
import '../push_direction.dart';
import '../push_layout.dart';
import '../sheet_pan.dart';
import '../types.dart';
import 'spring_driver.dart';

/// 封装或定义弹层控制器相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class SheetController extends BottomSheetControllerApi {
  SheetController({
    required TickerProvider vsync,
    required this.options,
    required this.layout,
    required this.progress,
    required this.screenHeight,
    required this.topInset,
    required this.bottomInset,
    required this.onDismissComplete,
    this.hostSheetTopY,
    this.pushProgressOpenY,
    this.pushSheetHeight,
  }) {
    final pushDir = pushDirectionToJs(options.pushDirection);
    _pushDirectionJs = pushDir;
    _pushLayoutTopInset = pushDir == PushDirectionJs.top ? 0 : topInset;
    _closedTopY = getPushClosedTopY(pushDir, screenHeight, _pushLayoutTopInset);
    _openTopY = getPushOpenTopY(pushDir, screenHeight, _pushLayoutTopInset);
    _isPushLayout = hostSheetTopY != null && pushProgressOpenY != null;

    final initialY = _isPushLayout ? _closedTopY : screenHeight;
    sheetTranslateY = hostSheetTopY ?? ValueNotifier(initialY);
    if (hostSheetTopY == null) {
      sheetTranslateY.value = initialY;
    } else {
      hostSheetTopY!.value = initialY;
    }

    if (_isPushLayout) {
      pushProgressOpenY!.value = _openTopY;
    }

    _sheetDriver = SpringDriver(vsync: vsync, value: sheetTranslateY);
    _progressDriver = SpringDriver(vsync: vsync, value: progress);

    activeDetentIndex = clampIndex(
      options.index,
      options.snapPoints.isEmpty ? 1 : options.snapPoints.length,
    );
    animatedIndex.value = activeDetentIndex.toDouble();

    sheetTranslateY.addListener(_syncPushProgress);
  }

  final ResolvedBottomSheetOptions options;
  final BottomSheetLayoutOptions layout;
  final ValueNotifier<double> progress;
  final ValueNotifier<double>? hostSheetTopY;
  final ValueNotifier<double>? pushProgressOpenY;
  final ValueNotifier<double>? pushSheetHeight;
  final double screenHeight;
  final double topInset;
  final double bottomInset;
  final VoidCallback onDismissComplete;

  late final ValueNotifier<double> sheetTranslateY;
  late final SpringDriver _sheetDriver;
  late final SpringDriver _progressDriver;
  late final bool _isPushLayout;
  late final int _pushDirectionJs;
  late final double _pushLayoutTopInset;
  late final double _closedTopY;
  late final double _openTopY;

  final animatedIndex = ValueNotifier<double>(0);
  final scrollOffset = ValueNotifier<double>(0);
  int activeDetentIndex = 0;
  double? contentHeight;
  double _dragStartY = 0;
  bool _isDragging = false;
  bool _didOpen = false;
  VoidCallback? _stopRouteSlide;

  BottomSheetSpringOptions get _layoutSpring {
    if (_isPushLayout) return layout.motion.pushLayoutSpring;
    if (options.mode == BottomSheetMode.presentation) {
      return layout.motion.presentationSpring;
    }
    return layout.motion.sheetSpring;
  }

  /// 处理对应事件并协调后续状态变化，用于底部弹层的状态、布局、手势与动画引擎。
  double get handleHeight =>
      options.showHandle ? layout.handle.height : layout.handle.hiddenHeight;

  /// 执行当前模块中的effectivesnappoints操作，用于底部弹层的状态、布局、手势与动画引擎。
  List<BottomSheetDetent> get effectiveSnapPoints {
    final dynamicPoint = options.enableDynamicSizing && contentHeight != null
        ? buildDynamicSnapPoint(
            contentHeight!,
            screenHeight,
            topInset,
            bottomInset,
            handleHeight,
          )
        : null;
    return mergeSnapPoints(
      options.snapPoints,
      dynamicPoint,
      options.enableDynamicSizing,
    );
  }

  /// 执行当前模块中的keyboardoffset操作，用于底部弹层的状态、布局、手势与动画引擎。
  double get keyboardOffset {
    // 该值由外部通过 [setKeyboardHeight] 更新。
    return _keyboardHeight;
  }

  double _keyboardHeight = 0;

  /// 应用选择并更新对应状态，用于底部弹层的状态、布局、手势与动画引擎。
  void setKeyboardHeight(double height) {
    final behavior = options.keyboardBehavior;
    if (behavior == BottomSheetKeyboardBehavior.extend) {
      _keyboardHeight = 0;
    } else {
      _keyboardHeight = height;
    }
  }

  void _syncPushProgress() {
    if (!_isPushLayout || pushProgressOpenY == null) return;
    progress.value = getPushLayoutProgress(
      sheetTranslateY.value,
      pushProgressOpenY!.value,
      screenHeight,
      _pushDirectionJs,
      _pushLayoutTopInset,
    );
    if (pushSheetHeight != null) {
      final snaps = effectiveSnapPoints;
      if (snaps.isNotEmpty) {
        pushSheetHeight!.value = getPushSheetHeightForDetent(
          snaps[activeDetentIndex.clamp(0, snaps.length - 1)],
          screenHeight,
          _pushLayoutTopInset,
        );
      }
    }
  }

  /// 执行当前模块中的open操作，用于底部弹层的状态、布局、手势与动画引擎。
  void open() {
    if (_didOpen) return;
    _didOpen = true;
    final snaps = effectiveSnapPoints;
    if (snaps.isEmpty) return;
    final index = clampIndex(options.index, snaps.length);
    activeDetentIndex = index;
    final targetY = getPushDetentTopY(
      snaps[index],
      _pushDirectionJs,
      screenHeight,
      _pushLayoutTopInset,
      layout.detents,
    );
    options.onAnimate?.call(-1, index);
    if (_isPushLayout) {
      pushProgressOpenY!.value = targetY;
      _sheetDriver.animateTo(
        targetY,
        spring: _layoutSpring,
        onComplete: () {
          options.onChange?.call(index);
        },
      );
    } else {
      _progressDriver.animateTo(1, spring: _layoutSpring);
      _sheetDriver.animateTo(
        targetY,
        spring: _layoutSpring,
        onComplete: () {
          options.onChange?.call(index);
        },
      );
    }
  }

  @override
  void close() {
    _stopRouteSlide?.call();
    if (_isPushLayout) {
      pushProgressOpenY!.value = _openTopY;
      _sheetDriver.animateTo(
        _closedTopY,
        spring: _layoutSpring,
        onComplete: onDismissComplete,
      );
      return;
    }
    _progressDriver.animateTo(0, spring: _layoutSpring);
    _sheetDriver.animateTo(
      screenHeight,
      spring: _layoutSpring,
      onComplete: onDismissComplete,
    );
  }

  /// Move the sheet and its host with the incoming fullscreen page.
  VoidCallback slideOutForRoute(
    Animation<double> progress, {
    required double distance,
  }) {
    _stopRouteSlide?.call();
    _sheetDriver.stop();
    _isDragging = false;
    final originalTop = sheetTranslateY.value;

    void update() =>
        sheetTranslateY.value = originalTop - distance * progress.value;

    void stop() {
      progress.removeListener(update);
      _stopRouteSlide = null;
    }

    _stopRouteSlide = stop;
    progress.addListener(update);
    update();
    return () {
      if (_stopRouteSlide != stop) return;
      stop();
      sheetTranslateY.value = originalTop;
    };
  }

  @override
  void snapToIndex(int index) {
    final snaps = effectiveSnapPoints;
    if (snaps.isEmpty) return;
    final nextIndex = clampIndex(index, snaps.length);
    final fromIndex = activeDetentIndex;
    final targetY = getPushDetentTopY(
      snaps[nextIndex],
      _pushDirectionJs,
      screenHeight,
      _pushLayoutTopInset,
      layout.detents,
    );
    options.onAnimate?.call(fromIndex, nextIndex);
    activeDetentIndex = nextIndex;
    animatedIndex.value = nextIndex.toDouble();
    if (_isPushLayout) {
      pushProgressOpenY!.value = targetY;
      _sheetDriver.animateTo(
        targetY,
        spring: _layoutSpring,
        onComplete: () => options.onChange?.call(nextIndex),
      );
    } else {
      _progressDriver.animateTo(1, spring: _layoutSpring);
      _sheetDriver.animateTo(
        targetY,
        spring: _layoutSpring,
        onComplete: () => options.onChange?.call(nextIndex),
      );
    }
  }

  @override
  void snapToPosition(double position) {
    // position 表示停靠点在屏幕高度中的比例，取值范围为 0 到 1。
    final detent = BottomSheetDetent.fraction(position);
    final targetY = getPushDetentTopY(
      detent,
      _pushDirectionJs,
      screenHeight,
      _pushLayoutTopInset,
      layout.detents,
    );
    if (_isPushLayout) {
      pushProgressOpenY!.value = targetY;
    } else {
      _progressDriver.animateTo(1, spring: _layoutSpring);
    }
    _sheetDriver.animateTo(targetY, spring: _layoutSpring);
  }

  @override
  void expand() {
    final snaps = effectiveSnapPoints;
    if (snaps.isEmpty) return;
    snapToIndex(snaps.length - 1);
  }

  @override
  void collapse() {
    snapToIndex(0);
  }

  /// 处理对应事件并协调后续状态变化，用于底部弹层的状态、布局、手势与动画引擎。
  void onContentLayout(double height) {
    contentHeight = height;
    if (options.enableDynamicSizing && !_didOpen) {
      open();
    }
  }

  /// 处理对应事件并协调后续状态变化，用于底部弹层的状态、布局、手势与动画引擎。
  void onDragStart() {
    _isDragging = true;
    _sheetDriver.stop();
    _progressDriver.stop();
    _dragStartY = sheetTranslateY.value;
  }

  /// 处理对应事件并协调后续状态变化，用于底部弹层的状态、布局、手势与动画引擎。
  void onDragUpdate(double translationY) {
    if (!_isDragging) return;
    final snaps = effectiveSnapPoints;
    if (snaps.isEmpty) return;
    final result = applySheetDragUpdate(
      dragStartY: _dragStartY,
      translationY: translationY,
      activeDetentIndex: activeDetentIndex,
      effectiveSnapPoints: snaps,
      screenHeight: screenHeight,
      topInset: _pushLayoutTopInset,
      detents: layout.detents,
      isPushLayout: _isPushLayout,
      pushDirection: _pushDirectionJs,
    );
    sheetTranslateY.value = result.sheetTranslateY;
    if (_isPushLayout) {
      pushProgressOpenY!.value = result.pushProgressOpenY!;
    } else {
      progress.value = result.progress;
    }
  }

  /// 处理对应事件并协调后续状态变化，用于底部弹层的状态、布局、手势与动画引擎。
  void onDragEnd(double velocityY) {
    if (!_isDragging) return;
    _isDragging = false;
    final snaps = effectiveSnapPoints;
    if (snaps.isEmpty) {
      close();
      return;
    }
    final result = resolveSheetPanEnd(
      currentY: sheetTranslateY.value,
      velocityY: velocityY,
      currentIndex: activeDetentIndex,
      effectiveSnapPoints: snaps,
      screenHeight: screenHeight,
      topInset: _pushLayoutTopInset,
      detents: layout.detents,
      dismissDragThreshold: layout.gestures.dismissDragThreshold,
      dismissVelocityThreshold: layout.gestures.dismissVelocityThreshold,
      detentVelocityThreshold: layout.gestures.detentVelocityThreshold,
      enablePanDownToClose: options.enablePanDownToClose,
      pushDirection: _pushDirectionJs,
    );

    if (result.kind == SheetPanEndKind.dismiss) {
      close();
      return;
    }

    final fromIndex = activeDetentIndex;
    activeDetentIndex = result.targetIndex;
    animatedIndex.value = result.targetIndex.toDouble();
    options.onAnimate?.call(fromIndex, result.targetIndex);

    if (_isPushLayout) {
      pushProgressOpenY!.value = result.targetY;
      _sheetDriver.animateTo(
        result.targetY,
        spring: _layoutSpring,
        velocity: velocityY,
        onComplete: () => options.onChange?.call(result.targetIndex),
      );
    } else {
      _progressDriver.animateTo(1, spring: _layoutSpring);
      _sheetDriver.animateTo(
        result.targetY,
        spring: _layoutSpring,
        velocity: velocityY,
        onComplete: () => options.onChange?.call(result.targetIndex),
      );
    }
  }

  /// 判断当前状态是否满足指定条件，用于底部弹层的状态、布局、手势与动画引擎。
  bool get canContentPanSheet =>
      options.enableContentPanningGesture &&
      scrollOffset.value <= layout.scroll.offsetEpsilon;

  /// 释放控制器、订阅、动画及其他持有资源，用于底部弹层的状态、布局、手势与动画引擎。
  void dispose() {
    _stopRouteSlide?.call();
    sheetTranslateY.removeListener(_syncPushProgress);
    _sheetDriver.dispose();
    _progressDriver.dispose();
    animatedIndex.dispose();
    scrollOffset.dispose();
    if (hostSheetTopY == null) {
      sheetTranslateY.dispose();
    }
  }
}
