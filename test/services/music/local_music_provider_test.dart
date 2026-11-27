import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/features/artwork/source/artwork_resolver.dart';
import 'package:musaic/features/music/catalog/album_catalog_mapper.dart';
import 'package:musaic/services/music/directory_music_library.dart';
import 'package:musaic/services/music/local_music_provider.dart';
import 'package:musaic/services/music/local_music_library.dart';
import 'package:musaic/services/music/music_provider.dart';
import 'package:musaic/storage/music/music_index.dart';
import 'package:musaic_query/musaic_query.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_audio_directories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.deskbtm.muasic.query');
  late LocalMusicProvider provider;
  late String access;
  late int requests;
  late int scans;
  late bool failScan;
  late List<int> artworkQueries;
  final artworkBytes = Uint8List.fromList([1, 2, 3]);
  final rows = <Map<String, Object?>>[
    {
      '_id': 1,
      'album_id': 10,
      'title': 'First song',
      'album': 'First',
      'artist': 'Artist',
      'duration': 1000,
      '_uri': 'file:///storage/emulated/0/Music/first.mp3',
      'is_protected': false,
    },
    {
      '_id': 2,
      'album_id': 10,
      'title': 'Protected song',
      '_uri': 'ipod-library://item/protected.m4a',
      'album': 'First',
      'duration': 2000,
      'is_protected': true,
    },
    {
      '_id': 3,
      'album_id': 20,
      'title': 'Other song',
      'album': 'Second',
      '_uri': 'ipod-library://item/item.m4a?id=3',
      'is_protected': false,
    },
  ];

  setUp(() {
    access = 'notDetermined';
    requests = 0;
    scans = 0;
    failScan = false;
    artworkQueries = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'permissionsStatus':
              return access == 'authorized';
            case 'permissionsRequest':
              requests++;
              access = 'authorized';
              return access == 'authorized';
            case 'querySongs':
              scans++;
              if (failScan) throw PlatformException(code: 'libraryQueryFailed');
              return rows;
            case 'queryArtwork':
              expect(call.arguments['type'], 0);
              final id = call.arguments['id'] as int;
              artworkQueries.add(id);
              return id == 4 ? artworkBytes : null;
            default:
              throw MissingPluginException();
          }
        });
    provider = LocalMusicProvider();
  });
  tearDown(() async {
    await provider.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'initialization is inert and permission requests are explicit',
    () async {
      await provider.initialize();
      expect(requests, 0);
      expect(scans, 0);
      expect(await provider.authorizationStatus(), MusicAccess.denied);
      expect((await provider.capabilities()).library.supported, isFalse);
      await expectLater(provider.libraryAlbums(), throwsStateError);
      expect(await provider.requestAuthorization(), MusicAccess.authorized);
      expect(requests, 1);
      expect(scans, 0);
    },
  );

  test(
    'system albums paginate and preserve metadata and playable restrictions',
    () async {
      await provider.initialize();
      await provider.requestAuthorization();
      final pages = await Future.wait([
        provider.libraryAlbums(limit: 1),
        provider.libraryAlbums(limit: 1),
      ]);
      expect(scans, 1);
      final first = pages.first;
      expect(first.items.single.title, 'First');
      expect(first.nextCursor, '1');
      final second = await provider.libraryAlbums(
        limit: 1,
        cursor: first.nextCursor,
      );
      expect(second.items.single.title, 'Second');
      expect(second.nextCursor, isNull);
      final album = await provider.album(first.items.single.reference);
      expect(album.tracks!.first.duration, const Duration(seconds: 1));
      expect(album.tracks!.last.playable, isFalse);
      expect(album.tracks!.first.reference.source, MusicSource.library);
      expect(() => first.items.clear(), throwsUnsupportedError);
      expect(await provider.animatedArtwork(album.reference), isEmpty);
      expect(
        (await provider.searchAlbums('FIRST')).single.reference,
        album.reference,
      );
      await expectLater(
        provider.play([album.tracks!.last.reference]),
        throwsUnsupportedError,
      );
      await provider.pause();
    },
  );

  test(
    'scan failures retry and revoked permission does not expose cached albums',
    () async {
      await provider.initialize();
      await provider.requestAuthorization();
      failScan = true;
      await expectLater(
        provider.libraryAlbums(),
        throwsA(isA<PlatformException>()),
      );
      failScan = false;
      expect((await provider.libraryAlbums()).items.length, 2);
      access = 'denied';
      await expectLater(provider.libraryAlbums(), throwsStateError);
      expect((await provider.capabilities()).playback.supported, isFalse);
      access = 'authorized';
      await provider.libraryAlbums();
      expect(scans, 3);
    },
  );

  test(
    'invalid references and cursors are rejected without starting a player',
    () async {
      await provider.initialize();
      await provider.requestAuthorization();
      await expectLater(
        provider.libraryAlbums(cursor: '-1'),
        throwsArgumentError,
      );
      await expectLater(
        provider.libraryAlbums(cursor: 'bad'),
        throwsArgumentError,
      );
      await expectLater(
        provider.play([
          (
            provider: 'local',
            id: 'file:///outside.mp3',
            kind: MusicKind.song,
            source: MusicSource.library,
            storefront: null,
          ),
        ]),
        throwsArgumentError,
      );
      await expectLater(
        provider.album((
          provider: 'apple_music',
          id: '123',
          kind: MusicKind.album,
          source: MusicSource.catalog,
          storefront: 'cn',
        )),
        throwsArgumentError,
      );
    },
  );

  test(
    'system non-music categories are excluded without guessing unknowns',
    () async {
      rows.add({
        '_id': 99,
        'album_id': 99,
        'title': 'Notification',
        'is_music': false,
      });
      try {
        await provider.initialize();
        await provider.requestAuthorization();
        expect((await provider.libraryAlbums()).items.length, 2);
      } finally {
        rows.removeLast();
      }
    },
  );

  test('refresh replaces cached catalog with one system query', () async {
    await provider.initialize();
    await provider.requestAuthorization();
    await provider.libraryAlbums();
    await provider.searchAlbums('First');
    await provider.libraryAlbums(limit: 1, cursor: '1');
    expect(scans, 1);
    await provider.refreshLibrary();
    await provider.libraryAlbums();
    expect(scans, 2);
  });

  test(
    'MediaStore tracks resolve their own artwork without assuming a file path',
    () async {
      access = 'authorized';
      rows.addAll([
        {
          '_id': 4,
          'album_id': 30,
          'title': 'Pathless',
          '_uri': 'content://media/external/audio/media/4',
        },
        {
          '_id': 5,
          'album_id': 30,
          'title': 'Readable',
          '_uri': 'content://media/external/audio/media/5',
          '_data': '/storage/emulated/0/Music/a b.mp3',
        },
      ]);
      try {
        final library = LocalMusicLibrary();
        await library.scan();
        final album = library.album(
          LocalMusicLibrary.reference('30', MusicKind.album),
        );
        final tracks = album.tracks!;
        expect(tracks.first.playable, isTrue);
        expect(
          library.source(tracks.first.reference),
          'content://media/external/audio/media/4',
        );
        expect(
          library.source(tracks.last.reference),
          'content://media/external/audio/media/5',
        );
        expect(artworkQueries, isEmpty);
        final asset = mapProviderAlbums([album]).single['asset'] as String;
        expect(asset, tracks.first.artworkUrl);
        const resolver = ArtworkResolver();
        final resource = await resolver.resolve(asset, directories: null);
        expect((resource?.image as MemoryImage?)?.bytes, artworkBytes);
        expect(
          await resolver.resolve(tracks.last.artworkUrl!, directories: null),
          isNull,
        );
        expect(artworkQueries, [4, 5]);
      } finally {
        rows.removeRange(3, rows.length);
      }
    },
  );

  test(
    'system and folder tracks share the player and release folder access',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const playerChannel = MethodChannel('xyz.luan/audioplayers');
      const globalChannel = MethodChannel('xyz.luan/audioplayers.global');
      const globalEvents = MethodChannel('xyz.luan/audioplayers.global/events');
      MethodChannel? playerEvents;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(globalChannel, (_) async => 1);
      messenger.setMockMethodCallHandler(globalEvents, (_) async => null);
      messenger.setMockMethodCallHandler(playerChannel, (call) async {
        calls.add(call);
        final id = (call.arguments as Map)['playerId'];
        if (call.method == 'create') {
          playerEvents = MethodChannel('xyz.luan/audioplayers/events/$id');
          messenger.setMockMethodCallHandler(playerEvents!, (_) async => null);
        }
        if (call.method == 'setSourceUrl' || call.method == 'seek') {
          // Deliver the native preparation event through the real Dart adapter.
          await messenger.handlePlatformMessage(
            playerEvents!.name,
            const StandardMethodCodec().encodeSuccessEnvelope({
              'event': call.method == 'seek'
                  ? 'audio.onSeekComplete'
                  : 'audio.onPrepared',
              'value': true,
            }),
            (_) {},
          );
        }
        return call.method == 'getDuration' ? 1000 : 1;
      });
      rows.add({
        '_id': 4,
        'album_id': 30,
        'title': 'Pathless',
        '_uri': 'content://media/external/audio/media/4',
      });
      sqfliteFfiInit();
      final index = await MusicIndex.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final native = FakeDirectories();
      native.folders[root.id]![0] = {
        ...entry('a'),
        'uri': 'file:///folder/My%20song.mp3',
      };
      final directories = DirectoryMusicLibrary(
        index: index,
        directories: AudioDirectories(native),
      );
      try {
        await index.saveSource(root);
        await directories.refresh();
        final album = directories.albums.value.single;
        final folderOnly = LocalMusicProvider.folderOnly(directories);
        try {
          await folderOnly.play([album.reference]);
          expect(
            (await folderOnly.playback.first).currentItem,
            album.tracks!.first.reference,
          );
          expect((await folderOnly.playback.first).isPlaying, isTrue);
          expect(native.playbackOpened, ['a']);
          expect(scans, 0);
          expect(requests, 0);

          await folderOnly.pause();
          await folderOnly.resume();
          expect(native.playbackOpened, ['a']);
          expect(native.playbackClosed, isEmpty);
          const codec = StandardMethodCodec();
          await messenger.handlePlatformMessage(
            playerEvents!.name,
            codec.encodeSuccessEnvelope({'event': 'audio.onComplete'}),
            (_) {},
          );
          await Future<void>.delayed(Duration.zero);
          expect(native.playbackOpened, ['a', 'b']);
          expect(native.playbackClosed, ['a']);
          final nextTrack = await folderOnly.playback.first;
          expect(nextTrack.currentItem, album.tracks!.last.reference);
          expect(nextTrack.isPlaying, isTrue);
          final opened = calls.firstWhere(
            (call) => call.method == 'setSourceUrl',
          );
          expect((opened.arguments as Map)['url'], '/folder/My song.mp3');
          expect((opened.arguments as Map)['isLocal'], isTrue);

          final duration = folderOnly.playback.firstWhere(
            (state) => state.duration == const Duration(seconds: 42),
          );
          await messenger.handlePlatformMessage(
            playerEvents!.name,
            codec.encodeSuccessEnvelope({
              'event': 'audio.onDuration',
              'value': 42000,
            }),
            (_) {},
          );
          await duration;

          var nativeErrors = 0;
          final errors = folderOnly.playback.listen((state) {
            if (state.error is PlatformException) nativeErrors++;
          });
          try {
            await messenger.handlePlatformMessage(
              playerEvents!.name,
              codec.encodeErrorEnvelope(
                code: 'AndroidAudioError',
                details: 'MEDIA_ERROR_IO',
              ),
              (_) {},
            );
            await Future<void>.delayed(Duration.zero);
            expect(nativeErrors, 1);
            expect(native.playbackClosed, ['a', 'b']);
          } finally {
            await errors.cancel();
          }
        } finally {
          await folderOnly.dispose();
          if (playerEvents != null) {
            messenger.setMockMethodCallHandler(playerEvents!, null);
          }
        }
        expect(native.playbackClosed, ['a', 'b']);

        await provider.dispose();
        provider = LocalMusicProvider(directories: directories);
        await provider.initialize();
        await provider.requestAuthorization();
        await provider.play([
          LocalMusicLibrary.reference('4', MusicKind.song),
          album.tracks!.last.reference,
        ], startIndex: 1);
        expect(
          (await provider.playback.first).currentItem,
          album.tracks!.last.reference,
        );
        expect(native.playbackOpened, ['a', 'b', 'b']);
        await provider.previous();
        expect(native.playbackClosed, ['a', 'b', 'b']);
        final source = calls.lastWhere((call) => call.method == 'setSourceUrl');
        expect(
          (source.arguments as Map)['url'],
          'content://media/external/audio/media/4',
        );
        expect((source.arguments as Map)['isLocal'], isFalse);
        await provider.pause();
        await provider.seek(const Duration(milliseconds: 200));
        expect(calls.any((call) => call.method == 'pause'), isTrue);
        expect(calls.any((call) => call.method == 'seek'), isTrue);
      } finally {
        await provider.dispose();
        await directories.dispose();
        rows.removeLast();
        messenger.setMockMethodCallHandler(playerChannel, null);
        messenger.setMockMethodCallHandler(globalChannel, null);
        messenger.setMockMethodCallHandler(globalEvents, null);
        if (playerEvents != null) {
          messenger.setMockMethodCallHandler(playerEvents!, null);
        }
      }
    },
  );

  for (final action in ['next', 'pause', 'dispose']) {
    test(
      '$action interrupts an unresolved content open without late resume',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const playerChannel = MethodChannel('xyz.luan/audioplayers');
        const globalChannel = MethodChannel('xyz.luan/audioplayers.global');
        const globalEvents = MethodChannel(
          'xyz.luan/audioplayers.global/events',
        );
        MethodChannel? events;
        final opened = Completer<void>();
        final slow = Completer<Object?>();
        final urls = <String>[];
        var resumes = 0;
        messenger.setMockMethodCallHandler(globalChannel, (_) async => 1);
        messenger.setMockMethodCallHandler(globalEvents, (_) async => null);
        messenger.setMockMethodCallHandler(playerChannel, (call) async {
          final args = call.arguments as Map;
          if (call.method == 'create') {
            events = MethodChannel(
              'xyz.luan/audioplayers/events/${args['playerId']}',
            );
            messenger.setMockMethodCallHandler(events!, (_) async => null);
          }
          if (call.method == 'resume') resumes++;
          if (call.method == 'seek') {
            expect(args['position'], 200);
            await messenger.handlePlatformMessage(
              events!.name,
              const StandardMethodCodec().encodeSuccessEnvelope({
                'event': 'audio.onSeekComplete',
              }),
              (_) {},
            );
          }
          if (call.method == 'setSourceUrl') {
            urls.add(args['url'] as String);
            if (urls.length == 1) {
              opened.complete();
              return slow.future;
            }
            await messenger.handlePlatformMessage(
              events!.name,
              const StandardMethodCodec().encodeSuccessEnvelope({
                'event': 'audio.onPrepared',
                'value': true,
              }),
              (_) {},
            );
          }
          return 1;
        });
        rows.addAll([
          {
            '_id': 4,
            'album_id': 30,
            'title': 'Slow',
            '_uri': 'content://music/4',
          },
          {
            '_id': 5,
            'album_id': 30,
            'title': 'Next',
            '_uri': 'content://music/5',
          },
        ]);
        try {
          await provider.initialize();
          await provider.requestAuthorization();
          final play = provider.play([
            LocalMusicLibrary.reference('4', MusicKind.song),
            LocalMusicLibrary.reference('5', MusicKind.song),
          ]);
          await opened.future;
          switch (action) {
            case 'next':
              await provider.next().timeout(const Duration(seconds: 2));
              expect(urls, ['content://music/4', 'content://music/5']);
            case 'pause':
              await provider.pause().timeout(const Duration(seconds: 2));
              expect(resumes, 0);
              await provider.seek(const Duration(milliseconds: 200));
              await provider.resume().timeout(const Duration(seconds: 2));
              expect(urls, ['content://music/4', 'content://music/4']);
            case 'dispose':
              await provider.dispose().timeout(const Duration(seconds: 2));
          }
          await play;
          slow.completeError(PlatformException(code: 'cancelled'));
          await Future<void>.delayed(Duration.zero);
          expect(resumes, action == 'dispose' ? 0 : 1);
        } finally {
          if (!slow.isCompleted) {
            slow.completeError(PlatformException(code: 'cancelled'));
          }
          await provider.dispose();
          rows.removeRange(3, rows.length);
          messenger.setMockMethodCallHandler(playerChannel, null);
          messenger.setMockMethodCallHandler(globalChannel, null);
          messenger.setMockMethodCallHandler(globalEvents, null);
          if (events != null) {
            messenger.setMockMethodCallHandler(events!, null);
          }
        }
      },
    );
  }

  test('large library pagination reuses one query and no artwork requests', () async {
    rows.addAll(
      List.generate(
        4096,
        (i) => {
          '_id': i + 100,
          'album_id': i ~/ 10 + 100,
          'title': 'Track $i',
          'album': 'Album ${i ~/ 10}',
          '_uri': 'file:///music/$i.mp3',
          'track': i % 10,
        },
      ),
    );
    try {
      final watch = Stopwatch()..start();
      await provider.initialize();
      await provider.requestAuthorization();
      String? cursor;
      var count = 0;
      do {
        final page = await provider.libraryAlbums(limit: 100, cursor: cursor);
        count += page.items.length;
        cursor = page.nextCursor;
      } while (cursor != null);
      expect(count, 412);
      expect(scans, 1);
      // ignore: avoid_print
      print(
        'System catalog: 4099 tracks, $count albums, ${watch.elapsedMilliseconds} ms',
      );
    } finally {
      rows.removeRange(3, rows.length);
    }
  });

  test('state replays and disposal is idempotent', () async {
    await provider.initialize();
    expect((await provider.playback.first).status, MusicPlaybackStatus.idle);
    await provider.dispose();
    await provider.dispose();
    await expectLater(provider.libraryAlbums(), throwsStateError);
    expect(await provider.playback.isEmpty, isTrue);
  });
}
