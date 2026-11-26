/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'dart:async';

import 'package:apple_music_kit_platform_interface/apple_music_kit_platform_interface.dart';

/// Catalog facade: search and fetch Apple Music catalog resources.
final class MusicCatalogService {
  /// Creates the facade over [platform].
  MusicCatalogService(this._platform, {void Function()? onUse})
      : _onUse = onUse;

  final MusicKitPlatform _platform;
  final void Function()? _onUse;
  final _artworkRequests = <(String, String), Future<List<MusicAnimatedArtwork>>>{};

  /// Searches the catalog for [term].
  ///
  /// [types] selects which resource kinds to search; each kind returns its
  /// own [MusicPage] inside the result. [storefront] defaults to the
  /// user's storefront.
  Future<MusicSearchResult> search(
    String term, {
    Set<MusicResourceType> types = const {
      MusicResourceType.song,
      MusicResourceType.album,
      MusicResourceType.artist,
      MusicResourceType.playlist,
    },
    int limit = 25,
    String? storefront,
  }) {
    _onUse?.call();
    return _platform.searchCatalog(term,
        types: types, limit: limit, storefront: storefront);
  }

  /// Fetches a catalog song by id.
  Future<MusicSong> getSong(String id, {String? storefront}) {
    _onUse?.call();
    return _platform.getCatalogSong(id, storefront: storefront);
  }

  /// Fetches a catalog album by id.
  Future<MusicAlbum> getAlbum(String id,
      {String? storefront, bool includeTracks = false}) {
    _onUse?.call();
    return _platform.getCatalogAlbum(id,
        storefront: storefront, includeTracks: includeTracks);
  }

  /// Fetches animated variants without changing the album's static artwork.
  ///
  /// Requires a numeric catalog album ID, never a library ID. [storefront]
  /// is explicit so requests cannot silently use a different region.
  /// Concurrent identical requests share work; completed results are not cached.
  /// Waits at most 30 seconds; timeout does not cancel the platform request.
  Future<List<MusicAnimatedArtwork>> getAlbumAnimatedArtwork(String id,
      {required String storefront}) {
    _onUse?.call();
    if (!RegExp(r'^[0-9]+$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'Expected a catalog album ID.');
    }
    final country = storefront.toLowerCase();
    if (!RegExp(r'^[a-z]{2}$').hasMatch(country)) {
      throw ArgumentError.value(
          storefront, 'storefront', 'Expected a country code.');
    }
    final key = (id, country);
    final existing = _artworkRequests[key];
    if (existing != null) return existing;
    final completer = Completer<List<MusicAnimatedArtwork>>();
    _artworkRequests[key] = completer.future;
    Future.sync(() => _platform.getAlbumAnimatedArtwork(id, storefront: country))
        .timeout(const Duration(seconds: 30), onTimeout: () {
      throw const MusicKitException(MusicKitErrorCode.requestTimeout,
          message: 'Animated artwork request timed out.');
    }).then((value) {
      if (identical(_artworkRequests[key], completer.future)) {
        _artworkRequests.remove(key);
      }
      completer.complete(value);
    }, onError: (Object error, StackTrace stack) {
      if (identical(_artworkRequests[key], completer.future)) {
        _artworkRequests.remove(key);
      }
      completer.completeError(error, stack);
    });
    return completer.future;
  }

  /// Forgets in-flight request associations. Does not cancel existing callers.
  /// There is no completed-result cache; subsequent calls start a new request.
  void clearAnimatedArtworkRequests() => _artworkRequests.clear();

  /// Fetches a catalog artist by id.
  Future<MusicArtist> getArtist(String id, {String? storefront}) {
    _onUse?.call();
    return _platform.getCatalogArtist(id, storefront: storefront);
  }

  /// Fetches a catalog playlist by id.
  Future<MusicPlaylist> getPlaylist(String id,
      {String? storefront, bool includeTracks = false}) {
    _onUse?.call();
    return _platform.getCatalogPlaylist(id,
        storefront: storefront, includeTracks: includeTracks);
  }

  /// Fetches storefront charts (e.g. top songs).
  Future<List<MusicChart>> getCharts(MusicChartKind kind,
      {String? storefront, int limit = 20}) {
    _onUse?.call();
    return _platform.getCharts(kind, storefront: storefront, limit: limit);
  }

  /// Resolves the user's current storefront.
  Future<MusicStorefront> getCurrentStorefront() {
    _onUse?.call();
    return _platform.getCurrentStorefront();
  }
}
