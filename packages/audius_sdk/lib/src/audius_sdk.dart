import 'package:http/http.dart' as http;

import 'audius_transport.dart';
import 'apis/albums_api.dart';
import 'apis/playlists_api.dart';
import 'apis/resolve_api.dart';
import 'apis/tracks_api.dart';
import 'apis/users_api.dart';

/// Audius Dart SDK 的入口。
///
/// 采用与官方 @audius/sdk 相近的 namespace 结构：tracks、users、
/// playlists、albums 和 resolve。当前版本聚焦播放器所需的只读 API。
class AudiusSdk {
  AudiusSdk({
    String? apiKey,
    String baseUrl = defaultBaseUrl,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 20),
  }) : _transport = AudiusTransport(
         apiKey: apiKey,
         baseUrl: baseUrl,
         client: httpClient ?? http.Client(),
         ownsClient: httpClient == null,
         timeout: timeout,
       ) {
    tracks = AudiusTracksApi(_transport);
    users = AudiusUsersApi(_transport);
    playlists = AudiusPlaylistsApi(_transport);
    albums = AudiusAlbumsApi(playlists: playlists, users: users);
    resolve = AudiusResolveApi(_transport);
  }

  static const String defaultBaseUrl = 'https://api.audius.co/v1';

  final AudiusTransport _transport;

  late final AudiusTracksApi tracks;
  late final AudiusUsersApi users;
  late final AudiusPlaylistsApi playlists;
  late final AudiusAlbumsApi albums;
  late final AudiusResolveApi resolve;

  /// 关闭 SDK 自己创建的 HTTP Client。
  ///
  /// 如果构造时传入了 httpClient，Client 的所有权仍属于调用方，
  /// SDK 不会替调用方关闭它。
  void close() => _transport.close();
}
