/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'music_item_ref.dart';
import 'resource_models.dart';

/// One entry in a player queue.
final class MusicQueueEntry {
  /// Creates a queue entry.
  const MusicQueueEntry({required this.ref, this.song});

  /// The queue item reference.
  final MusicItemRef ref;

  /// Resolved song metadata, when the platform provided it.
  final MusicSong? song;

  /// Serializes for transport.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'ref': ref.toJson(),
        if (song != null) 'song': song!.raw,
      };

  @override
  bool operator ==(Object other) =>
      other is MusicQueueEntry && other.ref == ref;

  @override
  int get hashCode => ref.hashCode;

  @override
  String toString() => 'MusicQueueEntry($ref)';
}

/// An immutable queue snapshot.
final class MusicQueue {
  /// Creates a queue snapshot.
  const MusicQueue({required this.entries, this.currentIndex});

  /// An empty queue.
  const MusicQueue.empty()
      : entries = const [],
        currentIndex = null;

  /// The queue items in order.
  final List<MusicQueueEntry> entries;

  /// Index of the currently playing item, when known.
  final int? currentIndex;

  /// Number of items.
  int get length => entries.length;

  /// The current entry, when it exists.
  MusicQueueEntry? get currentEntry =>
      currentIndex == null || currentIndex! >= entries.length
          ? null
          : entries[currentIndex!];
}
