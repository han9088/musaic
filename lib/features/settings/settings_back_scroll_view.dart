import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

class SettingsBackScrollView extends StatefulWidget {
  const SettingsBackScrollView({
    super.key,
    required this.distance,
    required this.onPull,
    required this.onRelease,
    required this.slivers,
  });

  final double distance;
  final ValueChanged<double> onPull;
  final void Function(double fraction, {required bool canceled}) onRelease;
  final List<Widget> slivers;

  @override
  State<SettingsBackScrollView> createState() => _SettingsBackScrollViewState();
}

class _SettingsBackScrollViewState extends State<SettingsBackScrollView> {
  double _pull = 0;

  double _applyDragOffset(ScrollMetrics position, double offset) {
    final previousPull = _pull;
    // Scroll to the top first, then hand the remaining drag to the route.
    final pullDelta = offset > 0
        ? math.max(0.0, offset - position.extentBefore)
        : offset;
    _pull = (_pull + pullDelta).clamp(0.0, widget.distance);
    if (_pull != previousPull) widget.onPull(_pull / widget.distance);
    return offset - (_pull - previousPull);
  }

  void _finishPull({required bool canceled}) {
    if (_pull == 0) return;
    final fraction = _pull / widget.distance;
    _pull = 0;
    widget.onRelease(fraction, canceled: canceled);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerCancel: (_) => _finishPull(canceled: true),
    child: NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) _finishPull(canceled: false);
        return false;
      },
      child: CustomScrollView(
        physics: _SettingsBackScrollPhysics(
          applyDragOffset: _applyDragOffset,
          isPulling: () => _pull > 0,
        ),
        slivers: widget.slivers,
      ),
    ),
  );
}

class _SettingsBackScrollPhysics extends ClampingScrollPhysics {
  const _SettingsBackScrollPhysics({
    required this.applyDragOffset,
    required this.isPulling,
    super.parent,
  });

  final double Function(ScrollMetrics, double) applyDragOffset;
  final bool Function() isPulling;

  @override
  _SettingsBackScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _SettingsBackScrollPhysics(
        applyDragOffset: applyDragOffset,
        isPulling: isPulling,
        parent: buildParent(ancestor),
      );

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => true;

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      applyDragOffset(position, offset);

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) => isPulling() ? null : super.createBallisticSimulation(position, velocity);
}
