import '../audius_response.dart';
import '../audius_transport.dart';
import '../json_utils.dart';
import '../models.dart';
import '../api_utils.dart';

/// Audius 歌单 API。专辑与歌单共享同一套底层接口。
class AudiusPlaylistsApi {
  const AudiusPlaylistsApi(this._transport);

  final AudiusTransport _transport;

  Future<AudiusResponse<AudiusPlaylist>> getPlaylist({
    required String playlistId,
    String? userId,
  }) async {
    final json = await _transport.getJson(
      'playlists/' + pathSegment(playlistId, 'playlistId'),
      query: <String, Object?>{'user_id': userId},
    );
    return decodeSingleResponse(json, AudiusPlaylist.fromJson);
  }

  Future<AudiusResponse<List<AudiusPlaylist>>> getBulkPlaylists({
    List<String>? ids,
    List<String>? permalinks,
    List<String>? upcs,
    String? userId,
  }) async {
    if ((ids == null || ids.isEmpty) &&
        (permalinks == null || permalinks.isEmpty) &&
        (upcs == null || upcs.isEmpty)) {
      throw ArgumentError(
        'Provide at least one playlist ID, permalink or UPC.',
      );
    }

    final json = await _transport.getJson(
      'playlists',
      query: <String, Object?>{
        'id': ids,
        'permalink': permalinks,
        'upc': upcs,
        'user_id': userId,
      },
    );
    return decodeListResponse(json, AudiusPlaylist.fromJson);
  }

  Future<AudiusResponse<List<AudiusTrack>>> getPlaylistTracks({
    required String playlistId,
  }) async {
    final json = await _transport.getJson(
      'playlists/' + pathSegment(playlistId, 'playlistId') + '/tracks',
    );
    return decodeListResponse(json, AudiusTrack.fromJson);
  }

  Future<AudiusResponse<List<AudiusPlaylist>>> getTrendingPlaylists({
    String time = 'week',
    int? offset,
    int? limit,
    String? userId,
    String? type,
  }) async {
    validatePagination(offset: offset, limit: limit);
    final json = await _transport.getJson(
      'playlists/trending',
      query: <String, Object?>{
        'time': time,
        'offset': offset,
        'limit': limit,
        'user_id': userId,
        'type': type,
      },
    );
    return decodeListResponse(json, AudiusPlaylist.fromJson);
  }

  Future<AudiusResponse<List<AudiusPlaylist>>> searchPlaylists({
    required String query,
    int? offset,
    int? limit,
  }) async {
    validatePagination(offset: offset, limit: limit);
    if (query.trim().isEmpty) {
      throw ArgumentError.value(query, 'query', 'Must not be empty.');
    }

    final json = await _transport.getJson(
      'playlists/search',
      query: <String, Object?>{
        'query': query,
        'offset': offset,
        'limit': limit,
      },
    );
    return decodeListResponse(json, AudiusPlaylist.fromJson);
  }

  /// 获取新发行的专辑/歌单。
  Future<AudiusResponse<List<AudiusPlaylist>>> getNewReleases({
    int? offset,
    int? limit,
  }) async {
    validatePagination(offset: offset, limit: limit);
    final json = await _transport.getJson(
      'playlists/new-releases',
      query: <String, Object?>{'offset': offset, 'limit': limit},
    );
    return decodeListResponse(json, AudiusPlaylist.fromJson);
  }
}
