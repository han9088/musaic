import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:audius_sdk/audius_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musaic/features/music/catalog/album_catalog_mapper.dart';
import 'package:musaic/features/music/playback/album_playback.dart';
import 'package:musaic/services/music/audius_music_provider.dart';
import 'package:musaic/services/music/music_provider.dart';

const _album = {
  'id': 'album-id',
  'playlist_name': 'Album',
  'is_album': true,
  'track_count': 2,
  'artwork': {'480x480': 'https://art.example/cover.jpg'},
  'user': {'id': 'artist-id', 'name': 'Album Artist'},
};
const _playlist = {
  'id': 'playlist-id',
  'playlist_name': 'List',
  'is_album': false,
};
const _tracks = [
  {
    'id': 'one',
    'title': 'One',
    'duration': 12,
    'user': {'name': 'Track Artist'},
  },
  {'id': 'two', 'title': 'Two', 'duration': 15},
];
const _origin = MusicSource.catalog;

MusicReference _ref(String id, MusicKind kind) =>
    (id: id, kind: kind, provider: 'audius', source: _origin, storefront: null);

http.Response _json(Object data) => http.Response(
  jsonEncode({'data': data}),
  200,
  headers: {'content-type': 'application/json'},
);

final class _Player extends Fake implements AudioPlayer {
  final events = StreamController<AudioEvent>.broadcast();
  final positions = StreamController<Duration>.broadcast();
  final urls = <String>[];
  final actions = <String>[];
  bool disposed = false;
  Completer<void>? prepareGate;

  @override
  Stream<AudioEvent> get eventStream => events.stream;
  @override
  Stream<Duration> get onPositionChanged => positions.stream;
  @override
  Future<void> setAudioContext(AudioContext context) async =>
      actions.add('context');
  @override
  Future<void> stop() async => actions.add('stop');
  @override
  Future<void> setSource(Source source) async {
    urls.add((source as UrlSource).url);
    await prepareGate?.future;
  }

  @override
  Future<void> resume() async => actions.add('resume');
  @override
  Future<void> pause() async => actions.add('pause');
  @override
  Future<void> seek(Duration position) async =>
      actions.add('seek:${position.inSeconds}');
  @override
  Future<void> dispose() async {
    disposed = true;
    await events.close();
    await positions.close();
  }
}

void main() {
  test(
    'a favorites queue survives swapping back to the trending canvas',
    () async {
      final player = _Player();
      final client = MockClient((request) async {
        switch (request.url.path) {
          case '/v1/playlists/trending':
            return _json([_album]);
          case '/v1/users/listener/library/tracks':
            expect(request.url.queryParameters['type'], 'favorite');
            return _json([
              for (final track in _tracks) {'item': track},
            ]);
          case '/v1/users/listener/library/albums':
            expect(request.url.queryParameters['type'], 'favorite');
            return _json([
              {'item': _album},
            ]);
          case '/v1/tracks/one/stream':
            return _json('https://audio.example/one.mp3');
          case '/v1/tracks/two/stream':
            return _json('https://audio.example/two.mp3');
          default:
            fail('Unexpected URL: ${request.url}');
        }
      });
      final provider = AudiusMusicProvider(
        sdk: AudiusSdk(httpClient: client),
        createPlayer: () => player,
      );
      final playback = AlbumPlayback();
      addTearDown(client.close);
      addTearDown(provider.dispose);
      addTearDown(playback.dispose);

      final trending = (await provider.libraryAlbums()).items;
      playback.bind(provider, trending);
      final favorites = await provider.favoriteTracks('listener');
      await playback.playAudiusFavorites(favorites.items, 0, 'Favorite tracks');
      await Future<void>.delayed(Duration.zero);
      expect(playback.currentTrack, _ref('one', MusicKind.song));
      expect(playback.playing, isTrue);

      final albums = (await provider.favoriteAlbums('listener')).items;
      playback.bind(provider, albums);
      playback.bind(provider, trending);
      expect(playback.currentTrack, _ref('one', MusicKind.song));
      expect(playback.playing, isTrue);
      player.events.add(const AudioEvent(eventType: AudioEventType.complete));
      await Future<void>.delayed(Duration.zero);
      expect(playback.currentTrack, _ref('two', MusicKind.song));
      expect(player.urls, [
        'https://audio.example/one.mp3',
        'https://audio.example/two.mp3',
      ]);
    },
  );

  test('catalog filters playlists and loads each album lazily once', () async {
    var details = 0;
    final client = MockClient((request) async {
      switch (request.url.path) {
        case '/v1/playlists/trending':
          expect(request.url.queryParameters['type'], 'album');
          expect(request.url.queryParameters['limit'], '2');
          return request.url.queryParameters['offset'] == '0'
              ? _json([_album, _playlist])
              : _json([]);
        case '/v1/search/full':
          expect(request.url.queryParameters['kind'], 'albums');
          return _json({
            'albums': [_playlist, _album],
          });
        case '/v1/playlists/album-id/tracks':
          details++;
          return _json([
            ..._tracks,
            {
              'id': 'restricted',
              'title': 'Restricted',
              'access': {'stream': false},
            },
          ]);
        case '/v1/users/artist-id':
          return _json([_album['user']]);
        case '/v1/playlists/playlist-id':
          return _json([_playlist]);
        case '/v1/playlists/playlist-id/tracks':
          return _json(_tracks);
        default:
          fail('Unexpected URL: ${request.url}');
      }
    });
    final provider = AudiusMusicProvider(sdk: AudiusSdk(httpClient: client));
    addTearDown(client.close);
    addTearDown(provider.dispose);

    final page = await provider.libraryAlbums(limit: 2);
    final album = page.items.single;
    expect(album.reference, _ref('album-id', MusicKind.album));
    expect(album.artist, 'Album Artist');
    expect(album.artworkUrl, startsWith('https://art.example/cover.jpg'));
    expect(album.tracks, isNull);
    expect(page.nextCursor, '2');
    expect(
      (await provider.libraryAlbums(limit: 2, cursor: page.nextCursor)).items,
      isEmpty,
    );
    expect(
      (await provider.searchAlbums('Album')).single.reference,
      album.reference,
    );
    expect(details, 0);
    final detail = provider.album(album.reference);
    expect(provider.album(album.reference), same(detail));
    final songs = (await detail).tracks!;
    final song = songs.first;
    expect(songs.last.playable, isFalse);
    expect(song.reference, _ref('one', MusicKind.song));
    expect(song.artist, 'Track Artist');
    expect(song.duration, const Duration(seconds: 12));
    expect(details, 1);
    expect(
      (await provider.artist(_ref('artist-id', MusicKind.artist))).name,
      'Album Artist',
    );
    expect(
      (await provider.playlist(_ref('playlist-id', MusicKind.playlist))).tracks,
      hasLength(2),
    );
    await expectLater(
      provider.album(_ref('playlist-id', MusicKind.album)),
      throwsStateError,
    );
  });

  test(
    'passes SDK headers and streams, seeks, skips and auto-advances',
    () async {
      final player = _Player();
      var creations = 0;
      final client = MockClient((request) async {
        expect(request.headers['x-api-key'], 'fake-key');
        expect(request.url.queryParameters['no_redirect'], 'true');
        expect(request.followRedirects, isFalse);
        final id = request.url.pathSegments[2];
        return _json('https://audio.example/$id.mp3');
      });
      final provider = AudiusMusicProvider(
        sdk: AudiusSdk(httpClient: client, apiKey: 'fake-key'),
        createPlayer: () {
          creations++;
          return player;
        },
      );
      addTearDown(client.close);
      addTearDown(provider.dispose);
      final states = <MusicPlayback>[];
      final sub = provider.playback.listen(states.add);
      addTearDown(sub.cancel);

      Future<void> flush() => Future<void>.delayed(Duration.zero);
      await provider.initialize();
      await provider.initialize();
      expect(creations, 0);
      await provider.play([
        _ref('one', MusicKind.song),
        _ref('two', MusicKind.song),
      ]);
      await flush();
      expect(player.urls, ['https://audio.example/one.mp3']);
      expect(
        states.map((state) => state.status),
        containsAllInOrder([
          MusicPlaybackStatus.loading,
          MusicPlaybackStatus.buffering,
          MusicPlaybackStatus.playing,
        ]),
      );
      player.positions.add(const Duration(seconds: 3));
      await flush();
      expect(states.last.position, const Duration(seconds: 3));
      await provider.pause();
      await flush();
      expect(states.last.status, MusicPlaybackStatus.paused);
      await provider.seek(const Duration(seconds: 5));
      expect(player.actions, contains('seek:5'));
      await provider.resume();
      await flush();
      expect(states.last.status, MusicPlaybackStatus.playing);
      await provider.next();
      await provider.previous();
      expect(player.urls, [
        'https://audio.example/one.mp3',
        'https://audio.example/two.mp3',
        'https://audio.example/one.mp3',
      ]);
      player.events.add(const AudioEvent(eventType: AudioEventType.complete));
      await flush();
      expect(states.last.currentItem, _ref('two', MusicKind.song));
      expect(states.last.status, MusicPlaybackStatus.playing);
      player.events.add(const AudioEvent(eventType: AudioEventType.complete));
      await flush();
      expect(states.last.status, MusicPlaybackStatus.completed);
      expect(creations, 1);
      await provider.dispose();
      expect(player.disposed, isTrue);
    },
  );

  test(
    'a lazy track keeps the artwork and metadata of the album used to play it',
    () async {
      final player = _Player();
      final second = {..._album, 'id': 'second-id', 'playlist_name': 'Second'};
      final client = MockClient(
        (request) async => switch (request.url.path) {
          '/v1/playlists/trending' => _json([_album, second]),
          '/v1/playlists/album-id/tracks' ||
          '/v1/playlists/second-id/tracks' => _json(_tracks),
          '/v1/tracks/one/stream' => _json('https://audio.example/one.mp3'),
          _ => throw StateError('Unexpected path: ${request.url.path}'),
        },
      );
      final provider = AudiusMusicProvider(
        sdk: AudiusSdk(httpClient: client),
        createPlayer: () => player,
      );
      final playback = AlbumPlayback();
      addTearDown(client.close);
      addTearDown(provider.dispose);
      addTearDown(playback.dispose);

      final albums = (await provider.libraryAlbums()).items;
      playback.bind(provider, albums);
      final firstAsset = albumArtworkSource(albums.first);
      final secondAsset = albumArtworkSource(albums.last);
      expect(firstAsset, isNot(secondAsset));
      final firstTracks = await playback.loadAlbumTracks(firstAsset);
      await playback.loadAlbumTracks(secondAsset);
      playback.playTrack(firstTracks!, 0, albumAsset: firstAsset);
      await Future<void>.delayed(Duration.zero);
      expect(playback.playing, isTrue);
      expect(playback.asset, firstAsset);
      expect(playback.title, 'Album');
      expect(playback.currentTitle, 'One');
      expect(playback.currentArtist, 'Track Artist');
    },
  );

  test(
    'stream 429 is reported and disposal cancels a stalled prepare',
    () async {
      final player = _Player();
      var requests = 0;
      final client = MockClient((_) async {
        if (requests++ == 0) return http.Response('rate limited', 429);
        return _json('https://audio.example/track.mp3');
      });
      final provider = AudiusMusicProvider(
        sdk: AudiusSdk(httpClient: client),
        createPlayer: () => player,
      );
      addTearDown(client.close);
      addTearDown(provider.dispose);

      final failed = provider.playback.firstWhere(
        (state) => state.status == MusicPlaybackStatus.error,
      );
      await expectLater(
        provider.play([_ref('one', MusicKind.song)]),
        throwsA(
          isA<AudiusApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            429,
          ),
        ),
      );
      expect((await failed).currentItem, _ref('one', MusicKind.song));

      final gate = player.prepareGate = Completer<void>();
      final retry = provider.resume();
      await Future<void>.delayed(Duration.zero);
      expect(player.urls, ['https://audio.example/track.mp3']);
      await provider.dispose().timeout(const Duration(seconds: 1));
      await retry;
      expect(player.disposed, isTrue);
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(player.actions, isNot(contains('resume')));
    },
  );
}
