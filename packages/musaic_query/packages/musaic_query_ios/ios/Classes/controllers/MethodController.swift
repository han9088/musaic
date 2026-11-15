import Flutter

public class MethodController {
  public func find(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]

    // All necessary method to this plugin support both platforms, only playlists
    // are limited when using [IOS].
    switch call.method {
    case Method.QUERY_AUDIOS:
      AudioQuery(args: args, result: result).querySongs()
    case Method.QUERY_ALBUMS:
      AlbumQuery(args: args, result: result).queryAlbums()
    case Method.QUERY_ARTISTS:
      ArtistQuery(args: args, result: result).queryArtists()
    case Method.QUERY_GENRES:
      GenreQuery(args: args, result: result).queryGenres()
    case Method.QUERY_PLAYLISTS:
      PlaylistQuery(args: args, result: result).queryPlaylists()
    case Method.QUERY_AUDIOS_FROM:
      AudioFromQuery(args: args, result: result).queryAudiosFrom()
    case Method.QUERY_WITH_FILTERS:
      WithFiltersQuery(args: args, result: result).queryWithFilters()
    case Method.QUERY_ARTWORK:
      ArtworkQuery(args: args, result: result).queryArtwork()
    // The playlist for [IOS] is completely limited, the developer can only:
    //   * Create playlist
    //   * Add item to playlist (Unsuported, for now)
    //
    // Missing methods:
    //   * Rename playlist
    //   * Remove playlist
    //   * Remove item from playlist
    //   * Move item inside playlist
    case Method.CREATE_PLAYLIST:
      PlaylistController(args: args, result: result).createPlaylist()
    case Method.ADD_TO_PLAYLIST:
      PlaylistController(args: args, result: result).addToPlaylist()
    default:
      // All non suported methods will throw this error.
      result(FlutterMethodNotImplemented)
    }
  }
}
