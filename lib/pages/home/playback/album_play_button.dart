import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../glass_icon_button.dart';
import 'album_playback.dart';

class AlbumPlayButton extends StatelessWidget {
  const AlbumPlayButton({
    super.key,
    required this.asset,
    required this.title,
    required this.playback,
    this.diameter = 30,
  });
  final String asset;
  final String title;
  final AlbumPlayback playback;
  final double diameter;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: playback,
    builder: (context, child) => Center(
      child: GlassIconButton(
        diameter: diameter,
        label: '${playback.isPlaying(asset, title) ? '暂停' : '播放'} $title',
        icon: playback.isPlaying(asset, title)
            ? PhosphorIcons.pauseFill
            : PhosphorIcons.playFill,
        onPressed: () => playback.toggle(asset, title),
      ),
    ),
  );
}
