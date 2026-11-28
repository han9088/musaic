import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../services/diagnostics/diagnostic_log.dart';
import '../../ui/transitions/rect_flip_transition.dart';
import '../artwork/presentation/directory_artwork.dart';
import '../artwork/presentation/xerox_palette.dart';

Future<void> showAlbumCoverPopup({
  required BuildContext source,
  required Widget artwork,
  required VoidCallback onReturned,
  Widget? trackList,
  GestureLongPressStartCallback? onCoverLongPress,
}) async {
  final navigator = Navigator.of(source, rootNavigator: true);
  final origin = RectFlipTransition.originOf(source, navigator);
  final directories = DirectoryArtworkScope.watch(source).library;
  final palette = source
      .getInheritedWidgetOfExactType<XeroxPaletteScope>()
      ?.notifier;

  final route = RawDialogRoute<void>(
    barrierLabel: MaterialLocalizations.of(source).modalBarrierDismissLabel,
    barrierColor: const Color(0x99000000),
    transitionDuration: MediaQuery.disableAnimationsOf(source)
        ? Duration.zero
        : RectFlipTransition.duration,
    // The cover's transform is the complete transition. Skip the route fade.
    transitionBuilder: (_, _, _, child) => child,
    pageBuilder: (context, animation, _) {
      final content = _AlbumCoverPopup(
        origin: origin,
        animation: animation,
        front: ColoredBox(color: Colors.black, child: artwork),
        back: trackList,
        onCoverLongPress: onCoverLongPress,
      );
      return DirectoryArtworkScope(
        library: directories,
        child: palette == null
            ? content
            : XeroxPaletteScope(notifier: palette, child: content),
      );
    },
  );
  final popped = navigator.push(route);
  diagnosticLog.record(DiagnosticEvent.albumPopupOpened);
  // Restore the grid in the same frame that removes the popup.
  route.animation!.addStatusListener((status) {
    if (status == AnimationStatus.dismissed) onReturned();
  });
  await popped;
  await route.completed;
  diagnosticLog.record(DiagnosticEvent.albumPopupClosed);
}

class _AlbumCoverPopup extends StatefulWidget {
  const _AlbumCoverPopup({
    required this.origin,
    required this.animation,
    required this.front,
    required this.back,
    required this.onCoverLongPress,
  });

  final Rect origin;
  final Animation<double> animation;
  final Widget front;
  final Widget? back;
  final GestureLongPressStartCallback? onCoverLongPress;

  @override
  State<_AlbumCoverPopup> createState() => _AlbumCoverPopupState();
}

class _AlbumCoverPopupState extends State<_AlbumCoverPopup>
    with SingleTickerProviderStateMixin {
  // One unit is a half-turn, ending with the next face flat.
  static const _deceleration = Cubic(1 / 3, 1, 2 / 3, 1);
  static const _popupPerspective = 0.18;
  late final _turn = AnimationController.unbounded(vsync: this);
  double? _dragStart;
  bool _closingFromFront = false;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_routeStatusChanged);
  }

  void _routeStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.reverse) return;
    _closingFromFront = widget.back != null && _faceAt(_turn.value).isOdd;
    _turn.stop();
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_routeStatusChanged);
    _turn.dispose();
    super.dispose();
  }

  // Keep the outgoing face at the exact edge-on angle.
  static int _faceAt(double turn) => (turn - 0.5).ceil();

  ({double expansion, double turn}) _routePose() {
    final expansion = RectFlipTransition.curve.transform(
      widget.animation.value,
    );
    return (
      expansion: expansion,
      turn: expansion * (_closingFromFront ? 2 : 1),
    );
  }

  void _settle(
    double speed, {
    required bool reducedMotion,
    bool canceled = false,
  }) {
    final start = _dragStart;
    _dragStart = null;
    if (start == null || !widget.animation.isCompleted) return;
    final startFace = _faceAt(start);
    final travel = _turn.value - start;
    final velocity = speed.clamp(0.0, 8.0);
    final shouldFlip = !canceled && (travel > 0 || velocity > 0);
    final oppositeFace = startFace + 1;
    var target = _faceAt(_turn.value).toDouble();
    if (shouldFlip) {
      // Add whole revolutions to the opposite face as the swipe travels farther.
      final coastWeight = ((travel - 0.15) / 0.60).clamp(0.0, 1.0);
      final projectedTurn = _turn.value + velocity * 0.22 * coastWeight;
      final revolutions = math.max(
        0,
        ((projectedTurn - oppositeFace) / 2).round(),
      );
      target = (oppositeFace + 2 * revolutions).toDouble();
      // Let a small overshoot settle back, but keep larger turns moving forward.
      if (target < _turn.value - 0.20) target += 2;
    }
    if (reducedMotion) {
      _turn.value = target;
      return;
    }
    final distance = (target - _turn.value).abs();
    final singleFlip = shouldFlip && target == oppositeFace;
    final milliseconds = (3000 * distance / math.max(velocity, 3.0))
        .round()
        .clamp(singleFlip ? 360 : 150, singleFlip ? 480 : 950);
    _turn.animateTo(
      target,
      duration: Duration(milliseconds: milliseconds),
      curve: singleFlip ? Curves.easeInOutSine : _deceleration,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final padding = MediaQuery.viewPaddingOf(context);
      final safeWidth = size.width - 2 * math.max(padding.left, padding.right);
      final safeHeight =
          size.height - 2 * math.max(padding.top, padding.bottom);
      final side = math.min(math.min(safeWidth, safeHeight) * 0.88, 440.0);
      if (side <= 0) return const SizedBox.shrink();
      final square = Rect.fromCenter(
        center: size.center(Offset.zero),
        width: side,
        height: side,
      );
      final dragDistance = side * 0.70;
      final reducedMotion = MediaQuery.disableAnimationsOf(context);
      return Stack(
        children: [
          Positioned.fromRect(
            rect: square,
            child: AnimatedBuilder(
              animation: widget.animation,
              builder: (context, child) {
                final pose = _routePose();
                return IgnorePointer(
                  ignoring: !widget.animation.isCompleted,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: RectFlipTransition.transform(
                      layout: square,
                      rect: Rect.lerp(widget.origin, square, pose.expansion)!,
                      turnProgress: pose.turn % 1,
                      perspectiveStrength: _closingFromFront
                          ? _popupPerspective
                          : null,
                    ),
                    child: child,
                  ),
                );
              },
              // The nested track list receives vertical drags before the card.
              child: GestureDetector(
                key: const ValueKey('album-cover-popup'),
                behavior: HitTestBehavior.opaque,
                onLongPressStart: widget.onCoverLongPress,
                onVerticalDragStart: (_) {
                  _turn.stop();
                  _dragStart = _turn.value;
                },
                onVerticalDragUpdate: (details) {
                  final start = _dragStart;
                  if (start == null || !widget.animation.isCompleted) return;
                  _turn.value = math.max(
                    start.floorToDouble(),
                    _turn.value + details.delta.dy / dragDistance,
                  );
                },
                onVerticalDragEnd: (details) => _settle(
                  details.velocity.pixelsPerSecond.dy / dragDistance,
                  reducedMotion: reducedMotion,
                ),
                onVerticalDragCancel: () =>
                    _settle(0, reducedMotion: reducedMotion, canceled: true),
                child: AnimatedBuilder(
                  animation: Listenable.merge([widget.animation, _turn]),
                  builder: (context, _) {
                    final pose = _routePose();
                    final face = _faceAt(_turn.value);
                    final showBack = _closingFromFront
                        ? pose.turn.round().isOdd
                        : pose.turn >= 0.5 && face.isEven;
                    final tiltProgress = _closingFromFront
                        ? pose.turn - 1
                        : (pose.turn - 0.5) * 2;
                    final tilt = reducedMotion
                        ? 0.0
                        : (_turn.value - face) * tiltProgress.clamp(0.0, 1.0);
                    return Transform(
                      alignment: Alignment.center,
                      transformHitTests: false,
                      // Keep the near edge within the popup's viewport inset.
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, _popupPerspective / side)
                        ..rotateX(tilt * math.pi),
                      child: RepaintBoundary(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Visibility(
                              visible: widget.back == null || !showBack,
                              maintainState: true,
                              child: widget.front,
                            ),
                            if (widget.back case final back?)
                              Visibility(
                                visible: showBack,
                                maintainState: true,
                                child: back,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
