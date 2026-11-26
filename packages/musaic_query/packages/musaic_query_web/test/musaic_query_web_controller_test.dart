import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:musaic_query_platform_interface/musaic_query_platform_interface.dart';
import 'package:musaic_query_web/src/musaic_query_web_controller.dart';
import 'support/assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('indexes once across concurrent queries, filters and artwork reads',
      () async {
    final bundle = TestBundle({
      'assets/one.mp3':
          mp3('Hello', artist: 'Singer', album: 'Album', genre: 'Rock'),
      'assets/two.mp3':
          mp3('Help', artist: 'Singer', album: 'Album', genre: 'Rock'),
    });
    final query = MusaicQueryWebController(bundle: bundle);
    final results = await Future.wait([query.querySongs(), query.querySongs()]);
    expect(results.first.map((song) => song.id).toSet().length, 2);
    expect(bundle.reads['assets/one.mp3'], 1);
    expect(bundle.reads['assets/two.mp3'], 1);
    expect((await query.queryAlbums()).single.numOfSongs, 2);
    expect((await query.queryArtists()).single.numberOfTracks, 2);
    expect((await query.queryGenres()).single.numOfSongs, 2);
    expect(
        await query.queryWithFilters(
            'help', WithFiltersType.AUDIOS, AudiosArgs.TITLE),
        hasLength(1));
    expect(
        await query.queryWithFilters(
            'singer', WithFiltersType.ALBUMS, AlbumsArgs.ARTIST),
        hasLength(1));
    final id = results.first.first.id;
    expect(await query.queryArtwork(id, ArtworkType.AUDIO), isNull);
    expect(await query.queryArtwork(id, ArtworkType.AUDIO), isNull);
    expect(bundle.reads['assets/one.mp3'], 2);
    expect(bundle.reads['assets/two.mp3'], 1);
  });

  test(
      'artwork requests coalesce and cached bytes cannot be mutated by callers',
      () async {
    final picture = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
    final bundle = TestBundle({'a.mp3': mp3('A', picture: picture)});
    final query = MusaicQueryWebController(bundle: bundle);
    final id = (await query.querySongs()).single.id;
    final results = await Future.wait([
      query.queryArtwork(id, ArtworkType.AUDIO),
      query.queryArtwork(id, ArtworkType.AUDIO),
    ]);
    expect(results.first, picture);
    expect(results.last, picture);
    expect(bundle.reads['a.mp3'], 2);
    results.first![0] = 0;
    expect(await query.queryArtwork(id, ArtworkType.AUDIO), picture);
    expect(bundle.reads['a.mp3'], 2);
  });

  test('sorts case and descending order consistently including ID filters',
      () async {
    final query = MusaicQueryWebController(
        bundle: TestBundle({
      'assets/a.mp3': mp3('Zebra', album: 'One'),
      'assets/b.mp3': mp3('apple', album: 'One'),
    }));
    expect((await query.querySongs()).map((s) => s.title), ['apple', 'Zebra']);
    expect((await query.querySongs(null, null, false)).map((s) => s.title),
        ['Zebra', 'apple']);
    final album = (await query.queryAlbums()).single;
    expect(
        (await query.queryAudiosFrom(AudiosFromType.ALBUM_ID, album.id, null,
                OrderType.DESC_OR_GREATER))
            .map((s) => s.title),
        ['Zebra', 'apple']);
  });

  test('handles short metadata and literal percent signs in asset paths',
      () async {
    final query = MusaicQueryWebController(
        bundle: TestBundle({
      'assets/100% mix/short.mp3': mp3('A', artist: ''),
      'assets/untagged.mp3': Uint8List(128),
    }));
    final songs = await query.querySongs();
    expect(songs, hasLength(2));
    expect(songs.map((s) => s.title), contains('untagged'));
    expect(await query.querySongs(null, null, true, 'assets/100% mix'),
        hasLength(1));
    expect(() => songs.first.getMap['_id'] = 7, throwsUnsupportedError);
  });

  test('separates same-name albums and keeps compilation tracks together',
      () async {
    final query = MusaicQueryWebController(
        bundle: TestBundle({
      'a.mp3': mp3('One', artist: 'A', album: 'Hits'),
      'b.mp3': mp3('Two', artist: 'B', album: 'Hits'),
      'c.mp3': mp3('Three',
          artist: 'A', album: 'Hits', albumArtist: 'Various Artists'),
      'd.mp3': mp3('Four',
          artist: 'B', album: 'Hits', albumArtist: 'Various Artists'),
    }));
    final albums = await query.queryAlbums();
    final songs = await Future.wait(albums.map(
        (album) => query.queryAudiosFrom(AudiosFromType.ALBUM_ID, album.id)));
    expect(
        songs.map((group) => group.map((song) => song.title).toList()),
        unorderedEquals([
          ['One'],
          ['Two'],
          ['Four', 'Three']
        ]));
  });

  test('retries a failed index load and validates artwork dimensions',
      () async {
    final bundle = TestBundle({'a.mp3': mp3('A')})..failNextLoad = true;
    final query = MusaicQueryWebController(bundle: bundle);
    await expectLater(query.querySongs(), throwsStateError);
    expect(await query.querySongs(), hasLength(1));
    await expectLater(
        query.queryArtwork(1, ArtworkType.AUDIO, null, 0), throwsRangeError);
    await expectLater(query.queryArtwork(1, ArtworkType.AUDIO, null, 200, -1),
        throwsRangeError);
  });
}
