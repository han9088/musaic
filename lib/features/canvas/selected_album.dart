// 文件职责：专辑墙无限画布的布局、视口与交互状态。

import 'package:material_ui/material_ui.dart';

import '../artwork/artwork_renderer.dart';
import '../artwork/model/artwork_identity.dart';
import '../artwork/presentation/custom_artwork_menu.dart';
import '../music/playback/album_play_button.dart';
import '../music/playback/album_playback.dart';
import 'album_grid_snapshot.dart';

/// 封装或定义选中专辑相关类型与行为，负责专辑墙无限画布的布局、视口与交互状态。
class SelectedAlbum extends StatelessWidget {
  const SelectedAlbum({
    super.key,
    required this.asset,
    required this.title,
    required this.playback,
    required this.onOpen,
    required this.liftScale,
    this.artist,
    this.xerox = false,
    this.artworkIdentity,
  });

  final String asset;
  final String title;
  final String? artist;
  final ArtworkIdentity? artworkIdentity;
  final AlbumPlayback playback;
  final ValueChanged<BuildContext> onOpen;
  final bool xerox;
  final Animation<double> liftScale;

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: liftScale,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: customArtworkMenuAction(
        context,
        asset,
        artworkIdentity,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Builder(
              builder: (context) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onOpen(context),
                child: albumArtwork(
                  asset,
                  artworkIdentity: artworkIdentity,
                  fit: BoxFit.cover,
                  semanticLabel: title,
                  xerox: xerox,
                  fixedResolution: albumCanvasArtworkResolution,
                ),
              ),
            ),
            AlbumPlayButton(
              asset: asset,
              title: title,
              artist: artist,
              playback: playback,
            ),
          ],
        ),
      ),
    ),
  );
}
