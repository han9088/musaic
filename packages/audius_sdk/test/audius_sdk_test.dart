import 'dart:convert';

import 'package:audius_sdk/audius_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('AudiusSdk', () {
    test('searchTracks sends API key and parses typed tracks', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/tracks/search');
        expect(request.headers['x-api-key'], 'public-test-key');
        expect(request.url.queryParameters['query'], 'lofi');
        expect(request.url.queryParametersAll['genre'], <String>[
          'Electronic',
          'Ambient',
        ]);

        return http.Response(
          jsonEncode(<String, Object?>{
            'data': <Object?>[
              <String, Object?>{
                'id': 'track-1',
                'title': 'Night Drive',
                'duration': 185,
                'is_streamable': true,
                'artwork': <String, Object?>{
                  '_480x480': 'https://example.com/artwork.jpg',
                },
                'user': <String, Object?>{
                  'id': 'artist-1',
                  'name': 'Musaic Artist',
                  'handle': 'musaic-artist',
                },
              },
            ],
            'timestamp': '2026-11-25T00:00:00Z',
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final sdk = AudiusSdk(apiKey: 'public-test-key', httpClient: client);

      final response = await sdk.tracks.searchTracks(
        query: 'lofi',
        genres: <String>['Electronic', 'Ambient'],
        limit: 20,
      );

      expect(response.data, hasLength(1));
      expect(response.data.single.id, 'track-1');
      expect(response.data.single.title, 'Night Drive');
      expect(response.data.single.duration, 185);
      expect(response.data.single.isStreamable, isTrue);
      expect(
        response.data.single.artwork?.best,
        'https://example.com/artwork.jpg',
      );
      expect(response.data.single.user?.handle, 'musaic-artist');
      expect(response.metadata['timestamp'], '2026-11-25T00:00:00Z');

      sdk.close();
      client.close();
    });

    test(
      'album search requests the album category and parses its envelope',
      () async {
        final client = MockClient((request) async {
          expect(request.url.path, '/v1/search/full');
          expect(request.url.queryParameters, {
            'query': 'Dub',
            'kind': 'albums',
            'offset': '2',
            'limit': '10',
          });
          return http.Response(
            jsonEncode({
              'data': {
                'albums': [
                  {'id': 'album', 'is_album': true},
                ],
                'playlists': [
                  {'id': 'playlist', 'is_album': false},
                ],
              },
            }),
            200,
          );
        });
        final sdk = AudiusSdk(httpClient: client);
        addTearDown(client.close);
        addTearDown(sdk.close);
        final result = await sdk.playlists.searchAlbums(
          query: ' Dub ',
          offset: 2,
          limit: 10,
        );
        expect(result.data.single.id, 'album');
        expect(result.data.single.isAlbum, isTrue);
      },
    );

    test('getTrackStream returns endpoint and API key headers', () {
      final client = MockClient((request) async {
        fail('Stream URL construction must not make an HTTP request.');
      });
      final sdk = AudiusSdk(apiKey: 'public-test-key', httpClient: client);

      final stream = sdk.tracks.getTrackStream(trackId: 'track/with space');

      expect(
        stream.uri.toString(),
        'https://api.audius.co/v1/tracks/track%2Fwith%20space/stream',
      );
      expect(stream.headers['x-api-key'], 'public-test-key');
      expect(stream.headers.containsKey('Accept'), isFalse);

      sdk.close();
      client.close();
    });

    test(
      'single playlist and user endpoints accept the API array envelope',
      () async {
        final client = MockClient((request) async {
          final id = request.url.pathSegments.last;
          return http.Response(
            jsonEncode({
              'data': [
                {'id': id},
              ],
            }),
            200,
          );
        });
        final sdk = AudiusSdk(httpClient: client);
        addTearDown(client.close);
        addTearDown(sdk.close);
        expect(
          (await sdk.playlists.getPlaylist(playlistId: 'playlist')).data.id,
          'playlist',
        );
        expect((await sdk.users.getUser(id: 'artist')).data.id, 'artist');
      },
    );

    test('resolves playback metadata with headers and no redirects', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/tracks/T/stream');
        expect(request.url.queryParameters['no_redirect'], 'true');
        expect(request.headers['x-api-key'], 'test-key');
        expect(request.followRedirects, isFalse);
        return http.Response(
          jsonEncode({'data': 'https://audio.example/track.mp3'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final sdk = AudiusSdk(apiKey: 'test-key', httpClient: client);
      addTearDown(client.close);
      addTearDown(sdk.close);
      final stream = sdk.tracks.getTrackStream(trackId: 'T');
      expect(
        await sdk.tracks.resolveTrackStream(stream),
        Uri.parse('https://audio.example/track.mp3'),
      );
      await expectLater(
        sdk.tracks.resolveTrackStream(
          AudiusStream(
            uri: Uri.https('other.example'),
            headers: stream.headers,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects audio bodies from the stream metadata endpoint', () async {
      final client = MockClient(
        (_) async => http.Response(
          'unexpected audio',
          200,
          headers: {'content-type': 'audio/mpeg'},
        ),
      );
      final sdk = AudiusSdk(httpClient: client);
      addTearDown(client.close);
      addTearDown(sdk.close);
      await expectLater(
        sdk.tracks.resolveTrackStream(sdk.tracks.getTrackStream(trackId: 'T')),
        throwsFormatException,
      );
    });

    test('resolveUrl identifies a playlist resource', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/resolve');
        expect(
          request.url.queryParameters['url'],
          'https://audius.co/artist/my-album',
        );
        return http.Response(
          jsonEncode(<String, Object?>{
            'data': <String, Object?>{
              'id': 'album-1',
              'playlist_name': 'My Album',
              'is_album': true,
              'track_count': 9,
            },
          }),
          200,
        );
      });
      final sdk = AudiusSdk(httpClient: client);

      final response = await sdk.resolve.resolveUrl(
        url: Uri.parse('https://audius.co/artist/my-album'),
      );

      expect(response.data.type, AudiusResolvedResourceType.playlist);
      expect(response.data.playlist?.id, 'album-1');
      expect(response.data.playlist?.isAlbum, isTrue);

      sdk.close();
      client.close();
    });

    test('non-success responses expose status and Retry-After', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object?>{'error': 'Rate limit exceeded'}),
          429,
          headers: <String, String>{'retry-after': '2'},
        );
      });
      final sdk = AudiusSdk(httpClient: client);

      await expectLater(
        sdk.tracks.getTrack(trackId: 'track-1'),
        throwsA(
          isA<AudiusApiException>()
              .having((error) => error.statusCode, 'statusCode', 429)
              .having(
                (error) => error.message,
                'message',
                'Rate limit exceeded',
              )
              .having((error) => error.retryAfter, 'retryAfter', '2'),
        ),
      );

      sdk.close();
      client.close();
    });

    test('invalid pagination fails before making a request', () async {
      final client = MockClient((request) async {
        fail('Invalid pagination must be rejected before the request.');
      });
      final sdk = AudiusSdk(httpClient: client);

      await expectLater(
        sdk.tracks.searchTracks(query: 'ambient', limit: 0),
        throwsArgumentError,
      );

      sdk.close();
      client.close();
    });
  });
}
