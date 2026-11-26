/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'dart:async';

import 'package:apple_music_kit/apple_music_kit.dart';
import 'package:flutter/material.dart';

/// A mini player: artwork, title, progress, transport, shuffle/repeat.
final class PlayerBar extends StatefulWidget {
  /// Creates the bar bound to [client].
  const PlayerBar({super.key, required this.client});

  final AppleMusicClient client;

  @override
  State<PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends State<PlayerBar> {
  StreamSubscription<MusicPlayerState>? _sub;
  MusicPlayerState _state = const MusicPlayerState.initial();

  @override
  void initState() {
    super.initState();
    _sub = widget.client.player.states.listen((s) {
      if (mounted) setState(() => _state = s);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.client.player;
    final duration = _state.duration;
    final position = _state.position;
    final progress = duration == null || duration.inMilliseconds == 0
        ? null
        : position.inMilliseconds / duration.inMilliseconds;

    String fmt(Duration d) =>
        '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress != null)
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _state.currentItem?.id.isEmpty == false
                            ? 'Now playing · ${_state.currentItem!.id}'
                            : 'Nothing playing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        duration == null
                            ? fmt(position)
                            : '${fmt(position)} / ${fmt(duration)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _state.shuffleMode == MusicShuffleMode.on
                        ? Icons.shuffle
                        : Icons.shuffle_outlined,
                  ),
                  onPressed: () => player.setShuffleMode(
                    _state.shuffleMode == MusicShuffleMode.on
                        ? MusicShuffleMode.off
                        : MusicShuffleMode.on,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _state.repeatMode == MusicRepeatMode.one
                        ? Icons.repeat_one
                        : Icons.repeat,
                    color: _state.repeatMode == MusicRepeatMode.off
                        ? null
                        : Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () => player.setRepeatMode(
                    switch (_state.repeatMode) {
                      MusicRepeatMode.off => MusicRepeatMode.all,
                      MusicRepeatMode.all => MusicRepeatMode.one,
                      MusicRepeatMode.one => MusicRepeatMode.off,
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: () => player.skipToPrevious(),
                ),
                IconButton.filled(
                  icon: Icon(
                    _state.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                  onPressed: () => player.togglePlayPause(),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: () => player.skipToNext(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
