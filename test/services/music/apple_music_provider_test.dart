import 'package:apple_music_kit/apple_music_kit.dart' as apple;
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/services/music/apple_music_provider.dart';
import 'package:musaic/services/music/music_provider.dart';

class _Platform extends apple.MusicKitPlatform {
  bool initialized = false;
  int? offset;
  List<apple.MusicItemRef>? queue;
  bool autoplay = false;
  int artworkCalls = 0;
  String? artworkStorefront;
  Object? artworkError;
  List<apple.MusicAnimatedArtwork> artwork = [];

  @override
  Future<apple.MusicStorefront> getCurrentStorefront() async =>
      const apple.MusicStorefront(id: 'jp', name: 'Japan');

  @override
  Future<List<apple.MusicAnimatedArtwork>> getAlbumAnimatedArtwork(
    String id, {
    required String storefront,
  }) async {
    artworkCalls++;
    artworkStorefront = storefront;
    if (artworkError != null) throw artworkError!;
    return artwork;
  }

  @override
  Future<void> initialize(apple.MusicKitPlatformConfig config) async {
    initialized = true;
  }

  @override
  Future<void> dispose({bool stopPlayback = false}) async {}

  @override
  Stream<apple.MusicPlayerState> get playerStates => const Stream.empty();

  @override
  Future<apple.MusicPage<apple.MusicAlbum>> getLibraryAlbums({
    int limit = 25,
    int? offset,
  }) async {
    this.offset = offset;
    return const apple.MusicPage(
      items: [
        apple.MusicAlbum(
          id: 'library-1',
          title: 'Album',
          source: apple.MusicItemSource.library,
          storefront: 'cn',
        ),
      ],
      nextOffset: 50,
    );
  }

  @override
  Future<void> setQueue(
    List<apple.MusicItemRef> items, {
    int startIndex = 0,
    bool autoplay = true,
  }) async {
    queue = items;
    this.autoplay = autoplay;
  }
}

void main() {
  late _Platform platform;
  late AppleMusicProvider provider;

  setUp(() {
    platform = _Platform();
    provider = AppleMusicProvider(
      client: apple.AppleMusicClient(
        config: const apple.AppleMusicConfig(),
        platform: platform,
      ),
    );
  });
  tearDown(() => provider.dispose());

  MusicReference albumReference({
    String providerId = 'apple_music',
    MusicSource source = MusicSource.catalog,
    MusicKind kind = MusicKind.album,
    String? storefront,
  }) => (
    provider: providerId,
    id: '123',
    kind: kind,
    source: source,
    storefront: storefront,
  );

  test(
    'animated artwork is opt-in and maps variants without guessing unknowns',
    () async {
      await provider.initialize();
      await provider.libraryAlbums();
      expect(platform.artworkCalls, 0);
      platform.artwork = apple.MusicAnimatedArtwork.fromApiResponse({
        'data': [
          {
            'type': 'albums',
            'attributes': {
              'editorialVideo': {
                'motionDetailSquare': {
                  'video': 'https://example.com/square.m3u8',
                },
                'motionTallVideo3x4': {
                  'video': 'https://example.com/tall.m3u8',
                },
                'futureVariant': {'video': 'https://example.com/new.m3u8'},
              },
            },
          },
        ],
      });
      final variants = await provider.animatedArtwork(
        albumReference(storefront: 'cn'),
      );
      expect(platform.artworkStorefront, 'cn');
      expect(variants.map((v) => v.layout), [
        MusicArtworkLayout.square,
        MusicArtworkLayout.portrait,
        MusicArtworkLayout.unknown,
      ]);
      expect(variants.first.videoUrl, 'https://example.com/square.m3u8');
      expect(() => variants.clear(), throwsUnsupportedError);
    },
  );

  test(
    'missing storefront uses account region and absent artwork stays empty',
    () async {
      await provider.initialize();
      expect(await provider.animatedArtwork(albumReference()), isEmpty);
      expect(platform.artworkStorefront, 'jp');
    },
  );

  test('artwork errors propagate and a later request can retry', () async {
    await provider.initialize();
    const error = apple.MusicKitException(
      apple.MusicKitErrorCode.unknown,
      message: 'Request failed',
    );
    platform.artworkError = error;
    await expectLater(
      provider.animatedArtwork(albumReference(storefront: 'cn')),
      throwsA(same(error)),
    );
    platform.artworkError = null;
    expect(
      await provider.animatedArtwork(albumReference(storefront: 'cn')),
      isEmpty,
    );
    expect(platform.artworkCalls, 2);
  });

  test('artwork rejects library, foreign and non-album references before requesting', () async {
    await provider.initialize();
    await expectLater(
      provider.animatedArtwork(albumReference(source: MusicSource.library)),
      throwsUnsupportedError,
    );
    await expectLater(
      provider.animatedArtwork(albumReference(providerId: 'other')),
      throwsArgumentError,
    );
    await expectLater(
      provider.animatedArtwork(albumReference(kind: MusicKind.song)),
      throwsArgumentError,
    );
    expect(platform.artworkCalls, 0);
  });

  test(
    'construction is inert and library access requires initialization',
    () async {
      expect(platform.initialized, isFalse);
      await expectLater(
        provider.libraryAlbums(),
        throwsA(isA<apple.MusicKitException>()),
      );
      expect(platform.initialized, isFalse);
    },
  );

  test(
    'pagination and queue preserve library identity and storefront',
    () async {
      await provider.initialize();
      final page = await provider.libraryAlbums(cursor: '25');
      expect(platform.offset, 25);
      expect(page.nextCursor, '50');
      final album = page.items.single;
      expect(album.reference.provider, 'apple_music');
      expect(album.reference.source, MusicSource.library);
      expect(album.tracks, isNull);
      await provider.play([album.reference]);
      expect(platform.queue!.single.id, 'library-1');
      expect(platform.queue!.single.source, apple.MusicItemSource.library);
      expect(platform.queue!.single.storefront, 'cn');
      expect(platform.autoplay, isTrue);
      await expectLater(
        provider.album(album.reference),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'invalid inputs and foreign provider IDs never reach playback',
    () async {
      await provider.initialize();
      await expectLater(
        provider.libraryAlbums(cursor: '-1'),
        throwsArgumentError,
      );
      await expectLater(
        provider.libraryAlbums(cursor: 'invalid'),
        throwsArgumentError,
      );
      await expectLater(provider.libraryAlbums(limit: 0), throwsRangeError);
      await expectLater(provider.play([]), throwsArgumentError);
      await expectLater(
        provider.play([
          (
            provider: 'other',
            id: '1',
            kind: MusicKind.song,
            source: MusicSource.catalog,
            storefront: null,
          ),
        ]),
        throwsArgumentError,
      );
      await expectLater(
        provider.seek(const Duration(seconds: -1)),
        throwsArgumentError,
      );
      expect(platform.queue, isNull);
    },
  );
}
