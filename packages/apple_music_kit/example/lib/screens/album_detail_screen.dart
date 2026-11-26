/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'package:apple_music_kit/apple_music_kit.dart';
import 'package:flutter/material.dart';

/// Album detail: artwork, metadata, track list, play-all.
final class AlbumDetailScreen extends StatefulWidget {
  /// Creates the screen for [album].
  const AlbumDetailScreen(
      {super.key, required this.album, required this.client});

  final MusicAlbum album;
  final AppleMusicClient client;

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<MusicSong> _tracks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Track listing: search songs by album title + artist. The catalog
      // search returns songs with playback parameters on every platform.
      final result = await widget.client.catalog.search(
        '${widget.album.artistName ?? ''} ${widget.album.title}',
        types: {MusicResourceType.song},
        limit: 50,
      );
      if (!mounted) return;
      setState(() => _tracks = result.songs?.items ?? const []);
    } on MusicKitException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _playAll() async {
    if (_tracks.isEmpty) return;
    try {
      await widget.client.player.setQueue(
        _tracks.map((t) => t.ref).toList(),
      );
    } on MusicKitException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final album = widget.album;
    return Scaffold(
      appBar: AppBar(title: Text(album.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                Row(
                  children: [
                    album.artwork == null
                        ? const SizedBox(
                            width: 160, height: 160, child: Icon(Icons.album))
                        : Image.network(
                            album.artwork!.url(size: 320) ?? '',
                            width: 160,
                            height: 160,
                            errorBuilder: (_, __, ___) => const SizedBox(
                                width: 160,
                                height: 160,
                                child: Icon(Icons.album)),
                          ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(album.title,
                              style: Theme.of(context).textTheme.titleLarge),
                          Text(album.artistName ?? ''),
                          if (album.releaseDate != null)
                            Text(album.releaseDate!),
                          if (album.trackCount != null)
                            Text('${album.trackCount} tracks'),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton.icon(
                    onPressed: _tracks.isEmpty ? null : _playAll,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play all'),
                  ),
                ),
                for (final track in _tracks)
                  ListTile(
                    leading: Text('${track.trackNumber ?? '-'}'),
                    title: Text(track.title),
                    subtitle: Text(track.artistName ?? ''),
                    onTap: () => widget.client.player.setQueue([track.ref]),
                  ),
              ],
            ),
    );
  }
}
