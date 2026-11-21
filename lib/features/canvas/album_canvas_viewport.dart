// 文件职责：专辑墙无限画布的布局、视口与交互状态。

import 'package:material_ui/material_ui.dart';

import '../artwork/artwork_renderer.dart';
import '../artwork/model/artwork_identity.dart';
import '../music/playback/album_play_button.dart';
import '../music/playback/album_playback.dart';
import 'album_canvas.dart';
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
  });

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

  @override
  State<AlbumCanvasViewport> createState() => _AlbumCanvasViewportState();
}

class _AlbumCanvasViewportState extends State<AlbumCanvasViewport> {
  (int, int)? _popupCell;

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
        artwork: albumArtwork(
          asset,
          artworkIdentity: _artworkIdentityFor(album),
          fit: BoxFit.cover,
          semanticLabel: title,
          xerox: widget.xerox,
        ),
        playButton: AlbumPlayButton(
          asset: asset,
          title: title,
          artist: album['artist'] as String?,
          playback: widget.playback,
          diameter: 64,
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
          child: albumArtwork(
            asset,
            artworkIdentity: identity,
            fit: BoxFit.cover,
            xerox: widget.xerox,
            fixedResolution: albumCanvasArtworkResolution,
            semanticLabel: title,
          ),
        ),
      ),
    );
  }

  Widget _selectedTile(int row, int column) {
    final album = widget.layout.albumAt(row, column, widget.albums);
    return Positioned(
      key: ValueKey(('selected', (row, column))),
      left: column * albumGridExtent,
      top: row * albumGridExtent,
      width: albumGridExtent,
      height: albumGridExtent,
      child: widget.animateSourceTile(
        row,
        column,
        SelectedAlbum(
          onOpen: (context) => _openAlbum(context, row, column),
          playback: widget.playback,
          xerox: widget.xerox,
          asset: album['asset'] as String,
          artworkIdentity: _artworkIdentityFor(album),
          title: album['title'] as String,
          artist: album['artist'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interaction = widget.interaction;
    final transform = widget.transform;
    final popup = _popupCell;
    final hiddenOffset = popup == null
        ? null
        : Offset(popup.$2 * albumGridExtent, popup.$1 * albumGridExtent);
    return PortraitTilt(
      child: LayoutBuilder(
        builder: (context, constraints) {
          widget.onViewportSizeChanged(constraints.biggest);
          final tiltPadding = PortraitTilt.viewportPadding(constraints.biggest);
          var tiles = const <(int, int), Widget>{};
          ({int left, int right, int top, int bottom})? previousBounds;
          (int, int)? previousSelection;
          AlbumCanvas? previousCanvas;
          return Listener(
            onPointerDown: (event) => interaction.pointerDown(event.pointer),
            onPointerUp: (event) => interaction.pointerUp(event.pointer),
            onPointerCancel: (event) => interaction.pointerUp(event.pointer),
            child: IgnorePointer(
              ignoring: widget.interactionBlocked || popup != null,
              child: InteractiveViewer.builder(
                clipBehavior: Clip.none,
                transformationController: transform,
                // 手势结束后由自定义漂移逻辑继续接管惯性运动。
                interactionEndFrictionCoefficient: 1e-100,
                onInteractionStart: (_) => interaction.interactionStart(),
                onInteractionUpdate: interaction.interactionUpdate,
                onInteractionEnd: interaction.interactionEnd,
                minScale: 0.4,
                maxScale: 2.5,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                builder: (context, viewport) {
                  final rect = viewport;
                  final scale = transform.value.getColumn(0).length;
                  final padding = tiltPadding / scale;
                  final previous = previousBounds;
                  final (left, right) = _mountedRange(
                    ((rect.point0.x - padding.dx) / albumGridExtent).floor(),
                    ((rect.point2.x + padding.dx) / albumGridExtent).floor(),
                    previous == null ? null : (previous.left, previous.right),
                  );
                  final (top, bottom) = _mountedRange(
                    ((rect.point0.y - padding.dy) / albumGridExtent).floor(),
                    ((rect.point2.y + padding.dy) / albumGridExtent).floor(),
                    previous == null ? null : (previous.top, previous.bottom),
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
                  if (bounds != previousBounds) {
                    tiles = {
                      for (var row = bounds.top; row <= bounds.bottom; row++)
                        for (var col = bounds.left; col <= bounds.right; col++)
                          (row, col): tiles[(row, col)] ?? _tile(row, col),
                    };
                  }
                  previousBounds = bounds;
                  previousSelection = selected;
                  return previousCanvas = AlbumCanvas(
                    size: constraints.biggest,
                    transform: transform,
                    tiltPadding: tiltPadding,
                    isTransitioning: widget.interactionBlocked,
                    hiddenTileOffset: hiddenOffset,
                    tiles: tiles.values,
                    selected: selected == null
                        ? null
                        : _selectedTile(selected.$1, selected.$2),
                  );
                },
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
