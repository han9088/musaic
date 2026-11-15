import Flutter
import MediaPlayer

class ArtistQuery {
  var args: [String: Any]
  var result: FlutterResult

  init(args: [String: Any], result: @escaping FlutterResult) {
    self.args = args
    self.result = result
  }

  func queryArtists() {
    let cursor = MPMediaQuery.artists()

    // We don't need to define a sortType here. [IOS] only support
    // the [Artist]. The others will be sorted "manually" using
    // [formatSongList] before send to Dart.

    // Filter to avoid audios/songs from cloud library.
    let cloudFilter = MPMediaPropertyPredicate(
      value: false,
      forProperty: MPMediaItemPropertyIsCloudItem
    )
    cursor.addFilterPredicate(cloudFilter)

    loadArtists(cursor: cursor)
  }

  private func loadArtists(cursor: MPMediaQuery) {
    DispatchQueue.global(qos: .userInitiated).async {
      var listOfArtists: [[String: Any?]] = Array()

      // For each item(artist) inside this "cursor", take one and "format"
      // into a [Map<String, dynamic>], all keys are based on [Android]
      // platforms.
      for artist in cursor.collections ?? [] {
        if let first = artist.items.first, !first.isCloudItem, first.assetURL != nil {
          let artistData = loadArtistItem(artist: artist)
          listOfArtists.append(artistData)
        }
      }

      let finalList = formatArtistList(args: self.args, allArtists: listOfArtists)
      DispatchQueue.main.async {
        self.result(finalList)
      }
    }
  }
}
