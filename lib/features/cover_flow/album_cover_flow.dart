import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../artwork/album_artwork.dart';
import 'cover_flow_input.dart';
import 'cover_flow_motion.dart';
import '../../services/album_haptics.dart';
import '../music/playback/album_play_button.dart';
import '../music/playback/album_playback.dart';

class AlbumCoverFlow extends StatefulWidget {
  const AlbumCoverFlow({
    super.key,
    required this.albums,
    this.haptics,
    this.playback,
    this.xerox = false,
    this.initialPosition = 0,
    this.initialTilt = 0,
    this.onMotionChanged,
  });

  final double initialPosition;
  final double initialTilt;
  final void Function(double position, double tilt)? onMotionChanged;

  /// When provided, the caller owns preparation and disposal.
  final AlbumHaptics? haptics;
  final AlbumPlayback? playback;
  final bool xerox;

  final List<Map<String, dynamic>> albums;

  @override
  State<AlbumCoverFlow> createState() => _AlbumCoverFlowState();
}

class _AlbumCoverFlowState extends State<AlbumCoverFlow>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  late final AlbumHaptics _haptics;
  late final CoverFlowMotion _motion;
  int _hapticIndex = 0;
  Duration? _lastHapticTime;

  @override
  void initState() {
    super.initState();
    _motion = CoverFlowMotion(
      position: widget.initialPosition,
      tilt: widget.initialTilt,
    );
    _hapticIndex = _motion.position.round();
    _ticker = createTicker(_tick);
    _haptics = widget.haptics ?? AlbumHaptics();
    WidgetsBinding.instance.addObserver(this);
    if (widget.haptics == null) unawaited(_haptics.prepare());
    if (_motion.tilt != 0 || _motion.position != _motion.position.roundToDouble()) {
      _motion.target = _motion.position.roundToDouble();
      _wake();
    }
  }

  void _wake() {
    if (!_ticker.isActive) {
      _motion.lastFrame = null;
      _ticker.start();
    }
  }

  void _tick(Duration time) {
    final frame = _motion.advance(
      time,
      reduced: MediaQuery.disableAnimationsOf(context),
    );
    if (!frame.changed) return;
    setState(() {});
    if (frame.settled) _ticker.stop();
    _notifyAlbumChange();
  }

  void _notifyAlbumChange() {
    widget.onMotionChanged?.call(_motion.position, _motion.tilt);
    final index = _motion.position.round();
    if (index == _hapticIndex) return;
    final movingLeft = index > _hapticIndex;
    _hapticIndex = index;
    final time = SchedulerBinding.instance.currentFrameTimeStamp;
    if (_lastHapticTime != null &&
        time - _lastHapticTime! < const Duration(milliseconds: 40)) {
      return;
    }
    _lastHapticTime = time;
    unawaited(
      _haptics.tick(
        movingLeft: movingLeft,
        strength: (_motion.velocity.abs() / 8).clamp(0.15, 1.0),
      ),
    );
  }

  void _settle(double target) {
    _motion.target = target;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() {
        _motion.position = target;
        _motion.velocity = 0;
        _motion.tilt = 0;
        _motion.gestureTilt = 0;
      });
      _ticker.stop();
      _notifyAlbumChange();
    } else {
      _wake();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_haptics.setActive(state == AppLifecycleState.resumed));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.haptics == null) unawaited(_haptics.dispose());
    _ticker.dispose();
    super.dispose();
  }

  Widget _image(Map<String, dynamic> album, double size) {
    return albumArtwork(
      album['asset'] as String,
      width: size,
      height: size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      xerox: widget.xerox,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.albums[_motion.position.round() % widget.albums.length];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: Colors.black,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = math.min(
                constraints.maxHeight * 0.65,
                constraints.maxWidth * 0.31,
              );
              final stride = size * 0.7 + 6;
              final center = _motion.position.round();
              final indices = List.generate(15, (i) => center + i - 7);
              final widths = <int, double>{
                for (final i in indices)
                  i:
                      size *
                      (0.7 + 0.3 * (1 - (i - _motion.position).abs()).clamp(0.0, 1.0)),
              };
              final centers = <int, double>{indices.first: 0};
              for (var i = 1; i < indices.length; i++) {
                final previous = indices[i - 1];
                final current = indices[i];
                centers[current] =
                    centers[previous]! +
                    (widths[previous]! + widths[current]!) / 2 +
                    6;
              }
              final lower = _motion.position.floor();
              final fraction = _motion.position - lower;
              final anchor =
                  centers[lower]! * (1 - fraction) +
                  centers[lower + 1]! * fraction;
              final plane = Matrix4.identity()
                ..setEntry(3, 2, 0.88 / constraints.maxWidth)
                ..rotateY(_motion.tilt);
              return Semantics(
                label: '${selected['artist']}, ${selected['title']}',
                onIncrease: () => _settle(_motion.position.roundToDouble() + 1),
                onDecrease: () => _settle(_motion.position.roundToDouble() - 1),
                child: CoverFlowInput(
                  canStartInput: () => !_motion.dragging,
                  onScroll: (delta, time) {
                    setState(() => _motion.scroll(delta, time, stride));
                    _wake();
                  },
                  onScrollEnd: () {
                    _motion.endScroll();
                    _settle(_motion.position.roundToDouble());
                  },
                  onStep: (direction) {
                    _motion.velocity = 0;
                    _settle((_motion.target ?? _motion.position.roundToDouble()) + direction);
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (details) {
                      _motion.startDrag(details.sourceTimeStamp);
                      _wake();
                    },
                    onHorizontalDragUpdate: (details) {
                      setState(() => _motion.updateDrag(
                        details.delta.dx,
                        details.sourceTimeStamp,
                        stride,
                      ));
                    },
                    onHorizontalDragEnd: (details) {
                      final shouldSettle = _motion.endDrag(
                        details.velocity.pixelsPerSecond.dx,
                        stride,
                      );
                      if (shouldSettle) {
                        _settle(_motion.position.roundToDouble());
                      }
                      _wake();
                    },
                    onHorizontalDragCancel: () {
                      _motion.cancelDrag();
                      _settle(_motion.position.roundToDouble());
                    },
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned.fill(
                          child: Transform(
                            key: const ValueKey('cover-flow-plane'),
                            alignment: const Alignment(0, 0.04),
                            transform: plane,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                for (final index in indices)
                                  _cover(
                                    index,
                                    widths[index]!,
                                    centers[index]! - anchor,
                                    constraints,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          left: 20,
                          right: 20,
                          child: IgnorePointer(
                            child: Column(
                              children: [
                                Text(
                                  selected['artist'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xffbfc6ce),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  selected['title'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _cover(int index, double size, double x, BoxConstraints constraints) {
    final album = widget.albums[index % widget.albums.length];
    return Positioned(
      key: ValueKey('cover-$index'),
      left: constraints.maxWidth / 2 + x - size / 2,
      top: constraints.maxHeight * 0.52 - size / 2,
      width: size,
      height: size * 1.36,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _settle(index.toDouble()),
              child: RepaintBoundary(
                child: Column(
                  children: [
                    _image(album, size),
                    SizedBox(
                      height: size * 0.36,
                      child: ClipRect(
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x70ffffff), Color(0x00ffffff)],
                          ).createShader(rect),
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            maxHeight: size,
                            child: Transform.flip(
                              flipY: true,
                              child: _image(album, size),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.playback != null)
            Positioned(
              left: 0,
              top: 0,
              width: size,
              height: size,
              child: IgnorePointer(
                ignoring: index != _motion.position.round(),
                child: AnimatedOpacity(
                  opacity: index == _motion.position.round() ? 1 : 0,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  child: AlbumPlayButton(
                    diameter: 48,
                    asset: album['asset'] as String,
                    title: album['title'] as String,
                    playback: widget.playback!,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
