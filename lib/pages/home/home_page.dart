import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import 'album_artwork.dart';
import '../../services/album_haptics.dart';
import '../../services/mock_album_cache.dart';
import '../../services/music/music_source_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import 'home_sheet.dart';
import 'canvas/album_canvas.dart';
import 'canvas/album_grid_snapshot.dart';
import 'canvas/portrait_tilt.dart';
import 'canvas/selected_album.dart';
import 'cover_flow/album_cover_flow.dart';
import 'layout/album_layout_transition.dart';
import 'layout/layout_switch_overlay.dart';
import 'playback/album_playback.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.albumCache, this.sources});

  final MusicSourceController? sources;

  final MockAlbumCache albumCache;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final _haptics = AlbumHaptics();
  final _playback = AlbumPlayback();
  late final _sources = widget.sources ?? MusicSourceController();
  late final VoidCallback _stopSourceListener;
  late final AnimationController _layout;
  late final Animation<double> _layoutProgress;
  bool _hasOrientation = false;
  Size? _portraitSize;
  AlbumGridSnapshot? _gridSnapshot;
  List<Map<String, dynamic>>? _catalog;
  List<Map<String, dynamic>>? _flowAlbums;
  final _gridAlbums = <(int, int), Map<String, dynamic>>{};
  double _flowPosition = 0;
  double _flowTilt = 0;
  int _gridOffset = 0;
  (int, int)? _selectedAlbum;
  bool _selectionPaused = false;

  Map<String, dynamic> _albumAt(
    int row,
    int column,
    List<Map<String, dynamic>> albums,
  ) =>
      _gridAlbums[(row, column)] ??
      albums[gridAlbumIndex(row, column, albums.length)];

  void _prepareExpansion() {
    final albums = _catalog;
    final size = _portraitSize;
    if (albums == null || albums.isEmpty || size == null) return;
    final snapshot = AlbumGridSnapshot.capture(size, _transform.value);
    if (snapshot.cells.isEmpty) return;
    _gridSnapshot = snapshot;
    final visible = [
      for (final cell in snapshot.cells)
        _albumAt(cell.row, cell.column, albums),
    ];
    final visibleAlbums = visible.toSet();
    _flowAlbums = [
      ...visible,
      ...albums.where((album) => !visibleAlbums.contains(album)),
    ];
    _flowPosition = snapshot.focus.toDouble();
    _flowTilt = 0;
    _gridOffset = 0;
  }

  void _prepareCollapse() {
    final albums = _flowAlbums ?? _catalog;
    if (albums == null || albums.isEmpty) return;
    _gridSnapshot ??= AlbumGridSnapshot.capture(
      MediaQuery.sizeOf(context),
      _transform.value,
    );
    final snapshot = _gridSnapshot!;
    _gridOffset = _flowPosition.round() - snapshot.focus;
    _gridAlbums.clear();
    _selectedAlbum = null;
    for (var i = 0; i < snapshot.cells.length; i++) {
      final cell = snapshot.cells[i];
      final album = albums[(i + _gridOffset) % albums.length];
      _gridAlbums[(cell.row, cell.column)] = album;
      if (album['asset'] == _playback.asset &&
          album['title'] == _playback.title) {
        _selectedAlbum = (cell.row, cell.column);
      }
    }
  }

  void _syncMotion() {
    final animating = _layout.isAnimating;
    unawaited(_haptics.setActive(_landscape && !animating));
    if (_landscape || _reduceMotion || animating) {
      _ticker.stop();
      _lastTick = null;
    } else if (!_ticker.isActive) {
      _lastTick = null;
      _ticker.start();
    }
  }

  final _transform = TransformationController();
  late final Ticker _ticker;
  Offset _velocity = Offset.fromDirection(
    math.Random().nextDouble() * math.pi * 2,
    12,
  );
  Duration? _lastTick;
  bool _touching = false;
  final _pressedPointers = <int>{};
  bool _reduceMotion = false;
  bool _landscape = false;
  bool? _manualLayout;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_advance);
    _layout = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _layoutProgress = _layout.drive(CurveTween(curve: Curves.easeInOutCubic));
    _layout.addStatusListener((status) {
      if (!mounted) return;
      _syncMotion();
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        setState(() {});
      }
    });
    _playback.onError = () {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).musicPlaybackFailed),
        ),
      );
    };
    _stopSourceListener = _sources.catalog.subscribe((albums) {
      if (!mounted) return;
      _playback.bind(_sources.provider, albums);
      setState(() {
        _albums = albums == null
            ? _mockAlbums
            : Future.value([
                for (final album in albums)
                  <String, dynamic>{
                    'asset': album.artworkUrl ?? 'local:${album.reference.id}',
                    'title': album.title,
                    'artist': album.artist ?? '',
                  },
              ]);
        _catalog = null;
        _flowAlbums = null;
        _gridAlbums.clear();
        _gridSnapshot = null;
        _selectedAlbum = null;
        _flowPosition = 0;
        _flowTilt = 0;
        _gridOffset = 0;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_haptics.prepare());
      unawaited(
        widget.albumCache
            .warmImages((image) async {
              if (mounted) await precacheImage(image, context);
            })
            .catchError((Object error, StackTrace stack) {
              FlutterError.reportError(
                FlutterErrorDetails(exception: error, stack: stack),
              );
            }),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final landscape =
        _manualLayout ??
        (defaultTargetPlatform != TargetPlatform.macOS &&
            MediaQuery.orientationOf(context) == Orientation.landscape);
    _updateLayout(landscape);
  }

  void _updateLayout(bool landscape) {
    if (!_hasOrientation) {
      _hasOrientation = true;
      _landscape = landscape;
      _layout.value = landscape ? 1 : 0;
    } else if (landscape != _landscape) {
      final reversing = _layout.isAnimating;
      _landscape = landscape;
      _touching = false;
      _pressedPointers.clear();
      _selectionPaused = false;
      if (landscape && !reversing) _prepareExpansion();
      if (!landscape && !reversing) _prepareCollapse();
      if (_reduceMotion || _gridSnapshot == null) {
        _layout.value = landscape ? 1 : 0;
      } else if (landscape) {
        _layout.forward();
      } else {
        _layout.reverse();
      }
    } else if (_reduceMotion && _layout.isAnimating) {
      _layout.value = landscape ? 1 : 0;
    }
    _syncMotion();
  }

  void _advance(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null ||
        _touching ||
        _pressedPointers.isNotEmpty ||
        _selectionPaused ||
        _reduceMotion ||
        _landscape) {
      return;
    }
    final dt = ((elapsed - previous).inMicroseconds / 1000000).clamp(0.0, 0.05);
    final speed = _velocity.distance;
    const decay = 2.2;
    final attenuation = math.exp(-decay * dt);
    final distance = 12 * dt + (speed - 12) * (1 - attenuation) / decay;
    final displacement = Offset.fromDirection(_velocity.direction, distance);
    _velocity = Offset.fromDirection(
      _velocity.direction,
      12 + (speed - 12) * attenuation,
    );
    final matrix = _transform.value.clone();
    matrix.setEntry(0, 3, matrix.entry(0, 3) + displacement.dx);
    matrix.setEntry(1, 3, matrix.entry(1, 3) + displacement.dy);
    _transform.value = matrix;
  }

  @override
  void dispose() {
    unawaited(_haptics.dispose());
    _stopSourceListener();
    _playback.dispose();
    if (widget.sources == null) {
      unawaited(
        _sources.dispose().catchError((Object error) {
          debugPrint('Music source disposal failed: $error');
        }),
      );
    }
    _layout.dispose();
    _ticker.dispose();
    _transform.dispose();
    super.dispose();
  }

  late final Future<List<Map<String, dynamic>>> _mockAlbums = widget.albumCache
      .load();
  late Future<List<Map<String, dynamic>>> _albums = _mockAlbums;

  @override
  Widget build(BuildContext context) {
    return HomeSheet(
      enabled: !_landscape,
      sources: _sources,
      child: Scaffold(
        backgroundColor: const Color(0xff171715),
        body: Builder(
          builder: (context) {
            final content = _buildAlbums();
            if (defaultTargetPlatform != TargetPlatform.iOS &&
                defaultTargetPlatform != TargetPlatform.macOS) {
              return content;
            }
            return LayoutSwitchOverlay(
              coverFlow: _landscape,
              onSwitch: () {
                if (_catalog == null || _catalog!.isEmpty) return;
                setState(() {
                  _manualLayout = !_landscape;
                  _updateLayout(_manualLayout!);
                });
              },
              child: content,
            );
          },
        ),
      ),
    );
  }

  Widget _buildAlbums() => FutureBuilder<List<Map<String, dynamic>>>(
    key: ObjectKey(_albums),
    future: _albums,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('Unable to load album covers.'));
      }
      final albums = snapshot.data;
      if (albums == null) {
        return const Center(child: CircularProgressIndicator());
      }
      _catalog = albums;
      if (albums.isEmpty) {
        return Center(
          child: Text(
            AppLocalizations.of(context).musicSourceEmpty,
            style: const TextStyle(color: Colors.white70),
          ),
        );
      }
      if (_layout.isAnimating && _gridSnapshot != null) {
        return AlbumLayoutTransition(
          albums: _flowAlbums ?? albums,
          snapshot: _gridSnapshot!,
          position: _flowPosition,
          tilt: _flowTilt,
          gridOffset: _gridOffset,
          progress: _layoutProgress,
        );
      }
      if (_landscape) {
        return AlbumCoverFlow(
          albums: _flowAlbums ?? albums,
          haptics: _haptics,
          playback: _playback,
          initialPosition: _flowPosition,
          initialTilt: _flowTilt,
          onMotionChanged: (position, tilt) {
            _flowPosition = position;
            _flowTilt = tilt;
          },
        );
      }
      return PortraitTilt(
        child: LayoutBuilder(
          builder: (context, constraints) {
            _portraitSize = constraints.biggest;
            return Listener(
              onPointerDown: (event) => _pressedPointers.add(event.pointer),
              onPointerUp: (event) => _pressedPointers.remove(event.pointer),
              onPointerCancel: (event) =>
                  _pressedPointers.remove(event.pointer),
              child: InteractiveViewer.builder(
                clipBehavior: Clip.none,
                transformationController: _transform,
                // Custom drift owns inertia after the gesture ends.
                interactionEndFrictionCoefficient: 1e-100,
                onInteractionStart: (_) {
                  _touching = true;
                  _velocity = Offset.fromDirection(_velocity.direction, 12);
                },
                onInteractionUpdate: (details) {
                  if (details.pointerCount == 1 &&
                      details.focalPointDelta.distance > 0.1) {
                    _selectionPaused = false;
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
                      velocity.distance.clamp(12.0, 2400.0),
                    );
                  }
                  _touching = false;
                },
                minScale: 0.4,
                maxScale: 2.5,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                builder: (context, viewport) {
                  final rect = viewport;
                  final margin =
                      PortraitTilt.overscan(constraints.biggest) /
                      _transform.value.getColumn(0).length;
                  final left =
                      ((rect.point0.x - margin) / albumGridExtent).floor() - 1;
                  final right =
                      ((rect.point2.x + margin) / albumGridExtent).ceil() + 1;
                  final top =
                      ((rect.point0.y - margin) / albumGridExtent).floor() - 1;
                  final bottom =
                      ((rect.point2.y + margin) / albumGridExtent).ceil() + 1;
                  return AlbumCanvas(
                    size: constraints.biggest,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var row = top; row <= bottom; row++)
                          for (var col = left; col <= right; col++)
                            Positioned(
                              key: ValueKey((row, col)),
                              left: col * albumGridExtent,
                              top: row * albumGridExtent,
                              width: albumGridExtent,
                              height: albumGridExtent,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _selectedAlbum = (row, col);
                                  _selectionPaused = true;
                                }),
                                child: albumArtwork(
                                  _albumAt(row, col, albums)['asset'] as String,
                                  fit: BoxFit.cover,
                                  semanticLabel:
                                      _albumAt(row, col, albums)['title']
                                          as String,
                                ),
                              ),
                            ),
                        if (_selectedAlbum case final selected?)
                          Positioned(
                            key: ValueKey(('selected', selected)),
                            left: selected.$2 * albumGridExtent,
                            top: selected.$1 * albumGridExtent,
                            width: albumGridExtent,
                            height: albumGridExtent,
                            child: SelectedAlbum(
                              playback: _playback,
                              asset:
                                  _albumAt(
                                        selected.$1,
                                        selected.$2,
                                        albums,
                                      )['asset']
                                      as String,
                              title:
                                  _albumAt(
                                        selected.$1,
                                        selected.$2,
                                        albums,
                                      )['title']
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
    },
  );
}
