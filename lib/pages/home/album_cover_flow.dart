import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

class AlbumCoverFlow extends StatefulWidget {
  const AlbumCoverFlow({super.key, required this.albums});

  final List<Map<String, dynamic>> albums;

  @override
  State<AlbumCoverFlow> createState() => _AlbumCoverFlowState();
}

class _AlbumCoverFlowState extends State<AlbumCoverFlow>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _position = 0;
  double _velocity = 0;
  double _tilt = 0;
  double? _target;
  bool _dragging = false;
  Duration? _lastFrame;
  Duration? _lastDrag;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
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
          final decay = math.exp(-3.2 * dt);
          _position += _velocity * (1 - decay) / 3.2;
          _velocity *= decay;
        } else {
          // Critically damped settling preserves velocity when entering a slot.
          final error = _position - target;
          final c = _velocity + 14 * error;
          final decay = math.exp(-14 * dt);
          _position = target + (error + c * dt) * decay;
          _velocity = (_velocity - 14 * c * dt) * decay;
        }
      }
      final desiredTilt = reduced
          ? 0.0
          : (-_velocity * 0.075).clamp(-0.55, 0.55);
      _tilt += (desiredTilt - _tilt) * (1 - math.exp(-14 * dt));
      if (!_dragging &&
          _target != null &&
          (_position - _target!).abs() < 0.001 &&
          _velocity.abs() < 0.01 &&
          _tilt.abs() < 0.001) {
        _position = _target!;
        _velocity = 0;
        _tilt = 0;
        _ticker.stop();
      }
    });
  }

  void _settle(double target) {
    _target = target;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() {
        _position = target;
        _velocity = 0;
        _tilt = 0;
      });
      _ticker.stop();
    } else {
      _wake();
    }
  }

  @override
  void dispose() {
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
                ..setEntry(3, 2, 0.8 / constraints.maxWidth)
                ..rotateY(_tilt);
              return Semantics(
                label: '${selected['artist']}, ${selected['title']}',
                onIncrease: () => _settle(_position.roundToDouble() + 1),
                onDecrease: () => _settle(_position.roundToDouble() - 1),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (details) {
                    _dragging = true;
                    _velocity = 0;
                    _target = null;
                    _lastDrag = details.sourceTimeStamp;
                    _wake();
                  },
                  onHorizontalDragUpdate: (details) {
                    final delta = -details.delta.dx / stride;
                    final time = details.sourceTimeStamp;
                    final previous = _lastDrag;
                    setState(() {
                      _position += delta;
                      if (time != null && previous != null && time > previous) {
                        final dt = (time - previous).inMicroseconds / 1000000;
                        _velocity = (_velocity * 0.35 + delta / dt * 0.65)
                            .clamp(-12.0, 12.0);
                      }
                    });
                    _lastDrag = time;
                  },
                  onHorizontalDragEnd: (details) {
                    _dragging = false;
                    _velocity = (-details.velocity.pixelsPerSecond.dx / stride)
                        .clamp(-12.0, 12.0);
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
      child: GestureDetector(
        onTap: () => _settle(index.toDouble()),
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
    );
  }
}
