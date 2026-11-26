import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../services/album_haptics.dart';

class HorizontalSelectionWheel extends StatefulWidget {
  const HorizontalSelectionWheel({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSettled,
    required this.semanticLabel,
    required this.semanticValue,
    required this.textStyle,
    this.haptics,
  }) : assert(selectedIndex >= 0 && selectedIndex < labels.length);

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSettled;
  final String semanticLabel;
  final String Function(int index) semanticValue;
  final TextStyle textStyle;
  final AlbumHaptics? haptics;

  @override
  State<HorizontalSelectionWheel> createState() =>
      _HorizontalSelectionWheelState();
}

class _HorizontalSelectionWheelState extends State<HorizontalSelectionWheel>
    with WidgetsBindingObserver {
  static const _itemExtent = 36.0;
  static const _hapticInterval = Duration(milliseconds: 40);
  static final _behavior = const MaterialScrollBehavior().copyWith(
    scrollbars: false,
    overscroll: false,
    dragDevices: {
      ...const MaterialScrollBehavior().dragDevices,
      PointerDeviceKind.mouse,
    },
  );

  late int _index = widget.selectedIndex;
  late int _settledIndex = widget.selectedIndex;
  late final _controller = ScrollController(
    initialScrollOffset: widget.selectedIndex * _itemExtent,
    keepScrollOffset: false,
  )..addListener(_updateSelection);
  late final AlbumHaptics _haptics = widget.haptics ?? AlbumHaptics();
  late final bool _ownsHaptics = widget.haptics == null;
  final _hapticClock = Stopwatch()..start();
  int? _targetIndex;
  Duration? _lastHapticTime;
  Duration? _lastScrollTime;
  double? _lastScrollOffset;
  bool _userScrolling = false;
  bool _syncing = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    _foreground =
        binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    binding.addObserver(this);
    if (_ownsHaptics && !_foreground) unawaited(_haptics.setActive(false));
    if (_ownsHaptics) unawaited(_haptics.prepare());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _userScrolling = false;
    if (_ownsHaptics) unawaited(_haptics.setActive(_foreground));
  }

  @override
  void didUpdateWidget(HorizontalSelectionWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.selectedIndex;
    if (selected == oldWidget.selectedIndex || selected == _settledIndex) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          selected != widget.selectedIndex ||
          !_controller.hasClients) {
        return;
      }
      _syncing = true;
      _userScrolling = false;
      _lastScrollTime = null;
      _lastScrollOffset = null;
      _targetIndex = null;
      _index = _settledIndex = selected;
      _controller.jumpTo(selected * _itemExtent);
      _syncing = false;
    });
  }

  void _updateSelection() {
    final offset = _controller.offset;
    final now = _hapticClock.elapsed;
    final previousTime = _lastScrollTime;
    final previousOffset = _lastScrollOffset;
    _lastScrollTime = now;
    _lastScrollOffset = offset;
    final next = (offset / _itemExtent).round().clamp(
      0,
      widget.labels.length - 1,
    );
    if (_index == next) return;
    final previous = _index;
    _index = next;
    if (!_syncing && _foreground && _userScrolling) {
      final last = _lastHapticTime;
      if (last == null || now - last >= _hapticInterval) {
        _lastHapticTime = now;
        final elapsed = previousTime == null
            ? 0
            : (now - previousTime).inMicroseconds;
        final strength = previousOffset == null || elapsed <= 0
            ? 0.35
            : ((offset - previousOffset).abs() *
                      Duration.microsecondsPerSecond /
                      elapsed /
                      _itemExtent /
                      8)
                  .clamp(0.15, 1.0);
        final rtl = _controller.position.axisDirection == AxisDirection.left;
        unawaited(
          _haptics.tick(
            movingLeft: (next > previous) != rtl,
            strength: strength,
          ),
        );
      }
    }
  }

  void _scrollTo(int index) {
    final next = index.clamp(0, widget.labels.length - 1);
    final offset = next * _itemExtent;
    if (_controller.offset != offset) _userScrolling = true;
    if (_controller.offset == offset ||
        MediaQuery.disableAnimationsOf(context)) {
      if (_targetIndex != null || _controller.offset != offset) {
        _targetIndex = null;
        _controller.jumpTo(offset);
      }
      return;
    }
    _targetIndex = next;
    unawaited(
      _controller.animateTo(
        offset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || _syncing) return false;
    if (notification is UserScrollNotification) {
      _userScrolling = notification.direction != ScrollDirection.idle;
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _targetIndex = null;
      _userScrolling = true;
    }
    if (notification is ScrollEndNotification &&
        (notification.metrics.pixels - _index * _itemExtent).abs() < 0.01) {
      _userScrolling = false;
      _lastScrollTime = null;
      _lastScrollOffset = null;
      _targetIndex = null;
      if (_index != _settledIndex) {
        _settledIndex = _index;
        widget.onSettled(_index);
      }
    }
    return false;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.kind != PointerDeviceKind.mouse ||
        event.scrollDelta.dx != 0 ||
        event.scrollDelta.dy == 0) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      _scrollTo((_targetIndex ?? _index) + event.scrollDelta.dy.sign.toInt());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    if (_ownsHaptics) unawaited(_haptics.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.semanticLabel,
    value: widget.semanticValue(widget.selectedIndex),
    increasedValue: widget.selectedIndex < widget.labels.length - 1
        ? widget.semanticValue(widget.selectedIndex + 1)
        : null,
    decreasedValue: widget.selectedIndex > 0
        ? widget.semanticValue(widget.selectedIndex - 1)
        : null,
    onIncrease: widget.selectedIndex < widget.labels.length - 1
        ? () => _scrollTo(_index + 1)
        : null,
    onDecrease: widget.selectedIndex > 0 ? () => _scrollTo(_index - 1) : null,
    excludeSemantics: true,
    child: Focus(
      onKeyEvent: (_, event) {
        if (event is KeyUpEvent) return KeyEventResult.ignored;
        final step = switch (event.logicalKey) {
          LogicalKeyboardKey.arrowLeft => -1,
          LogicalKeyboardKey.arrowRight => 1,
          _ => 0,
        };
        if (step == 0) return KeyEventResult.ignored;
        final direction = Directionality.of(context) == TextDirection.ltr
            ? 1
            : -1;
        _scrollTo((_targetIndex ?? _index) + step * direction);
        return KeyEventResult.handled;
      },
      child: SizedBox(
        height: 44,
        child: LayoutBuilder(
          builder: (context, constraints) => Listener(
            onPointerSignal: _onPointerSignal,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: ScrollConfiguration(
                behavior: _behavior,
                child: ListView.builder(
                  controller: _controller,
                  primary: false,
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(
                    horizontal: ((constraints.maxWidth - _itemExtent) / 2)
                        .clamp(0.0, double.infinity),
                  ),
                  physics: const _WheelScrollPhysics(
                    itemExtent: _itemExtent,
                    parent: ClampingScrollPhysics(),
                  ),
                  itemExtent: _itemExtent,
                  itemCount: widget.labels.length,
                  itemBuilder: (context, index) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _scrollTo(index),
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _controller,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.labels[index],
                              style: widget.textStyle,
                            ),
                          ),
                        ),
                        builder: (context, child) {
                          final offset = _controller.hasClients
                              ? _controller.offset
                              : widget.selectedIndex * _itemExtent;
                          final distance = (index - offset / _itemExtent).abs();
                          final emphasis = (1 - distance / 2).clamp(0.0, 1.0);
                          final edgeFade =
                              ((constraints.maxWidth / 2 -
                                          distance * _itemExtent) /
                                      18)
                                  .clamp(0.0, 1.0);
                          return Opacity(
                            opacity:
                                (0.22 + 0.78 * emphasis * emphasis) * edgeFade,
                            child: Transform.scale(
                              scale: 0.74 + 0.42 * emphasis,
                              child: child,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _WheelScrollPhysics extends ScrollPhysics {
  const _WheelScrollPhysics({required this.itemExtent, super.parent});

  final double itemExtent;

  @override
  double get maxFlingVelocity => 900;

  @override
  _WheelScrollPhysics applyTo(ScrollPhysics? ancestor) => _WheelScrollPhysics(
    itemExtent: itemExtent,
    parent: buildParent(ancestor),
  );

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final current = position.pixels;
    final friction = super.createBallisticSimulation(position, velocity);
    final projected = friction?.x(double.infinity) ?? current;
    final target = ((projected / itemExtent).round() * itemExtent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final distance = target - current;
    if (distance.abs() < 0.000001) return null;

    // Cap the launch speed near the target so the spring does not overshoot.
    final speed = (velocity * distance.sign).clamp(0.0, distance.abs() * 12);
    return ScrollSpringSimulation(
      spring,
      current,
      target,
      speed * distance.sign,
      tolerance: toleranceFor(position),
    );
  }
}
