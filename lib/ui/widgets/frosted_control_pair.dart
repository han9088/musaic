part of 'frosted_control_surface.dart';

/// Places a frosted pill and its optional companion on one centerline.
/// The primary control stretches toward the pointer and springs back on release.
class FrostedControlPair extends StatefulWidget {
  const FrostedControlPair({
    super.key,
    required this.primary,
    required this.primaryVisible,
    this.companion,
    this.companionVisible = false,
    this.onPrimaryPullUp,
  });

  final Widget primary;
  final bool primaryVisible;
  final Widget? companion;
  final bool companionVisible;
  final VoidCallback? onPrimaryPullUp;

  @override
  State<FrostedControlPair> createState() => _FrostedControlPairState();
}

class _FrostedControlPairState extends State<FrostedControlPair>
    with TickerProviderStateMixin {
  static const _companionWidth = FrostedControlSurface.compactHeight;
  static const _companionSlot = _companionWidth + 8;
  static const _paintInset = 90.0;
  static const _maxTravel = 34.0;
  static const _pullUpThreshold = 27.0;
  static final _pressSpring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 430,
    ratio: 0.82,
  );
  static final _releaseSpring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: 0.52,
  );
  static final _dragSpring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 340,
    ratio: 0.46,
  );
  static final _dragSurface = FrostedControlSurface._material(
    opacity: 1,
    shape: const RoundedRectangleBorder(),
    child: const SizedBox.expand(),
  );

  late final _pressure = AnimationController.unbounded(vsync: this);
  late final _dragX = AnimationController.unbounded(vsync: this);
  late final _dragY = AnimationController.unbounded(vsync: this);
  late final _motion = Listenable.merge([_pressure, _dragX, _dragY]);
  Timer? _hold;
  int? _pointer;
  VelocityTracker? _velocity;
  Offset _pressOrigin = Offset.zero;
  double _pressX = 0;
  Offset _dragStart = Offset.zero;
  bool _dragging = false;

  Offset get _offset => Offset(_dragX.value, _dragY.value);

  void _press(PointerDownEvent event) {
    if (_pointer != null ||
        event.buttons != kPrimaryButton ||
        !widget.primaryVisible) {
      return;
    }
    _pointer = event.pointer;
    _pressOrigin = event.position;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _pressX = event.localPosition.dx;
    _dragStart = _offset;
    _dragX.stop();
    _dragY.stop();
    _velocity = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
    _springTo(_pressure, -0.38, _pressSpring);
    _hold = Timer(
      const Duration(milliseconds: 105),
      () => _springTo(_pressure, 1, _pressSpring),
    );
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _velocity?.addPosition(event.timeStamp, event.position);
    final delta = event.position - _pressOrigin;
    if (delta.distanceSquared < 9 && !_dragging) return;
    final pull = _resistedPull(delta);
    if (!MediaQuery.disableAnimationsOf(context)) {
      if (!_dragging) {
        _dragging = true;
        _hold?.cancel();
        _springTo(_pressure, 1, _pressSpring);
      }
      var offset = _dragStart + pull;
      if (offset.distance > _maxTravel) offset *= _maxTravel / offset.distance;
      _dragX.value = offset.dx;
      _dragY.value = offset.dy;
    }
  }

  static Offset _resistedPull(Offset delta) =>
      delta * (_maxTravel / (_maxTravel + delta.distance));

  void _end(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _velocity?.addPosition(event.timeStamp, event.position);
    final lifted = event is PointerUpEvent;
    final velocity = lifted && _dragging
        ? _velocity?.getVelocity().pixelsPerSecond ?? Offset.zero
        : Offset.zero;
    final delta = event.position - _pressOrigin;
    _release(velocity);
    if (lifted &&
        -delta.dy > delta.dx.abs() &&
        -_resistedPull(delta).dy >= _pullUpThreshold) {
      widget.onPrimaryPullUp?.call();
    }
  }

  void _release([Offset velocity = Offset.zero]) {
    _pointer = null;
    _velocity = null;
    _dragging = false;
    _hold?.cancel();
    _springTo(_pressure, 0, _releaseSpring);
    final momentum = velocity * 0.18;
    _springTo(
      _dragX,
      0,
      _dragSpring,
      velocity: momentum.dx.clamp(-150.0, 150.0),
    );
    _springTo(
      _dragY,
      0,
      _dragSpring,
      velocity: momentum.dy.clamp(-150.0, 150.0),
    );
  }

  void _springTo(
    AnimationController controller,
    double target,
    SpringDescription spring, {
    double? velocity,
  }) {
    final initialVelocity = velocity ?? controller.velocity;
    if (controller.value == target && initialVelocity == 0) {
      controller.stop();
      return;
    }
    controller.animateWith(
      SpringSimulation(
        spring,
        controller.value,
        target,
        initialVelocity,
        snapToEnd: true,
      ),
    );
  }

  @override
  void didUpdateWidget(FrostedControlPair oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.primaryVisible && _pointer != null) _release();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _pressure.dispose();
    _dragX.dispose();
    _dragY.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    child: widget.primary,
    builder: (context, primary) {
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      final pressure = reduceMotion
          ? 0.0
          : _pressure.value.clamp(-0.5, 1.08).toDouble();
      final offset = reduceMotion ? Offset.zero : _offset;
      final companion = widget.companion;
      final distanceAway = math.max(0.0, -offset.dx) + 0.7 * offset.dy.abs();
      final proximity = (1 - distanceAway / 30).clamp(0.0, 1.0);
      final pressConnection = ((pressure - 0.52) / 0.48).clamp(0.0, 1.0);
      final dragConnection = ((offset.dx - 0.55 * offset.dy.abs() - 5) / 12)
          .clamp(0.0, 1.0);
      final upwardPull = -offset.dy - 0.7 * offset.dx.abs();
      final connection =
          companion != null &&
              widget.primaryVisible &&
              widget.companionVisible &&
              upwardPull <= 0
          ? math.max(pressConnection * proximity, dragConnection)
          : 0.0;
      final primaryTransform = _stretchToward(offset, pressure);
      final companionScale = 1 + connection * 0.04;
      final pull = connection * 0.7;
      final upwardStretch = ((upwardPull - 3) / (_pullUpThreshold - 3)).clamp(
        0.0,
        1.0,
      );
      final connected = connection > 0;
      final paintPrimaryBackdrop =
          connected || (widget.primaryVisible && upwardStretch > 0);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -_paintInset,
            top: -_paintInset,
            right: -_paintInset,
            bottom: -_paintInset,
            child: paintPrimaryBackdrop
                ? IgnorePointer(
                    child: ClipPath(
                      clipper: _ControlGlassClipper(
                        primaryTransform: primaryTransform,
                        hasCompanion: companion != null,
                        tipX: _pressX,
                        upwardStretch: upwardStretch,
                        companionScale: companionScale,
                        pull: pull,
                        connection: connection,
                      ),
                      child: _dragSurface,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: companion == null ? 0 : _companionSlot,
            ),
            child: Listener(
              onPointerDown: _press,
              onPointerMove: _move,
              onPointerUp: _end,
              onPointerCancel: _end,
              child: Transform(
                alignment: Alignment.center,
                transformHitTests: false,
                transform: primaryTransform,
                child: _SharedGlassBackdrop(
                  active: paintPrimaryBackdrop,
                  child: primary!,
                ),
              ),
            ),
          ),
          if (companion != null)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: _companionWidth,
              child: Transform.translate(
                offset: Offset(-pull, 0),
                transformHitTests: false,
                child: Transform.scale(
                  scale: companionScale,
                  transformHitTests: false,
                  child: _SharedGlassBackdrop(
                    active: connected,
                    child: companion,
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  static Matrix4 _stretchToward(Offset offset, double pressure) {
    final distance = offset.distance;
    final axis = distance == 0 ? Offset.zero : offset / distance;
    final stretch = (distance / _maxTravel).clamp(0.0, 1.0);
    final across = 1 - 0.10 * stretch;
    final coupling = 0.25 * stretch;
    final shear = coupling * axis.dx * axis.dy;
    final width = 1 + 0.087 * pressure;
    final height = 1 + 0.14 * pressure;
    return Matrix4.identity()
      ..setEntry(0, 0, (across + coupling * axis.dx * axis.dx) * width)
      ..setEntry(0, 1, shear * height)
      ..setEntry(1, 0, shear * width)
      ..setEntry(1, 1, (across + coupling * axis.dy * axis.dy) * height)
      ..setTranslationRaw(offset.dx, offset.dy, 0);
  }
}

class _SharedGlassBackdrop extends InheritedWidget {
  const _SharedGlassBackdrop({required this.active, required super.child});

  final bool active;

  @override
  bool updateShouldNotify(_SharedGlassBackdrop oldWidget) =>
      active != oldWidget.active;
}

class _ControlGlassClipper extends CustomClipper<Path> {
  const _ControlGlassClipper({
    required this.primaryTransform,
    required this.hasCompanion,
    required this.tipX,
    required this.upwardStretch,
    required this.companionScale,
    required this.pull,
    required this.connection,
  });

  final Matrix4 primaryTransform;
  final bool hasCompanion;
  final double tipX;
  final double upwardStretch;
  final double companionScale;
  final double pull;
  final double connection;

  @override
  Path getClip(Size size) {
    const inset = _FrostedControlPairState._paintInset;
    final slot = hasCompanion ? _FrostedControlPairState._companionSlot : 0.0;
    const buttonWidth = _FrostedControlPairState._companionWidth;
    final width = size.width - 2 * inset;
    final height = size.height - 2 * inset;
    if (width <= 2 * slot || height <= 0) return Path();

    final pill = Rect.fromLTWH(inset + slot, inset, width - 2 * slot, height);
    final center = pill.center;
    final pillPath = _primaryOutline(pill.shift(-center))
        .transform(primaryTransform.storage)
        .shift(center);
    if (connection == 0) return pillPath;

    final button = Rect.fromCenter(
      center: Offset(
        inset + width - buttonWidth / 2 - pull,
        inset + height / 2,
      ),
      width: buttonWidth * companionScale,
      height: height * companionScale,
    );

    final shapes = Path()
      ..addPath(pillPath, Offset.zero)
      ..addRRect(_stadium(button));
    Offset placeOnPill(Offset point) =>
        center + MatrixUtils.transformPoint(primaryTransform, point - center);

    final pillRadius = _radius(pill);
    final buttonRadius = _radius(button);
    final pillCap = Offset(pill.right - pillRadius, center.dy);
    final gap = button.center - placeOnPill(pillCap);
    if (gap.dx <= 0 || gap.distanceSquared < 1) return shapes;
    final axis = gap / gap.distance;
    final normal = Offset(-axis.dy, axis.dx);
    final contact = 0.22 + 0.54 * connection;
    final forward = axis * math.sqrt(1 - contact * contact);
    final side = normal * contact;
    final pillTop = placeOnPill(pillCap + (forward - side) * pillRadius) - axis;
    final pillBottom =
        placeOnPill(pillCap + (forward + side) * pillRadius) - axis;
    final buttonTop = button.center + (-forward - side) * buttonRadius + axis;
    final buttonBottom =
        button.center + (-forward + side) * buttonRadius + axis;
    final insetToNeck =
        normal *
        (math.min(pillRadius, buttonRadius) *
            contact *
            (0.78 - 0.5 * connection));
    final topTangent = (buttonTop - pillTop) * 0.28;
    final bottomTangent = (buttonBottom - pillBottom) * 0.28;
    final topLead = pillTop + topTangent + insetToNeck;
    final topTrail = buttonTop - topTangent + insetToNeck;
    final bottomLead = buttonBottom - bottomTangent - insetToNeck;
    final bottomTrail = pillBottom + bottomTangent - insetToNeck;
    final bridge = Path()
      ..moveTo(pillTop.dx, pillTop.dy)
      ..cubicTo(
        topLead.dx,
        topLead.dy,
        topTrail.dx,
        topTrail.dy,
        buttonTop.dx,
        buttonTop.dy,
      )
      ..lineTo(buttonBottom.dx, buttonBottom.dy)
      ..cubicTo(
        bottomLead.dx,
        bottomLead.dy,
        bottomTrail.dx,
        bottomTrail.dy,
        pillBottom.dx,
        pillBottom.dy,
      )
      ..close();
    return Path.combine(PathOperation.union, shapes, bridge);
  }

  static double _radius(Rect rect) => math.min(rect.width, rect.height) / 2;

  static RRect _stadium(Rect rect) =>
      RRect.fromRectAndRadius(rect, Radius.circular(_radius(rect)));

  Path _primaryOutline(Rect rect) {
    final stretch = upwardStretch;
    final radius = _radius(rect);
    if (stretch == 0 || rect.width < 4 * radius) {
      return Path()..addRRect(_stadium(rect));
    }

    final left = Offset(rect.left + radius, rect.center.dy);
    final right = Offset(rect.right - radius, rect.center.dy);
    final apex = Offset(
      (rect.left + tipX).clamp(
        rect.left + 1.65 * radius,
        rect.right - 1.65 * radius,
      ),
      rect.center.dy - rect.height * 0.70 * stretch,
    );
    const bottomNormal = math.pi / 2;
    final leftNormal = (apex - left).direction - bottomNormal;
    final rightNormal = (right - apex).direction - bottomNormal;

    // Connecting the corner arcs along their common tangents keeps each side straight.
    return Path()
      ..arcTo(
        Rect.fromCircle(center: left, radius: radius),
        bottomNormal,
        leftNormal + 2 * math.pi - bottomNormal,
        true,
      )
      ..arcTo(
        Rect.fromCircle(center: apex, radius: radius),
        leftNormal,
        rightNormal - leftNormal,
        false,
      )
      ..arcTo(
        Rect.fromCircle(center: right, radius: radius),
        rightNormal,
        bottomNormal - rightNormal,
        false,
      )
      ..close();
  }

  @override
  bool shouldReclip(_ControlGlassClipper oldClipper) =>
      primaryTransform != oldClipper.primaryTransform ||
      hasCompanion != oldClipper.hasCompanion ||
      tipX != oldClipper.tipX ||
      upwardStretch != oldClipper.upwardStretch ||
      companionScale != oldClipper.companionScale ||
      pull != oldClipper.pull ||
      connection != oldClipper.connection;
}
