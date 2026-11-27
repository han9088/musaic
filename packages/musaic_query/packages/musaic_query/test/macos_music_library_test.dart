import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic_query/musaic_query.dart';
import 'package:musaic_query_macos/musaic_query_macos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('macOS shares the system query channel and opens scoped song playback',
      () async {
    const channel = MethodChannel('com.deskbtm.muasic.query');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final previous = MusaicQueryPlatform.instance;
    final calls = <MethodCall>[];
    const songId = -7147011246814739142;
    const uri = 'file:///Music/Track%20%231.m4a';
    var authorized = false;

    MusaicQueryMacos.registerWith();
    addTearDown(() {
      MusaicQueryPlatform.instance = previous;
      messenger.setMockMethodCallHandler(channel, null);
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'permissionsStatus':
          return authorized;
        case 'permissionsRequest':
          return authorized = true;
        case 'querySongs':
          return [
            {'_id': songId, '_uri': uri, 'album_id': 8, 'title': 'Track #1'}
          ];
        case 'queryAlbums':
          return [
            {'_id': 8, 'album': 'Album', 'numsongs': 1}
          ];
        case 'openSongPlayback':
          return {'uri': uri, 'session': 'track-scope'};
        case 'closeSongPlayback':
          return null;
        default:
          throw MissingPluginException();
      }
    });

    final query = MusaicQuery();
    expect(await query.directories.supported, isTrue);
    expect(await query.permissionsStatus(), isFalse);
    expect(calls.map((call) => call.method), ['permissionsStatus']);
    expect(await query.permissionsRequest(), isTrue);
    expect(await query.permissionsStatus(), isTrue);

    final song = (await query.querySongs(
      sortType: SongSortType.DURATION,
      orderType: OrderType.DESC_OR_GREATER,
    ))
        .single;
    expect(song.id, songId);
    expect(song.uri, uri);
    expect(calls.last.arguments['sortType'], SongSortType.DURATION.index);
    expect(calls.last.arguments['orderType'], OrderType.DESC_OR_GREATER.index);
    final album = (await query.queryAlbums()).single;
    expect(album.id, song.albumId);
    expect(album.numOfSongs, 1);

    final playback = (await query.openSongPlayback(song.id))!;
    expect(calls.last.arguments, {'id': songId});
    expect(playback.uri.toFilePath(), '/Music/Track #1.m4a');
    await playback.close();
    await playback.close();
    expect(
      calls
          .where((call) => call.method == 'closeSongPlayback')
          .single
          .arguments,
      {'session': 'track-scope'},
    );
  });
}
