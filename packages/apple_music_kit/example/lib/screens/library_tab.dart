/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'package:apple_music_kit/apple_music_kit.dart';
import 'package:flutter/material.dart';

/// Lists the user's library songs.
final class LibraryTab extends StatefulWidget {
  /// Creates the library tab bound to [client].
  const LibraryTab({super.key, required this.client});

  final AppleMusicClient client;

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  List<MusicSong> _songs = [];
  bool _loading = false;
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
      final page = await widget.client.library.getSongs();
      setState(() => _songs = page.items);
    } on MusicKitException catch (e) {
      setState(() => _error = e.userMessage);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_songs.isEmpty) {
      return const Center(child: Text('No library songs.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _songs.length,
        itemBuilder: (context, index) {
          final song = _songs[index];
          return ListTile(
            leading: const Icon(Icons.library_music),
            title: Text(song.title),
            subtitle: Text(song.artistName ?? ''),
            onTap: () => widget.client.player.setQueue([song.ref]),
          );
        },
      ),
    );
  }
}
