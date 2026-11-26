import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../ui/widgets/frosted_control_surface.dart';
import 'album_playback.dart';
import 'now_playing_title.dart';
import 'playback_loading_arc.dart';

class NowPlayingCapsule extends StatelessWidget {
  const NowPlayingCapsule({
    super.key,
    required this.playback,
    required this.visible,
    required this.onOpenSheet,
    this.pullFeedbackIcon,
    this.previewTitle,
  });

  final AlbumPlayback? playback;
  final bool visible;
  final VoidCallback? onOpenSheet;
  final IconData? pullFeedbackIcon;
  final String? previewTitle;

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
    final loading =
        visible &&
        pullFeedbackIcon == null &&
        (playback?.showLoadingIndicator ?? false);
    final playing = playback?.playing ?? false;
    final l10n = AppLocalizations.of(context);

    final playButton = IconButton(
      tooltip: playing ? l10n.musicPause : l10n.musicPlay,
      onPressed: title == null ? null : playback!.toggleCurrent,
      color: Colors.white,
      disabledColor: loading || pullFeedbackIcon != null
          ? Colors.white
          : Colors.white38,
      iconSize: 14,
      padding: EdgeInsets.zero,
      icon: Icon(
        pullFeedbackIcon ??
            (!loading && playing
                ? PhosphorIcons.pauseFill
                : PhosphorIcons.playFill),
        shadows: _textShadows,
      ),
    );

    final controls = Material(
      type: MaterialType.transparency,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              customSemanticsActions: {
                CustomSemanticsAction(label: l10n.settings): ?onOpenSheet,
                if (playback != null && playback.currentTrack != null) ...{
                  CustomSemanticsAction(label: l10n.musicPreviousTrack): () =>
                      playback.skip(forward: false),
                  CustomSemanticsAction(label: l10n.musicNextTrack): () =>
                      playback.skip(forward: true),
                  CustomSemanticsAction(label: l10n.musicRewind): () =>
                      playback.seekStep(forward: false),
                  CustomSemanticsAction(label: l10n.musicFastForward): () =>
                      playback.seekStep(forward: true),
                },
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
                        title: previewTitle ?? title ?? l10n.musicNotPlaying,
                        animate: previewTitle == null && title != null,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          shadows: _textShadows,
                        ),
                      ),
                      if (artist != null && previewTitle == null)
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                playButton,
                if (loading)
                  const Center(
                    child: IgnorePointer(
                      child: SizedBox.square(
                        dimension: 32,
                        child: PlaybackLoadingArc(),
                      ),
                    ),
                  ),
              ],
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
