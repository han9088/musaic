// 文件职责：底部弹层的状态、布局、手势与动画引擎。

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../controller/bottom_sheet_controller.dart';
import '../push_direction.dart';
import '../push_layout.dart';
import '../scope/bottom_sheet_scope.dart';
import '../types.dart';
import 'bottom_sheet_handle.dart';
import 'bottom_sheet_mask.dart';

/// 封装或定义底部弹层覆层相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class BottomSheetOverlay extends StatefulWidget {
  const BottomSheetOverlay({
    super.key,
    required this.sheet,
    required this.layout,
    required this.screenHeight,
    required this.screenWidth,
    required this.topInset,
    required this.bottomInset,
    required this.onDismissComplete,
    required this.onDismissHandlerChange,
    required this.onControllerReady,
    this.progress,
    this.hostSheetTopY,
    this.pushProgressOpenY,
    this.pushSheetHeight,
    this.stackIndex = 0,
    this.depthFromTop = 0,
    this.enableStackCardStyle = false,
    this.isTop = true,
  });

  final BottomSheetState sheet;

  /// When null, the overlay owns a local progress notifier (buried sheets).
  final ValueNotifier<double>? progress;
  final ValueNotifier<double>? hostSheetTopY;
  final ValueNotifier<double>? pushProgressOpenY;
  final ValueNotifier<double>? pushSheetHeight;
  final BottomSheetLayoutOptions layout;
  final double screenHeight;
  final double screenWidth;
  final double topInset;
  final double bottomInset;
  final VoidCallback onDismissComplete;
  final void Function(VoidCallback? handler) onDismissHandlerChange;
  final void Function(BottomSheetControllerApi? api) onControllerReady;
  final int stackIndex;
  final int depthFromTop;
  final bool enableStackCardStyle;
  final bool isTop;

  @override
  State<BottomSheetOverlay> createState() => _BottomSheetOverlayState();
}

/// 封装或定义底部弹层覆层状态相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class _BottomSheetOverlayState extends State<BottomSheetOverlay>
    with TickerProviderStateMixin {
  late SheetController _controller;
  ValueNotifier<double>? _localProgress;
  double _dragTranslation = 0;

  @override
  void initState() {
    super.initState();
    _createController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.open();
      widget.onDismissHandlerChange(_controller.close);
      widget.onControllerReady(_controller);
    });
  }

  /// 创建并组装所需对象或界面结构，用于底部弹层的状态、布局、手势与动画引擎。
  void _createController() {
    final isPush = widget.sheet.options.mode == BottomSheetMode.push;
    final progress = widget.progress ?? ValueNotifier<double>(0);
    if (widget.progress == null) {
      _localProgress = progress;
    }
    _controller = SheetController(
      vsync: this,
      options: widget.sheet.options,
      layout: widget.layout,
      progress: progress,
      hostSheetTopY: isPush && widget.stackIndex == 0
          ? widget.hostSheetTopY
          : null,
      pushProgressOpenY: isPush && widget.stackIndex == 0
          ? widget.pushProgressOpenY
          : null,
      pushSheetHeight: isPush && widget.stackIndex == 0
          ? widget.pushSheetHeight
          : null,
      screenHeight: widget.screenHeight,
      topInset: widget.topInset,
      bottomInset: widget.bottomInset,
      onDismissComplete: widget.onDismissComplete,
    );
  }

  @override
  void dispose() {
    widget.onDismissHandlerChange(null);
    widget.onControllerReady(null);
    _controller.dispose();
    _localProgress?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.sheet.options;
    final theme = options.theme;
    final isPush = options.mode == BottomSheetMode.push;
    final isTopPush = isPush && options.pushDirection == PushDirection.top;
    final viewKeyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return BottomSheetContentScope(
      controller: _controller,
      bottomInset: widget.bottomInset,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          _controller.sheetTranslateY,
          widget.progress ?? _localProgress!,
          FocusManager.instance,
        ]),
        builder: (context, _) {
          final focusedScope = FocusManager.instance.primaryFocus?.context
              ?.getInheritedWidgetOfExactType<BottomSheetContentScope>();
          final keyboardInset = resolveBottomSheetKeyboardInset(
            viewKeyboardInset,
            focusBelongsToSheet: identical(
              focusedScope?.controller,
              _controller,
            ),
          );
          _controller.setKeyboardHeight(keyboardInset);

          final sheetTop = _controller.sheetTranslateY.value;
          final sheetHeight = (widget.screenHeight - sheetTop).clamp(
            0.0,
            widget.screenHeight,
          );

          // Stack 卡片露出效果，仅用于展示层。
          double scale = 1;
          double hInset = 0;
          double offsetY = 0;
          double radiusBonus = 0;
          if (widget.enableStackCardStyle && widget.depthFromTop > 0) {
            final depth = widget.depthFromTop.toDouble();
            scale = mathPow(widget.layout.stack.scalePerLevel, depth);
            hInset = widget.layout.stack.horizontalInsetPerLevel * depth;
            offsetY = widget.layout.stack.offsetYPerLevel * depth;
            radiusBonus = widget.layout.stack.radiusBonusPerLevel * depth;
          }

          // 推动式弹层的水平缩放。
          double pushScaleX = 1;
          BorderRadius borderRadius = BorderRadius.vertical(
            top: Radius.circular(
              widget.layout.presentation.cornerRadius + radiusBonus,
            ),
          );
          if (isPush) {
            final pushDir = pushDirectionToJs(options.pushDirection);
            final openY =
                widget.pushProgressOpenY?.value ??
                (isTopPush ? 0.0 : widget.screenHeight);
            final pushProgress = getPushLayoutProgress(
              sheetTop,
              openY,
              widget.screenHeight,
              pushDir,
              isTopPush ? 0 : widget.topInset,
            );
            pushScaleX = getPushScale(
              widget.screenWidth,
              pushProgress,
              targetInset: widget.layout.push.hostHorizontalInset,
            );
            // 圆角保持固定，不随展开进度从 0 增长到最大值。
            final corners = getPushSheetCornerRadiusStyle(
              1,
              pushDir,
              maxRadius: widget.layout.presentation.cornerRadius,
            );
            borderRadius = BorderRadius.only(
              topLeft: Radius.circular(corners.topLeft ?? 0),
              topRight: Radius.circular(corners.topRight ?? 0),
              bottomLeft: Radius.circular(corners.bottomLeft ?? 0),
              bottomRight: Radius.circular(corners.bottomRight ?? 0),
            );
          }

          final keyboardLift =
              options.keyboardBehavior == BottomSheetKeyboardBehavior.extend
              ? 0.0
              : keyboardInset;

          final handleH = options.showHandle
              ? widget.layout.handle.height
              : widget.layout.handle.hiddenHeight;
          final panelHeight =
              sheetHeight +
              (options.keyboardBehavior == BottomSheetKeyboardBehavior.extend
                  ? keyboardInset
                  : 0);
          final minContentHeight = handleH + 8;
          final panelTallEnough = sheetHeight >= minContentHeight;
          final handle = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (_) {
              _dragTranslation = 0;
              _controller.onDragStart();
            },
            onVerticalDragUpdate: (details) {
              _dragTranslation += details.primaryDelta ?? 0;
              _controller.onDragUpdate(_dragTranslation);
            },
            onVerticalDragEnd: (details) {
              _controller.onDragEnd(details.primaryVelocity ?? 0);
            },
            onVerticalDragCancel: () => _controller.onDragEnd(0),
            child: BottomSheetHandle(
              color: theme.handleColor,
              visible: options.showHandle,
              height: widget.layout.handle.height,
              hiddenHeight: widget.layout.handle.hiddenHeight,
            ),
          );

          Widget panel = Material(
            color: theme.sheetBackgroundColor,
            borderRadius: borderRadius,
            clipBehavior: Clip.antiAlias,
            // 将弹层内部的 Scaffold 与宿主的 ScaffoldMessenger 隔离，否则
            // 根级 Messenger 发出的 SnackBar 会同时绘制在宿主和每个弹层
            // 的 Scaffold 上（例如导航页、设置页等）。
            child: ScaffoldMessenger(
              // Keep the active gesture recognizers mounted until release,
              // even when the last pixels of the sheet are almost offscreen.
              child: OverflowBox(
                alignment: isTopPush
                    ? Alignment.bottomCenter
                    : Alignment.topCenter,
                maxHeight: panelHeight < minContentHeight
                    ? minContentHeight
                    : panelHeight,
                child: Opacity(
                  opacity: panelTallEnough ? 1 : 0,
                  child: Column(
                    children: [
                      if (!isTopPush) handle,
                      Expanded(
                        child: _ContentPanWrapper(
                          controller: _controller,
                          child: widget.sheet.content,
                        ),
                      ),
                      if (isTopPush) handle,
                    ],
                  ),
                ),
              ),
            ),
          );

          if (options.enableDynamicSizing) {
            panel = NotificationListener<SizeChangedLayoutNotification>(
              child: SizeChangedLayoutNotifier(child: panel),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              BottomSheetMask(
                height: sheetTop.clamp(0.0, widget.screenHeight),
                color: options.scrimColor,
                enabled: options.dismissOnScrimPress && widget.isTop,
                onTap: widget.isTop ? _controller.close : null,
              ),
              Positioned(
                left: hInset,
                right: hInset,
                top: sheetTop + offsetY - keyboardLift,
                height: panelHeight,
                child: IgnorePointer(
                  ignoring: !widget.isTop || !panelTallEnough,
                  child: Semantics(
                    label: options.accessibilityLabel,
                    // 推动式效果只改变水平缩放（与 RN 版本一致），使弹层顶部保持对齐，
                    // 垂直间距则与侧边内边距保持一致。
                    child: _buildSheetTransform(
                      isPush: isPush,
                      isTopPush: isTopPush,
                      stackScale: scale,
                      pushScaleX: pushScaleX,
                      child: panel,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 创建并组装所需对象或界面结构，用于底部弹层的状态、布局、手势与动画引擎。
  Widget _buildSheetTransform({
    required bool isPush,
    required bool isTopPush,
    required double stackScale,
    required double pushScaleX,
    required Widget child,
  }) {
    var result = child;
    if (isPush && pushScaleX != 1.0) {
      result = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(pushScaleX, 1.0, 1.0),
        child: result,
      );
    }
    if (stackScale != 1.0) {
      result = Transform.scale(
        scale: stackScale,
        alignment: isTopPush ? Alignment.topCenter : Alignment.bottomCenter,
        child: result,
      );
    }
    return result;
  }
}

/// 解析输入并转换为内部数据，用于底部弹层的状态、布局、手势与动画引擎。
double resolveBottomSheetKeyboardInset(
  double viewInset, {
  required bool focusBelongsToSheet,
}) => focusBelongsToSheet ? viewInset : 0;

/// 执行当前模块中的mathpow操作，用于底部弹层的状态、布局、手势与动画引擎。
double mathPow(double base, double exp) {
  var result = 1.0;
  for (var i = 0; i < exp.round(); i++) {
    result *= base;
  }
  return result;
}

/// 封装或定义内容拖拽wrapper相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class _ContentPanWrapper extends StatefulWidget {
  const _ContentPanWrapper({required this.controller, required this.child});

  final SheetController controller;
  final Widget child;

  @override
  State<_ContentPanWrapper> createState() => _ContentPanWrapperState();
}

/// 封装或定义内容拖拽wrapper状态相关类型与行为，负责底部弹层的状态、布局、手势与动画引擎。
class _ContentPanWrapperState extends State<_ContentPanWrapper> {
  double _translation = 0;
  bool _dragging = false;
  double _lastVelocity = 0;

  bool get _enabled => widget.controller.options.enableContentPanningGesture;

  bool get _atTop =>
      widget.controller.scrollOffset.value <=
      widget.controller.layout.scroll.offsetEpsilon;

  void _beginSheetDrag(double initialDy) {
    _dragging = true;
    _translation = initialDy < 0 ? 0 : initialDy;
    _lastVelocity = 0;
    widget.controller.onDragStart();
    if (_translation != 0) {
      widget.controller.onDragUpdate(_translation);
    }
  }

  /// 更新相关状态并同步依赖方，用于底部弹层的状态、布局、手势与动画引擎。
  void _updateSheetDrag(double deltaDy) {
    _translation += deltaDy;
    if (_translation < 0) _translation = 0;
    widget.controller.onDragUpdate(_translation);
  }

  void _endSheetDrag(double velocityY) {
    if (!_dragging) return;
    _dragging = false;
    widget.controller.onDragEnd(velocityY);
    _translation = 0;
    _lastVelocity = 0;
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (!_enabled) return false;
    if (notification.metrics.axis != Axis.vertical) return false;

    // 同步弹层的滚动偏移，兼容任意层级的纵向可滚动组件。
    if (notification is ScrollUpdateNotification ||
        notification is ScrollStartNotification) {
      widget.controller.scrollOffset.value = notification.metrics.pixels;
    }

    final atTop =
        notification.metrics.pixels <=
        widget.controller.layout.scroll.offsetEpsilon;

    if (!_dragging) {
      if (!atTop) return false;

      // ClampingPhysics：在列表顶部向下拖动会触发 OverscrollNotification（overscroll 小于 0）。
      if (notification is OverscrollNotification &&
          notification.overscroll < 0) {
        _beginSheetDrag(-notification.overscroll);
        return false;
      }

      // BouncingPhysics：滚动位置保持在约 0，或在 scrollDelta 小于 0 时略微变为负数。
      if (notification is ScrollUpdateNotification &&
          notification.dragDetails != null &&
          (notification.scrollDelta ?? 0) < 0) {
        _beginSheetDrag(-(notification.scrollDelta ?? 0));
        return false;
      }
      return false;
    }

    // 当前已经由内容区域的过度滚动驱动弹层移动。
    if (notification is OverscrollNotification) {
      if (notification.overscroll < 0) {
        _updateSheetDrag(-notification.overscroll);
      } else if (notification.overscroll > 0) {
        _updateSheetDrag(-notification.overscroll);
      }
      final v = notification.velocity;
      if (v != 0) _lastVelocity = v;
      return false;
    }

    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      _updateSheetDrag(notification.dragDetails!.delta.dy);
      return false;
    }

    if (notification is ScrollEndNotification) {
      final v = notification.dragDetails?.primaryVelocity ?? _lastVelocity;
      // A bouncing scroll can end during layout as the viewport shrinks.
      scheduleMicrotask(() {
        if (mounted) _endSheetDrag(v);
      });
      return false;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;

    final panContent = NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: (d) {
          // 空白区域或非滚动区域使用此手势处理；其余情况优先让可滚动组件赢得手势竞争。
          if (!_atTop) return;
          _beginSheetDrag(0);
        },
        onVerticalDragUpdate: (d) {
          if (!_dragging) return;
          _updateSheetDrag(d.primaryDelta ?? 0);
        },
        onVerticalDragEnd: (d) {
          if (!_dragging) return;
          _endSheetDrag(d.primaryVelocity ?? 0);
        },
        onVerticalDragCancel: () {
          if (!_dragging) return;
          _endSheetDrag(0);
        },
        child: widget.child,
      ),
    );
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        // Expanding a detent can clamp the scroll offset without scrolling.
        if (notification.metrics.axis == Axis.vertical) {
          widget.controller.scrollOffset.value = notification.metrics.pixels;
        }
        return false;
      },
      child: panContent,
    );
  }
}
