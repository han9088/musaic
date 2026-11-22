import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Slides in from the opposite edge and pushes the preceding route in [direction].
class DirectionalPushRoute<T> extends PageRouteBuilder<T> {
  DirectionalPushRoute({
    required this.direction,
    required WidgetBuilder builder,
    super.settings,
    super.opaque,
    bool animate = true,
    this.swipeToDismiss = false,
  }) : super(
         pageBuilder: (context, _, _) => builder(context),
         transitionDuration: animate ? _duration : Duration.zero,
         reverseTransitionDuration: animate ? _duration : Duration.zero,
       );

  final AxisDirection direction;

  /// Lets touch drags opposite [direction] dismiss the route.
  final bool swipeToDismiss;

  static const _duration = Duration(milliseconds: 420);
  static const _curve = Curves.easeInOutCubic;
  static final _ease = CurveTween(curve: _curve);
  static final _inverse = Cubic(_curve.b, _curve.a, _curve.d, _curve.c);
  static const _dismissFraction = 0.22;
  double? _swipeFraction;

  late final _shift = switch (direction) {
    AxisDirection.up => const Offset(0, -1),
    AxisDirection.right => const Offset(1, 0),
    AxisDirection.down => const Offset(0, 1),
    AxisDirection.left => const Offset(-1, 0),
  };
  late final _enter = Tween(begin: -_shift, end: Offset.zero).chain(_ease);
  late final _leave = Tween(begin: Offset.zero, end: _shift).chain(_ease);

  /// Use the controller because an offstage modal route masks its animation.
  Animation<double> get pushProgress => controller!.view.drive(_ease);

  void updateDismissGesture(double fraction) {
    if (isCurrent) controller!.value = _inverse.transform(1 - fraction);
  }

  void finishDismissGesture(double fraction, {required bool canceled}) {
    if (!isCurrent) return;
    if (!canceled && fraction >= _dismissFraction) {
      navigator!.pop();
    } else {
      unawaited(controller!.forward());
    }
  }

  Widget _buildSwipeGesture(Widget child) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontal = axisDirectionToAxis(direction) == Axis.horizontal;
      final distance = horizontal
          ? constraints.maxWidth
          : constraints.maxHeight;
      final sign = axisDirectionIsReversed(direction) ? 1 : -1;

      void start(DragStartDetails details) {
        if (isCurrent && popGestureEnabled && !popGestureInProgress) {
          _swipeFraction = 0;
        }
      }

      void update(DragUpdateDetails details) {
        final fraction = _swipeFraction;
        if (fraction == null || distance <= 0) return;
        final delta = details.primaryDelta! * sign / distance;
        final next = (fraction + delta).clamp(0.0, 1.0);
        if (next == fraction) return;
        _swipeFraction = next;
        updateDismissGesture(next);
      }

      void finish({required bool canceled}) {
        final fraction = _swipeFraction;
        _swipeFraction = null;
        if (fraction != null) {
          finishDismissGesture(fraction, canceled: canceled);
        }
      }

      void end(DragEndDetails details) => finish(canceled: false);
      void cancel() => finish(canceled: true);

      return Listener(
        // Flutter can deliver onDragEnd when an accepted drag is canceled.
        onPointerCancel: (event) {
          if (event.kind == PointerDeviceKind.touch) cancel();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            // Keep taps and scrolling available to the page beneath the swipe.
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              dragStartBehavior: DragStartBehavior.down,
              excludeFromSemantics: true,
              supportedDevices: const {PointerDeviceKind.touch},
              onHorizontalDragStart: horizontal ? start : null,
              onHorizontalDragUpdate: horizontal ? update : null,
              onHorizontalDragEnd: horizontal ? end : null,
              onHorizontalDragCancel: horizontal ? cancel : null,
              onVerticalDragStart: horizontal ? null : start,
              onVerticalDragUpdate: horizontal ? null : update,
              onVerticalDragEnd: horizontal ? null : end,
              onVerticalDragCancel: horizontal ? null : cancel,
            ),
          ],
        ),
      );
    },
  );

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) =>
      previousRoute is DirectionalPushRoute<dynamic>;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is DirectionalPushRoute<dynamic>;

  @override
  DelegatedTransitionBuilder get delegatedTransition => _pushPrevious;

  Widget _pushPrevious(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondary,
    bool allowSnapshotting,
    Widget? child,
  ) => SlideTransition(position: secondary.drive(_leave), child: child);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final transition = AnimatedBuilder(
      animation: animation,
      child: SlideTransition(position: animation.drive(_enter), child: child),
      builder: (_, child) =>
          IgnorePointer(ignoring: !animation.isCompleted, child: child),
    );
    return ClipRect(
      child: swipeToDismiss ? _buildSwipeGesture(transition) : transition,
    );
  }
}
