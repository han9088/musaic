/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'package:apple_music_kit_platform_interface/apple_music_kit_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MusicArtwork', () {
    test('builds concrete URL from template', () {
      const art =
          MusicArtwork(templateUrl: 'https://example.com/{w}x{h}bb.jpg');
      expect(art.url(size: 300), 'https://example.com/300x300bb.jpg');
    });

    test('returns null URL for empty template', () {
      const art = MusicArtwork(templateUrl: '');
      expect(art.url(), isNull);
    });

    test('fits within bounding box preserving aspect', () {
      const art = MusicArtwork(
          templateUrl: 'https://x/{w}x{h}bb.jpg', width: 2000, height: 1000);
      final url = art.urlFitted(maxWidth: 200, maxHeight: 200)!;
      expect(url, contains('200x100'));
    });

    test('roundtrips json', () {
      const art = MusicArtwork(
          templateUrl: 'https://x/{w}x{h}bb.jpg', width: 100, height: 100);
      final back = MusicArtwork.fromJson(art.toJson());
      expect(back!.templateUrl, art.templateUrl);
      expect(back.width, 100);
    });

    test('fromJson handles null', () {
      expect(MusicArtwork.fromJson(null), isNull);
    });
  });

  group('MusicItemRef', () {
    test('parses catalog API href', () {
      final ref = MusicItemRef.fromUrl(
          'https://api.music.apple.com/v1/catalog/us/songs/1440843637');
      expect(ref.id, '1440843637');
      expect(ref.type, MusicResourceType.song);
      expect(ref.source, MusicItemSource.catalog);
      expect(ref.storefront, 'us');
    });

    test('parses library href', () {
      final ref = MusicItemRef.fromUrl(
          'https://api.music.apple.com/v1/me/library/songs/i.abc123');
      expect(ref.source, MusicItemSource.library);
    });

    test('returns empty id for garbage', () {
      final ref = MusicItemRef.fromUrl('https://example.com/nope');
      expect(ref.id, isEmpty);
    });

    test('equality ignores storefront', () {
      const a = MusicItemRef(id: 'x', type: MusicResourceType.song);
      const b =
          MusicItemRef(id: 'x', type: MusicResourceType.song, storefront: 'us');
      expect(a, b);
    });

    test('json roundtrip', () {
      const ref = MusicItemRef(
          id: 'x',
          type: MusicResourceType.album,
          source: MusicItemSource.library);
      final back = MusicItemRef.fromJson(ref.toJson());
      expect(back, ref);
    });
  });

  group('MusicSong.fromApiJson', () {
    test('parses full attributes', () {
      final song = MusicSong.fromApiJson(<String, dynamic>{
        'id': '1440843637',
        'type': 'songs',
        'href': 'https://api.music.apple.com/v1/catalog/us/songs/1440843637',
        'attributes': <String, dynamic>{
          'name': 'Never Gonna Give You Up',
          'artistName': 'Rick Astley',
          'albumName': 'Whenever You Need Somebody',
          'durationInMillis': 213000,
          'trackNumber': 1,
          'discNumber': 1,
          'contentRating': 'explicit',
          'playParams': <String, dynamic>{'id': '1440843637'},
          'genreNames': <String>['Pop'],
        },
      });
      expect(song.id, '1440843637');
      expect(song.title, 'Never Gonna Give You Up');
      expect(song.artistName, 'Rick Astley');
      expect(song.duration, const Duration(milliseconds: 213000));
      expect(song.isExplicit, isTrue);
      expect(song.isPlayable, isTrue);
      expect(song.storefront, 'us');
      expect(song.ref.type, MusicResourceType.song);
    });

    test('handles missing attributes gracefully', () {
      final song = MusicSong.fromApiJson(<String, dynamic>{'id': 'x'});
      expect(song.title, isEmpty);
      expect(song.duration, isNull);
      expect(song.isExplicit, isFalse);
      expect(song.isPlayable, isFalse);
    });
  });

  group('MusicPage', () {
    test('parses data and next offset', () {
      final page = MusicPage.fromApiJson<String>(
        <String, dynamic>{
          'data': <dynamic>[
            <String, dynamic>{'id': 'a'},
            <String, dynamic>{'id': 'b'},
          ],
          'next': '/v1/catalog/us/songs?offset=2&limit=2',
        },
        (m) => m['id'] as String,
      );
      expect(page.items, ['a', 'b']);
      expect(page.hasMore, isTrue);
      expect(page.nextOffset, 2);
    });

    test('no next link means no more', () {
      final page = MusicPage.fromApiJson<String>(
        <String, dynamic>{'data': <dynamic>[]},
        (m) => m['id'] as String,
      );
      expect(page.hasMore, isFalse);
      expect(page.nextOffset, isNull);
    });
  });

  group('MusicPlayerState', () {
    test('copyWith preserves unspecified fields', () {
      const s = MusicPlayerState(
        status: MusicPlayerStatus.playing,
        currentItem: MusicItemRef(id: 'x', type: MusicResourceType.song),
        currentIndex: 0,
        duration: Duration(minutes: 3),
      );
      final next = s.copyWith(position: const Duration(seconds: 10));
      expect(next.status, MusicPlayerStatus.playing);
      expect(next.currentItem, s.currentItem);
      expect(next.duration, const Duration(minutes: 3));
      expect(next.position, const Duration(seconds: 10));
    });

    test('copyWith can clear nullable fields', () {
      const s = MusicPlayerState(duration: Duration(minutes: 3));
      final next = s.copyWith(duration: null);
      expect(next.duration, isNull);
    });

    test('equality dedupes identical states', () {
      const a = MusicPlayerState(
          status: MusicPlayerStatus.playing, position: Duration(seconds: 1));
      const b = MusicPlayerState(
          status: MusicPlayerStatus.playing, position: Duration(seconds: 1));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('MusicKitException', () {
    test('maps code names roundtrip', () {
      for (final code in MusicKitErrorCode.values) {
        expect(MusicKitErrorCode.fromName(code.name), code);
      }
    });

    test('userMessage is presentable', () {
      const e = MusicKitException(MusicKitErrorCode.subscriptionRequired,
          message: 'detail');
      expect(e.userMessage, contains('subscription'));
    });

    test('toString includes code and message', () {
      const e =
          MusicKitException(MusicKitErrorCode.networkError, message: 'offline');
      expect(e.toString(), contains('networkError'));
      expect(e.toString(), contains('offline'));
    });
  });

  group('CachingDeveloperTokenProvider', () {
    test('caches and single-flights concurrent requests', () async {
      var calls = 0;
      final provider = CachingDeveloperTokenProvider(
        delegate: _SlowProvider(() async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return 'tok-$calls';
        }),
      );
      final results = await Future.wait(
          [provider.getToken(), provider.getToken(), provider.getToken()]);
      expect(calls, 1, reason: 'concurrent requests must single-flight');
      expect(results, everyElement('tok-1'));
      // Cached now.
      expect(await provider.getToken(), 'tok-1');
      expect(calls, 1);
    });

    test('invalidation forces refetch', () async {
      var calls = 0;
      final provider = CachingDeveloperTokenProvider(
        delegate: _CountingProvider(() => 'tok-${++calls}'),
      );
      await provider.getToken();
      provider.invalidate();
      await provider.getToken();
      expect(calls, 2);
    });

    test('parses JWT exp claim', () {
      // header.payload.sig with {"exp": 9999999999}
      const jwt = 'eyJhbGciOiJFUzI1NiJ9.eyJleHAiOiA5OTk5OTk5OTk5fQ.sig';
      expect(CachingDeveloperTokenProvider.jwtExpiry(jwt), 9999999999);
      expect(CachingDeveloperTokenProvider.jwtExpiry('garbage'), isNull);
    });
  });
}

final class _SlowProvider implements DeveloperTokenProvider {
  _SlowProvider(this._fetch);
  final Future<String> Function() _fetch;

  @override
  Future<String> getToken() => _fetch();
}

final class _CountingProvider implements DeveloperTokenProvider {
  _CountingProvider(this._next);
  final String Function() _next;

  @override
  Future<String> getToken() async => _next();
}
