/*
=============
Author: Lucas Josino
Github: https://github.com/LucJosin
Website: https://www.lucasjosino.com/
=============
Plugin/Id: musaic_query#0
Copyright: © 2021, Lucas Josino. All rights reserved.
=============
*/

library musaic_query_web;

import 'dart:js_interop';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:musaic_query_platform_interface/musaic_query_platform_interface.dart';

import 'package:flutter/services.dart';
import 'src/musaic_query_web_controller.dart';

@JS('navigator.userAgent')
external JSString get _userAgent;

/// A web implementation of the MusaicQueryWeb plugin.
class MusaicQueryPlugin extends MusaicQueryPlatform {
  final MusaicQueryWebController _controller = MusaicQueryWebController();

  /// Registers this class as the default instance of [MusaicQueryPlatform].
  static void registerWith(Registrar registrar) {
    MusaicQueryPlatform.instance = MusaicQueryPlugin();
  }

  @override
  Future<List<SongModel>> querySongs({
    SongSortType? sortType,
    OrderType? orderType,
    UriType? uriType,
    bool? ignoreCase,
    String? path,
  }) async {
    return _controller.querySongs(
        sortType, orderType, ignoreCase ?? true, path);
  }

  @override
  Future<List<AlbumModel>> queryAlbums({
    AlbumSortType? sortType,
    OrderType? orderType,
    UriType? uriType,
    bool? ignoreCase,
  }) async {
    return _controller.queryAlbums(sortType, orderType, ignoreCase ?? true);
  }

  @override
  Future<List<ArtistModel>> queryArtists({
    ArtistSortType? sortType,
    OrderType? orderType,
    UriType? uriType,
    bool? ignoreCase,
  }) async {
    return _controller.queryArtists(sortType, orderType, ignoreCase ?? true);
  }

  @override
  Future<List<GenreModel>> queryGenres({
    GenreSortType? sortType,
    OrderType? orderType,
    UriType? uriType,
    bool? ignoreCase,
  }) async {
    return _controller.queryGenres(sortType, orderType, ignoreCase ?? true);
  }

  @override
  Future<List<SongModel>> queryAudiosFrom(
    AudiosFromType type,
    Object where, {
    SongSortType? sortType,
    OrderType? orderType,
    bool? ignoreCase,
  }) async {
    return _controller.queryAudiosFrom(
      type,
      where,
      sortType,
      orderType,
      ignoreCase ?? true,
    );
  }

  @override
  Future<List<dynamic>> queryWithFilters(
    String argsVal,
    WithFiltersType withType,
    dynamic args,
  ) async {
    return _controller.queryWithFilters(argsVal, withType, args);
  }

  @override
  Future<DeviceModel> queryDeviceInfo() async {
    Map tmpMap = {
      "device_model": _browserName(_userAgent.toDart),
      "device_sys_type": "Web",
      "device_sys_version": -1,
    };
    return DeviceModel(tmpMap);
  }

  @override
  Future<Uint8List?> queryArtwork(
    int id,
    ArtworkType type, {
    ArtworkFormat? format,
    int? size,
    int? quality,
  }) async {
    return _controller.queryArtwork(id, type, format, size, quality);
  }
}

String _browserName(String userAgent) {
  for (final entry in {
    'Firefox': 'Firefox',
    'SamsungBrowser': 'SamsungBrowser',
    'OPR': 'Opera',
    'Trident': 'Trident',
    'Edg': 'Edge',
    'Chrome': 'Chrome',
    'Safari': 'Safari',
  }.entries) {
    if (userAgent.contains(entry.key)) return entry.value;
  }
  return 'Unknown';
}
