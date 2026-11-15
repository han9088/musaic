@TestOn('browser')
library web_plugin_test;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'support/assets.dart';
import 'package:musaic_query_platform_interface/musaic_query_platform_interface.dart';
import 'package:musaic_query_web/musaic_query_web.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('public web methods accept their default optional arguments', () async {
    final bundle = TestBundle({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) {
      final key = utf8.decode(message!.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes));
      return bundle.load(key);
    });
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
    final plugin = MusaicQueryPlugin();
    expect(await plugin.querySongs(), isEmpty);
    expect(await plugin.queryAlbums(), isEmpty);
    expect(await plugin.queryArtists(), isEmpty);
    expect(await plugin.queryGenres(), isEmpty);
    expect(
        await plugin.queryAudiosFrom(AudiosFromType.ALBUM, 'missing'), isEmpty);
  });
}
