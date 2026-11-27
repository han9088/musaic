import Flutter
import MediaPlayer

class AlbumQuery {
  var args: [String: Any]
  var result: FlutterResult

  init(args: [String: Any], result: @escaping FlutterResult) {
    self.args = args
    self.result = result
  }

  func queryAlbums() {
    let sortType = args["sortType"] as? Int ?? 0

    let cursor = MPMediaQuery.albums()

    // Using native sort from [IOS] you can only use the [Album] and [Artist].
    // The others will be sorted "manually" using [formatAlbumList] before
    // send to Dart.

    // Filter to avoid audios/songs from cloud library.
    let cloudFilter = MPMediaPropertyPredicate(
      value: false,
      forProperty: MPMediaItemPropertyIsCloudItem
    )
    cursor.addFilterPredicate(cloudFilter)

    Log.type.debug("Query config: ")
    Log.type.debug("\tsortType: \(sortType)")

    // Query everything in background for a better performance.
    loadAlbums(cursor: cursor)
  }

  private func loadAlbums(cursor: MPMediaQuery) {
    DispatchQueue.global(qos: .userInitiated).async {
      var listOfAlbums: [[String: Any?]] = Array()

      // For each item(album) inside this "cursor", take one and "format"
      // into a [Map<String, dynamic>], all keys are based on [Android]
      // platforms.
      for album in cursor.collections ?? [] {
        if let first = album.items.first, !first.isCloudItem, first.assetURL != nil {
          let albumData = loadAlbumItem(album: album)
          listOfAlbums.append(albumData)
        }
      }

      let finalList = formatAlbumList(args: self.args, allAlbums: listOfAlbums)
      DispatchQueue.main.async {
        self.result(finalList)
      }
    }
  }
}
