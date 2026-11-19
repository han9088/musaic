// 文件职责：专辑墙无限画布的布局、视口与交互状态。

import 'package:material_ui/material_ui.dart';

import '../artwork/artwork_renderer.dart';
import '../artwork/model/artwork_identity.dart';
import '../music/playback/album_playback.dart';
import 'album_canvas.dart';
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

  @override
  Widget build(BuildContext context) {
    return PortraitTilt(
      child: LayoutBuilder(
        builder: (context, constraints) {
          onViewportSizeChanged(constraints.biggest);
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
                              child: animateSourceTile(
                                row,
                                col,
                                GestureDetector(
                                  onTap: () => onTileSelected(row, col),
                                  child: Builder(
                                    builder: (context) {
                                      final album = layout.albumAt(
                                        row,
                                        col,
                                        albums,
                                      );
                                      final asset = album['asset'] as String;
                                      final rawIdentity = album['id'] as String?;
                                      return albumArtwork(
                                        asset,
                                        artworkIdentity: rawIdentity == null
                                            ? null
                                            : ArtworkIdentity(rawIdentity),
                                        fit: BoxFit.cover,
                                        xerox: xerox,
                                        scale: scale,
                                        semanticLabel: album['title'] as String,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                        if (layout.selectedAlbum case final selected?)
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
                                playback: playback,
                                xerox: xerox,
                                scale: scale,
                                asset: layout.albumAt(
                                  selected.$1,
                                  selected.$2,
                                  albums,
                                )['asset'] as String,
                                artworkIdentity: _artworkIdentityFor(
                                  layout.albumAt(
                                    selected.$1,
                                    selected.$2,
                                    albums,
                                  ),
                                ),
                                title: layout.albumAt(
                                  selected.$1,
                                  selected.$2,
                                  albums,
                                )['title'] as String,
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
