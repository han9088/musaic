// 文件职责：音乐源、媒体库、播放及切换流程。

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../ui/widgets/glass_icon_button.dart';
import 'album_playback.dart';
import 'playback_loading_arc.dart';

/// 封装或定义专辑播放按钮相关类型与行为，负责音乐源、媒体库、播放及切换流程。
class AlbumPlayButton extends StatelessWidget {
  const AlbumPlayButton({
    super.key,
    required this.asset,
    required this.title,
    required this.playback,
    this.artist,
    this.diameter = 30,
    this.iconSize,
  });
  final String asset;
  final String title;
  final String? artist;
  final AlbumPlayback playback;
  final double diameter;
  final double? iconSize;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: playback,
    builder: (context, child) {
      if (!playback.supportsPlayback) return const SizedBox.shrink();
      final loading = playback.showsAlbumLoading(asset, title);
      final playing = playback.isPlaying(asset, title);
      return Center(
        child: GlassIconButton(
          diameter: diameter,
          iconSize: iconSize,
          label: '${playing ? '暂停' : '播放'} $title',
          icon: !loading && playing
              ? PhosphorIcons.pauseFill
              : PhosphorIcons.playFill,
          foreground: loading ? const PlaybackLoadingArc() : null,
          onPressed: () => playback.toggle(asset, title, artist: artist),
        ),
      );
    },
  );
}
