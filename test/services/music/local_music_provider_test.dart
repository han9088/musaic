import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/services/music/local_music_provider.dart';
import 'package:musaic/services/music/local_music_library.dart';
import 'package:musaic/services/music/music_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.deskbtm.muasic.query');
  late LocalMusicProvider provider;
  late String access;
  late int requests;
  late int scans;
  late bool failScan;
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
    'content identities retain metadata without assuming a file path',
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
        final tracks = library
            .album(LocalMusicLibrary.reference('30', MusicKind.album))
            .tracks!;
        expect(tracks.first.playable, isTrue);
        expect(
          library.source(tracks.first),
          'content://media/external/audio/media/4',
        );
        expect(
          library.source(tracks.last),
          'content://media/external/audio/media/5',
        );
      } finally {
        rows.removeRange(3, rows.length);
      }
    },
  );

  test('pathless content URI reaches existing player unchanged', () async {
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
    try {
      await provider.initialize();
      await provider.requestAuthorization();
      await provider.play([LocalMusicLibrary.reference('4', MusicKind.song)]);
      final source = calls.singleWhere((call) => call.method == 'setSourceUrl');
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
      rows.removeLast();
      messenger.setMockMethodCallHandler(playerChannel, null);
      messenger.setMockMethodCallHandler(globalChannel, null);
      messenger.setMockMethodCallHandler(globalEvents, null);
      if (playerEvents != null) {
        messenger.setMockMethodCallHandler(playerEvents!, null);
      }
    }
  });

  for (final action in ['next', 'pause', 'dispose']) {
    test(
      '$action interrupts an unresolved content open without late resume',
      () async {
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
