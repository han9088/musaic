import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:apple_music_kit/apple_music_kit.dart';
import 'package:apple_music_kit_platform_interface/apple_music_kit_platform_interface.dart'
    show MethodChannelMusicKit;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> fixture() => jsonDecode(
    File('test/fixtures/animated_artwork.json').readAsStringSync())
    as Map<String, dynamic>;

Map<String, dynamic> attributes(Map<String, dynamic> response) =>
    ((response['data'] as List).single as Map)['attributes']
        as Map<String, dynamic>;

final class ArtworkPlatform extends MusicKitPlatform {
  final calls = <(String, String)>[];
  final replies = <Completer<List<MusicAnimatedArtwork>>>[];

  bool disposed = false;

  @override
  Future<void> initialize(MusicKitPlatformConfig config) async {}

  @override
  Stream<MusicPlayerState> get playerStates => const Stream.empty();

  @override
  Future<void> dispose({bool stopPlayback = false}) async { disposed = true; }

  @override
  Future<List<MusicAnimatedArtwork>> getAlbumAnimatedArtwork(String id,
      {required String storefront}) {
    calls.add((id, storefront));
    final reply = Completer<List<MusicAnimatedArtwork>>();
    replies.add(reply);
    return reply.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final parsed = MusicAnimatedArtwork.fromApiResponse(fixture());

  test('preserves square, tall and alternate variants with original HLS URLs', () {
    expect(parsed.map((v) => v.type), [
      'motionDetailSquare', 'motionDetailTall',
      'motionSquareVideo1x1', 'motionTallVideo3x4',
    ]);
    expect(parsed.first.videoUrl, 'https://example.invalid/square.m3u8');
    expect(parsed.first.metadata, {'video': parsed.first.videoUrl});
    expect(() => parsed.first.metadata['width'] = 1, throwsUnsupportedError);
    expect(() => parsed.clear(), throwsUnsupportedError);
  });

  test('preserves supplied metadata without inferring a schema', () {
    final json = fixture();
    final variants = attributes(json)['editorialVideo'] as Map;
    final square = variants['motionDetailSquare'] as Map;
    // Synthetic extension, not a claim about Apple's current metadata schema.
    square['fixtureExtension'] = {'values': [1, 'value', null]};
    final result = MusicAnimatedArtwork.fromApiResponse(json).first;
    (square['fixtureExtension'] as Map)['values'] = <Object?>[];
    final retained = result.metadata['fixtureExtension'] as Map;
    expect(retained['values'], [1, 'value', null]);
    expect(() => (retained['values'] as List).clear(), throwsUnsupportedError);
  });

  test('missing optional fields are empty; malformed responses are errors', () {
    final json = fixture();
    attributes(json).remove('editorialVideo');
    expect(MusicAnimatedArtwork.fromApiResponse(json), isEmpty);
    attributes(json)['editorialVideo'] = {
      'motionDetailSquare': <String, Object?>{}, 'motionDetailTall': null,
      'motionSquareVideo1x1': {'video': null},
    };
    expect(MusicAnimatedArtwork.fromApiResponse(json), isEmpty);
    for (final invalid in [false, 'broken', {'motionDetailSquare': {'video': 3}}]) {
      attributes(json)['editorialVideo'] = invalid;
      expect(() => MusicAnimatedArtwork.fromApiResponse(json),
          throwsA(isA<MusicKitException>().having((e) => e.code, 'code',
              MusicKitErrorCode.unknown)));
    }
    expect(() => MusicAnimatedArtwork.fromApiResponse({}),
        throwsA(isA<MusicKitException>()));
    expect(() => MusicAnimatedArtwork.fromApiResponse({'data': <Object?>[]}),
        throwsA(isA<MusicKitException>().having((e) => e.code, 'code',
            MusicKitErrorCode.resourceNotFound)));
  });

  test('merges matching requests, separates storefronts and retains no results', () async {
    final platform = ArtworkPlatform();
    final catalog = MusicCatalogService(platform);
    final first = catalog.getAlbumAnimatedArtwork('123456', storefront: 'US');
    final same = catalog.getAlbumAnimatedArtwork('123456', storefront: 'us');
    final other = catalog.getAlbumAnimatedArtwork('123456', storefront: 'jp');
    expect(identical(first, same), isTrue);
    expect(platform.calls, [('123456', 'us'), ('123456', 'jp')]);
    platform.replies[0].complete(parsed);
    platform.replies[1].complete([]);
    expect(await first, parsed);
    expect(await other, isEmpty);
    final again = catalog.getAlbumAnimatedArtwork('123456', storefront: 'us');
    expect(platform.calls.length, 3);
    platform.replies[2].complete([]);
    await again;
    expect(() => catalog.getAlbumAnimatedArtwork('l.library', storefront: 'us'),
        throwsArgumentError);
    expect(() => catalog.getAlbumAnimatedArtwork('123456', storefront: '../us'),
        throwsArgumentError);
  });

  test('clearing pending associations cannot let old completion remove new work', () async {
    final platform = ArtworkPlatform();
    final catalog = MusicCatalogService(platform);
    final old = catalog.getAlbumAnimatedArtwork('123456', storefront: 'us');
    catalog.clearAnimatedArtworkRequests();
    final fresh = catalog.getAlbumAnimatedArtwork('123456', storefront: 'us');
    platform.replies[0].complete([]);
    await old;
    expect(identical(fresh,
        catalog.getAlbumAnimatedArtwork('123456', storefront: 'us')), isTrue);
    platform.replies[1].complete(parsed);
    expect(await fresh, parsed);
  });

  test('shared failures propagate unchanged and the next call retries', () async {
    final platform = ArtworkPlatform();
    final catalog = MusicCatalogService(platform);
    const failure = MusicKitException(MusicKitErrorCode.rateLimited,
        message: 'Fixture failure.', retryAfter: Duration(seconds: 5));
    final first = catalog.getAlbumAnimatedArtwork('123456', storefront: 'us');
    final second = catalog.getAlbumAnimatedArtwork('123456', storefront: 'us');
    final checks = [expectLater(first, throwsA(same(failure))),
      expectLater(second, throwsA(same(failure)))];
    platform.replies[0].completeError(failure);
    await Future.wait(checks);
    final retry = catalog.getAlbumAnimatedArtwork('123456', storefront: 'us');
    expect(platform.calls.length, 2);
    platform.replies[1].complete([]);
    await retry;
  });

  test('native transport preserves storefront, response and error classification', () async {
    const channel = MethodChannel('deskbtm.apple_music_kit/methods');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getAlbumAnimatedArtwork');
      expect(call.arguments, {'id': '123456', 'storefront': 'jp'});
      return fixture();
    });
    final native = MethodChannelMusicKit('test');
    expect((await native.getAlbumAnimatedArtwork('123456', storefront: 'jp')).length, 4);
    for (final code in ['authenticationFailed', 'networkError', 'rateLimited']) {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: code);
      });
      await expectLater(native.getAlbumAnimatedArtwork('123456', storefront: 'jp'),
          throwsA(isA<MusicKitException>().having((e) => e.code.name, 'code', code)));
    }
  });

  testWidgets('timeout releases shared work and ignores late completion', (tester) async {
    final platform = ArtworkPlatform();
    final catalog = MusicCatalogService(platform);
    final pending = catalog.getAlbumAnimatedArtwork('123456', storefront: 'us');
    expect(identical(pending,
        catalog.getAlbumAnimatedArtwork('123456', storefront: 'us')), isTrue);
    final timedOut = expectLater(pending,
        throwsA(isA<MusicKitException>().having((e) => e.code, 'code',
            MusicKitErrorCode.requestTimeout)));
    await tester.pump(const Duration(seconds: 30));
    await timedOut;
    final retry = catalog.getAlbumAnimatedArtwork('123456', storefront: 'us');
    expect(platform.calls.length, 2);
    platform.replies[0].completeError(const MusicKitException(
        MusicKitErrorCode.networkError, message: 'Late fixture failure.'));
    await tester.pump();
    expect(identical(retry,
        catalog.getAlbumAnimatedArtwork('123456', storefront: 'us')), isTrue);
    platform.replies[1].complete(parsed);
    await tester.pump();
    expect(await retry, parsed);
  });

  test('synchronous platform failures are shared and removed before retry', () async {
    final catalog = MusicCatalogService(_UnsupportedPlatform());
    final first = catalog.getAlbumAnimatedArtwork('123456', storefront: 'us');
    final second = catalog.getAlbumAnimatedArtwork('123456', storefront: 'us');
    expect(identical(first, second), isTrue);
    await Future.wait([
      expectLater(first, throwsA(isA<MusicKitException>())),
      expectLater(second, throwsA(isA<MusicKitException>())),
    ]);
    final retry = catalog.getAlbumAnimatedArtwork('123456', storefront: 'us');
    expect(identical(first, retry), isFalse);
    await expectLater(retry, throwsA(isA<MusicKitException>()));
  });

  test('dispose rejects new work but lets existing callers settle', () async {
    final platform = ArtworkPlatform();
    final client = AppleMusicClient(
        config: const AppleMusicConfig(), platform: platform);
    expect(() => client.catalog.getAlbumAnimatedArtwork('123456', storefront: 'us'),
        throwsA(isA<MusicKitException>().having((e) => e.code, 'code',
            MusicKitErrorCode.notInitialized)));
    await client.initialize();
    final pending = client.catalog.getAlbumAnimatedArtwork('123456', storefront: 'us');
    final disposal = client.dispose();
    expect(identical(disposal, client.dispose()), isTrue);
    expect(() => client.catalog.getAlbumAnimatedArtwork('123456', storefront: 'us'),
        throwsA(isA<MusicKitException>().having((e) => e.code, 'code',
            MusicKitErrorCode.alreadyDisposed)));
    await disposal;
    expect(platform.disposed, isTrue);
    platform.replies.single.complete(parsed);
    expect(await pending, parsed);
    expect(platform.calls.length, 1);
  });

  test('native missing methods and non-map error details stay typed', () async {
    const channel = MethodChannel('deskbtm.apple_music_kit/methods');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final native = MethodChannelMusicKit('test');
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw MissingPluginException();
    });
    await expectLater(native.getAlbumAnimatedArtwork('123456', storefront: 'us'),
        throwsA(isA<MusicKitException>().having((e) => e.code, 'code',
            MusicKitErrorCode.unsupportedFeature)));
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'rateLimited', details: 'upstream detail');
    });
    await expectLater(native.getAlbumAnimatedArtwork('123456', storefront: 'us'),
        throwsA(isA<MusicKitException>()
            .having((e) => e.code, 'code', MusicKitErrorCode.rateLimited)
            .having((e) => e.details, 'details', isNull)));
  });

  test('unimplemented platforms fail explicitly', () async {
    // The inherited method must never report a successful empty response.
    final platform = _UnsupportedPlatform();
    expect(() => platform.getAlbumAnimatedArtwork('123456', storefront: 'us'),
        throwsA(isA<MusicKitException>().having((e) => e.code, 'code',
            MusicKitErrorCode.unsupportedFeature)));
  });
}

final class _UnsupportedPlatform extends MusicKitPlatform {}
