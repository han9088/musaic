import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:metadata_audio/metadata_audio.dart';
import 'package:musaic_query_platform_interface/musaic_query_platform_interface.dart';
import 'package:path/path.dart' as p;

import 'src/desktop_artwork_cache.dart';

class DesktopMusaicQuery extends MusaicQueryPlatform {
  DesktopMusaicQuery(this.directories);

  @override
  final DesktopAudioDirectory directories;

  @override
  Future<void> setLogConfig(LogConfig? logConfig) async {}

  @override
  Future<bool> permissionsStatus() async => false;

  @override
  Future<bool> permissionsRequest({bool retryRequest = false}) async => false;
}

abstract class DesktopAudioDirectory extends AudioDirectoryPlatform {
  DesktopAudioDirectory();

  static const _pageSize = 128;
  static const _maxSessions = 16;
  final _scans = <String, _DirectoryScan>{};
  final _artwork = DesktopArtworkCache();
  int _nextScan = 0;

  @override
  Future<bool> get supported async => true;

  Future<AudioDirectory?> pickDirectory();

  Future<AudioDirectory> openDirectory(String path, {String? token}) async {
    final root = await Directory(path).resolveSymbolicLinks();
    if (await FileSystemEntity.type(root) != FileSystemEntityType.directory) {
      throw FileSystemException('Audio directory is unavailable', path);
    }
    final id = Uri.directory(root).toString();
    final name = p.basename(root);
    return AudioDirectory(
      id: id,
      name: name.isEmpty ? root : name,
      token: token ?? id,
    );
  }

  Future<AudioDirectory> restoreDirectory(AudioDirectory source) async {
    final root = await openDirectory(
      Uri.parse(source.id).toFilePath(),
      token: source.token,
    );
    if (root.id != source.id) throw StateError('Audio directory moved');
    return root;
  }

  Future<void> releaseDirectory(AudioDirectory source) async {}

  Future<String?> retainPlayback(AudioDirectory source) async => null;

  Future<void> releasePlayback(String session) async {}

  AudioDirectory _source(Map<String, Object?> args) =>
      AudioDirectory.fromMap(args['source'] as Map);

  @override
  Future<Object?> invoke(
    String method, [
    Map<String, Object?> args = const {},
  ]) async {
    switch (method) {
      case 'pick':
        return (await pickDirectory())?.toMap();
      case 'openPath':
        return (await openDirectory(args['path'] as String)).toMap();
      case 'restore':
        return (await restoreDirectory(_source(args))).toMap();
      case 'release':
        await releaseDirectory(_source(args));
        return null;
      case 'open':
        final path = await _entryPath(
          _source(args),
          args['directory'] as String,
          directory: true,
        );
        if (_scans.length >= _maxSessions) {
          throw StateError('Too many open audio directory scans');
        }
        final session = (++_nextScan).toString();
        _scans[session] = _DirectoryScan(
          args['directory'] as String,
          StreamIterator(Directory(path).list(followLinks: false)),
        );
        return session;
      case 'next':
        final scan = _scans[args['session']];
        if (scan == null) throw StateError('Audio directory scan is closed');
        return scan.next();
      case 'close':
        await _scans.remove(args['session'])?.entries.cancel();
        return null;
      case 'metadata':
        return _readMetadata(await _filePath(_source(args), args['file']));
      case 'openPlayback':
        final source = _source(args);
        final path = await _filePath(source, args['file']);
        await (await File(path).open()).close();
        final session = await retainPlayback(source);
        return {'uri': Uri.file(path).toString(), 'session': session};
      case 'closePlayback':
        await releasePlayback(args['session'] as String);
        return null;
      case 'mediaPaths':
        return const <String, String>{};
      case 'artwork':
        final source = _source(args);
        final file = AudioFileEntry(args['file'] as Map);
        final cover = args['cover'] == null
            ? null
            : AudioFileEntry(args['cover'] as Map);
        final path = await _entryPath(source, file.id);
        return _artwork.read(
          path,
          cover == null ? null : await _coverPath(source, cover),
          args['size'] as int,
          reusable:
              file.data['reliable'] == true &&
              (cover == null || cover.data['reliable'] == true),
        );
      case 'clearCache':
        await _artwork.clear();
        return null;
    }
    throw UnsupportedError('Unknown audio directory operation: $method');
  }

  Future<String> _filePath(AudioDirectory source, Object? rawFile) =>
      _entryPath(source, AudioFileEntry(rawFile as Map).id);

  Future<String?> _coverPath(
    AudioDirectory source,
    AudioFileEntry cover,
  ) async {
    try {
      return await _entryPath(source, cover.id);
    } on FileSystemException {
      if (!await File.fromUri(Uri.parse(cover.id)).exists()) return null;
      rethrow;
    }
  }

  Future<String> _entryPath(
    AudioDirectory source,
    String id, {
    bool directory = false,
  }) async {
    final root = p.normalize(Uri.parse(source.id).toFilePath());
    final path = p.normalize(Uri.parse(id).toFilePath());
    if (!p.equals(root, path) && !p.isWithin(root, path)) {
      throw ArgumentError('Audio entry is outside its directory');
    }
    await restoreDirectory(source);
    final type = await FileSystemEntity.type(path, followLinks: false);
    final expected = directory
        ? FileSystemEntityType.directory
        : FileSystemEntityType.file;
    if (type != expected)
      throw FileSystemException('Audio entry is unavailable', path);
    final resolved = await (directory ? Directory(path) : File(path))
        .resolveSymbolicLinks();
    // A Windows filesystem can return a canonical path with a device prefix.
    if (!p.equals(path, Uri.file(resolved).toFilePath())) {
      throw FileSystemException(
        'Symbolic links are unavailable in an audio directory',
        path,
      );
    }
    return path;
  }
}

class _DirectoryScan {
  _DirectoryScan(this.parent, this.entries);

  final String parent;
  final StreamIterator<FileSystemEntity> entries;
  bool _reading = false;
  bool _done = false;

  Future<Map<String, Object?>> next() async {
    if (_reading) throw StateError('Audio directory scan is already reading');
    _reading = true;
    final result = <Map<String, Object?>>[];
    final errors = <String>[];
    try {
      for (
        var count = 0;
        !_done && count < DesktopAudioDirectory._pageSize;
        count++
      ) {
        try {
          _done = !await entries.moveNext();
        } on FileSystemException catch (error) {
          _done = true;
          errors.add(error.message);
        }
        if (_done) break;
        final entry = entries.current;
        if (entry is Link) continue;
        try {
          final stat = await entry.stat();
          if (stat.type == FileSystemEntityType.notFound) {
            errors.add('Audio directory entry disappeared during enumeration');
            continue;
          }
          final directory = entry is Directory;
          final uri = directory
              ? Uri.directory(entry.path)
              : Uri.file(entry.path);
          result.add({
            'id': uri.toString(),
            'uri': uri.toString(),
            'parent': parent,
            'name': p.basename(entry.path),
            'directory': directory,
            if (!directory) 'size': stat.size,
            if (!directory) 'modified': stat.modified.millisecondsSinceEpoch,
            if (!directory) 'reliable': true,
          });
        } on FileSystemException catch (error) {
          errors.add(error.message);
        }
      }
      return {'entries': result, 'done': _done, 'errors': errors};
    } finally {
      _reading = false;
    }
  }
}

Future<Map<String, Object?>> _readMetadata(String path) async {
  final before = await fileStamp(path);
  final metadata = await Isolate.run(() => _parseMetadata(path));
  if (await fileStamp(path) != before) {
    throw FileSystemException(
      'Audio file changed while reading metadata',
      path,
    );
  }
  return metadata;
}

Future<Map<String, Object?>> _parseMetadata(String path) async {
  try {
    final metadata = await parseFile(
      path,
      options: const ParseOptions(skipCovers: true),
    );
    final tags = metadata.common;
    final duration = metadata.format.duration;
    return {
      'title': tags.title,
      'artist': tags.artist,
      'album': tags.album,
      'albumArtist': tags.albumartist,
      'track': tags.track.no?.toString(),
      'disc': tags.disk.no?.toString(),
      'genre': tags.genre?.firstOrNull,
      if (duration != null && duration.isFinite && duration >= 0)
        'durationMs': (duration * 1000).round(),
    };
  } on UnsupportedFileTypeError {
    return const {};
  }
}
