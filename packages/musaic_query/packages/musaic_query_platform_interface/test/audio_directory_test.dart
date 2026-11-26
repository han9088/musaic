import 'package:flutter_test/flutter_test.dart';
import 'package:musaic_query_platform_interface/audio_directory.dart';

class Pages extends AudioDirectoryPlatform {
  int closed = 0;
  final opened = <String>[];
  bool partial = false;
  @override
  Future<Object?> invoke(String method,
      [Map<String, Object?> args = const {}]) async {
    if (method == 'open') {
      opened.add(args['directory'] as String);
      return args['directory'];
    }
    if (method == 'close') {
      closed++;
      return null;
    }
    if (method == 'next') {
      final id = args['session'] as String;
      return {
        'done': true,
        'errors': partial ? ['unreadable entry'] : [],
        'entries': id == 'root'
            ? [
                {
                  'id': 'sub',
                  'name': 'Sub',
                  'parent': 'root',
                  'uri': 'sub',
                  'directory': true
                },
                {
                  'id': 'hidden',
                  'name': '.hidden.mp3',
                  'parent': 'root',
                  'uri': 'hidden'
                },
                {
                  'id': 'song',
                  'name': 'song.MP3',
                  'parent': 'root',
                  'uri': 'song',
                  'size': 100
                },
                {
                  'id': 'cover',
                  'name': 'COVER.JPG',
                  'parent': 'root',
                  'uri': 'cover',
                  'size': 500
                },
              ]
            : [
                {
                  'id': 'root',
                  'name': 'cycle',
                  'parent': 'sub',
                  'uri': 'root',
                  'directory': true
                },
                {
                  'id': 'child',
                  'name': 'child.flac',
                  'parent': 'sub',
                  'uri': 'child'
                },
              ]
      };
    }
    throw UnsupportedError(method);
  }
}

void main() {
  const root = AudioDirectory(id: 'root', name: 'Music', token: 'grant');
  test(
      'recursive scan terminates cycles; hidden files excluded; summaries reuse pages',
      () async {
    final native = Pages();
    final summaries = AudioFolderSummaries(root);
    final pages = await AudioDirectories(native).scan(root).toList();
    for (final page in pages) {
      summaries.add(page);
    }
    expect(native.opened, ['root', 'sub']);
    expect(native.closed, 2);
    expect(pages.expand((p) => p.entries).any((e) => e.id == 'hidden'), false);
    final summary =
        summaries.snapshot(recursive: true).firstWhere((s) => s.id == 'root');
    expect(summary.count, 2);
    expect(summary.bytes, null);
    expect(summary.complete, true);
  });
  test('nonrecursive and excluded directory scans do not descend', () async {
    final native = Pages();
    await AudioDirectories(native)
        .scan(root, options: const AudioScanOptions(recursive: false))
        .drain<void>();
    expect(native.opened, ['root']);
    native.opened.clear();
    await AudioDirectories(native)
        .scan(root,
            options: const AudioScanOptions(excludedDirectories: {'Sub'}))
        .drain<void>();
    expect(native.opened, ['root']);
  });
  test('cancellation closes active enumerator', () async {
    final native = Pages();
    final cancel = AudioScanCancellation();
    await for (final _
        in AudioDirectories(native).scan(root, cancellation: cancel)) {
      cancel.cancel();
    }
    expect(native.opened, ['root']);
    expect(native.closed, 1);
  });
  test(
      'unknown values do not pass constrained filters; boundaries are inclusive',
      () {
    const filter = AudioFilter(
        minDurationMs: 10,
        maxDurationMs: 20,
        minSize: 100,
        extensions: {'MP3'},
        categories: {AudioCategory.music});
    expect(
        filter.matches(
            extension: 'mp3',
            durationMs: 10,
            size: 100,
            classification: {AudioCategory.music: true}),
        true);
    expect(filter.matches(extension: 'mp3', durationMs: 10, size: 100), false);
    expect(
        filter.matches(
            extension: 'mp3',
            size: 100,
            classification: {AudioCategory.music: true}),
        false);
    expect(() => const AudioFilter(minSize: 2, maxSize: 1).validate(),
        throwsArgumentError);
    expect(() => const AudioScanOptions(minSize: -1).validate(),
        throwsArgumentError);
  });
  test('partial pages retain healthy entries and mark summaries incomplete',
      () async {
    final native = Pages()..partial = true;
    final summaries = AudioFolderSummaries(root);
    final pages = await AudioDirectories(native).scan(root).toList();
    expect(pages.first.entries.any((entry) => entry.id == 'song'), true);
    expect(pages.first.error, isA<StateError>());
    for (final page in pages) {
      summaries.add(page);
    }
    expect(
        summaries.snapshot(recursive: true).every((folder) => !folder.complete),
        true);
    expect(native.closed, 2);
  });
  test('directories and extensionless names are not audio or cover files', () {
    expect(AudioFileEntry({'name': 'mp3'}).isAudio, false);
    expect(AudioFileEntry({'name': 'album.mp3', 'directory': true}).isAudio,
        false);
    expect(
        AudioFileEntry({'name': 'cover.jpg', 'directory': true}).coverPriority,
        null);
  });
  test('Web and unsupported adapters fail explicitly', () async {
    const platform = AudioDirectoryPlatform();
    expect(await platform.supported, false);
    await expectLater(platform.invoke('pick'), throwsUnsupportedError);
    expect(await const AudioDirectories(platform).mediaPaths(['content://doc']),
        isEmpty);
  });
}
