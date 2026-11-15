import 'package:flutter/services.dart';

/// A persisted grant, not a filesystem path. Keep [token] private to the app.
class AudioDirectory {
  const AudioDirectory(
      {required this.id, required this.name, required this.token});
  factory AudioDirectory.fromMap(Map<Object?, Object?> map) => AudioDirectory(
      id: map['id'] as String,
      name: map['name'] as String,
      token: map['token'] as String);
  final String id, name, token;
  Map<String, Object?> toMap() => {'id': id, 'name': name, 'token': token};
}

/// Lightweight enumeration data. Null size/time means unknown, never zero.
class AudioFileEntry {
  AudioFileEntry(Map<Object?, Object?> map)
      : data =
            Map<String, Object?>.unmodifiable(Map<String, Object?>.from(map));
  final Map<String, Object?> data;
  String get id => data['id'] as String;
  String get uri => data['uri'] as String;
  String get name => data['name'] as String;
  String get parent => data['parent'] as String;
  bool get isDirectory => data['directory'] == true;
  int? get size => data['size'] as int?;
  int? get modified => data['modified'] as int?;
  String get extension =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';
  bool get isAudio =>
      !isDirectory &&
      const {
        'mp3',
        'm4a',
        'aac',
        'flac',
        'wav',
        'ogg',
        'opus',
        'aiff',
        'aif',
        'caf',
        'amr',
        'wma'
      }.contains(extension);
  int? get coverPriority {
    if (isDirectory) return null;
    final parts = name.toLowerCase().split('.');
    if (parts.length != 2) return null;
    final stem = const ['cover', 'folder', 'front', 'album', 'artwork']
        .indexOf(parts.first);
    final ext = const ['jpg', 'jpeg', 'png'].indexOf(parts.last);
    return stem < 0 || ext < 0 ? null : stem * 3 + ext;
  }
}

class AudioScanOptions {
  const AudioScanOptions(
      {this.recursive = true,
      this.includeHidden = false,
      this.excludedDirectories = const {},
      this.extensions = const {},
      this.excludedExtensions = const {},
      this.minSize,
      this.maxSize});
  final bool recursive, includeHidden;

  /// Exact resource IDs or directory names; these change scan scope, not display.
  final Set<String> excludedDirectories, extensions, excludedExtensions;
  final int? minSize, maxSize;
  void validate() {
    if ((minSize ?? 0) < 0 ||
        (maxSize ?? 0) < 0 ||
        (minSize != null && maxSize != null && minSize! > maxSize!)) {
      throw ArgumentError('Invalid inclusive size range');
    }
  }

  bool accepts(AudioFileEntry e) =>
      e.isAudio &&
      (extensions.isEmpty ||
          extensions.map((s) => s.toLowerCase()).contains(e.extension)) &&
      !excludedExtensions.map((s) => s.toLowerCase()).contains(e.extension) &&
      (minSize == null || e.size != null && e.size! >= minSize!) &&
      (maxSize == null || e.size != null && e.size! <= maxSize!);
}

class AudioScanCancellation {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// A directory page. A failed page prevents deletion reconciliation for the scan.
class AudioDirectoryPage {
  const AudioDirectoryPage(this.directory, this.entries,
      {this.error, this.directoryComplete = false});
  final String directory;
  final List<AudioFileEntry> entries;
  final Object? error;
  final bool directoryComplete;
}

/// Native adapter. Web explicitly rejects directory operations.
class AudioDirectoryPlatform {
  const AudioDirectoryPlatform();
  Future<Object?> invoke(String method,
          [Map<String, Object?> args = const {}]) =>
      Future.error(
          UnsupportedError('Native audio directories are unavailable'));
  Future<bool> get supported async => false;
}

class MethodChannelAudioDirectory extends AudioDirectoryPlatform {
  const MethodChannelAudioDirectory();
  static const channel = MethodChannel('com.deskbtm.muasic.query/directories');
  @override
  Future<bool> get supported async {
    try {
      return await channel.invokeMethod<bool>('supported') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<Object?> invoke(String method,
          [Map<String, Object?> args = const {}]) =>
      channel.invokeMethod<Object?>(method, args);
}

/// Enumeration is pull-based: at most one native page (128 entries) in flight.
class AudioDirectories {
  const AudioDirectories(this.platform);
  final AudioDirectoryPlatform platform;
  Future<bool> get supported => platform.supported;
  Future<AudioDirectory?> pick() async {
    final map = await platform.invoke('pick');
    return map == null ? null : AudioDirectory.fromMap(map as Map);
  }

  Future<AudioDirectory> openPath(String path) async => AudioDirectory.fromMap(
      await platform.invoke('openPath', {'path': path}) as Map);
  Future<AudioDirectory> restore(AudioDirectory source) async =>
      AudioDirectory.fromMap(
          await platform.invoke('restore', {'source': source.toMap()}) as Map);
  Future<void> release(AudioDirectory source) async {
    await platform.invoke('release', {'source': source.toMap()});
  }

  Stream<AudioDirectoryPage> scan(
    AudioDirectory source, {
    AudioScanOptions options = const AudioScanOptions(),
    AudioScanCancellation? cancellation,
  }) async* {
    options.validate();
    final pending = <String>[source.id];
    final seen = <String>{};
    while (pending.isNotEmpty && cancellation?.isCancelled != true) {
      final directory = pending.removeLast();
      if (!seen.add(directory)) continue;
      String? session;
      try {
        session = await platform.invoke(
                'open', {'source': source.toMap(), 'directory': directory})
            as String;
        while (cancellation?.isCancelled != true) {
          final page = Map<String, Object?>.from(
              await platform.invoke('next', {'session': session}) as Map);
          final entries = <AudioFileEntry>[];
          for (final map in page['entries'] as List) {
            final entry = AudioFileEntry(map as Map);
            if (!options.includeHidden && entry.name.startsWith('.')) continue;
            if (entry.isDirectory) {
              if (options.excludedDirectories.contains(entry.id) ||
                  options.excludedDirectories.contains(entry.name)) {
                continue;
              }
              if (options.recursive) pending.add(entry.id);
              entries.add(entry);
            } else if (options.accepts(entry) || entry.coverPriority != null) {
              entries.add(entry);
            }
          }
          if (cancellation?.isCancelled == true) break;
          final done = page['done'] == true;
          final errors = page['errors'] as List? ?? const [];
          yield AudioDirectoryPage(directory, entries,
              directoryComplete: done,
              error: errors.isEmpty ? null : StateError(errors.join('; ')));
          if (done) break;
        }
      } catch (error) {
        yield AudioDirectoryPage(directory, const [], error: error);
      } finally {
        if (session != null) {
          await platform.invoke('close', {'session': session});
        }
      }
    }
  }

  Future<Map<String, Object?>> metadata(
          AudioDirectory source, AudioFileEntry file) async =>
      Map<String, Object?>.from(await platform.invoke(
          'metadata', {'source': source.toMap(), 'file': file.data}) as Map);
  Future<String?> artwork(
    AudioDirectory source,
    AudioFileEntry file, {
    AudioFileEntry? cover,
    int size = 512,
  }) async {
    RangeError.checkValueInInterval(size, 1, 4096, 'size');
    return await platform.invoke('artwork', {
      'source': source.toMap(),
      'file': file.data,
      'cover': cover?.data,
      'size': size
    }) as String?;
  }

  Future<void> clearArtworkCache() async {
    await platform.invoke('clearCache');
  }
}

/// Null classification stays unknown. A requested category must be known true.
class AudioFilter {
  const AudioFilter(
      {this.minDurationMs,
      this.maxDurationMs,
      this.minSize,
      this.maxSize,
      this.extensions = const {},
      this.excludedExtensions = const {},
      this.categories = const {}});
  final int? minDurationMs, maxDurationMs, minSize, maxSize;
  final Set<String> extensions, excludedExtensions;
  final Set<AudioCategory> categories;
  void validate() {
    for (final range in [
      [minDurationMs, maxDurationMs],
      [minSize, maxSize]
    ]) {
      if ((range[0] ?? 0) < 0 ||
          (range[1] ?? 0) < 0 ||
          range[0] != null && range[1] != null && range[0]! > range[1]!) {
        throw ArgumentError('Invalid inclusive audio filter range');
      }
    }
  }

  bool matches(
      {required String extension,
      int? durationMs,
      int? size,
      Map<AudioCategory, bool?> classification = const {}}) {
    validate();
    final ext = extension.toLowerCase();
    return (minDurationMs == null ||
            durationMs != null && durationMs >= minDurationMs!) &&
        (maxDurationMs == null ||
            durationMs != null && durationMs <= maxDurationMs!) &&
        (minSize == null || size != null && size >= minSize!) &&
        (maxSize == null || size != null && size <= maxSize!) &&
        (extensions.isEmpty || extensions.any((e) => e.toLowerCase() == ext)) &&
        !excludedExtensions.any((e) => e.toLowerCase() == ext) &&
        (categories.isEmpty ||
            categories.any((category) => classification[category] == true));
  }
}

enum AudioCategory { music, ringtone, notification, alarm, podcast, audiobook }

class AudioFolderSummary {
  const AudioFolderSummary(
      {required this.id,
      required this.name,
      required this.count,
      required this.bytes,
      required this.complete,
      required this.recursive});
  final String id, name;
  final int count;
  final int? bytes;
  final bool complete, recursive;
}

/// Feed the same pages used for indexing; no second directory traversal.
class AudioFolderSummaries {
  AudioFolderSummaries(AudioDirectory source) : _root = source.id {
    _names[source.id] = source.name;
  }
  final String _root;
  final _names = <String, String>{};
  final _parents = <String, String>{};
  final _counts = <String, int>{};
  final _bytes = <String, int>{};
  final _unknown = <String>{};
  final _complete = <String>{};
  final _failed = <String>{};
  void add(AudioDirectoryPage page) {
    if (page.error != null) _failed.add(page.directory);
    if (page.directoryComplete) _complete.add(page.directory);
    for (final entry in page.entries) {
      if (entry.isDirectory) {
        _names.putIfAbsent(entry.id, () => entry.name);
        if (entry.id != _root) {
          _parents.putIfAbsent(entry.id, () => entry.parent);
        }
      } else if (entry.isAudio) {
        _counts.update(entry.parent, (n) => n + 1, ifAbsent: () => 1);
        if (entry.size == null) {
          _unknown.add(entry.parent);
        } else {
          _bytes.update(entry.parent, (n) => n + entry.size!,
              ifAbsent: () => entry.size!);
        }
      }
    }
  }

  List<AudioFolderSummary> snapshot({bool recursive = false}) {
    final counts = Map<String, int>.of(_counts);
    final bytes = Map<String, int>.of(_bytes);
    final unknown = Set<String>.of(_unknown);
    final complete = {
      for (final id in _names.keys)
        id: _complete.contains(id) && !_failed.contains(id)
    };
    if (recursive) {
      final remaining = {for (final id in _names.keys) id: 0};
      for (final parent in _parents.values) {
        if (remaining.containsKey(parent)) {
          remaining[parent] = remaining[parent]! + 1;
        }
      }
      final leaves = [
        for (final id in remaining.keys)
          if (remaining[id] == 0) id
      ];
      final processed = <String>{};
      while (leaves.isNotEmpty) {
        final id = leaves.removeLast();
        if (!processed.add(id)) continue;
        final parent = _parents[id];
        if (parent == null || !remaining.containsKey(parent)) continue;
        counts[parent] = (counts[parent] ?? 0) + (counts[id] ?? 0);
        bytes[parent] = (bytes[parent] ?? 0) + (bytes[id] ?? 0);
        if (unknown.contains(id)) unknown.add(parent);
        complete[parent] = complete[parent]! && complete[id]!;
        remaining[parent] = remaining[parent]! - 1;
        if (remaining[parent] == 0) leaves.add(parent);
      }
      // Invalid provider cycles cannot produce trustworthy recursive totals.
      for (final id in _names.keys.where((id) => !processed.contains(id))) {
        complete[id] = false;
      }
    }
    return [
      for (final id in _names.keys)
        AudioFolderSummary(
          id: id,
          name: _names[id]!,
          count: counts[id] ?? 0,
          bytes: unknown.contains(id) ? null : bytes[id] ?? 0,
          complete: complete[id]!,
          recursive: recursive,
        )
    ];
  }
}
