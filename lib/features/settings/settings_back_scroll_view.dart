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
  static const _pullStartSlop = 40.0;

  double? _remainingPullSlop;
  double _pull = 0;

  double _applyDragOffset(ScrollMetrics position, double offset) {
    final remainingSlop = _remainingPullSlop;
    if (remainingSlop == null || position.extentBefore > 0) {
      _remainingPullSlop = null;
      return offset;
    }

    if (offset > 0) {
      final slop = math.min(offset, remainingSlop);
      _remainingPullSlop = remainingSlop - slop;
      offset -= slop;
    }

    final previousPull = _pull;
    _pull = (_pull + offset).clamp(0.0, widget.distance);
    if (_pull != previousPull) widget.onPull(_pull / widget.distance);
    if (offset < 0 && _pull == 0) _remainingPullSlop = _pullStartSlop;
    return offset - (_pull - previousPull);
  }

  void _finishPull({required bool canceled}) {
    _remainingPullSlop = null;
    if (_pull == 0) return;
    final fraction = _pull / widget.distance;
    _pull = 0;
    widget.onRelease(fraction, canceled: canceled);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerCancel: (_) => _finishPull(canceled: true),
    child: NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth != 0) return false;
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null &&
            notification.metrics.extentBefore == 0) {
          _remainingPullSlop = _pullStartSlop;
        } else if (notification is ScrollEndNotification) {
          _finishPull(canceled: false);
        }
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
