import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../ui/widgets/frosted_control_surface.dart';
import 'album_playback.dart';
import 'now_playing_title.dart';

class NowPlayingCapsule extends StatelessWidget {
  const NowPlayingCapsule({
    super.key,
    required this.playback,
    required this.visible,
    required this.onOpenSheet,
  });

  final AlbumPlayback? playback;
  final bool visible;
  final VoidCallback onOpenSheet;

  static const _textShadows = [Shadow(color: Color(0xB3000000), blurRadius: 3)];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: playback ?? const AlwaysStoppedAnimation(0),
    builder: (context, _) => _buildCapsule(context),
  );

  Widget _buildCapsule(BuildContext context) {
    final playback = this.playback;
    final title = playback?.currentTitle;
    final artist = playback?.currentArtist;
    final playing = playback?.playing ?? false;
    final l10n = AppLocalizations.of(context);

    final controls = Material(
      type: MaterialType.transparency,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              customSemanticsActions: {
                CustomSemanticsAction(label: l10n.settings): onOpenSheet,
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: FrostedControlSurface.compactHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NowPlayingTitle(
                        title: title ?? l10n.musicNotPlaying,
                        animate: title != null,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          shadows: _textShadows,
                        ),
                      ),
                      if (artist != null && artist.trim().isNotEmpty)
                        Text(
                          artist,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            height: 1.2,
                            shadows: _textShadows,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 36,
            height: FrostedControlSurface.compactHeight,
            child: IconButton(
              tooltip: playing ? l10n.musicPause : l10n.musicPlay,
              onPressed: title == null ? null : playback!.toggleCurrent,
              color: Colors.white,
              disabledColor: Colors.white38,
              iconSize: 14,
              padding: EdgeInsets.zero,
              icon: Icon(
                playing ? PhosphorIcons.pauseFill : PhosphorIcons.playFill,
                shadows: _textShadows,
              ),
            ),
          ),
        ],
      ),
    );

    return IgnorePointer(
      ignoring: !visible,
      child: SizedBox(
        width: 146,
        child: FrostedControlSurface(
          visible: visible,
          outline: const BorderSide(color: Color(0x18FFFFFF)),
          child: Listener(behavior: HitTestBehavior.opaque, child: controls),
        ),
      ),
    );
  }
}
