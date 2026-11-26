import Flutter
import MediaPlayer

class AudioQuery {
  var args: [String: Any]
  var result: FlutterResult

  init(args: [String: Any], result: @escaping FlutterResult) {
    self.args = args
    self.result = result
  }

  func querySongs() {
    if let path = args["path"] as? String, !path.isEmpty {
      result(FlutterError(
        code: "UnsupportedDirectoryFilter",
        message: "Use the directory picker to scan an audio folder on iOS.",
        details: nil))
      return
    }
    let sortType = args["sortType"] as? Int ?? 0

    let cursor = MPMediaQuery.songs()

    // Using native sort from [IOS] you can only use the [Title], [Album] and
    // [Artist]. The others will be sorted "manually" using [formatSongList] before
    // send to Dart.
    cursor.groupingType = checkSongSortType(sortType: sortType)

    // Filter to avoid audios/songs from cloud library.
    let cloudFilter = MPMediaPropertyPredicate(
      value: false,
      forProperty: MPMediaItemPropertyIsCloudItem
    )
    cursor.addFilterPredicate(cloudFilter)

    Log.type.debug("Query config: ")
    Log.type.debug("\tsortType: \(sortType)")

    // Query everything in background for a better performance.
    loadSongs(cursor: cursor)
  }

  private func loadSongs(cursor: MPMediaQuery!) {
    DispatchQueue.global(qos: .userInitiated).async {
      var listOfSongs: [[String: Any?]] = Array()

      // For each item(song) inside this "cursor", take one and "format"
      // into a [Map<String, dynamic>], all keys are based on [Android]
      // platforms.
      for song in (cursor.items ?? []) {
        // Ignore cloud items.
        if !song.isCloudItem, song.assetURL != nil {
          let songData = loadSongItem(song: song)
          listOfSongs.append(songData)
        }
      }

      let finalList = formatSongList(args: self.args, allSongs: listOfSongs)
      DispatchQueue.main.async {
        self.result(finalList)
      }
    }
  }
}
