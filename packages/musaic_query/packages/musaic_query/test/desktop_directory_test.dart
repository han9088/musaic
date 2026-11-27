import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic_query/musaic_query.dart';
import 'package:musaic_query_macos/musaic_query_macos.dart';
import 'package:musaic_query_windows/musaic_query_windows.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  late File audio;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('musaic-desktop-query-');
    audio = File.fromUri(folder.uri.resolveUri(Uri(path: 'Track # 1.wav')));
    await audio.writeAsString('audio fixture');
  });

  tearDown(() => folder.delete(recursive: true));

  test('Windows registers a paged directory scanner and local playback paths',
      () async {
    MusaicQueryWindows.registerWith();
    final directories = MusaicQuery().directories;
    expect(await directories.supported, isTrue);
    final source = await directories.openPath(folder.path);
    expect((await directories.restore(source)).id, source.id);

    for (var index = 0; index < 130; index++) {
      await File.fromUri(folder.uri.resolve('file-$index.txt')).create();
    }
    final pages = await directories.scan(source).toList();
    expect(pages, hasLength(2));
    expect(pages.every((page) => page.error == null), isTrue);
    final track = pages.expand((page) => page.entries).single;
    expect(track.name, 'Track # 1.wav');
    expect(track.parent, source.id);
    final playback = await directories.openPlayback(source, track);
    expect(await File.fromUri(playback.uri).readAsString(), 'audio fixture');
    await playback.close();

    final unrelated = await File.fromUri(folder.parent.uri.resolve(
      '${folder.uri.pathSegments.where((segment) => segment.isNotEmpty).last}.wav',
    )).create();
    addTearDown(unrelated.delete);
    final forged =
        AudioFileEntry({...track.data, 'id': unrelated.uri.toString()});
    await expectLater(
        directories.openPlayback(source, forged), throwsArgumentError);
  });

  test(
      'macOS restores a bookmark and closes playback separately from its folder',
      () async {
    const channel = MethodChannel('com.deskbtm.musaic.query/macos_directories');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    final path = await folder.resolveSymbolicLinks();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'pick':
          return {'path': path, 'token': 'original-bookmark'};
        case 'restore':
          return 'renewed-bookmark';
        case 'retainPlayback':
          return 'playback-session';
        default:
          return null;
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    MusaicQueryMacos.registerWith();
    final source = (await MusaicQuery().directories.pick())!;
    expect(source.token, 'original-bookmark');

    MusaicQueryMacos.registerWith();
    final directories = MusaicQuery().directories;
    final restored = await directories.restore(source);
    expect(restored.token, 'renewed-bookmark');
    expect(restored.id, source.id);
    final track =
        (await directories.scan(restored).toList()).single.entries.single;
    final playback = await directories.openPlayback(restored, track);
    await directories.release(restored);
    await playback.close();
    await playback.close();

    expect(calls.map((call) => call.method), [
      'pick',
      'restore',
      'retainPlayback',
      'release',
      'releasePlayback',
    ]);
    expect(calls[2].arguments, containsPair('token', 'renewed-bookmark'));
    expect(calls.last.arguments, {'session': 'playback-session'});
  });
}
