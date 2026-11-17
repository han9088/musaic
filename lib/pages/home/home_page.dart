import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../services/album_haptics.dart';
import '../../services/mock_album_cache.dart';
import '../../services/music/music_models.dart';
import '../../services/music/music_source_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import 'home_sheet.dart';
import '../../features/canvas/album_grid_snapshot.dart';
import '../../features/canvas/canvas_drift.dart';
import '../../features/canvas/home_album_layout_state.dart';
import '../../features/canvas/canvas_interaction_state.dart';
import '../../features/canvas/album_canvas_viewport.dart';
import '../../features/cover_flow/album_cover_flow.dart';
import '../../features/layout/album_layout_transition.dart';
import '../../features/layout/layout_switch_overlay.dart';
import '../../features/music/transition/music_source_transition.dart';
import '../../features/music/playback/album_playback.dart';
import '../../features/music/catalog/album_catalog_mapper.dart';

enum _HomeMusicSource { mock, mock2, local, directories }

enum _SourceTransitionPhase { exit, handoff, enter }

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
  late final AnimationController _sourceTimeline;
  final _sourceSwitching = ValueNotifier(false);
  List<Map<String, dynamic>>? _transitionTargetAlbums;
  Map<(int, int), SourceTileMotion> _exitMotions = const {};
  Map<(int, int), SourceTileMotion> _enterMotions = const {};
  _HomeMusicSource _renderedSource = _HomeMusicSource.mock;
  _SourceTransitionPhase? _sourcePhase;
  Completer<void>? _sourceTransitionCompleter;
  double _exitDurationMs = 0;
  double _sourceDurationMs = 0;
  bool _sourcePreparing = false;
  bool _hasOrientation = false;
  Size? _portraitSize;
  final _albumLayout = HomeAlbumLayoutState();
  List<Map<String, dynamic>>? _catalog;
  bool _xeroxEnabled = false;

  _HomeMusicSource get _currentSource => _sources.catalog.value == null
      ? _sources.mock2Selected.value
            ? _HomeMusicSource.mock2
            : _HomeMusicSource.mock
      : _sources.directorySelected.value
      ? _HomeMusicSource.directories
      : _HomeMusicSource.local;

  Future<List<Map<String, dynamic>>> _readCatalog(
    List<ProviderAlbum>? albums, {
    _HomeMusicSource? source,
  }) => albums == null
      ? source == _HomeMusicSource.mock2 ||
                (source == null && _sources.mock2Selected.value)
            ? _mock2Albums
            : _mockAlbums
      : Future.value(mapProviderAlbums(albums));

  Future<void> _applyCatalog(List<ProviderAlbum>? sourceAlbums) async {
    final albums = await _readCatalog(sourceAlbums);
    if (!mounted || _sourceSwitching.value) return;
    if (sourceAlbums == null) _warmMockImages();
    _playback.bind(_sources.provider, sourceAlbums);
    setState(() {
      _catalog = albums;
      _renderedSource = _currentSource;
      _albumLayout.clear();
    });
  }

  Future<void> _selectMusicSource(Future<void> Function() select) async {
    if (_sourceSwitching.value || _sourcePhase != null) return;
    final previousCatalog = _sources.catalog.value;
    _sourceSwitching.value = true;
    try {
      await select();
      if (!mounted) return;
      final source = _currentSource;
      final sourceAlbums = _sources.catalog.value;
      final target = await _readCatalog(sourceAlbums, source: source);
      if (!mounted) return;
      if (source == _renderedSource || _reduceMotion || _landscape) {
        if (source == _renderedSource &&
            identical(sourceAlbums, previousCatalog)) {
          return;
        }
        if (sourceAlbums == null) _warmMockImages();
        _playback.bind(_sources.provider, sourceAlbums);
        setState(() {
          _catalog = target;
          _renderedSource = source;
          _albumLayout.clear();
        });
        return;
      }

      final oldAlbums = _catalog ?? await _mockCatalogFor(_renderedSource);
      if (!mounted) return;
      _catalog ??= oldAlbums;
      if (oldAlbums.isEmpty && target.isEmpty) {
        _playback.bind(_sources.provider, sourceAlbums);
        setState(() {
          _catalog = target;
          _renderedSource = source;
          _albumLayout.clear();
        });
        return;
      }
      setState(() => _sourcePreparing = true);
      _syncMotion();
      final viewportSize = _portraitSize ?? MediaQuery.sizeOf(context);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final snapshot = AlbumGridSnapshot.capture(
        viewportSize,
        _transform.value,
      );
      await _precacheVisibleAlbums(target, snapshot.cells);
      if (!mounted) return;
      final exit = SourceTileMotion.exit(
        oldAlbums.isEmpty ? const [] : snapshot.cells,
        viewportSize,
      );
      final enter = SourceTileMotion.enter(
        target.isEmpty ? const [] : snapshot.cells,
      );
      if (exit.tiles.isEmpty && enter.tiles.isEmpty) {
        _playback.bind(_sources.provider, sourceAlbums);
        setState(() {
          _catalog = target;
          _renderedSource = source;
          _sourcePreparing = false;
          _albumLayout.clear();
        });
        return;
      }
      _exitMotions = exit.tiles;
      _enterMotions = enter.tiles;
      _exitDurationMs = exit.durationMs;
      _sourceDurationMs = exit.durationMs + sourceHandoffMs + enter.durationMs;
      _sourceDurationMs = _sourceDurationMs.ceilToDouble();
      _transitionTargetAlbums = target;
      _sourceTransitionCompleter = Completer<void>();
      _sourceTimeline.duration = Duration(
        milliseconds: _sourceDurationMs.ceil(),
      );
      setState(() => _sourcePhase = _SourceTransitionPhase.exit);
      _syncMotion();
      _sourceTimeline.forward(from: 0);
      await _sourceTransitionCompleter!.future;
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'music source transition',
        ),
      );
    } finally {
      if (mounted) {
        if (_sourcePhase == null && _sourcePreparing) {
          setState(() => _sourcePreparing = false);
          _syncMotion();
        }
        _sourceSwitching.value = false;
      }
    }
  }

  Future<void> _precacheVisibleAlbums(
    List<Map<String, dynamic>> albums,
    List<({int row, int column, Rect rect})> cells,
  ) async {
    final prepared = <String>{};
    for (final cell in cells) {
      if (albums.isEmpty) return;
      final album =
          albums[gridAlbumIndex(cell.row, cell.column, albums.length)];
      final asset = album['asset'] as String;
      if (!prepared.add(asset) || asset.startsWith('local:')) continue;
      ImageProvider? image;
      if (asset.startsWith('directory:')) {
        final library = _sources.directories;
        final id = Uri.decodeComponent(asset.substring('directory:'.length));
        final track = library?.track(id);
        if (library != null && track != null) {
          try {
            final uri = await library.artwork(track);
            if (uri != null) image = FileImage(File.fromUri(Uri.parse(uri)));
          } catch (_) {
            // The existing DirectoryArtwork widget will show its placeholder.
          }
        }
      } else {
        image = AssetImage(asset);
      }
      if (!mounted) return;
      if (image != null) {
        await precacheImage(
          image,
          context,
          size: const Size(albumGridExtent, albumGridExtent),
          onError: (error, stackTrace) {},
        );
      }
    }
  }

  void _advanceSourceTransition() {
    final phase = _sourcePhase;
    if (!mounted || phase == null) return;
    final elapsed = _sourceTimeline.value * _sourceDurationMs;
    if (phase == _SourceTransitionPhase.exit && elapsed >= _exitDurationMs) {
      setState(() => _sourcePhase = _SourceTransitionPhase.handoff);
    }
    if (_sourcePhase == _SourceTransitionPhase.handoff &&
        elapsed >= _exitDurationMs + sourceHandoffMs) {
      final target = _transitionTargetAlbums!;
      _catalog = target;
      _renderedSource = _currentSource;
      _playback.bind(_sources.provider, _sources.catalog.value);
      _albumLayout.clear();
      setState(() => _sourcePhase = _SourceTransitionPhase.enter);
    }
  }

  void _finishSourceTransition() {
    final done = _sourceTransitionCompleter;
    _sourceTransitionCompleter = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  Widget _animateSourceTile(int row, int column, Widget child) {
    final phase = _sourcePhase;
    if (phase == null) return child;
    final motion = phase == _SourceTransitionPhase.enter
        ? _enterMotions[(row, column)]
        : _exitMotions[(row, column)];
    if (motion == null) return child;
    return AnimatedBuilder(
      animation: _sourceTimeline,
      child: child,
      builder: (context, child) {
        final scale = _transform.value.getColumn(0).length;
        final viewport = _portraitSize ?? MediaQuery.sizeOf(context);
        final elapsed = _sourceTimeline.value * _sourceDurationMs;
        final value = phase == _SourceTransitionPhase.enter
            ? motion.enterTransform(
                elapsedMs: elapsed - _exitDurationMs - sourceHandoffMs,
                viewport: viewport,
                scale: scale,
                tileSize: albumGridExtent,
              )
            : motion.exitTransform(
                elapsedMs: elapsed,
                viewport: viewport,
                scale: scale,
                tileSize: albumGridExtent,
              );
        return Transform(
          alignment: Alignment.center,
          transform: value.transform,
          child: Opacity(opacity: value.alpha, child: child),
        );
      },
    );
  }

  void _syncMotion() {
    final animating = _layout.isAnimating;
    unawaited(_haptics.setActive(_landscape && !animating));
    if (_landscape ||
        _reduceMotion ||
        animating ||
        _sourcePreparing ||
        _sourcePhase != null) {
      _ticker.stop();
      _drift.lastTick = null;
    } else if (!_ticker.isActive) {
      _drift.lastTick = null;
      _ticker.start();
    }
  }

  final _transform = TransformationController();
  late final Ticker _ticker;
  final _drift = CanvasDrift();
  late final _interaction = CanvasInteractionState(_drift);
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
    _sourceTimeline = AnimationController(vsync: this)
      ..addListener(_advanceSourceTransition)
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed || !mounted) return;
        setState(() {
          _sourcePhase = null;
          _transitionTargetAlbums = null;
          _exitMotions = const {};
          _enterMotions = const {};
          _sourcePreparing = false;
        });
        _syncMotion();
        _finishSourceTransition();
      });
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
    final initialCatalog = _sources.catalog.value;
    _renderedSource = _currentSource;
    _catalog = initialCatalog == null
        ? null
        : mapProviderAlbums(initialCatalog);
    _playback.bind(_sources.provider, initialCatalog);
    List<ProviderAlbum>? lastCatalog = initialCatalog;
    _stopSourceListener = _sources.catalog.subscribe((albums) {
      if (!mounted || identical(albums, lastCatalog)) return;
      lastCatalog = albums;
      if (_sourceSwitching.value) return;
      unawaited(_applyCatalog(albums));
    });
    if (initialCatalog == null) _warmMockImages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_haptics.prepare());
    });
  }

  void _warmMockImages() {
    // Let first-frame work and restored source selection finish before offscreen decoding.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 300), () async {
        if (!mounted || _sources.catalog.value != null) return;
        final cache = _sources.mock2Selected.value
            ? _mock2AlbumCache
            : widget.albumCache;
        await cache.warmImages((image) async {
          if (mounted) await precacheImage(image, context);
        });
      }).catchError((Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stack),
        );
      }),
    );
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
      _interaction.resetForLayoutChange();
      if (landscape && !reversing) {
        _albumLayout.prepareExpansion(_catalog, _portraitSize, _transform.value);
      }
      if (!landscape && !reversing) {
        _albumLayout.prepareCollapse(
          _catalog,
          MediaQuery.sizeOf(context),
          _transform.value,
          playingAsset: _playback.asset,
          playingTitle: _playback.title,
        );
      }
      if (_reduceMotion || _albumLayout.snapshot == null) {
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

  void _advance(Duration elapsed) => _drift.advance(
    elapsed,
    _transform,
    enabled: !_interaction.touching &&
        _interaction.pressedPointers.isEmpty &&
        !_interaction.selectionPaused &&
        !_sourcePreparing &&
        _sourcePhase == null &&
        !_reduceMotion &&
        !_landscape,
  );

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
    _sourceTransitionCompleter?.complete();
    _sourceTimeline.dispose();
    _sourceSwitching.dispose();
    _ticker.dispose();
    _transform.dispose();
    super.dispose();
  }

  late final Future<List<Map<String, dynamic>>> _mockAlbums = widget.albumCache
      .load();
  late final _mock2AlbumCache = MockAlbumCache(
    catalogAsset: 'assets/albums/catalog_mock2.json',
  );
  late final Future<List<Map<String, dynamic>>> _mock2Albums = _mock2AlbumCache
      .load();

  Future<List<Map<String, dynamic>>> _mockCatalogFor(_HomeMusicSource source) =>
      source == _HomeMusicSource.mock2 ? _mock2Albums : _mockAlbums;

  @override
  Widget build(BuildContext context) {
    return HomeSheet(
      enabled: !_landscape,
      sources: _sources,
      sourceSwitching: _sourceSwitching,
      onSourceSelection: _selectMusicSource,
      xeroxEnabled: _xeroxEnabled,
      onXeroxChanged: (enabled) => setState(() => _xeroxEnabled = enabled),
      child: Scaffold(
        backgroundColor: const Color(0xff000000),
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

  Widget _buildAlbums() {
    final target = _sourcePhase == _SourceTransitionPhase.enter
        ? _transitionTargetAlbums
        : null;
    final albums = target ?? _catalog;
    if (albums != null) return _buildAlbumContent(albums);
    final future = _mockCatalogFor(_currentSource);
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ObjectKey(future),
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load album covers.'));
        }
        final loaded = snapshot.data;
        if (loaded == null) {
          return const Center(child: CircularProgressIndicator());
        }
        _catalog = loaded;
        return _buildAlbumContent(loaded);
      },
    );
  }

  Widget _buildAlbumContent(List<Map<String, dynamic>> albums) {
    if (albums.isEmpty) {
      if (_sourcePhase == _SourceTransitionPhase.handoff) {
        return const SizedBox.expand();
      }
      return Center(
        child: Text(
          AppLocalizations.of(context).musicSourceEmpty,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    if (_layout.isAnimating && _albumLayout.snapshot != null) {
      return AlbumLayoutTransition(
        albums: _albumLayout.flowAlbums ?? albums,
        snapshot: _albumLayout.snapshot!,
        position: _albumLayout.flowPosition,
        tilt: _albumLayout.flowTilt,
        gridOffset: _albumLayout.gridOffset,
        progress: _layoutProgress,
        xerox: _xeroxEnabled,
      );
    }
    if (_landscape) {
      return AlbumCoverFlow(
        albums: _albumLayout.flowAlbums ?? albums,
        haptics: _haptics,
        playback: _playback,
        xerox: _xeroxEnabled,
        initialPosition: _albumLayout.flowPosition,
        initialTilt: _albumLayout.flowTilt,
        onMotionChanged: (position, tilt) {
          _albumLayout.flowPosition = position;
          _albumLayout.flowTilt = tilt;
        },
      );
    }
    return AlbumCanvasViewport(
      albums: albums,
      layout: _albumLayout,
      transform: _transform,
      interaction: _interaction,
      playback: _playback,
      xerox: _xeroxEnabled,
      interactionBlocked: _sourcePreparing || _sourcePhase != null,
      onViewportSizeChanged: (size) => _portraitSize = size,
      onTileSelected: (row, column) => setState(() {
        _albumLayout.selectedAlbum = (row, column);
        _interaction.selectionPaused = true;
      }),
      animateSourceTile: _animateSourceTile,
    );
  }
}
