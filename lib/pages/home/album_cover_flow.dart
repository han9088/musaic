import 'dart:async';

import 'album_play_button.dart';

import '../../services/album_haptics.dart';

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

class AlbumCoverFlow extends StatefulWidget {
  const AlbumCoverFlow({
    super.key,
    required this.albums,
    this.haptics,
    this.playback,
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

  final List<Map<String, dynamic>> albums;

  @override
  State<AlbumCoverFlow> createState() => _AlbumCoverFlowState();
}

class _AlbumCoverFlowState extends State<AlbumCoverFlow>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _friction = 1.8;
  static const _dragSensitivity = 1.12;
  static const _settlingRate = 10.0;
  static const _maxTilt = 0.66;
  static const _tiltDeadZone = 200.0;

  late final Ticker _ticker;
  late final AlbumHaptics _haptics;
  double _position = 0;
  int _hapticIndex = 0;
  Duration? _lastHapticTime;
  double _velocity = 0;
  double _tilt = 0;
  double _dragDistance = 0;
  double _gestureTilt = 0;
  double? _target;
  bool _dragging = false;
  Duration? _lastFrame;
  Duration? _lastDrag;
  Duration? _lastReleaseTime;
  double _lastReleaseDirection = 0;
  double _coastGain = 1;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    _hapticIndex = _position.round();
    _tilt = widget.initialTilt;
    _gestureTilt = _tilt;
    _ticker = createTicker(_tick);
    _haptics = widget.haptics ?? AlbumHaptics();
    WidgetsBinding.instance.addObserver(this);
    if (widget.haptics == null) unawaited(_haptics.prepare());
    if (_tilt != 0 || _position != _position.roundToDouble()) {
      _target = _position.roundToDouble();
      _wake();
    }
  }

  void _wake() {
    if (!_ticker.isActive) {
      _lastFrame = null;
      _ticker.start();
    }
  }

  void _tick(Duration time) {
    final previous = _lastFrame;
    _lastFrame = time;
    if (previous == null) return;
    final dt = ((time - previous).inMicroseconds / 1000000).clamp(0.0, 0.032);
    final reduced = MediaQuery.disableAnimationsOf(context);
    setState(() {
      if (!_dragging) {
        if (_target == null && _velocity.abs() < 0.35) {
          _target = _position.roundToDouble();
        }
        final target = _target;
        if (target == null) {
          final friction = _friction / _coastGain;
          final decay = math.exp(-friction * dt);
          _position += _velocity * (1 - decay) / friction;
          _velocity *= decay;
        } else {
          // Critically damped settling preserves velocity when entering a slot.
          final error = _position - target;
          final c = _velocity + _settlingRate * error;
          final decay = math.exp(-_settlingRate * dt);
          _position = target + (error + c * dt) * decay;
          _velocity = (_velocity - _settlingRate * c * dt) * decay;
        }
      }
      final desiredTilt = reduced || _target != null ? 0.0 : _gestureTilt;
      // Hold perspective while coasting; ease back only when settling.
      final tiltResponse = _dragging ? 10.0 : 6.0;
      _tilt += (desiredTilt - _tilt) * (1 - math.exp(-tiltResponse * dt));
      if (!_dragging &&
          _target != null &&
          (_position - _target!).abs() < 0.001 &&
          _velocity.abs() < 0.01 &&
          _tilt.abs() < 0.001) {
        _position = _target!;
        _velocity = 0;
        _tilt = 0;
        _gestureTilt = 0;
        _ticker.stop();
      }
    });
    _notifyAlbumChange();
  }

  void _notifyAlbumChange() {
    widget.onMotionChanged?.call(_position, _tilt);
    final index = _position.round();
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
        strength: (_velocity.abs() / 8).clamp(0.15, 1.0),
      ),
    );
  }

  void _settle(double target) {
    _target = target;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() {
        _position = target;
        _velocity = 0;
        _tilt = 0;
        _gestureTilt = 0;
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
    return Image.asset(
      album['asset'] as String,
      width: size,
      height: size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.albums[_position.round() % widget.albums.length];
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
              final center = _position.round();
              final indices = List.generate(15, (i) => center + i - 7);
              final widths = <int, double>{
                for (final i in indices)
                  i:
                      size *
                      (0.7 + 0.3 * (1 - (i - _position).abs()).clamp(0.0, 1.0)),
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
              final lower = _position.floor();
              final fraction = _position - lower;
              final anchor =
                  centers[lower]! * (1 - fraction) +
                  centers[lower + 1]! * fraction;
              final plane = Matrix4.identity()
                ..setEntry(3, 2, 0.88 / constraints.maxWidth)
                ..rotateY(_tilt);
              return Semantics(
                label: '${selected['artist']}, ${selected['title']}',
                onIncrease: () => _settle(_position.roundToDouble() + 1),
                onDecrease: () => _settle(_position.roundToDouble() - 1),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (details) {
                    _dragging = true;
                    _dragDistance = 0;
                    _gestureTilt = _tilt;
                    if (_target != null) _velocity = 0;
                    _target = null;
                    _lastDrag = details.sourceTimeStamp;
                    _wake();
                  },
                  onHorizontalDragUpdate: (details) {
                    final delta = -details.delta.dx * _dragSensitivity / stride;
                    final time = details.sourceTimeStamp;
                    final previous = _lastDrag;
                    setState(() {
                      _position += delta;
                      _dragDistance += details.delta.dx;
                      if (_gestureTilt != 0) {
                        if (details.delta.dx != 0 &&
                            (details.delta.dx * _gestureTilt < 0 ||
                                _dragDistance.abs() > _tiltDeadZone)) {
                          _gestureTilt = details.delta.dx.sign * _maxTilt;
                        }
                      } else if (_dragDistance.abs() > _tiltDeadZone) {
                        _gestureTilt = _dragDistance.sign * _maxTilt;
                      }
                      if (time != null && previous != null && time > previous) {
                        final dt = (time - previous).inMicroseconds / 1000000;
                        final dragVelocity = delta / dt;
                        _velocity =
                            (_velocity * dragVelocity < 0
                                    ? dragVelocity
                                    : _velocity * 0.35 + dragVelocity * 0.65)
                                .clamp(-12.0, 12.0);
                      }
                    });
                    _lastDrag = time;
                  },
                  onHorizontalDragEnd: (details) {
                    _dragging = false;
                    final releaseVelocity =
                        (-details.velocity.pixelsPerSecond.dx *
                                _dragSensitivity /
                                stride)
                            .clamp(-12.0, 12.0);
                    // Keep recent motion when the release estimate points backwards.
                    if (_velocity * releaseVelocity >= 0) {
                      _velocity = releaseVelocity == 0
                          ? 0
                          : _velocity * 0.65 + releaseVelocity * 0.35;
                    }
                    final now = _lastDrag;
                    final previousRelease = _lastReleaseTime;
                    final interval = previousRelease == null || now == null
                        ? 1.0
                        : (now - previousRelease).inMicroseconds / 1000000;
                    final cadence = (1 - interval / 0.7).clamp(0.0, 1.0);
                    _coastGain =
                        _velocity.abs() >= 0.35 &&
                            _velocity.sign == _lastReleaseDirection
                        ? 1 + (_coastGain * 0.35 + 0.3) * cadence
                        : 1;
                    _lastReleaseTime = now;
                    _lastReleaseDirection = _velocity.sign;
                    if (_velocity.abs() < 0.35) {
                      _settle(_position.roundToDouble());
                    }
                    _wake();
                  },
                  onHorizontalDragCancel: () {
                    _dragging = false;
                    _settle(_position.roundToDouble());
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
                ignoring: index != _position.round(),
                child: AnimatedOpacity(
                  opacity: index == _position.round() ? 1 : 0,
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
