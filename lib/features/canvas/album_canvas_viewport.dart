// 文件职责：专辑墙无限画布的布局、视口与交互状态。

import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, listEquals;
import 'package:material_ui/material_ui.dart';

import '../artwork/artwork_renderer.dart';
import '../artwork/model/artwork_identity.dart';
import '../artwork/model/artwork_request.dart';
import '../artwork/presentation/artwork_placeholder.dart';
import '../artwork/presentation/custom_artwork_menu.dart';
import '../artwork/presentation/custom_artwork_scope.dart';
import '../artwork/presentation/directory_artwork.dart';
import '../music/catalog/album_catalog_mapper.dart';
import '../music/catalog/album_track_list.dart';
import '../music/playback/album_playback.dart';
import 'album_artwork_atlas.dart';
import 'album_canvas.dart';
import 'album_sprite_canvas.dart';
import 'album_cover_popup.dart';
import 'album_grid_snapshot.dart';
import 'canvas_interaction_state.dart';
import 'home_album_layout_state.dart';
import 'portrait_tilt.dart';
import 'selected_album.dart';

/// 封装或定义专辑画布视口相关类型与行为，负责专辑墙无限画布的布局、视口与交互状态。
class AlbumCanvasViewport extends StatefulWidget {
  const AlbumCanvasViewport({
    super.key,
    required this.albums,
    required this.layout,
    required this.transform,
    required this.interaction,
    required this.playback,
    required this.xerox,
    required this.interactionBlocked,
    required this.onViewportSizeChanged,
    required this.onTileSelected,
    required this.animateSourceTile,
    this.onArtworkAccent,
  });

  static bool useWidgetGridForBenchmark = false;

  final List<Map<String, dynamic>> albums;
  final HomeAlbumLayoutState layout;
  final TransformationController transform;
  final CanvasInteractionState interaction;
  final AlbumPlayback playback;
  final bool xerox;
  final bool interactionBlocked;
  final ValueChanged<Size> onViewportSizeChanged;
  final void Function(int row, int column) onTileSelected;
  final Widget Function(int row, int column, Widget child) animateSourceTile;
  final void Function(Map<String, dynamic> album, Color accent)? onArtworkAccent;

  @override
  State<AlbumCanvasViewport> createState() => _AlbumCanvasViewportState();
}

class _AlbumCanvasViewportState extends State<AlbumCanvasViewport>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  (int, int)? _popupCell;
  CanvasArtworkAtlas? _atlas;
  CanvasArtworkAtlas? _readyAtlas;
  List<Object?>? _atlasInput;
  int _atlasGeneration = 0;
  bool _atlasRequested = false;

  final _lifts =
      <Object, ({AnimationController controller, Animation<double> scale})>{};
  Object? _liftedAlbum;

  Object _albumKey(Map<String, dynamic> album) =>
      (album['id'] as String?) ?? (album['asset'], album['title']);

  Object? get _selectedAlbumKey {
    final selected = widget.layout.selectedAlbum;
    if (selected == null || widget.albums.isEmpty) return null;
    return _albumKey(
      widget.layout.albumAt(selected.$1, selected.$2, widget.albums),
    );
  }

  void _syncLift() {
    final album = _selectedAlbumKey;
    final previous = _liftedAlbum;
    _liftedAlbum = album;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      for (final key in _lifts.keys.toList()) {
        if (key != album) _lifts.remove(key)!.controller.dispose();
      }
    } else if (previous != null && previous != album) {
      final returning = _lifts[previous]!.controller;
      returning
          .animateBack(
            0,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
          )
          .whenCompleteOrCancel(() {
            scheduleMicrotask(() {
              if (!mounted ||
                  _liftedAlbum == previous ||
                  _lifts[previous]?.controller != returning ||
                  !returning.isDismissed) {
                return;
              }
              setState(() => _lifts.remove(previous)!.controller.dispose());
            });
          });
    }
    if (album == null) return;
    final lift = _lifts.putIfAbsent(album, () {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      );
      return (
        controller: controller,
        scale: controller.drive(Tween<double>(begin: 1, end: 1.16)),
      );
    });
    if (reduceMotion) {
      lift.controller.value = 1;
    } else if (album != previous) {
      lift.controller.animateTo(1, curve: Curves.easeOutCubic);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAtlas();
    _syncLift();
  }

  @override
  void didUpdateWidget(covariant AlbumCanvasViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAtlas();
    _syncLift();
  }

  @override
  void didHaveMemoryPressure() => setState(_discardAtlas);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _discardAtlas();
    for (final lift in _lifts.values) {
      lift.controller.dispose();
    }
    _lifts.clear();
    super.dispose();
  }

  void _discardAtlas() {
    _atlasGeneration++;
    _readyAtlas?.dispose();
    _readyAtlas = null;
    final previous = _atlas;
    _atlas = null;
    // A picture from this frame can still refer to the outgoing texture.
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  void _syncAtlas() {
    final albums = widget.albums;
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        widget.xerox ||
        albums.isEmpty ||
        albums.length > CanvasArtworkAtlas.maxCovers) {
      _atlasInput = null;
      _atlasRequested = false;
      _discardAtlas();
      return;
    }
    final store = CustomArtworkScope.watch(context);
    final directory =
        albums.any(
          (album) => (album['asset'] as String).startsWith('directory:'),
        )
        ? DirectoryArtworkScope.watch(context)
        : (library: null, revision: 0);
    final config = createLocalImageConfiguration(context);
    final input = <Object?>[
      albums,
      config,
      directory.library,
      directory.revision,
      store,
      for (final album in albums)
        store?.revisionOf((album['id'] ?? album['asset']) as String),
    ];
    if (!listEquals(input, _atlasInput)) {
      _discardAtlas();
      _atlasInput = input;
      _atlasRequested = false;
    }
    if (_atlasRequested || widget.interactionBlocked) return;
    _atlasRequested = true;

    final generation = _atlasGeneration;
    final covers = [
      for (final album in albums)
        (
          album: album as Object,
          request: ArtworkRequest(
            source: album['asset'] as String,
            identity: _artworkIdentityFor(album),
            version: switch (album['artworkVersion']) {
              final String version => ArtworkVersion(version),
              _ => null,
            },
          ),
        ),
    ];
    bool isCurrent() => mounted && generation == _atlasGeneration;
    unawaited(() async {
      await WidgetsBinding.instance.endOfFrame;
      if (!isCurrent()) return;
      try {
        final atlas = await CanvasArtworkAtlas.load(
          covers: covers,
          directories: directory.library,
          configuration: config,
          isCurrent: isCurrent,
          onAccent: widget.onArtworkAccent == null
              ? null
              : (album, accent) => widget.onArtworkAccent!(album as Map<String, dynamic>, accent),
        );
        if (atlas == null) return;
        if (!isCurrent()) {
          atlas.dispose();
          return;
        }
        _readyAtlas = atlas;
        _publishReadyAtlas();
      } catch (error) {
        // Keep the ordinary artwork pipeline in charge of unavailable covers.
        debugPrint('Album atlas could not be prepared: $error');
      }
    }());
  }

  void _publishReadyAtlas() {
    final ready = _readyAtlas;
    if (!mounted ||
        ready == null ||
        widget.interaction.pressedPointers.isNotEmpty) {
      return;
    }
    _readyAtlas = null;
    setState(() => _atlas = ready);
  }

  ArtworkIdentity? _artworkIdentityFor(Map<String, dynamic> album) {
    final id = album['id'] as String?;
    return id == null ? null : ArtworkIdentity(id);
  }

  Future<void> _openAlbum(BuildContext source, int row, int col) async {
    if (_popupCell != null) return;
    final album = widget.layout.albumAt(row, col, widget.albums);
    final asset = album['asset'] as String;
    final title = album['title'] as String;
    widget.interaction.selectionPaused = true;
    setState(() => _popupCell = (row, col));
    void restoreSource() {
      if (mounted && _popupCell != null) setState(() => _popupCell = null);
    }

    try {
      await showAlbumCoverPopup(
        source: source,
        onReturned: restoreSource,
        onCoverLongPress: customArtworkMenuAction(
          context,
          asset,
          _artworkIdentityFor(album),
        ),
        artwork: albumArtwork(
          asset,
          artworkIdentity: _artworkIdentityFor(album),
          fit: BoxFit.cover,
          semanticLabel: title,
          xerox: widget.xerox,
        ),
        trackList: albumHasSingleTrack(album)
            ? null
            : AlbumTrackList(
                album: album,
                playback: widget.playback,
                xerox: widget.xerox,
              ),
      );
    } finally {
      restoreSource();
    }
  }

  Widget _tile(int row, int column) {
    final album = widget.layout.albumAt(row, column, widget.albums);
    final identity = _artworkIdentityFor(album);
    final asset = album['asset'] as String;
    final title = album['title'] as String;
    return Positioned(
      key: ValueKey((row, column)),
      left: column * albumGridExtent,
      top: row * albumGridExtent,
      width: albumGridExtent,
      height: albumGridExtent,
      child: widget.animateSourceTile(
        row,
        column,
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onTileSelected(row, column),
          onLongPressStart: customArtworkMenuAction(context, asset, identity),
          child: albumArtwork(
            asset,
            artworkIdentity: identity,
            fit: BoxFit.cover,
            xerox: widget.xerox,
            fixedResolution: albumCanvasArtworkResolution,
            semanticLabel: title,
            placeholder:
                asset.startsWith('media-store:') || asset.startsWith('local:')
                ? const ArtworkPlaceholder.canvasTile()
                : null,
            accentBuilder: widget.onArtworkAccent == null
                ? null
                : (context, artwork, accent) {
                    if (accent != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) widget.onArtworkAccent!(album, accent);
                      });
                    }
                    return artwork;
                  },
          ),
        ),
      ),
    );
  }

  GestureLongPressStartCallback? _longPressAt(int row, int column) {
    final album = widget.layout.albumAt(row, column, widget.albums);
    return customArtworkMenuAction(
      context,
      album['asset'] as String,
      _artworkIdentityFor(album),
    );
  }

  Widget _selectedTile(
    int row,
    int column,
    Animation<double> scale, {
    required bool isSelected,
  }) => Positioned(
    key: ValueKey(('selected', (row, column))),
    left: column * albumGridExtent,
    top: row * albumGridExtent,
    width: albumGridExtent,
    height: albumGridExtent,
    child: IgnorePointer(
      ignoring: !isSelected,
      child: _selectedCover(row, column, scale),
    ),
  );

  Widget _selectedCover(int row, int column, Animation<double> scale) {
    final album = widget.layout.albumAt(row, column, widget.albums);
    return widget.animateSourceTile(
      row,
      column,
      SelectedAlbum(
        key: ValueKey(('selected-cover', (row, column))),
        onOpen: (context) => _openAlbum(context, row, column),
        playback: widget.playback,
        liftScale: scale,
        xerox: widget.xerox,
        asset: album['asset'] as String,
        artworkIdentity: _artworkIdentityFor(album),
        title: album['title'] as String,
        artist: album['artist'] as String?,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interaction = widget.interaction;
    final transform = widget.transform;
    final popup = _popupCell;
    final selected = widget.layout.selectedAlbum;
    final atlas =
        widget.interactionBlocked ||
            AlbumCanvasViewport.useWidgetGridForBenchmark
        ? null
        : _atlas;
    final batch =
        atlas != null && widget.layout.gridAlbums.values.every(atlas.contains)
        ? atlas
        : null;
    final hiddenOffset = popup == null
        ? null
        : Offset(popup.$2 * albumGridExtent, popup.$1 * albumGridExtent);
    return ValueListenableBuilder(
      valueListenable: customArtworkMenuVisible,
      builder: (_, menuVisible, canvas) => TickerMode(
        enabled: !menuVisible,
        child: PortraitTilt(paused: menuVisible, child: canvas!),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          widget.onViewportSizeChanged(constraints.biggest);
          final tiltPadding = PortraitTilt.viewportPadding(constraints.biggest);
          var tiles = const <Widget>[];
          ({int left, int right, int top, int bottom})? previousBounds;
          (int, int)? previousSelection;
          Widget? previousCanvas;
          AlbumSpriteCanvas buildSprites({
            Set<(int, int)>? liftedCells,
            Widget? overlay,
          }) => AlbumSpriteCanvas(
            viewport: constraints.biggest,
            tiltPadding: tiltPadding,
            transform: transform,
            atlas: batch!,
            selected: selected,
            hidden: popup,
            liftedCells: liftedCells,
            albumAt: (row, column) =>
                widget.layout.albumAt(row, column, widget.albums),
            titleAt: (row, column) =>
                widget.layout.albumAt(row, column, widget.albums)['title']
                    as String,
            onTileSelected: widget.onTileSelected,
            longPressAt: _longPressAt,
            child: overlay,
          );
          void finishPointer(PointerEvent event) {
            interaction.pointerUp(event.pointer);
            if (_readyAtlas != null && interaction.pressedPointers.isEmpty) {
              scheduleMicrotask(_publishReadyAtlas);
            }
          }

          return Listener(
            onPointerDown: (event) => interaction.pointerDown(event.pointer),
            onPointerUp: finishPointer,
            onPointerCancel: finishPointer,
            child: IgnorePointer(
              ignoring: widget.interactionBlocked || popup != null,
              child: InteractiveViewer(
                constrained: false,
                clipBehavior: Clip.none,
                transformationController: transform,
                // Use the smallest allowed coefficient to make the viewer's
                // fling zero-duration. CanvasDrift owns motion after release.
                interactionEndFrictionCoefficient: double.minPositive,
                onInteractionStart: (_) => interaction.interactionStart(),
                onInteractionUpdate: interaction.interactionUpdate,
                onInteractionEnd: interaction.interactionEnd,
                minScale: 0.4,
                maxScale: 2.5,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                // Pan and zoom update the tile window without a layout callback.
                child: batch != null && _lifts.isEmpty
                    ? buildSprites()
                    : ListenableBuilder(
                        listenable: transform,
                        builder: (_, _) {
                          final matrix = transform.value;
                          final tileSize =
                              matrix.getColumn(0).length * albumGridExtent;
                          final x = matrix.entry(0, 3);
                          final y = matrix.entry(1, 3);
                          final previous = previousBounds;
                          final (left, right) = _mountedRange(
                            ((-tiltPadding.dx - x) / tileSize).floor(),
                            ((constraints.maxWidth + tiltPadding.dx - x) /
                                    tileSize)
                                .floor(),
                            previous == null
                                ? null
                                : (previous.left, previous.right),
                          );
                          final (top, bottom) = _mountedRange(
                            ((-tiltPadding.dy - y) / tileSize).floor(),
                            ((constraints.maxHeight + tiltPadding.dy - y) /
                                    tileSize)
                                .floor(),
                            previous == null
                                ? null
                                : (previous.top, previous.bottom),
                          );
                          final bounds = (
                            left: left,
                            right: right,
                            top: top,
                            bottom: bottom,
                          );
                          final selected = widget.layout.selectedAlbum;
                          if (bounds == previousBounds &&
                              selected == previousSelection) {
                            return previousCanvas!;
                          }
                          if (batch == null && bounds != previous) {
                            // The previous window is stored in row-major order.
                            final previousTiles = tiles;
                            final previousWidth = previous == null
                                ? 0
                                : previous.right - previous.left + 1;
                            tiles = [
                              for (var row = top; row <= bottom; row++)
                                for (
                                  var column = left;
                                  column <= right;
                                  column++
                                )
                                  if (previous != null &&
                                      row >= previous.top &&
                                      row <= previous.bottom &&
                                      column >= previous.left &&
                                      column <= previous.right)
                                    previousTiles[(row - previous.top) *
                                            previousWidth +
                                        column -
                                        previous.left]
                                  else
                                    _tile(row, column),
                            ];
                          }
                          previousBounds = bounds;
                          previousSelection = selected;
                          final liftedCells = <(int, int)>{};
                          final returningTiles = <Widget>[];
                          final selectedTiles = <Widget>[];
                          if (_lifts.isNotEmpty) {
                            for (var row = top; row <= bottom; row++) {
                              for (
                                var column = left;
                                column <= right;
                                column++
                              ) {
                                if ((row, column) == popup) continue;
                                final album = widget.layout.albumAt(
                                  row,
                                  column,
                                  widget.albums,
                                );
                                final key = _albumKey(album);
                                final lift = _lifts[key];
                                if (lift == null) continue;
                                final isSelected = key == _liftedAlbum;
                                if (isSelected) liftedCells.add((row, column));
                                (isSelected ? selectedTiles : returningTiles)
                                    .add(
                                      _selectedTile(
                                        row,
                                        column,
                                        lift.scale,
                                        isSelected: isSelected,
                                      ),
                                    );
                              }
                            }
                          }
                          final canvas = AlbumCanvas(
                            size: constraints.biggest,
                            transform: transform,
                            tiltPadding: tiltPadding,
                            isTransitioning: widget.interactionBlocked,
                            albumAt: (row, column) => widget.layout.albumAt(
                              row,
                              column,
                              widget.albums,
                            ),
                            hiddenTileOffset: hiddenOffset,
                            tiles: tiles,
                            selectedTiles: [
                              ...returningTiles,
                              ...selectedTiles,
                            ],
                          );
                          return previousCanvas = batch == null
                              ? canvas
                              : buildSprites(
                                  liftedCells: liftedCells,
                                  overlay: canvas,
                                );
                        },
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Moving past one guard ring edge does not reload the other axis.
(int, int) _mountedRange(int first, int last, (int, int)? previous) {
  const guard = 2;
  final span = last - first + guard * 2;
  if (previous != null) {
    final (start, end) = previous;
    if (end - start <= span + 1) {
      if (start < first && end > last) return previous;
      // Add the approaching row or column while the last buffered one is ready.
      if (start < first) return (last + 1 - span, last + 1);
      if (end > last) return (first - 1, first - 1 + span);
    }
  }
  return (first - guard, last + guard);
}
