// 文件职责：音乐源、媒体库、播放及切换流程。

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../ui/widgets/glass_icon_button.dart';
import 'album_playback.dart';

/// 封装或定义专辑播放按钮相关类型与行为，负责音乐源、媒体库、播放及切换流程。
class AlbumPlayButton extends StatelessWidget {
  const AlbumPlayButton({
    super.key,
    required this.asset,
    required this.title,
    required this.playback,
    this.artist,
    this.diameter = 30,
  });
  final String asset;
  final String title;
  final String? artist;
  final AlbumPlayback playback;
  final double diameter;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: playback,
    builder: (context, child) => !playback.supportsPlayback
        ? const SizedBox.shrink()
        : Center(
            child: GlassIconButton(
              diameter: diameter,
              label: '${playback.isPlaying(asset, title) ? '暂停' : '播放'} $title',
              icon: playback.isPlaying(asset, title)
                  ? PhosphorIcons.pauseFill
                  : PhosphorIcons.playFill,
              onPressed: () => playback.toggle(asset, title, artist: artist),
            ),
          ),
  );
}
