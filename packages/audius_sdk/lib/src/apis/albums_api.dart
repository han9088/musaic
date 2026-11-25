import '../audius_response.dart';
import '../models.dart';
import 'playlists_api.dart';
import 'users_api.dart';

/// 专辑便捷 API。
///
/// Audius API 没有独立的 Album 资源：专辑是 is_album=true 的 Playlist。
/// 此类只提供语义化方法，不复制或重写底层请求。
class AudiusAlbumsApi {
  const AudiusAlbumsApi({
    required AudiusPlaylistsApi playlists,
    required AudiusUsersApi users,
  }) : _playlists = playlists,
       _users = users;

  final AudiusPlaylistsApi _playlists;
  final AudiusUsersApi _users;

  Future<AudiusResponse<AudiusPlaylist>> getAlbum({
    required String albumId,
    String? userId,
  }) {
    return _playlists.getPlaylist(playlistId: albumId, userId: userId);
  }

  Future<AudiusResponse<List<AudiusPlaylist>>> getAlbumsByUser({
    required String userId,
    int? offset,
    int? limit,
  }) {
    return _users.getAlbumsByUser(id: userId, offset: offset, limit: limit);
  }

  Future<AudiusResponse<List<AudiusTrack>>> getAlbumTracks({
    required String albumId,
  }) {
    return _playlists.getPlaylistTracks(playlistId: albumId);
  }
}
