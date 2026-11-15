import 'dart:async';

import 'package:musaic_query/musaic_query.dart';

const root = AudioDirectory(id: 'root', name: 'Music', token: 'grant');
Map<String, Object?> entry(
  String id, {
  int? modified = 1,
  int? size = 100,
  String parent = 'root',
  bool directory = false,
  String? name,
}) => {
  'id': id,
  'uri': 'file:///$id',
  'name': name ?? '$id.mp3',
  'parent': parent,
  'size': size,
  'modified': modified,
  'directory': directory,
};

class FakeDirectories extends AudioDirectoryPlatform {
  final folders = <String, List<Map<String, Object?>>>{
    'root': [entry('a'), entry('b')],
  };
  final offsets = <String, int>{};
  final parsed = <String>[];
  final failures = <String>{};
  final partialFailures = <String>{};
  final damaged = <String>{};
  int maxPage = 128, closes = 0, artworkCalls = 0;
  Completer<void>? gate, releaseGate;
  int picks = 0, releases = 0;
  final artworkGates = <Completer<String?>>[];
  bool restoreFails = false;
  final deniedSources = <String>{};
  @override
  Future<Object?> invoke(
    String method, [
    Map<String, Object?> args = const {},
  ]) async {
    switch (method) {
      case 'pick':
        picks++;
        return root.toMap();
      case 'restore':
        if (restoreFails ||
            deniedSources.contains(
              (args['source'] as Map<String, Object?>)['id'],
            )) {
          throw StateError('permission denied');
        }
        return args['source'];
      case 'open':
        final id = args['directory'] as String;
        if (failures.contains(id)) throw StateError('cannot list $id');
        offsets[id] = 0;
        return id;
      case 'next':
        final id = args['session'] as String;
        final all = folders[id] ?? [];
        final offset = offsets[id]!;
        final page = all.skip(offset).take(maxPage).toList();
        offsets[id] = offset + page.length;
        return {
          'entries': page,
          'done': offset + page.length >= all.length,
          'errors': partialFailures.contains(id) ? ['entry unavailable'] : <String>[],
        };
      case 'close':
        closes++;
        return null;
      case 'metadata':
        final file = args['file'] as Map<String, Object?>;
        parsed.add(file['id'] as String);
        await gate?.future;
        if (damaged.contains(file['id'])) throw StateError('damaged');
        return {'title': file['name'], 'album': 'Album', 'durationMs': 60000};
      case 'artwork':
        final position = artworkCalls++;
        if (position < artworkGates.length) {
          return artworkGates[position].future;
        }
        return 'file:///cover.jpg';
      case 'clearCache':
        return null;
      case 'release':
        releases++;
        await releaseGate?.future;
        return null;
      default:
        throw UnsupportedError(method);
    }
  }
}
