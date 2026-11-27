import Flutter
import MediaPlayer

class AudioFromQuery {
  var args: [String: Any]
  var result: FlutterResult
  var type: Int = -1

  init(args: [String: Any], result: @escaping FlutterResult) {
    self.args = args
    self.result = result
  }

  func queryAudiosFrom() {
    guard let type = args["type"] as? Int, let value = args["where"] else {
      result(
        FlutterError(code: "InvalidArguments", message: "type and where are required", details: nil)
      )
      return
    }
    DispatchQueue.global(qos: .userInitiated).async {
      var items: [MPMediaItem] = []
      if type == 6 {
        let playlists = MPMediaQuery.playlists().collections ?? []
        for case let playlist as MPMediaPlaylist in playlists {
          let matches: Bool
          if let name = value as? String {
            matches = playlist.name == name
          } else if let id = value as? NSNumber {
            matches = playlist.persistentID == id.uint64Value
          } else {
            matches = false
          }
          if matches { items.append(contentsOf: playlist.items) }
        }
      } else if let query = checkAudiosFrom(type: type, where: value) {
        items = query.items ?? []
      }
      let songs = items.filter { !$0.isCloudItem && $0.assetURL != nil }.map {
        loadSongItem(song: $0)
      }
      let sorted = formatSongList(args: self.args, allSongs: songs)
      DispatchQueue.main.async { self.result(sorted) }
    }
  }
}
