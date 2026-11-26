@TestOn('browser')
library;

import 'dart:js_interop';
import 'package:flutter_test/flutter_test.dart';
import 'package:apple_music_kit_web/src/music_kit_web.dart';
import 'package:apple_music_kit_platform_interface/apple_music_kit_platform_interface.dart';

@JS('eval')
external JSAny? evaluate(String source);
void main() {
  test('REST envelope, library identity, playlist body and reinitialization',
      () async {
    evaluate(r'''
      globalThis.requests = [];
      globalThis.responseMode = 'valid';
      globalThis.handlers = new Map();
      globalThis.MusicKit = {configure: async () => ({
        authorizationStatus: 3,
        addEventListener: (name, cb) => handlers.set(name, cb),
        removeEventListener: (name, cb) => { if(handlers.get(name) !== cb) throw Error('callback identity'); handlers.delete(name); },
        api: {music: async (path, parameters, options) => {
          requests.push({path, parameters, options});
          if(typeof responseMode === 'number')
            throw {status: responseMode, toString: () => 'sensitive upstream content'};
          if(responseMode === 'malformed') return {data: []};
          if(responseMode === 'decodeFailure') return {get data() {throw Error('decode failure');}};
          if(path.includes('extend=editorialVideo'))
            return {data:{data:[{id:'123456',type:'albums',attributes:{editorialVideo:{
              motionDetailSquare:{video:'https://example.invalid/square.m3u8'},
              motionDetailTall:{video:'https://example.invalid/tall.m3u8'}
            }}}]}};
          if(path.includes('playlists') && options.fetchOptions.method === 'POST')
            return {data:{data:[{id:'p.test',attributes:{name:'test',description:{standard:'desc'}}}]}};
          return {data:{data:[{id:'i.test',type:'library-songs',attributes:{name:'song'}}]}};
        }}
      })};
    ''');
    final platform = AppleMusicKitWebPlatform();
    final config = MusicKitPlatformConfig(
        developerTokenProvider: const StaticDeveloperTokenProvider('test'));
    await platform.initialize(config);
    final songs = await platform.getLibrarySongs();
    expect(songs.items.single.ref.source, MusicItemSource.library);
    final playlist = await platform.createPlaylist('test',
        description: 'desc', tracks: [songs.items.single.ref]);
    expect(playlist.id, 'p.test');
    expect(playlist.description, 'desc');
    expect(
        (evaluate("JSON.parse(requests[1].options.fetchOptions.body).attributes.description")
                as JSString)
            .toDart,
        'desc');
    expect(
        (evaluate("requests[1].options.fetchOptions.headers['Content-Type']")
                as JSString)
            .toDart,
        'application/json');
    final animated = await platform.getAlbumAnimatedArtwork('123456',
        storefront: 'jp');
    expect(animated.map((v) => v.type), ['motionDetailSquare', 'motionDetailTall']);
    expect((evaluate('requests[2].path') as JSString).toDart,
        'v1/catalog/jp/albums/123456?extend=editorialVideo');
    for (final mode in ['malformed', 'decodeFailure']) {
      evaluate("responseMode = '$mode'");
      await expectLater(platform.getAlbumAnimatedArtwork('123456', storefront: 'jp'),
          throwsA(isA<MusicKitException>()
              .having((e) => e.code, 'code', MusicKitErrorCode.unknown)
              .having((e) => e.details?['reason'], 'reason', 'invalidResponse')));
    }
    for (final entry in {
      401: MusicKitErrorCode.authenticationFailed,
      403: MusicKitErrorCode.authorizationDenied,
      408: MusicKitErrorCode.requestTimeout,
      410: MusicKitErrorCode.resourceUnavailable,
      429: MusicKitErrorCode.rateLimited,
      503: MusicKitErrorCode.networkError,
    }.entries) {
      evaluate('responseMode = ${entry.key}');
      await expectLater(platform.getAlbumAnimatedArtwork('123456', storefront: 'jp'),
          throwsA(isA<MusicKitException>()
              .having((e) => e.code, 'code', entry.value)
              .having((e) => e.message, 'message',
                  isNot(contains('sensitive upstream content')))));
    }
    evaluate("responseMode = 'valid'");
    await platform.dispose();
    expect((evaluate('handlers.size') as JSNumber).toDartInt, 0);
    await platform.initialize(config);
    await platform.dispose();
  });
}
