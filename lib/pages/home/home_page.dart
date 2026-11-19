import 'dart:async';

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
import '../../features/canvas/portrait_tilt.dart';
import '../../features/artwork/visible_album_preloader.dart';
import '../../features/artwork/artwork_image_provider.dart';
import '../../features/artwork/xerox/home_artwork_mode_controller.dart';
import '../../features/artwork/xerox/xerox_visible_artwork_planner.dart';
import '../../features/artwork/xerox/xerox_raster_cache.dart';
import '../../features/artwork/xerox/xerox_raster_request.dart';
import '../../features/cover_flow/album_cover_flow.dart';
import '../../features/layout/album_layout_transition.dart';
import '../../features/layout/layout_switch_overlay.dart';
import '../../features/music/transition/music_source_transition.dart';
import '../../features/music/transition/home_source_transition.dart';
import '../../features/music/playback/album_playback.dart';
import '../../features/music/catalog/album_catalog_mapper.dart';

enum _HomeMusicSource { mock, mock2, local, directories }

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.albumCache, this.sources});

  final MusicSourceController? sources;

  final MockAlbumCache albumCache;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final _haptics = AlbumHaptics();
  final _mockWarmupTimers = <Timer>{};
  final _playback = AlbumPlayback();
  late final _sources = widget.sources ?? MusicSourceController();
  late final VoidCallback _stopSourceListener;
  late final AnimationController _layout;
  late final Animation<double> _layoutProgress;
  late final HomeSourceTransition _sourceTransition;
  late final HomeArtworkModeController _artworkMode;
  _HomeMusicSource _renderedSource = _HomeMusicSource.mock;
  bool _hasOrientation = false;
  Size? _portraitSize;
  final _albumLayout = HomeAlbumLayoutState();
  List<Map<String, dynamic>>? _catalog;

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
    if (!mounted ||
        _sourceTransition.switching.value ||
        _artworkMode.preparing ||
        _artworkMode.isTransitioning) return;
    if (sourceAlbums == null) _warmMockImages();
    _playback.bind(_sources.provider, sourceAlbums);
    setState(() {
      _catalog = albums;
      _renderedSource = _currentSource;
      _albumLayout.clear();
    });
  }

  Future<void> _selectMusicSource(Future<void> Function() select) async {
    if (_sourceTransition.switching.value ||
        _sourceTransition.phase != null ||
        _artworkMode.preparing ||
        _artworkMode.isTransitioning) return;
    final sourceXeroxLeases = <XeroxRasterLease>[];
    final previousCatalog = _sources.catalog.value;
    _sourceTransition.switching.value = true;
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
      setState(() => _sourceTransition.preparing = true);
      _syncMotion();
      final viewportSize = _portraitSize ?? MediaQuery.sizeOf(context);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final snapshot = AlbumGridSnapshot.capture(
        viewportSize,
        _transform.value,
      );
      if (_artworkMode.enabled) {
        final scale = _transform.value.getColumn(0).length;
        final preparationSnapshot = AlbumGridSnapshot.capture(
          viewportSize,
          _transform.value,
          overscan:
              PortraitTilt.overscan(viewportSize) + albumGridExtent * scale,
        );
        final requests = await _buildXeroxRequests(
          target,
          preparationSnapshot.cells,
          useLayout: false,
          isActive: () => mounted,
        );
        sourceXeroxLeases.addAll(
          await _artworkMode.scheduler.prepare(
            requests,
            isActive: () => mounted,
            allowFailures: true,
          ),
        );
      } else {
        await const VisibleAlbumPreloader().warm(
          albums: target,
          cells: snapshot.cells,
          directory: _sources.directories,
          context: context,
          isActive: () => mounted,
        );
      }
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
          _sourceTransition.preparing = false;
          _albumLayout.clear();
        });
        return;
      }
      await _sourceTransition.start(
        targetAlbums: target,
        exit: exit,
        enter: enter,
      );
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'music source transition',
        ),
      );
    } finally {
      for (final lease in sourceXeroxLeases) {
        lease.release();
      }
      if (mounted) {
        if (_sourceTransition.phase == null && _sourceTransition.preparing) {
          setState(() => _sourceTransition.preparing = false);
          _syncMotion();
        }
        _sourceTransition.switching.value = false;
      }
    }
  }

  Widget _animateSourceTile(int row, int column, Widget child) =>
      _sourceTransition.animateTile(
        row,
        column,
        child,
        scale: () => _transform.value.getColumn(0).length,
        viewport: (context) => _portraitSize ?? MediaQuery.sizeOf(context),
      );

  Widget _animateCanvasTile(int row, int column, Widget child) {
    if (_sourceTransition.phase != null) {
      return _animateSourceTile(row, column, child);
    }
    return _artworkMode.animateTile(
      row,
      column,
      child,
      scale: () => _transform.value.getColumn(0).length,
      viewport: (context) => _portraitSize ?? MediaQuery.sizeOf(context),
    );
  }

  Future<List<XeroxRasterRequest>> _buildXeroxRequests(
    List<Map<String, dynamic>> albums,
    List<({int row, int column, Rect rect})> cells, {
    required bool useLayout,
    bool includeSelected = false,
    bool Function()? isActive,
  }) async {
    if (albums.isEmpty) return const [];
    String? selectedAsset;
    if (includeSelected) {
      final selected = _albumLayout.selectedAlbum;
      if (selected != null) {
        selectedAsset = _albumLayout.albumAt(
          selected.$1,
          selected.$2,
          albums,
        )['asset'] as String;
      }
    }

    return const XeroxVisibleArtworkPlanner().build(
      cells: cells,
      viewport: _portraitSize ?? MediaQuery.sizeOf(context),
      scale: _transform.value.getColumn(0).length,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      assetAt: (row, column) {
        final album = useLayout
            ? _albumLayout.albumAt(row, column, albums)
            : albums[gridAlbumIndex(row, column, albums.length)];
        return album['asset'] as String;
      },
      resolveImageProvider: (asset) => resolveArtworkImageProvider(
        asset,
        directories: _sources.directories,
      ),
      selectedAsset: selectedAsset,
      isActive: isActive,
    );
  }

  Future<void> _setXeroxMode(bool enabled) async {
    if (enabled == _artworkMode.enabled ||
        _artworkMode.preparing ||
        _artworkMode.isTransitioning ||
        _sourceTransition.switching.value ||
        _sourceTransition.phase != null ||
        _layout.isAnimating ||
        _landscape) {
      return;
    }

    _artworkMode.beginPreparation();
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      final albums = _catalog ?? const <Map<String, dynamic>>[];
      final viewport = _portraitSize ?? MediaQuery.sizeOf(context);
      final scale = _transform.value.getColumn(0).length;
      final visibleSnapshot = AlbumGridSnapshot.capture(
        viewport,
        _transform.value,
      );
      final preparationSnapshot = AlbumGridSnapshot.capture(
        viewport,
        _transform.value,
        overscan: PortraitTilt.overscan(viewport) + albumGridExtent * scale,
      );
      final requests = await _buildXeroxRequests(
        albums,
        preparationSnapshot.cells,
        useLayout: true,
        includeSelected: true,
        isActive: () => mounted,
      );
      if (!mounted) return;

      await _artworkMode.apply(
        enabled: enabled,
        requests: requests,
        visibleCells: albums.isEmpty ? const [] : visibleSnapshot.cells,
        viewport: viewport,
        reduceMotion: _reduceMotion,
        context: context,
      );
    } catch (error, stack) {
      if (_artworkMode.preparing) _artworkMode.cancelPreparation();
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'Xerox mode transition',
        ),
      );
    } finally {
      if (mounted &&
          _artworkMode.preparing &&
          !_artworkMode.isTransitioning) {
        _artworkMode.cancelPreparation();
      }
    }
  }

  void _syncMotion() {
    final pendingLandscape = _pendingLandscape;
    if (!_artworkMode.preparing &&
        !_artworkMode.isTransitioning &&
        pendingLandscape != null) {
      _pendingLandscape = null;
      if (pendingLandscape != _landscape) {
        _updateLayout(pendingLandscape);
        return;
      }
    }
    final animating = _layout.isAnimating;
    unawaited(_haptics.setActive(_landscape && !animating));
    if (_landscape ||
        _reduceMotion ||
        animating ||
        _sourceTransition.preparing ||
        _sourceTransition.phase != null ||
        _artworkMode.preparing ||
        _artworkMode.phase != null) {
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
  bool? _pendingLandscape;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_advance);
    _layout = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _layoutProgress = _layout.drive(CurveTween(curve: Curves.easeInOutCubic));
    _artworkMode = HomeArtworkModeController(
      vsync: this,
      isMounted: () => mounted,
      notifyChanged: () => setState(() {}),
      onMotionChanged: _syncMotion,
    );
    _sourceTransition = HomeSourceTransition(
      vsync: this,
      isMounted: () => mounted,
      notifyChanged: () => setState(() {}),
      onHandoff: (target) {
        _catalog = target;
        _renderedSource = _currentSource;
        _playback.bind(_sources.provider, _sources.catalog.value);
        _albumLayout.clear();
      },
      onMotionChanged: _syncMotion,
    );
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
      if (_sourceTransition.switching.value) return;
      unawaited(_applyCatalog(albums));
    });
    if (initialCatalog == null) _warmMockImages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_haptics.prepare());
    });
  }

  void _warmMockImages() {
    // Defer offscreen decoding until after first-frame and source restoration.
    // Cancel pending warmups when the page is removed from the widget tree.
    late final Timer timer;
    timer = Timer(const Duration(milliseconds: 300), () {
      _mockWarmupTimers.remove(timer);
      if (!mounted || _sources.catalog.value != null) return;
      final cache = _sources.mock2Selected.value
          ? _mock2AlbumCache
          : widget.albumCache;
      unawaited(
        cache.warmImages((image) async {
          if (mounted) await precacheImage(image, context);
        }).catchError((Object error, StackTrace stack) {
          FlutterError.reportError(
            FlutterErrorDetails(exception: error, stack: stack),
          );
        }),
      );
    });
    _mockWarmupTimers.add(timer);
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
    if (_hasOrientation &&
        (_artworkMode.preparing || _artworkMode.isTransitioning)) {
      _pendingLandscape = landscape;
      return;
    }
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
        !_sourceTransition.preparing &&
        _sourceTransition.phase == null &&
        !_artworkMode.preparing &&
        _artworkMode.phase == null &&
        !_reduceMotion &&
        !_landscape,
  );

  @override
  void dispose() {
    for (final timer in _mockWarmupTimers) {
      timer.cancel();
    }
    _mockWarmupTimers.clear();
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
    _sourceTransition.dispose();
    _artworkMode.dispose();
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
      sourceSwitching: _sourceTransition.switching,
      onSourceSelection: _selectMusicSource,
      xeroxEnabled: _artworkMode.enabled,
      onXeroxChanged: _setXeroxMode,
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
    final target = _sourceTransition.phase == SourceTransitionPhase.enter
        ? _sourceTransition.targetAlbums
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
      if (_sourceTransition.phase == SourceTransitionPhase.handoff) {
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
        xerox: _artworkMode.enabled,
      );
    }
    if (_landscape) {
      return AlbumCoverFlow(
        albums: _albumLayout.flowAlbums ?? albums,
        haptics: _haptics,
        playback: _playback,
        xerox: _artworkMode.enabled,
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
      xerox: _artworkMode.enabled,
      interactionBlocked: _sourceTransition.preparing ||
          _sourceTransition.phase != null ||
          _artworkMode.preparing ||
          _artworkMode.phase != null,
      onViewportSizeChanged: (size) => _portraitSize = size,
      onTileSelected: (row, column) => setState(() {
        _albumLayout.selectedAlbum = (row, column);
        _interaction.selectionPaused = true;
      }),
      animateSourceTile: _animateCanvasTile,
    );
  }
}
