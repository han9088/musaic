import '../audius_response.dart';
import '../audius_transport.dart';
import '../json_utils.dart';
import '../models.dart';
import '../api_utils.dart';

/// Audius 用户与创作者 API。Audius 的 Artist 资料使用 User 资源。
class AudiusUsersApi {
  const AudiusUsersApi(this._transport);

  final AudiusTransport _transport;

  Future<AudiusResponse<AudiusUser>> getUser({required String id}) async {
    final json = await _transport.getJson('users/' + pathSegment(id, 'id'));
    return decodeSingleResponse(json, AudiusUser.fromJson);
  }

  Future<AudiusResponse<AudiusUser>> getUserByHandle({
    required String handle,
  }) async {
    final json = await _transport.getJson(
      'users/handle/' + pathSegment(handle, 'handle'),
    );
    return decodeSingleResponse(json, AudiusUser.fromJson);
  }

  Future<AudiusResponse<List<AudiusUser>>> searchUsers({
    String? query,
    int? offset,
    int? limit,
    List<String>? genres,
    String? sortMethod,
    bool? isVerified,
  }) async {
    validatePagination(offset: offset, limit: limit);
    final json = await _transport.getJson(
      'users/search',
      query: <String, Object?>{
        'query': query,
        'offset': offset,
        'limit': limit,
        'genre': genres,
        'sort_method': sortMethod,
        'is_verified': isVerified,
      },
    );
    return decodeListResponse(json, AudiusUser.fromJson);
  }

  /// 获取创作者发布的歌曲。
  Future<AudiusResponse<List<AudiusTrack>>> getTracksByUser({
    required String id,
    int? offset,
    int? limit,
    String? filterTracks,
    String? query,
    String? sortDirection,
    String? sortMethod,
  }) async {
    validatePagination(offset: offset, limit: limit);
    final json = await _transport.getJson(
      'users/' + pathSegment(id, 'id') + '/tracks',
      query: <String, Object?>{
        'offset': offset,
        'limit': limit,
        'filter_tracks': filterTracks,
        'query': query,
        'sort_direction': sortDirection,
        'sort_method': sortMethod,
      },
    );
    return decodeListResponse(json, AudiusTrack.fromJson);
  }

  /// 获取创作者发布的专辑。Audius 将专辑建模为 is_album=true 的 Playlist。
  Future<AudiusResponse<List<AudiusPlaylist>>> getAlbumsByUser({
    required String id,
    int? offset,
    int? limit,
  }) async {
    validatePagination(offset: offset, limit: limit);
    final json = await _transport.getJson(
      'users/' + pathSegment(id, 'id') + '/albums',
      query: <String, Object?>{'offset': offset, 'limit': limit},
    );
    return decodeListResponse(json, AudiusPlaylist.fromJson);
  }

  /// 获取创作者的公开歌单。
  Future<AudiusResponse<List<AudiusPlaylist>>> getPlaylistsByUser({
    required String id,
    int? offset,
    int? limit,
  }) async {
    validatePagination(offset: offset, limit: limit);
    final json = await _transport.getJson(
      'users/' + pathSegment(id, 'id') + '/playlists',
      query: <String, Object?>{'offset': offset, 'limit': limit},
    );
    return decodeListResponse(json, AudiusPlaylist.fromJson);
  }

  /// 获取用户收藏的歌曲。
  Future<AudiusResponse<List<AudiusTrack>>> getFavoriteTracks({
    required String id,
    int? offset,
    int? limit,
    String? query,
    String? sortDirection,
    String? sortMethod,
  }) async {
    validatePagination(offset: offset, limit: limit);
    final json = await _transport.getJson(
      'users/${pathSegment(id, 'id')}/library/tracks',
      query: <String, Object?>{
        'type': 'favorite',
        'offset': offset,
        'limit': limit,
        'query': query,
        'sort_direction': sortDirection,
        'sort_method': sortMethod,
      },
    );
    return decodeListResponse(
      json,
      (activity) => AudiusTrack.fromJson(requireJsonMap(activity['item'])),
    );
  }

  /// 获取用户收藏的专辑，不包括转发、购买或热门专辑。
  Future<AudiusResponse<List<AudiusPlaylist>>> getFavoriteAlbums({
    required String id,
    int? offset,
    int? limit,
  }) async {
    validatePagination(offset: offset, limit: limit);
    final json = await _transport.getJson(
      'users/${pathSegment(id, 'id')}/library/albums',
      query: {'type': 'favorite', 'offset': offset, 'limit': limit},
    );
    return decodeListResponse(
      json,
      (activity) => AudiusPlaylist.fromJson(requireJsonMap(activity['item'])),
    );
  }
}
