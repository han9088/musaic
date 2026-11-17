import 'package:material_ui/material_ui.dart';

import '../album_artwork.dart';
import '../playback/album_play_button.dart';
import '../playback/album_playback.dart';

class SelectedAlbum extends StatefulWidget {
  const SelectedAlbum({
    super.key,
    required this.asset,
    required this.title,
    required this.playback,
    this.xerox = false,
    this.scale = 1,
  });

  final String asset;
  final String title;
  final AlbumPlayback playback;
  final bool xerox;
  final double scale;

  @override
  State<SelectedAlbum> createState() => _SelectedAlbumState();
}

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
          albumArtwork(
            widget.asset,
            fit: BoxFit.cover,
            semanticLabel: widget.title,
            xerox: widget.xerox,
            scale: widget.scale * 1.16,
          ),
          AlbumPlayButton(
            asset: widget.asset,
            title: widget.title,
            playback: widget.playback,
          ),
        ],
      ),
    ),
  );
}
