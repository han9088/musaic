/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'package:apple_music_kit/apple_music_kit.dart';
import 'package:flutter/material.dart';

import 'album_detail_screen.dart';

/// Search + results + tap-to-play.
final class SearchTab extends StatefulWidget {
  /// Creates the search tab bound to [client].
  const SearchTab({super.key, required this.client});

  final AppleMusicClient client;

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _controller = TextEditingController();
  List<MusicSong> _songs = [];
  List<MusicAlbum> _albums = [];
  bool _searching = false;
  String? _error;

  Future<void> _search() async {
    final term = _controller.text.trim();
    if (term.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final result = await widget.client.catalog.search(
        term,
        types: {MusicResourceType.song, MusicResourceType.album},
      );
      setState(() {
        _songs = result.songs?.items ?? const [];
        _albums = result.albums?.items ?? const [];
      });
    } on MusicKitException catch (e) {
      setState(() => _error = e.userMessage);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _play(MusicSong song) async {
    try {
      await widget.client.player.setQueue([song.ref]);
    } on MusicKitException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.userMessage)),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _controller,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Search songs',
              suffixIcon: IconButton(
                onPressed: _searching ? null : _search,
                icon: const Icon(Icons.search),
              ),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: _searching
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    if (_albums.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Albums'),
                      ),
                      for (final album in _albums)
                        ListTile(
                          leading: const Icon(Icons.album),
                          title: Text(album.title),
                          subtitle: Text(album.artistName ?? ''),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AlbumDetailScreen(
                                album: album,
                                client: widget.client,
                              ),
                            ),
                          ),
                        ),
                    ],
                    if (_songs.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Songs'),
                      ),
                      for (final song in _songs)
                        ListTile(
                          leading: song.artwork == null
                              ? const Icon(Icons.music_note)
                              : Image.network(
                                  song.artwork!.url(size: 64) ?? '',
                                  width: 48,
                                  height: 48,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.music_note),
                                ),
                          title: Text(song.title),
                          subtitle: Text(
                            '${song.artistName ?? ''} · '
                            '${song.duration?.inMinutes ?? '?'}:'
                            '${((song.duration?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}',
                          ),
                          trailing: song.isPlayable
                              ? const Icon(Icons.play_arrow)
                              : const Tooltip(
                                  message: 'Not playable',
                                  child: Icon(Icons.block),
                                ),
                          onTap: song.isPlayable ? () => _play(song) : null,
                        ),
                    ],
                    if (_songs.isEmpty && _albums.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No results.')),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
