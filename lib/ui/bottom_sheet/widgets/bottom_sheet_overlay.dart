import 'package:material_ui/material_ui.dart';

import '../controller/bottom_sheet_controller.dart';
import '../push_direction.dart';
import '../push_layout.dart';
import '../scope/bottom_sheet_scope.dart';
import '../types.dart';
import 'bottom_sheet_handle.dart';
import 'bottom_sheet_mask.dart';

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

          // Stack card peek (presentation only).
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

          // Push sheet scaleX.
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
            // Fixed radius — avoid growing 0→max with open progress.
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
          // During open/close springs the panel height can be < handle —
          // avoid laying out handle + Expanded content (Flex overflow).
          final panelTallEnough = sheetHeight >= handleH + 8;

          Widget panel = Material(
            color: theme.sheetBackgroundColor,
            borderRadius: borderRadius,
            clipBehavior: Clip.antiAlias,
            // Isolate sheet Scaffolds from the host ScaffoldMessenger — otherwise
            // SnackBars from the root messenger paint on host AND every sheet
            // Scaffold (Navigation/Settings/…).
            child: ScaffoldMessenger(
              child: panelTallEnough
                  ? Column(
                      children: [
                        if (!isTopPush)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragStart: (_) {
                              _dragTranslation = 0;
                              _controller.onDragStart();
                            },
                            onVerticalDragUpdate: (d) {
                              _dragTranslation += d.primaryDelta ?? 0;
                              _controller.onDragUpdate(_dragTranslation);
                            },
                            onVerticalDragEnd: (d) {
                              _controller.onDragEnd(d.primaryVelocity ?? 0);
                            },
                            child: BottomSheetHandle(
                              color: theme.handleColor,
                              visible: options.showHandle,
                              height: widget.layout.handle.height,
                              hiddenHeight: widget.layout.handle.hiddenHeight,
                            ),
                          ),
                        Expanded(
                          child: _ContentPanWrapper(
                            controller: _controller,
                            child: widget.sheet.content,
                          ),
                        ),
                        if (isTopPush)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragStart: (_) {
                              _dragTranslation = 0;
                              _controller.onDragStart();
                            },
                            onVerticalDragUpdate: (d) {
                              _dragTranslation += d.primaryDelta ?? 0;
                              _controller.onDragUpdate(_dragTranslation);
                            },
                            onVerticalDragEnd: (d) {
                              _controller.onDragEnd(d.primaryVelocity ?? 0);
                            },
                            child: BottomSheetHandle(
                              color: theme.handleColor,
                              visible: options.showHandle,
                              height: widget.layout.handle.height,
                              hiddenHeight: widget.layout.handle.hiddenHeight,
                            ),
                          ),
                      ],
                    )
                  : const SizedBox.expand(),
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
                height:
                    sheetHeight +
                    (options.keyboardBehavior ==
                            BottomSheetKeyboardBehavior.extend
                        ? keyboardInset
                        : 0),
                child: IgnorePointer(
                  ignoring: !widget.isTop,
                  child: Semantics(
                    label: options.accessibilityLabel,
                    // Push: scaleX only (RN parity) so the sheet top stays flush
                    // with host — vertical gap matches side inset.
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

  /// Push sheets use horizontal scale only so the anchored edge stays flush.
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

/// A keyboard shown for a route above the sheet must not move the sheet below.
double resolveBottomSheetKeyboardInset(
  double viewInset, {
  required bool focusBelongsToSheet,
}) => focusBelongsToSheet ? viewInset : 0;

double mathPow(double base, double exp) {
  var result = 1.0;
  for (var i = 0; i < exp.round(); i++) {
    result *= base;
  }
  return result;
}

class _ContentPanWrapper extends StatefulWidget {
  const _ContentPanWrapper({required this.controller, required this.child});

  final SheetController controller;
  final Widget child;

  @override
  State<_ContentPanWrapper> createState() => _ContentPanWrapperState();
}

/// Scroll→sheet handoff: when content is at the top and the user pulls down,
/// drive the sheet pan (close / collapse). Works with any nested vertical
/// scrollable via [OverscrollNotification] / bounce [ScrollUpdateNotification].
/// Non-scroll empty areas still use [GestureDetector].
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

    // Keep sheet scroll-offset in sync (any nested vertical scrollable).
    if (notification is ScrollUpdateNotification ||
        notification is ScrollStartNotification) {
      widget.controller.scrollOffset.value = notification.metrics.pixels;
    }

    final atTop =
        notification.metrics.pixels <=
        widget.controller.layout.scroll.offsetEpsilon;

    if (!_dragging) {
      if (!atTop) return false;

      // ClampingPhysics: pull-down at top → OverscrollNotification (overscroll < 0).
      if (notification is OverscrollNotification &&
          notification.overscroll < 0) {
        _beginSheetDrag(-notification.overscroll);
        return false;
      }

      // BouncingPhysics: pixels stay ~0 / go slightly negative with scrollDelta < 0.
      if (notification is ScrollUpdateNotification &&
          notification.dragDetails != null &&
          (notification.scrollDelta ?? 0) < 0) {
        _beginSheetDrag(-(notification.scrollDelta ?? 0));
        return false;
      }
      return false;
    }

    // Already driving the sheet from content overscroll.
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
      _endSheetDrag(v);
      return false;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: (d) {
          // Empty / non-scroll regions — scrollables win the arena otherwise.
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
  }
}
