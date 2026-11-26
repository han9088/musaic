/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'music_item_ref.dart';

/// Coarse playback status of the player.
enum MusicPlayerStatus {
  /// No queue loaded.
  idle,

  /// Queue is being prepared (fetching/stream starting).
  loading,

  /// Buffering mid-playback (stalled waiting for data).
  buffering,

  /// Ready with a queue, not playing.
  ready,

  /// Actively playing.
  playing,

  /// Paused by the user.
  paused,

  /// Stopped (queue end or explicit stop).
  stopped,

  /// Playback reached the end of the queue.
  completed,

  /// The player is in an error state; see the snapshot's error.
  error;

  /// Deserializes from transport.
  static MusicPlayerStatus fromName(String? name) => switch (name) {
        'loading' => MusicPlayerStatus.loading,
        'buffering' => MusicPlayerStatus.buffering,
        'ready' => MusicPlayerStatus.ready,
        'playing' => MusicPlayerStatus.playing,
        'paused' => MusicPlayerStatus.paused,
        'stopped' => MusicPlayerStatus.stopped,
        'completed' => MusicPlayerStatus.completed,
        'error' => MusicPlayerStatus.error,
        _ => MusicPlayerStatus.idle,
      };

  /// Serializes for transport.
  String get name => switch (this) {
        idle => 'idle',
        loading => 'loading',
        buffering => 'buffering',
        ready => 'ready',
        playing => 'playing',
        paused => 'paused',
        stopped => 'stopped',
        completed => 'completed',
        error => 'error',
      };
}

/// Repeat mode.
enum MusicRepeatMode {
  /// No repeat.
  off,

  /// Repeat the current item.
  one,

  /// Repeat the whole queue.
  all;

  /// Deserializes from transport.
  static MusicRepeatMode fromName(String? name) => switch (name) {
        'one' => MusicRepeatMode.one,
        'all' => MusicRepeatMode.all,
        _ => MusicRepeatMode.off,
      };

  /// Serializes for transport.
  String get name => switch (this) {
        off => 'off',
        one => 'one',
        all => 'all',
      };
}

/// Shuffle mode.
enum MusicShuffleMode {
  /// Sequential playback.
  off,

  /// Shuffled playback.
  on;

  /// Deserializes from transport.
  static MusicShuffleMode fromName(String? name) =>
      name == 'on' ? MusicShuffleMode.on : MusicShuffleMode.off;

  /// Serializes for transport.
  String get name => this == MusicShuffleMode.on ? 'on' : 'off';
}

/// An immutable snapshot of the player at a point in time.
final class MusicPlayerState {
  /// Creates a player snapshot.
  const MusicPlayerState({
    this.status = MusicPlayerStatus.idle,
    this.currentItem,
    this.currentIndex,
    this.position = Duration.zero,
    this.duration,
    this.queueLength = 0,
    this.shuffleMode = MusicShuffleMode.off,
    this.repeatMode = MusicRepeatMode.off,
    this.error,
    this.isPlaying = false,
    this.isBuffering = false,
  });

  /// An idle initial snapshot.
  const MusicPlayerState.initial() : this();

  /// Coarse status.
  final MusicPlayerStatus status;

  /// Reference of the current queue item, when one exists.
  final MusicItemRef? currentItem;

  /// Index of the current item in the queue.
  final int? currentIndex;

  /// Playback position within the current item.
  ///
  /// This is a UI sampling of progress, not a substitute for platform
  /// playback state.
  final Duration position;

  /// Duration of the current item; null when unknown.
  final Duration? duration;

  /// Number of items in the queue.
  final int queueLength;

  /// Current shuffle mode.
  final MusicShuffleMode shuffleMode;

  /// Current repeat mode.
  final MusicRepeatMode repeatMode;

  /// Last error, when status is [MusicPlayerStatus.error].
  final Object? error;

  /// Convenience: actively playing.
  final bool isPlaying;

  /// Convenience: loading or buffering.
  final bool isBuffering;

  /// Returns a copy with the given fields replaced.
  ///
  /// Pass `null` explicitly to clear a nullable field; omitted parameters
  /// keep their current values.
  MusicPlayerState copyWith({
    MusicPlayerStatus? status,
    Object? currentItem = _sentinel,
    Object? currentIndex = _sentinel,
    Duration? position,
    Object? duration = _sentinelDuration,
    int? queueLength,
    MusicShuffleMode? shuffleMode,
    MusicRepeatMode? repeatMode,
    Object? error = _sentinel,
    bool? isPlaying,
    bool? isBuffering,
  }) =>
      MusicPlayerState(
        status: status ?? this.status,
        currentItem: identical(currentItem, _sentinel)
            ? this.currentItem
            : currentItem as MusicItemRef?,
        currentIndex: identical(currentIndex, _sentinel)
            ? this.currentIndex
            : currentIndex as int?,
        position: position ?? this.position,
        duration: identical(duration, _sentinelDuration)
            ? this.duration
            : duration as Duration?,
        queueLength: queueLength ?? this.queueLength,
        shuffleMode: shuffleMode ?? this.shuffleMode,
        repeatMode: repeatMode ?? this.repeatMode,
        error: identical(error, _sentinel) ? this.error : error,
        isPlaying: isPlaying ?? this.isPlaying,
        isBuffering: isBuffering ?? this.isBuffering,
      );

  static const _sentinel = Object();
  static const _sentinelDuration = _sentinel;

  @override
  bool operator ==(Object other) =>
      other is MusicPlayerState &&
      other.status == status &&
      other.currentItem == currentItem &&
      other.currentIndex == currentIndex &&
      other.position == position &&
      other.duration == duration &&
      other.queueLength == queueLength &&
      other.shuffleMode == shuffleMode &&
      other.repeatMode == repeatMode &&
      other.isPlaying == isPlaying &&
      other.isBuffering == isBuffering &&
      _errorEquals(other.error);

  /// Errors are compared by runtimeType + toString so that two otherwise
  /// identical snapshots carrying equivalent error info deduplicate,
  /// while a changed error still produces a new state.
  bool _errorEquals(Object? other) {
    final mine = error;
    if (mine == null && other == null) return true;
    if (mine == null || other == null) return false;
    return mine.runtimeType == other.runtimeType &&
        mine.toString() == other.toString();
  }

  @override
  int get hashCode => Object.hash(
        status,
        currentItem,
        currentIndex,
        position,
        duration,
        queueLength,
        shuffleMode,
        repeatMode,
        isPlaying,
        isBuffering,
      );

  @override
  String toString() =>
      'MusicPlayerState($status, item: $currentIndex/${currentItem?.id}, '
      'pos: $position, dur: $duration, queue: $queueLength)';
}
