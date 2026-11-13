import 'dart:convert';
import 'dart:math' as math;

import 'album_cover_flow.dart';

import 'package:flutter/scheduler.dart';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final Ticker _ticker;
  Offset _velocity = Offset.fromDirection(
    math.Random().nextDouble() * math.pi * 2,
    12,
  );
  Duration? _lastTick;
  bool _touching = false;
  double _dragDistance = 0;
  bool _reduceMotion = false;
  bool _landscape = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_advance)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
  }

  void _advance(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null || _touching || _reduceMotion || _landscape) return;
    final dt = ((elapsed - previous).inMicroseconds / 1000000).clamp(0.0, 0.05);
    final speed = _velocity.distance;
    final nextSpeed = 12 + (speed - 12) * math.exp(-2.5 * dt);
    _velocity = Offset.fromDirection(_velocity.direction, nextSpeed);
    final matrix = _transform.value.clone();
    matrix.setEntry(0, 3, matrix.entry(0, 3) + _velocity.dx * dt);
    matrix.setEntry(1, 3, matrix.entry(1, 3) + _velocity.dy * dt);
    _transform.value = matrix;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _transform.dispose();
    super.dispose();
  }

  late final Future<List<Map<String, dynamic>>> _albums = rootBundle
      .loadString('assets/albums/catalog.json')
      .then(
        (value) =>
            (jsonDecode(value) as List<dynamic>).cast<Map<String, dynamic>>(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff171715),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _albums,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load album covers.'));
          }
          final albums = snapshot.data;
          if (albums == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_landscape) return AlbumCoverFlow(albums: albums);
          return LayoutBuilder(
            builder: (context, constraints) => InteractiveViewer.builder(
              transformationController: _transform,
              // Custom drift owns inertia after the gesture ends.
              interactionEndFrictionCoefficient: 1e-100,
              onInteractionStart: (_) {
                _touching = true;
                _dragDistance = 0;
                _velocity = Offset.fromDirection(_velocity.direction, 12);
              },
              onInteractionUpdate: (details) {
                if (details.pointerCount == 1 &&
                    details.focalPointDelta.distance > 0.1) {
                  _dragDistance += details.focalPointDelta.distance;
                  _velocity = Offset.fromDirection(
                    details.focalPointDelta.direction,
                    12,
                  );
                }
              },
              onInteractionEnd: (details) {
                final velocity = details.velocity.pixelsPerSecond;
                if (velocity.distance > 12) {
                  _velocity = Offset.fromDirection(
                    velocity.direction,
                    velocity.distance.clamp(
                      12.0,
                      math.min(600.0, 12 + _dragDistance * 2.5),
                    ),
                  );
                }
                _touching = false;
              },
              minScale: 0.4,
              maxScale: 2.5,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              builder: (context, viewport) {
                final rect = viewport;
                final left = (rect.point0.x / 150).floor() - 1;
                final right = (rect.point2.x / 150).ceil() + 1;
                final top = (rect.point0.y / 150).floor() - 1;
                final bottom = (rect.point2.y / 150).ceil() + 1;
                return SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var row = top; row <= bottom; row++)
                        for (var col = left; col <= right; col++)
                          Positioned(
                            key: ValueKey((row, col)),
                            left: col * 150.0,
                            top: row * 150.0,
                            width: 142,
                            height: 142,
                            child: Image.asset(
                              albums[((row * 73856093) ^ (col * 19349663)) %
                                      albums.length]['asset']
                                  as String,
                              fit: BoxFit.cover,
                              cacheWidth: 300,
                              semanticLabel:
                                  albums[((row * 73856093) ^ (col * 19349663)) %
                                          albums.length]['title']
                                      as String,
                            ),
                          ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
