// 文件职责：专辑墙无限画布的布局、视口与交互状态。

import 'package:material_ui/material_ui.dart';

import '../artwork/artwork_renderer.dart';
import '../artwork/model/artwork_identity.dart';
import '../artwork/pipeline/artwork_lod_manager.dart';
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
class AlbumCanvasViewport extends StatelessWidget {
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

  ArtworkIdentity? _artworkIdentityFor(Map<String, dynamic> album) {
    final id = album['id'] as String?;
    return id == null ? null : ArtworkIdentity(id);
  }

  Future<void> _openAlbum(BuildContext source, int row, int col) {
    final album = layout.albumAt(row, col, albums);
    final asset = album['asset'] as String;
    final title = album['title'] as String;
    interaction.selectionPaused = true;
    return showAlbumCoverPopup(
      source: source,
      artwork: albumArtwork(
        asset,
        artworkIdentity: _artworkIdentityFor(album),
        fit: BoxFit.cover,
        semanticLabel: title,
        xerox: xerox,
      ),
      playButton: AlbumPlayButton(
        asset: asset,
        title: title,
        playback: playback,
      ),
    );
  }

  Widget _tile(int row, int column, double scale) => Positioned(
    key: ValueKey((row, column)),
    left: column * albumGridExtent,
    top: row * albumGridExtent,
    width: albumGridExtent,
    height: albumGridExtent,
    child: animateSourceTile(
      row,
      column,
      Builder(
        builder: (context) {
          final album = layout.albumAt(row, column, albums);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTileSelected(row, column),
            child: albumArtwork(
              album['asset'] as String,
              artworkIdentity: _artworkIdentityFor(album),
              fit: BoxFit.cover,
              xerox: xerox,
              scale: scale,
              semanticLabel: album['title'] as String,
            ),
          );
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return PortraitTilt(
      child: LayoutBuilder(
        builder: (context, constraints) {
          onViewportSizeChanged(constraints.biggest);
          final dpr = MediaQuery.devicePixelRatioOf(context);
          var tiles = const <(int, int), Widget>{};
          ({int left, int right, int top, int bottom})? previousBounds;
          double? previousExtent;
          (int, int)? previousSelection;
          double? previousSelectionScale;
          AlbumCanvas? previousCanvas;
          return Listener(
            onPointerDown: (event) => interaction.pointerDown(event.pointer),
            onPointerUp: (event) => interaction.pointerUp(event.pointer),
            onPointerCancel: (event) => interaction.pointerUp(event.pointer),
            child: IgnorePointer(
              ignoring: interactionBlocked,
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
                  final margin =
                      PortraitTilt.overscan(constraints.biggest) / scale;
                  final left =
                      ((rect.point0.x - margin) / albumGridExtent).floor() - 1;
                  final right =
                      ((rect.point2.x + margin) / albumGridExtent).ceil() + 1;
                  final top =
                      ((rect.point0.y - margin) / albumGridExtent).floor() - 1;
                  final bottom =
                      ((rect.point2.y + margin) / albumGridExtent).ceil() + 1;
                  final bounds = (
                    left: left,
                    right: right,
                    top: top,
                    bottom: bottom,
                  );
                  final extent = albumGridExtent * scale * dpr;
                  final lastExtent = previousExtent;
                  final sameLod =
                      lastExtent != null &&
                      ArtworkLodManager.instance.hasSameSelections(
                        lastExtent,
                        extent,
                      );
                  final selected = layout.selectedAlbum;
                  if (sameLod &&
                      bounds == previousBounds &&
                      selected == previousSelection &&
                      (selected == null || previousSelectionScale == scale)) {
                    return previousCanvas!;
                  }

                  final retained = sameLod
                      ? tiles
                      : const <(int, int), Widget>{};
                  tiles = {
                    for (var row = top; row <= bottom; row++)
                      for (var col = left; col <= right; col++)
                        (row, col):
                            retained[(row, col)] ?? _tile(row, col, scale),
                  };
                  previousBounds = bounds;
                  previousExtent = extent;
                  previousSelection = selected;
                  previousSelectionScale = scale;
                  return previousCanvas = AlbumCanvas(
                    size: constraints.biggest,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ...tiles.values,
                        if (selected != null)
                          Positioned(
                            key: ValueKey(('selected', selected)),
                            left: selected.$2 * albumGridExtent,
                            top: selected.$1 * albumGridExtent,
                            width: albumGridExtent,
                            height: albumGridExtent,
                            child: animateSourceTile(
                              selected.$1,
                              selected.$2,
                              SelectedAlbum(
                                onOpen: (context) => _openAlbum(
                                  context,
                                  selected.$1,
                                  selected.$2,
                                ),
                                playback: playback,
                                xerox: xerox,
                                scale: scale,
                                asset:
                                    layout.albumAt(
                                          selected.$1,
                                          selected.$2,
                                          albums,
                                        )['asset']
                                        as String,
                                artworkIdentity: _artworkIdentityFor(
                                  layout.albumAt(
                                    selected.$1,
                                    selected.$2,
                                    albums,
                                  ),
                                ),
                                title:
                                    layout.albumAt(
                                          selected.$1,
                                          selected.$2,
                                          albums,
                                        )['title']
                                        as String,
                              ),
                            ),
                          ),
                      ],
                    ),
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
