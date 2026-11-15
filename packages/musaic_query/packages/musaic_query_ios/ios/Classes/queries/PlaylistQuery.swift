import Flutter
import MediaPlayer

class PlaylistQuery {
  var args: [String: Any]
  var result: FlutterResult

  init(args: [String: Any], result: @escaping FlutterResult) {
    self.args = args
    self.result = result
  }

  func queryPlaylists() {
    let cursor = MPMediaQuery.playlists()

    // TODO: Add sort type to [queryPlaylists].

    // Query everything in background for a better performance.
    loadPlaylists(cursor: cursor)
  }

  private func loadPlaylists(cursor: MPMediaQuery) {
    DispatchQueue.global(qos: .userInitiated).async {
      var listOfPlaylists: [[String: Any?]] = Array()

      // For each item(playlist) inside this "cursor", take one and "format"
      // into a [Map<String, dynamic>], all keys are based on [Android]
      // platforms.
      for playlist in cursor.collections ?? [] {
        // Ignore cloud items.
        if playlist.items.isEmpty
          || playlist.items.contains(where: { !$0.isCloudItem && $0.assetURL != nil })
        {
          let playlistData = loadPlaylistItem(playlist: playlist)

          listOfPlaylists.append(playlistData)
        }
      }

      DispatchQueue.main.async {
        // TODO: Add sort type to [queryPlaylists].
        self.result(listOfPlaylists)
      }
    }
  }
}
