import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:id3/id3.dart';
import 'package:musaic_query_platform_interface/musaic_query_platform_interface.dart';
import 'package:path/path.dart' as path;

/// Indexes immutable bundled MP3 assets. IDs are scoped to this asset manifest.
class MusaicQueryWebController {
  MusaicQueryWebController({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  Future<List<SongModel>>? _index;
  final _artwork = <String, Uint8List?>{};
  final _loadingArtwork = <String, Future<Uint8List?>>{};
  int _artworkBytes = 0;
  static const _maxArtworkBytes = 8 * 1024 * 1024;
  static const _maxArtworkEntries = 128;

  Future<List<SongModel>> _songs() async {
    final pending = _index ??= _loadIndex();
    try {
      return await pending;
    } catch (_) {
      if (identical(_index, pending)) _index = null;
      rethrow;
    }
  }

  Future<MP3Instance> _mp3(String asset) async {
    final data = await _bundle.load(asset);
    return MP3Instance(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  Map<String, dynamic> _tags(MP3Instance mp3) {
    try {
      if (mp3.parseTagsSync()) return mp3.getMetaTags() ?? {};
    } on FormatException {
      return {};
    } on RangeError {
      return {};
    }
    return {};
  }

  Future<List<SongModel>> _loadIndex() async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final assets = manifest
        .listAssets()
        .where((key) => key.toLowerCase().endsWith('.mp3'))
        .toList()
      ..sort();
    final albums = <(String, String?), int>{};
    final artists = <String, int>{};
    final genres = <String, int>{};
    final songs = <SongModel>[];
    int? groupId<Key extends Object>(Map<Key, int> groups, Key? key) =>
        key == null ? null : groups.putIfAbsent(key, () => groups.length + 1);
    for (final asset in assets) {
      final mp3 = await _mp3(asset);
      final tags = _tags(mp3);
      String? tag(String key) {
        final value = tags[key];
        return value is String && value.isNotEmpty ? value : null;
      }

      final album = tag('Album');
      final artist = tag('Artist');
      final albumArtist = tag('Accompaniment') ?? artist;
      final genre = tag('Genre');
      songs.add(SongModel(Map.unmodifiable({
        '_id': songs.length + 1,
        '_data': asset,
        '_uri': asset,
        '_display_name': path.basename(asset),
        '_display_name_wo_ext': path.basenameWithoutExtension(asset),
        '_size': mp3.mp3Bytes.length,
        'title': tag('Title') ?? path.basenameWithoutExtension(asset),
        'album': album,
        'album_id':
            groupId(albums, album == null ? null : (album, albumArtist)),
        'artist': artist,
        'artist_id': groupId(artists, artist),
        'genre': genre,
        'genre_id': groupId(genres, genre),
        'track': int.tryParse('${tags['Track']}'.split('/').first),
        'file_extension': path.extension(asset).replaceFirst('.', ''),
      })));
    }
    return List.unmodifiable(songs);
  }

  Future<List<SongModel>> querySongs([
    SongSortType? sortType,
    OrderType? orderType,
    bool ignoreCase = true,
    String? folder,
  ]) async {
    var songs = await _songs();
    if (folder != null) {
      final prefix = '${folder.replaceFirst(RegExp(r'/+$'), '')}/';
      songs = songs.where((song) => song.data.startsWith(prefix)).toList();
    }
    return _sortSongs(songs, sortType, orderType, ignoreCase);
  }

  List<SongModel> _sortSongs(List<SongModel> songs, SongSortType? type,
      OrderType? order, bool ignoreCase) {
    return _sorted(songs, (song) {
      switch (type ?? SongSortType.TITLE) {
        case SongSortType.TITLE:
          return song.title;
        case SongSortType.ARTIST:
          return song.artist;
        case SongSortType.ALBUM:
          return song.album;
        case SongSortType.DURATION:
          return song.duration;
        case SongSortType.DATE_ADDED:
          return song.dateAdded;
        case SongSortType.SIZE:
          return song.size;
        case SongSortType.DISPLAY_NAME:
          return song.displayName;
      }
    }, order, ignoreCase);
  }

  Map<int, List<SongModel>> _groups(
      List<SongModel> songs, int? Function(SongModel) key) {
    final groups = <int, List<SongModel>>{};
    for (final song in songs) {
      final id = key(song);
      if (id != null) (groups[id] ??= []).add(song);
    }
    return groups;
  }

  Future<List<AlbumModel>> queryAlbums(
      [AlbumSortType? type, OrderType? order, bool ignoreCase = true]) async {
    final albums =
        _groups(await _songs(), (song) => song.albumId).entries.map((entry) {
      final song = entry.value.first;
      return AlbumModel({
        '_id': entry.key,
        'album': song.album,
        'artist': song.artist,
        'artist_id': song.artistId,
        'numsongs': entry.value.length
      });
    }).toList();
    return _sorted(albums, (album) {
      switch (type ?? AlbumSortType.ALBUM) {
        case AlbumSortType.ALBUM:
          return album.album;
        case AlbumSortType.ARTIST:
          return album.artist;
        case AlbumSortType.NUM_OF_SONGS:
          return album.numOfSongs;
      }
    }, order, ignoreCase);
  }

  Future<List<ArtistModel>> queryArtists(
      [ArtistSortType? type, OrderType? order, bool ignoreCase = true]) async {
    final artists =
        _groups(await _songs(), (song) => song.artistId).entries.map((entry) {
      return ArtistModel({
        '_id': entry.key,
        'artist': entry.value.first.artist,
        'number_of_tracks': entry.value.length,
        'number_of_albums': entry.value
            .map((song) => song.albumId)
            .whereType<int>()
            .toSet()
            .length
      });
    }).toList();
    return _sorted(artists, (artist) {
      switch (type ?? ArtistSortType.ARTIST) {
        case ArtistSortType.ARTIST:
          return artist.artist;
        case ArtistSortType.NUM_OF_TRACKS:
          return artist.numberOfTracks;
        case ArtistSortType.NUM_OF_ALBUMS:
          return artist.numberOfAlbums;
      }
    }, order, ignoreCase);
  }

  Future<List<GenreModel>> queryGenres(
      [GenreSortType? type, OrderType? order, bool ignoreCase = true]) async {
    final genres = _groups(await _songs(), (song) => song.genreId)
        .entries
        .map((entry) => GenreModel({
              '_id': entry.key,
              'name': entry.value.first.genre,
              'num_of_songs': entry.value.length
            }))
        .toList();
    return _sorted(genres, (genre) => genre.genre, order, ignoreCase);
  }

  Future<List<SongModel>> queryAudiosFrom(AudiosFromType type, Object where,
      [SongSortType? sortType,
      OrderType? order,
      bool ignoreCase = true]) async {
    if (type == AudiosFromType.PLAYLIST) {
      throw UnsupportedError('Web assets do not contain playlists');
    }
    final songs = (await _songs()).where((song) {
      switch (type) {
        case AudiosFromType.ALBUM:
          return song.album == where;
        case AudiosFromType.ALBUM_ID:
          return song.albumId == where;
        case AudiosFromType.ARTIST:
          return song.artist == where;
        case AudiosFromType.ARTIST_ID:
          return song.artistId == where;
        case AudiosFromType.GENRE:
          return song.genre == where;
        case AudiosFromType.GENRE_ID:
          return song.genreId == where;
        case AudiosFromType.PLAYLIST:
          return false;
      }
    }).toList();
    return _sortSongs(songs, sortType, order, ignoreCase);
  }

  Future<List<dynamic>> queryWithFilters(
      String value, WithFiltersType type, dynamic args) async {
    bool matches(String? text) =>
        text?.toLowerCase().contains(value.toLowerCase()) ?? false;
    switch (type) {
      case WithFiltersType.AUDIOS:
        return (await querySongs())
            .where((song) {
              switch (args ?? AudiosArgs.TITLE) {
                case AudiosArgs.TITLE:
                  return matches(song.title);
                case AudiosArgs.DISPLAY_NAME:
                  return matches(song.displayName);
                case AudiosArgs.ALBUM:
                  return matches(song.album);
                case AudiosArgs.ARTIST:
                  return matches(song.artist);
                default:
                  throw ArgumentError.value(args, 'args');
              }
            })
            .map((song) => song.getMap)
            .toList();
      case WithFiltersType.ALBUMS:
        if (args != null && args is! AlbumsArgs) {
          throw ArgumentError.value(args, 'args');
        }
        return (await queryAlbums())
            .where((album) =>
                matches(args == AlbumsArgs.ARTIST ? album.artist : album.album))
            .map((album) => album.getMap)
            .toList();
      case WithFiltersType.ARTISTS:
        return (await queryArtists())
            .where((artist) => matches(artist.artist))
            .map((artist) => artist.getMap)
            .toList();
      case WithFiltersType.GENRES:
        return (await queryGenres())
            .where((genre) => matches(genre.genre))
            .map((genre) => genre.getMap)
            .toList();
      case WithFiltersType.PLAYLISTS:
        throw UnsupportedError('Web assets do not contain playlists');
    }
  }

  Future<Uint8List?> queryArtwork(int id, ArtworkType type,
      [ArtworkFormat? format, int? size, int? quality]) async {
    if (size != null && (size < 1 || size > 4096)) {
      throw RangeError.range(size, 1, 4096, 'size');
    }
    if (quality != null && (quality < 0 || quality > 100)) {
      throw RangeError.range(quality, 0, 100, 'quality');
    }
    final songs = await _songs();
    for (final song in songs) {
      final matches = type == ArtworkType.AUDIO
          ? song.id == id
          : type == ArtworkType.ALBUM
              ? song.albumId == id
              : type == ArtworkType.ARTIST
                  ? song.artistId == id
                  : type == ArtworkType.GENRE
                      ? song.genreId == id
                      : false;
      if (!matches) continue;
      if (_artwork.containsKey(song.data)) {
        final cached = _artwork.remove(song.data);
        _artwork[song.data] = cached;
        return cached == null ? null : Uint8List.fromList(cached);
      }
      final pending =
          _loadingArtwork.putIfAbsent(song.data, () => _loadArtwork(song.data));
      try {
        final bytes = await pending;
        return bytes == null ? null : Uint8List.fromList(bytes);
      } finally {
        if (identical(_loadingArtwork[song.data], pending)) {
          _loadingArtwork.remove(song.data);
        }
      }
    }
    return null;
  }

  Future<Uint8List?> _loadArtwork(String asset) async {
    final tags = _tags(await _mp3(asset));
    final picture = tags['APIC'];
    final encoded = picture is Map ? picture['base64'] : null;
    Uint8List? bytes;
    if (encoded is String) {
      try {
        bytes = base64Decode(encoded);
      } on FormatException {
        bytes = null;
      }
    }
    if ((bytes?.length ?? 0) <= _maxArtworkBytes) {
      _artwork[asset] = bytes;
      _artworkBytes += bytes?.length ?? 0;
      while (_artworkBytes > _maxArtworkBytes ||
          _artwork.length > _maxArtworkEntries) {
        _artworkBytes -= _artwork.remove(_artwork.keys.first)?.length ?? 0;
      }
    }
    return bytes;
  }
}

List<T> _sorted<T>(List<T> values, Object? Function(T) key, OrderType? order,
    bool ignoreCase) {
  final result = List<T>.of(values);
  result.sort((left, right) {
    final a = key(left);
    final b = key(right);
    if (a == null) return b == null ? 0 : 1;
    if (b == null) return -1;
    final comparison = a is num && b is num
        ? a.compareTo(b)
        : (ignoreCase ? a.toString().toLowerCase() : a.toString())
            .compareTo(ignoreCase ? b.toString().toLowerCase() : b.toString());
    return order == OrderType.DESC_OR_GREATER ? -comparison : comparison;
  });
  return result;
}
