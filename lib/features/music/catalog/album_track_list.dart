import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../services/music/music_models.dart';
import '../../artwork/artwork_renderer.dart';
import '../../artwork/model/artwork_identity.dart';
import '../playback/album_play_button.dart';
import '../playback/album_playback.dart';
import 'album_paper_backdrop.dart';
import 'album_track_edge_blur.dart';

/// The album back face shared by the canvas and Cover Flow previews.
class AlbumTrackList extends StatefulWidget {
  const AlbumTrackList({
    super.key,
    required this.album,
    this.playback,
    this.onClose,
  });

  final Map<String, dynamic> album;
  final AlbumPlayback? playback;
  final VoidCallback? onClose;

  @override
  State<AlbumTrackList> createState() => _AlbumTrackListState();
}

class _AlbumTrackListState extends State<AlbumTrackList> {
  static const _foreground = Color(0xfffff7e8);
  static const _fallbackAccent = Color(0xffdbc198);
  static const _playButtonTimeout = Duration(seconds: 3);
  static const _trackEdgeFade = 14.0;

  final _playButtonVisible = ValueNotifier(true);
  Timer? _hidePlayButton;
  Future<List<ProviderSong>>? _remoteTracks;

  Future<List<ProviderSong>>? _loadTracks() => widget.album['tracks'] != null
      ? null
      : widget.playback?.loadAlbumTracks(widget.album['asset'] as String);

  @override
  void initState() {
    super.initState();
    _remoteTracks = _loadTracks();
    if (widget.playback != null) _revealPlayButton();
  }

  @override
  void didUpdateWidget(covariant AlbumTrackList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.album['id'] != widget.album['id'] ||
        oldWidget.album['asset'] != widget.album['asset'] ||
        oldWidget.playback != widget.playback) {
      _remoteTracks = _loadTracks();
    }
  }

  void _revealPlayButton() {
    _playButtonVisible.value = true;
    _hidePlayButton?.cancel();
    _hidePlayButton = Timer(_playButtonTimeout, () {
      _playButtonVisible.value = false;
    });
  }

  @override
  void dispose() {
    _hidePlayButton?.cancel();
    _playButtonVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracks = widget.album['tracks'] as List<ProviderSong>? ?? const [];
    if (_remoteTracks == null) return _buildAlbum(tracks, loading: false);
    return FutureBuilder<List<ProviderSong>>(
      future: _remoteTracks,
      builder: (context, snapshot) => _buildAlbum(
        snapshot.data ?? const [],
        loading: snapshot.connectionState != ConnectionState.done,
      ),
    );
  }

  Widget _buildAlbum(List<ProviderSong> tracks, {required bool loading}) {
    final album = widget.album;
    final id = album['id'] as String?;
    final content = Listener(
      onPointerDown: widget.playback == null
          ? null
          : (_) => _revealPlayButton(),
      child: albumArtwork(
        album['asset'] as String,
        artworkIdentity: id == null ? null : ArtworkIdentity(id),
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        placeholder: const SizedBox.shrink(),
        prepareXerox: false,
        accentBuilder: (context, artwork, accent) => Stack(
          fit: StackFit.expand,
          children: [
            AlbumPaperBackdrop(artwork: artwork, accent: accent),
            Material(
              type: MaterialType.transparency,
              child: LayoutBuilder(
                builder: (context, constraints) => _buildContents(
                  context,
                  constraints.maxWidth,
                  accent,
                  tracks,
                  loading: loading,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(onDismiss: widget.onClose, child: content);
  }

  Widget _buildContents(
    BuildContext context,
    double side,
    Color? accent,
    List<ProviderSong> tracks, {
    required bool loading,
  }) {
    final album = widget.album;
    final title = album['title'] as String;
    final artist = album['artist'] as String?;
    final hue = HSLColor.fromColor(accent ?? _fallbackAccent);
    final secondary = hue.withSaturation(hue.saturation.clamp(0.0, 0.56));
    final artistColor = secondary.withLightness(0.80).toColor();
    final trackColor = secondary.withLightness(0.73).toColor();
    final inset = side * 0.07;
    final trackSize = (side * 0.0425).clamp(13.0, 16.0);
    final numberWidth = MediaQuery.textScalerOf(context)
        .scale((side * 0.073).clamp(23.0, 32.0));
    Widget trackBody(List<ProviderSong> songs) => songs.isEmpty
        ? Center(
            child: Text(
              AppLocalizations.of(context).albumTracksUnavailable,
              textAlign: TextAlign.center,
              style: TextStyle(color: artistColor, fontSize: 14),
            ),
          )
        : _buildTrackScroller(
            songs,
            trackSize: trackSize,
            numberWidth: numberWidth,
            numberColor: trackColor,
            activeColor: artistColor,
          );

    return Padding(
      padding: EdgeInsets.all(inset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _foreground,
                        fontSize: (side * 0.078).clamp(23.0, 30.0),
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        height: 1.13,
                      ),
                    ),
                    if (artist != null && artist.isNotEmpty) ...[
                      SizedBox(height: side * 0.013),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: artistColor,
                          fontSize: (side * 0.036).clamp(12.0, 14.0),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.playback case final controller?)
                ValueListenableBuilder(
                  valueListenable: _playButtonVisible,
                  builder: (context, visible, child) {
                    final show =
                        visible || MediaQuery.accessibleNavigationOf(context);
                    return IgnorePointer(
                      ignoring: !show,
                      child: AnimatedOpacity(
                        opacity: show ? 1 : 0,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        child: child,
                      ),
                    );
                  },
                  child: AlbumPlayButton(
                    diameter: 34,
                    iconSize: 15,
                    asset: album['asset'] as String,
                    title: title,
                    artist: artist,
                    playback: controller,
                  ),
                ),
            ],
          ),
          SizedBox(height: side * (tracks.isEmpty ? 0.053 : 0.014)),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : trackBody(tracks),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackScroller(
    List<ProviderSong> tracks, {
    required double trackSize,
    required double numberWidth,
    required Color numberColor,
    required Color activeColor,
  }) {
    final playback = widget.playback;
    Widget buildList() => ListView.builder(
      primary: false,
      addRepaintBoundaries: false,
      padding: const EdgeInsets.symmetric(vertical: _trackEdgeFade),
      physics: const ClampingScrollPhysics(),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final asset = widget.album['asset'] as String;
        final selected = playback?.isCurrentAlbumTrack(track, asset) ?? false;
        const radius = BorderRadius.all(Radius.circular(6));
        final row = Semantics(
          selected: selected,
          child: Material(
            color: selected
                ? activeColor.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap:
                  playback != null &&
                      playback.canPlayTrack(track, albumAsset: asset)
                  ? () => playback.playTrack(tracks, index, albumAsset: asset)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    SizedBox(
                      width: numberWidth,
                      child: Text(
                        '${index + 1}'.padLeft(2, '0'),
                        style: TextStyle(
                          color: selected ? activeColor : numberColor,
                          fontSize: trackSize * 0.75,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? activeColor : _foreground,
                          fontSize: trackSize,
                          fontWeight: selected ? FontWeight.w600 : null,
                          height: 1.23,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        return AlbumTrackEdgeBlur(
          edgeExtent: _trackEdgeFade,
          child: RepaintBoundary(child: row),
        );
      },
    );
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final fade = (_trackEdgeFade / bounds.height).clamp(0.0, 0.35);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, fade, 1 - fade, 1],
          colors: const [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
        ).createShader(bounds);
      },
      child: playback == null
          ? buildList()
          : ListenableBuilder(
              listenable: playback,
              builder: (_, _) => buildList(),
            ),
    );
  }
}
