// 文件职责：页面状态组织与业务流程协调。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../storage/settings/app_language_preference.dart';
import '../../storage/settings/manual_rotation_preference.dart';
import '../../services/album_haptics.dart';
import '../../services/diagnostics/diagnostic_log.dart';
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
import '../../features/artwork/pipeline/artwork_prefetch_scheduler.dart';
import '../../features/artwork/pipeline/artwork_pipeline.dart';
import '../../features/artwork/model/artwork_identity.dart';
import '../../features/artwork/model/artwork_request.dart';
import '../../features/artwork/mode/artwork_mode_controller.dart';
import '../../features/artwork/presentation/custom_artwork_menu.dart';
import '../../features/artwork/presentation/xerox_palette.dart';
import '../../features/artwork/presentation/xerox_palette_picker.dart';
import '../../features/artwork/xerox/xerox_visible_artwork_planner.dart';
import '../../features/artwork/xerox/xerox_raster_cache.dart';
import '../../features/artwork/xerox/xerox_raster_request.dart';
import '../../features/coverflow/album_coverflow.dart';
import '../../features/desktop_shortcuts/desktop_shortcuts.dart';
import '../../features/desktop_wallpaper/desktop_wallpaper.dart';
import '../../features/layout/album_layout_transition.dart';
import '../../features/layout/layout_switch_overlay.dart';
import '../../ui/bottom_sheet/bottom_sheet.dart';
import '../../ui/transitions/source_tile_motion.dart';
import '../../features/music/transition/home_source_transition.dart';
import '../../features/music/playback/album_playback.dart';
import '../../features/music/catalog/album_catalog_mapper.dart';

/// 封装或定义首页音乐来源相关类型与行为，负责页面状态组织与业务流程协调。
enum _HomeMusicSource { mock, mock2, local, directories }

/// 封装或定义首页page相关类型与行为，负责页面状态组织与业务流程协调。
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.albumCache,
    this.sources,
    this.language,
  });

  final MusicSourceController? sources;
  final AppLanguagePreference? language;

  final MockAlbumCache albumCache;

  @override
  State<HomePage> createState() => _HomePageState();
}

/// 封装或定义首页page状态相关类型与行为，负责页面状态组织与业务流程协调。
class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final _haptics = AlbumHaptics();
  final _playback = AlbumPlayback();
  DesktopShortcuts? _desktopShortcuts;
  final _manualRotation = ManualRotationPreference();
  late final VoidCallback _stopManualRotationListener;
  late final _sources = widget.sources ?? MusicSourceController();
  late final VoidCallback _stopSourceListener;
  late final AnimationController _layout;
  late final Animation<double> _layoutProgress;
  late final HomeSourceTransition _sourceTransition;
  late final ArtworkModeController _artworkMode;
  _HomeMusicSource _renderedSource = _HomeMusicSource.mock;
  bool _hasOrientation = false;
  Size? _portraitSize;
  Size? _landscapeFlowViewport;
  final _albumLayout = HomeAlbumLayoutState();
  List<Map<String, dynamic>>? _catalog;

  _HomeMusicSource get _currentSource => _sources.catalog.value == null
      ? _sources.mock2Selected.value
            ? _HomeMusicSource.mock2
            : _HomeMusicSource.mock
      : _sources.directorySelected.value
      ? _HomeMusicSource.directories
      : _HomeMusicSource.local;

  /// 读取并恢复所需数据或资源，用于页面状态组织与业务流程协调。
  Future<List<Map<String, dynamic>>> _readCatalog(
    List<ProviderAlbum>? albums, {
    _HomeMusicSource? source,
  }) => albums == null
      ? source == _HomeMusicSource.mock2 ||
                (source == null && _sources.mock2Selected.value)
            ? _mock2Albums
            : _mockAlbums
      : Future.value(mapProviderAlbums(albums));

  /// 应用选择并更新对应状态，用于页面状态组织与业务流程协调。
  Future<void> _applyCatalog(List<ProviderAlbum>? sourceAlbums) async {
    final albums = await _readCatalog(sourceAlbums);
    if (!mounted ||
        _sourceTransition.switching.value ||
        _artworkMode.preparing ||
        _artworkMode.isTransitioning) {
      return;
    }
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
        _artworkMode.isTransitioning) {
      return;
    }
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
          ),
        );
      } else {
        await _warmOriginalArtwork(
          albums: target,
          cells: snapshot.cells,
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
      diagnosticLog.record(
        DiagnosticEvent.musicSourceTransitionFailed,
        error: error,
      );
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

  /// 协调动画进度与状态过渡，用于页面状态组织与业务流程协调。
  Widget _animateSourceTile(int row, int column, Widget child) =>
      _sourceTransition.animateTile(
        row,
        column,
        child,
        scale: () => _transform.value.getColumn(0).length,
        viewport: (context) => _portraitSize ?? MediaQuery.sizeOf(context),
        tileSize: albumGridExtent,
      );

  /// 协调动画进度与状态过渡，用于页面状态组织与业务流程协调。
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
      tileSize: albumGridExtent,
    );
  }

  /// 将视口中的专辑映射为通用 ArtworkRequest，再交给资源层预热。
  Future<void> _warmOriginalArtwork({
    required List<Map<String, dynamic>> albums,
    required List<({int row, int column, Rect rect})> cells,
    required bool Function() isActive,
  }) async {
    if (albums.isEmpty || cells.isEmpty) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final requests = <ArtworkRequest>[];
    for (final cell in cells) {
      final album =
          albums[gridAlbumIndex(cell.row, cell.column, albums.length)];
      final source = album['asset'] as String;
      final rawIdentity = album['id'] as String?;
      final rawVersion = album['artworkVersion'] as String?;
      requests.add(
        ArtworkRequest(
          source: source,
          identity: rawIdentity == null ? null : ArtworkIdentity(rawIdentity),
          version: rawVersion == null ? null : ArtworkVersion(rawVersion),
          targetSize: const Size.square(albumGridExtent),
          fixedResolution: albumCanvasArtworkResolution,
          devicePixelRatio: dpr,
          fit: BoxFit.cover,
        ),
      );
    }
    await const ArtworkPrefetchScheduler().warm(
      requests: requests,
      directory: _sources.directories,
      context: context,
      isActive: isActive,
    );
  }

  /// 创建并组装所需对象或界面结构，用于页面状态组织与业务流程协调。
  Future<List<XeroxRasterRequest>> _buildXeroxRequests(
    List<Map<String, dynamic>> albums,
    List<({int row, int column, Rect rect})> cells, {
    required bool useLayout,
    bool includeSelected = false,
    bool Function()? isActive,
  }) async {
    if (albums.isEmpty) return const [];
    String? selectedAsset;
    ArtworkIdentity? selectedIdentity;
    ArtworkVersion? selectedVersion;
    if (includeSelected) {
      final selected = _albumLayout.selectedAlbum;
      if (selected != null) {
        final selectedAlbum = _albumLayout.albumAt(
          selected.$1,
          selected.$2,
          albums,
        );
        selectedAsset = selectedAlbum['asset'] as String;
        final rawIdentity = selectedAlbum['id'] as String?;
        selectedIdentity = rawIdentity == null
            ? null
            : ArtworkIdentity(rawIdentity);
        final rawVersion = selectedAlbum['artworkVersion'] as String?;
        selectedVersion = rawVersion == null
            ? null
            : ArtworkVersion(rawVersion);
      }
    }

    return const XeroxVisibleArtworkPlanner().build(
      cells: cells,
      viewport: _portraitSize ?? MediaQuery.sizeOf(context),
      scale: _transform.value.getColumn(0).length,
      tileExtent: albumGridExtent,
      fixedResolution: albumCanvasArtworkResolution,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      assetAt: (row, column) {
        final album = useLayout
            ? _albumLayout.albumAt(row, column, albums)
            : albums[gridAlbumIndex(row, column, albums.length)];
        return album['asset'] as String;
      },
      identityAt: (row, column) {
        final album = useLayout
            ? _albumLayout.albumAt(row, column, albums)
            : albums[gridAlbumIndex(row, column, albums.length)];
        final rawIdentity = album['id'] as String?;
        return rawIdentity == null ? null : ArtworkIdentity(rawIdentity);
      },
      versionAt: (row, column) {
        final album = useLayout
            ? _albumLayout.albumAt(row, column, albums)
            : albums[gridAlbumIndex(row, column, albums.length)];
        final rawVersion = album['artworkVersion'] as String?;
        return rawVersion == null ? null : ArtworkVersion(rawVersion);
      },
      resolveArtwork: (request) => ArtworkPipeline.instance.resolve(
        request,
        directories: _sources.directories,
      ),
      selectedAsset: selectedAsset,
      selectedIdentity: selectedIdentity,
      selectedVersion: selectedVersion,
      isActive: isActive,
    );
  }

  bool get _artworkChangeBlocked =>
      _artworkMode.preparing ||
      _artworkMode.isTransitioning ||
      _sourceTransition.switching.value ||
      _sourceTransition.phase != null ||
      _layout.isAnimating ||
      _landscape;

  Future<void> _setXeroxPalette(XeroxPalette palette) async {
    if (_artworkChangeBlocked || palette == _artworkMode.palette.value) return;
    final viewport = _portraitSize ?? MediaQuery.sizeOf(context);
    final visibleCells = _catalog?.isNotEmpty == true
        ? AlbumGridSnapshot.capture(viewport, _transform.value).cells
        : const <({int row, int column, Rect rect})>[];
    await _artworkMode.applyPalette(
      selection: palette,
      visibleCells: visibleCells,
      viewport: viewport,
      reduceMotion: _reduceMotion,
    );
  }

  Future<void> _setXeroxMode(bool enabled) async {
    if (enabled == _artworkMode.enabled || _artworkChangeBlocked) {
      return;
    }

    _artworkMode.beginPreparation();
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      // 用户第一次点击 Xerox 时，内置演示专辑目录可能尚未
      // 通过 FutureBuilder 发布加载结果；因此需要先解析目录，再捕获
      // 当前视口，确保过渡流程能为真正可见的封面准备资源。
      final albums = _catalog ?? await _mockCatalogFor(_currentSource);
      if (!mounted) return;
      _catalog ??= albums;
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
      if (mounted && _artworkMode.enabled == enabled) {
        diagnosticLog.record(
          enabled
              ? DiagnosticEvent.xeroxEnabled
              : DiagnosticEvent.xeroxDisabled,
        );
      }
    } catch (error, stack) {
      diagnosticLog.record(DiagnosticEvent.xeroxTransitionFailed, error: error);
      if (_artworkMode.preparing) _artworkMode.cancelPreparation();
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'Xerox mode transition',
        ),
      );
    } finally {
      if (mounted && _artworkMode.preparing && !_artworkMode.isTransitioning) {
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
  bool _desktopWallpaperEnabled = false;
  PageRoute<void>? _keyboardShortcutsRoute;
  Locale? _desktopWallpaperMenuLocale;
  bool _landscape = false;
  bool _lastAutomaticLandscape = false;
  bool? _manualLayout;
  bool? _pendingLandscape;

  bool get _automaticLandscape =>
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) &&
      MediaQuery.orientationOf(context) == Orientation.landscape;

  @override
  void initState() {
    super.initState();
    if (DesktopShortcuts.isAvailable) {
      _desktopShortcuts = DesktopShortcuts(_playback);
    }
    DesktopWallpaper.setHandlers(
      onPrepare: _prepareDesktopWallpaper,
      onRestore: _restoreDesktopWallpaperControls,
    );
    _ticker = createTicker(_advance);
    _layout = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _layoutProgress = _layout.drive(CurveTween(curve: Curves.easeInOutCubic));
    _artworkMode = ArtworkModeController(
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
    _stopManualRotationListener = _manualRotation.enabled.subscribe((enabled) {
      if (enabled || _manualLayout == null) return;
      setState(() {
        _manualLayout = null;
        _updateLayout(_automaticLandscape);
      });
    });
    unawaited(_manualRotation.restore());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_haptics.prepare());
    });
  }

  void _trackKeyboardShortcutsRoute(PageRoute<void> route) {
    _keyboardShortcutsRoute = route;
    unawaited(
      route.completed.whenComplete(() {
        if (identical(_keyboardShortcutsRoute, route)) {
          _keyboardShortcutsRoute = null;
        }
      }),
    );
  }

  Future<bool> _prepareDesktopWallpaper() async {
    if (_desktopWallpaperEnabled) return false;
    if (_keyboardShortcutsRoute case final route? when route.isCurrent) {
      if (!SchedulerBinding.instance.framesEnabled) return false;
      route.navigator!.pop();
      await route.completed;
      if (!mounted) return false;
      await BottomSheetScope.maybeOf(context)?.dismissAll();
      if (!mounted) return false;
    }
    if (ModalRoute.isCurrentOf(context) == false ||
        BottomSheetScope.maybeOf(context)?.sheetStore.snapshot.isPresented ==
            true) {
      return false;
    }
    setState(() {
      _desktopWallpaperEnabled = true;
      _albumLayout.selectedAlbum = null;
      _interaction.resetForLayoutChange();
    });
    if (SchedulerBinding.instance.framesEnabled) {
      await SchedulerBinding.instance.endOfFrame;
    }
    return mounted;
  }

  void _restoreDesktopWallpaperControls() =>
      setState(() => _desktopWallpaperEnabled = false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (DesktopWallpaper.isAvailable) {
      final locale = Localizations.localeOf(context);
      if (_desktopWallpaperMenuLocale != locale) {
        _desktopWallpaperMenuLocale = locale;
        final l10n = AppLocalizations.of(context);
        unawaited(
          DesktopWallpaper.setMenuTitles(
            setWallpaper: l10n.desktopWallpaperSet,
            restoreWindow: l10n.desktopWallpaperRestore,
            quit: l10n.desktopShortcutsQuit,
          ),
        );
      }
    }
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final automaticLandscape = _automaticLandscape;
    if (automaticLandscape) {
      final viewport = MediaQuery.paddingOf(context)
          .deflateSize(MediaQuery.sizeOf(context));
      // Keep the landscape strip in place if an artwork effect delays rotation.
      if (!viewport.isEmpty) _landscapeFlowViewport = viewport;
    }
    if (automaticLandscape != _lastAutomaticLandscape) {
      _lastAutomaticLandscape = automaticLandscape;
      _manualLayout = null;
    }
    _updateLayout(_manualLayout ?? automaticLandscape);
  }

  /// 更新相关状态并同步依赖方，用于页面状态组织与业务流程协调。
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
      diagnosticLog.record(
        landscape
            ? DiagnosticEvent.coverFlowShown
            : DiagnosticEvent.canvasShown,
      );
      _interaction.resetForLayoutChange();
      if (landscape && !reversing) {
        _albumLayout.prepareExpansion(
          _catalog,
          _portraitSize,
          _transform.value,
        );
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

  /// 执行当前模块中的advance操作，用于页面状态组织与业务流程协调。
  void _advance(Duration elapsed) => _drift.advance(
    elapsed,
    _transform,
    enabled:
        !_interaction.touching &&
        _interaction.pressedPointers.isEmpty &&
        !_interaction.selectionPaused &&
        !customArtworkMenuVisible.value &&
        !_sourceTransition.preparing &&
        _sourceTransition.phase == null &&
        !_artworkMode.preparing &&
        _artworkMode.phase == null &&
        !_reduceMotion &&
        !_landscape,
  );

  @override
  void dispose() {
    unawaited(_desktopShortcuts?.dispose());
    DesktopWallpaper.clearHandlers();
    unawaited(_haptics.dispose());
    _stopSourceListener();
    _stopManualRotationListener();
    _manualRotation.dispose();
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
    final platform = defaultTargetPlatform;
    final canvas = Scaffold(
      backgroundColor: const Color(0xff000000),
      body: XeroxPaletteScope(
        notifier: _artworkMode.palette,
        child: Builder(
          builder: (context) {
            final content = _buildAlbums();
            if (kIsWeb || platform != TargetPlatform.android) return content;
            // Android samples the outermost pixels for its rotation backdrop.
            return DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.black,
                  width: 4 / MediaQuery.devicePixelRatioOf(context),
                ),
              ),
              child: content,
            );
          },
        ),
      ),
    );
    Widget homeSheet(({Widget button, bool visible})? layoutSwitch) =>
        HomeSheet(
          enabled:
              !_desktopWallpaperEnabled &&
              !_landscape &&
              !_lastAutomaticLandscape,
          playbackReady: _landscapeFlowViewport == null || !_layout.isAnimating,
          sources: _sources,
          playback: _playback,
          desktopShortcuts: _desktopShortcuts,
          onKeyboardShortcutsOpened: _trackKeyboardShortcutsRoute,
          layoutSwitch: layoutSwitch,
          sourceSwitching: _sourceTransition.switching,
          onSourceSelection: _selectMusicSource,
          language: widget.language,
          manualRotation: _manualRotation,
          xeroxEnabled: _artworkMode.enabledListenable,
          onXeroxChanged: _setXeroxMode,
          xeroxPalettePicker: XeroxPalettePicker(
            selection: _artworkMode.palette,
            onChanged: _setXeroxPalette,
          ),
          child: canvas,
        );
    return SignalBuilder(
      builder: (context) => LayoutSwitchOverlay(
        enabled: !_desktopWallpaperEnabled && _manualRotation.enabled.value,
        coverFlow: _landscape,
        screenLandscape: _lastAutomaticLandscape,
        onSwitch: () {
          if (_lastAutomaticLandscape ||
              _catalog == null ||
              _catalog!.isEmpty) {
            return;
          }
          setState(() {
            _landscapeFlowViewport = null;
            _manualLayout = !_landscape;
            _updateLayout(_manualLayout!);
          });
        },
        builder: (button, visible) => homeSheet(
          button == null ? null : (button: button, visible: visible),
        ),
      ),
    );
  }

  /// 创建并组装所需对象或界面结构，用于页面状态组织与业务流程协调。
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
          return Center(
            child: Text(AppLocalizations.of(context).albumCoversLoadFailed),
          );
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

  /// 创建并组装所需对象或界面结构，用于页面状态组织与业务流程协调。
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
    final retainedLandscapeViewport = _lastAutomaticLandscape
        ? null
        : _landscapeFlowViewport;
    if (_layout.isAnimating && _albumLayout.snapshot != null) {
      return AlbumLayoutTransition(
        albums: _albumLayout.flowAlbums ?? albums,
        snapshot: _albumLayout.snapshot!,
        position: _albumLayout.flowPosition,
        tilt: _albumLayout.flowTilt,
        gridOffset: _albumLayout.gridOffset,
        progress: _layoutProgress,
        retainLandscapeAlignment: retainedLandscapeViewport != null,
        xerox: _artworkMode.enabled,
      );
    }
    if (_landscape) {
      return ValueListenableBuilder(
        valueListenable: customArtworkMenuVisible,
        builder: (_, menuVisible, flow) =>
            TickerMode(enabled: !menuVisible, child: flow!),
        child: AlbumCoverFlow(
          albums: _albumLayout.flowAlbums ?? albums,
          haptics: _haptics,
          playback: _playback,
          xerox: _artworkMode.enabled,
          initialPosition: _albumLayout.flowPosition,
          initialTilt: _albumLayout.flowTilt,
          retainedLandscapeViewport: retainedLandscapeViewport,
          onMotionChanged: (position, tilt) {
            _albumLayout.flowPosition = position;
            _albumLayout.flowTilt = tilt;
          },
        ),
      );
    }
    return AlbumCanvasViewport(
      albums: albums,
      layout: _albumLayout,
      transform: _transform,
      interaction: _interaction,
      playback: _playback,
      xerox: _artworkMode.enabled,
      interactionBlocked:
          _sourceTransition.preparing ||
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
