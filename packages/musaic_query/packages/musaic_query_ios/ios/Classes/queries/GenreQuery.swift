import Flutter
import MediaPlayer

class GenreQuery {
  var args: [String: Any]
  var result: FlutterResult

  init(args: [String: Any], result: @escaping FlutterResult) {
    self.args = args
    self.result = result
  }

  func queryGenres() {
    let cursor = MPMediaQuery.genres()

    // We don't need to define a sortType here. [IOS] only support
    // the [Artist]. The others will be sorted "manually" using
    // [formatSongList] before send to Dart.

    // Filter to avoid audios/songs from cloud library.
    let cloudFilter = MPMediaPropertyPredicate(
      value: false,
      forProperty: MPMediaItemPropertyIsCloudItem
    )
    cursor.addFilterPredicate(cloudFilter)

    // Query everything in background for a better performance.
    loadGenres(cursor: cursor)
  }

  private func loadGenres(cursor: MPMediaQuery) {
    DispatchQueue.global(qos: .userInitiated).async {
      var listOfGenres: [[String: Any?]] = Array()

      // For each item(genre) inside this "cursor", take one and "format"
      // into a [Map<String, dynamic>], all keys are based on [Android]
      // platforms.
      for genre in cursor.collections ?? [] {
        if let first = genre.items.first, !first.isCloudItem, first.assetURL != nil {
          let genreData = loadGenreItem(genre: genre)

          listOfGenres.append(genreData)
        }
      }

      let finalList = formatGenreList(args: self.args, allGenres: listOfGenres)
      DispatchQueue.main.async {
        self.result(finalList)
      }
    }
  }
}
