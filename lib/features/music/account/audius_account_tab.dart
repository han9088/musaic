import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../services/music/audius_account.dart';
import '../../../services/music/audius_music_provider.dart';
import '../../../services/music/music_provider.dart';
import '../../../services/music/music_source_controller.dart';
import '../../../ui/bottom_sheet/bottom_sheet.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/settings_section_heading.dart';
import '../playback/album_playback.dart';

class AudiusAccountTab extends StatelessWidget {
  const AudiusAccountTab({super.key, required this.sources, this.playback});

  final MusicSourceController sources;
  final AlbumPlayback? playback;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = sources.audiusAccount;
    final provider = sources.provider;
    if (account == null || provider is! AudiusMusicProvider) {
      return ListTile(title: Text(l10n.audiusAccountUnavailable));
    }
    return BottomSheetScrollView(
      child: SettingsInteractionTheme(
        child: ListenableBuilder(
          listenable: account,
          builder: (context, _) {
            final user = account.user;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: const Icon(PhosphorIcons.userCircle),
                  title: Text(
                    user == null
                        ? l10n.audiusConnect
                        : user.handle == null
                        ? user.id
                        : '@${user.handle}',
                  ),
                  onTap: user == null && !account.busy ? account.connect : null,
                  trailing: account.busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : user == null
                      ? const Icon(PhosphorIcons.arrowUpRight)
                      : TextButton(
                          onPressed: account.disconnect,
                          child: Text(l10n.audiusDisconnect),
                        ),
                ),
                if (account.error != null)
                  ListTile(title: Text(l10n.audiusAccountFailed)),
                if (user != null)
                  _AudiusLibrary(
                    key: ValueKey(user.id),
                    userId: user.id,
                    account: account,
                    sources: sources,
                    provider: provider,
                    playback: playback,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _LibrarySection { tracks, albums, playlists }

class _AudiusLibrary extends StatefulWidget {
  const _AudiusLibrary({
    super.key,
    required this.userId,
    required this.account,
    required this.sources,
    required this.provider,
    this.playback,
  });

  final String userId;
  final AudiusAccount account;
  final MusicSourceController sources;
  final AudiusMusicProvider provider;
  final AlbumPlayback? playback;

  @override
  State<_AudiusLibrary> createState() => _AudiusLibraryState();
}

class _AudiusLibraryState extends State<_AudiusLibrary> {
  _LibrarySection? _section;
  var _revision = 0;
  var _canvasLoading = false;
  var _canvasError = false;

  void _reload() => setState(() => _revision++);

  Future<void> _setFavorite(MusicReference reference, bool favorite) async {
    final updated = await widget.account.setFavorite(
      id: reference.id,
      kind: reference.kind,
      favorite: favorite,
    );
    if (!updated || !mounted) return;
    _reload();
    if (reference.kind == MusicKind.album &&
        widget.sources.showingAudiusFavorites) {
      await _showFavorites();
    }
  }

  Future<void> _showFavorites() async {
    setState(() {
      _canvasLoading = true;
      _canvasError = false;
    });
    try {
      await widget.sources.showAudiusFavorites();
    } catch (_) {
      if (mounted) setState(() => _canvasError = true);
    } finally {
      if (mounted) setState(() => _canvasLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final playback = widget.playback;
    final section = _section;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const ValueKey('my-audius'),
          leading: const Icon(PhosphorIcons.musicNotes),
          title: Text(l10n.audiusMyLibrary),
          trailing: Icon(
            section == null ? PhosphorIcons.caretDown : PhosphorIcons.caretUp,
          ),
          onTap: () => setState(() {
            _section = section == null ? _LibrarySection.tracks : null;
          }),
        ),
        if (playback != null)
          ListenableBuilder(
            listenable: playback,
            builder: (context, _) {
              final track = playback.currentTrack;
              final album = playback.currentAudiusAlbum;
              if (track == null ||
                  track.provider != AudiusMusicProvider.providerId) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsSectionHeading(l10n.audiusNowPlaying),
                  ListTile(
                    leading: const Icon(PhosphorIcons.musicNote),
                    title: Text(playback.currentTitle ?? track.id),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        _FavoriteButton(
                          key: ValueKey((track, _revision)),
                          reference: track,
                          account: widget.account,
                          load: () =>
                              widget.provider.isFavorite(track, widget.userId),
                          onChanged: _setFavorite,
                        ),
                        if (album != null)
                          _FavoriteButton(
                            key: ValueKey((album, _revision)),
                            reference: album,
                            account: widget.account,
                            load: () => widget.provider.isFavorite(
                              album,
                              widget.userId,
                            ),
                            onChanged: _setFavorite,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        if (section != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: settingsContentInset,
            ),
            child: Wrap(
              spacing: 8,
              children: [
                for (final item in _LibrarySection.values)
                  ChoiceChip(
                    label: Text(switch (item) {
                      _LibrarySection.tracks => l10n.audiusFavoriteTracks,
                      _LibrarySection.albums => l10n.audiusFavoriteAlbums,
                      _LibrarySection.playlists => l10n.audiusPublicPlaylists,
                    }),
                    selected: section == item,
                    onSelected: (_) => setState(() => _section = item),
                  ),
              ],
            ),
          ),
          if (section == _LibrarySection.albums)
            SignalBuilder(
              builder: (_) {
                final favorites = widget.sources.showingAudiusFavorites;
                return ListTile(
                  leading: const Icon(PhosphorIcons.squaresFour),
                  title: Text(
                    favorites
                        ? l10n.audiusTrendingCanvas
                        : l10n.audiusFavoriteCanvas,
                  ),
                  subtitle: _canvasError
                      ? Text(l10n.audiusLibraryFailed)
                      : null,
                  trailing: _canvasLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _canvasLoading
                      ? null
                      : favorites
                      ? widget.sources.showAudiusTrending
                      : _showFavorites,
                );
              },
            ),
          if (section == _LibrarySection.tracks)
            _LibraryList<ProviderSong>(
              key: ValueKey((section, _revision)),
              load: (cursor) =>
                  widget.provider.favoriteTracks(widget.userId, cursor: cursor),
              itemBuilder: (tracks, index) {
                final song = tracks[index];
                return ListTile(
                  leading: const Icon(PhosphorIcons.play),
                  title: Text(song.title),
                  subtitle: song.artist == null ? null : Text(song.artist!),
                  onTap: playback != null && song.playable
                      ? () => playback.playAudiusFavorites(
                          tracks,
                          index,
                          l10n.audiusFavoriteTracks,
                        )
                      : null,
                  trailing: _removeFavorite(song.reference, l10n),
                );
              },
            )
          else
            _LibraryList<ProviderAlbum>(
              key: ValueKey((section, _revision)),
              load: (cursor) => section == _LibrarySection.albums
                  ? widget.provider.favoriteAlbums(
                      widget.userId,
                      cursor: cursor,
                    )
                  : widget.provider.publicPlaylists(
                      widget.userId,
                      cursor: cursor,
                    ),
              itemBuilder: (albums, index) {
                final album = albums[index];
                return ListTile(
                  leading: const Icon(PhosphorIcons.play),
                  title: Text(album.title),
                  subtitle: album.artist == null ? null : Text(album.artist!),
                  onTap: playback == null
                      ? null
                      : () => playback.playAudiusCollection(album),
                  trailing: section == _LibrarySection.albums
                      ? _removeFavorite(album.reference, l10n)
                      : null,
                );
              },
            ),
        ],
      ],
    );
  }

  Widget _removeFavorite(MusicReference reference, AppLocalizations l10n) =>
      IconButton(
        icon: const Icon(PhosphorIcons.heartFill),
        tooltip: reference.kind == MusicKind.album
            ? l10n.audiusUnfavoriteAlbum
            : l10n.audiusUnfavoriteTrack,
        onPressed: widget.account.busy
            ? null
            : () => _setFavorite(reference, false),
      );
}

class _FavoriteButton extends StatefulWidget {
  const _FavoriteButton({
    super.key,
    required this.reference,
    required this.account,
    required this.load,
    required this.onChanged,
  });

  final MusicReference reference;
  final AudiusAccount account;
  final Future<bool> Function() load;
  final Future<void> Function(MusicReference, bool) onChanged;

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  late Future<bool> _favorite = widget.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _favorite,
    builder: (context, state) {
      final l10n = AppLocalizations.of(context);
      final album = widget.reference.kind == MusicKind.album;
      final favorite = state.data;
      return IconButton(
        icon: Icon(
          favorite == true
              ? PhosphorIcons.heartFill
              : album
              ? PhosphorIcons.heartStraight
              : PhosphorIcons.heart,
        ),
        tooltip: state.hasError
            ? l10n.audiusRetry
            : switch ((album, favorite)) {
                (true, true) => l10n.audiusUnfavoriteAlbum,
                (true, _) => l10n.audiusFavoriteAlbum,
                (false, true) => l10n.audiusUnfavoriteTrack,
                (false, _) => l10n.audiusFavoriteTrack,
              },
        onPressed: widget.account.busy
            ? null
            : state.hasError
            ? () => setState(() => _favorite = widget.load())
            : favorite == null
            ? null
            : () => widget.onChanged(widget.reference, !favorite),
      );
    },
  );
}

class _LibraryList<T> extends StatefulWidget {
  const _LibraryList({
    super.key,
    required this.load,
    required this.itemBuilder,
  });

  final Future<MusicPage<T>> Function(String?) load;
  final Widget Function(List<T>, int) itemBuilder;

  @override
  State<_LibraryList<T>> createState() => _LibraryListState<T>();
}

class _LibraryListState<T> extends State<_LibraryList<T>> {
  final _items = <T>[];
  String? _cursor;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final page = await widget.load(_cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadMore() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _items.length; i++) widget.itemBuilder(_items, i),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_failed)
          ListTile(title: Text(l10n.audiusLibraryFailed), onTap: _loadMore)
        else if (_cursor != null)
          ListTile(title: Text(l10n.audiusLoadMore), onTap: _loadMore)
        else if (_items.isEmpty)
          ListTile(title: Text(l10n.audiusLibraryEmpty)),
      ],
    );
  }
}
