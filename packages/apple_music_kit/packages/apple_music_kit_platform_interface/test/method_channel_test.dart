import 'package:apple_music_kit_platform_interface/apple_music_kit_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('deskbtm.apple_music_kit/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('native library resources preserve library identity', () async {
    messenger.setMockMethodCallHandler(
        channel,
        (call) async => {
              'data': [
                {
                  'id': 'i.test',
                  'attributes': {'name': 'Library song'}
                }
              ]
            });
    final platform = MethodChannelMusicKit('test');
    expect((await platform.getLibrarySongs()).items.single.ref.source,
        MusicItemSource.library);
    expect(identical(platform.playerStates, platform.playerStates), isTrue);
    expect(
        identical(
            platform.onAuthorizationChanged, platform.onAuthorizationChanged),
        isTrue);
  });
  test('native failures keep stable error codes', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'authorizationDenied');
    });
    await expectLater(
        MethodChannelMusicKit('test').play(),
        throwsA(isA<MusicKitException>().having((error) => error.code, 'code',
            MusicKitErrorCode.authorizationDenied)));
  });
  test('API relationships carry album and playlist tracks', () {
    final json = <String, dynamic>{
      'id': 'album',
      'attributes': {'name': 'Album'},
      'relationships': {
        'tracks': {
          'data': [
            {
              'id': 'song',
              'attributes': {'name': 'Song'}
            }
          ]
        }
      }
    };
    expect(MusicAlbum.fromApiJson(json).tracks!.single.id, 'song');
    expect(MusicPlaylist.fromApiJson(json).tracks!.single.id, 'song');
  });
}
