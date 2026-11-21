// 文件职责：专辑墙无限画布的布局、视口与交互状态。

import 'package:material_ui/material_ui.dart';

import '../artwork/artwork_renderer.dart';
import '../artwork/model/artwork_identity.dart';
import '../music/playback/album_play_button.dart';
import '../music/playback/album_playback.dart';
import 'album_grid_snapshot.dart';

/// 封装或定义选中专辑相关类型与行为，负责专辑墙无限画布的布局、视口与交互状态。
class SelectedAlbum extends StatefulWidget {
  const SelectedAlbum({
    super.key,
    required this.asset,
    required this.title,
    required this.playback,
    required this.onOpen,
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

  @override
  State<SelectedAlbum> createState() => _SelectedAlbumState();
}

/// 封装或定义选中专辑状态相关类型与行为，负责专辑墙无限画布的布局、视口与交互状态。
class _SelectedAlbumState extends State<SelectedAlbum> {
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 1, end: 1.16),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
    builder: (context, scale, child) =>
        Transform.scale(scale: scale, child: child),
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
              onTap: () => widget.onOpen(context),
              child: albumArtwork(
                widget.asset,
                artworkIdentity: widget.artworkIdentity,
                fit: BoxFit.cover,
                semanticLabel: widget.title,
                xerox: widget.xerox,
                fixedResolution: albumCanvasArtworkResolution,
              ),
            ),
          ),
          AlbumPlayButton(
            asset: widget.asset,
            title: widget.title,
            artist: widget.artist,
            playback: widget.playback,
          ),
        ],
      ),
    ),
  );
}
