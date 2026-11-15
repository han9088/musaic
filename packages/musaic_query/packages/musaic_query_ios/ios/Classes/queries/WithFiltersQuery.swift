import Flutter
import MediaPlayer

class WithFiltersQuery {
  var args: [String: Any]
  var result: FlutterResult

  init(args: [String: Any], result: @escaping FlutterResult) {
    self.args = args
    self.result = result
  }

  func queryWithFilters() {
    // None of this arguments can be null.
    // The [type] will be used to define where item will be queried.
    guard let withType = args["withType"] as? Int, (0...4).contains(withType),
      let argVal = args["argsVal"] as? String
    else {
      result(
        FlutterError(code: "InvalidArguments", message: "Invalid filter arguments", details: nil))
      return
    }

    // The [arg] will be used to define the "search".
    let arg = args["args"] as? Int ?? 0
    guard (0...[3, 1, 0, 0, 0][withType]).contains(arg) else {
      result(
        FlutterError(
          code: "InvalidArguments", message: "Filter argument does not match type", details: nil))
      return
    }

    // The [argVal] is the "name" to the "search"

    // (To match android side, let's call "cursor").
    var cursor: MPMediaQuery?
    var filter: MPMediaPropertyPredicate?

    // Use the [type] to define the query.
    switch withType {
    case 0:
      cursor = MPMediaQuery.songs()
      filter = checkSongsArgs(args: arg, argsVal: argVal)
    case 1:
      cursor = MPMediaQuery.albums()
      filter = checkAlbumsArgs(args: arg, argsVal: argVal)
    case 2:
      // To query the playlist we need a different approach.
      // So, filter will be null.
      cursor = MPMediaQuery.playlists()
    case 3:
      cursor = MPMediaQuery.artists()
      filter = checkArtistsArgs(args: arg, argsVal: argVal)
    case 4:
      cursor = MPMediaQuery.genres()
      filter = checkGenresArgs(args: arg, argsVal: argVal)
    default:
      break
    }

    Log.type.debug("Query config: ")
    Log.type.debug("\twithType: \(withType)")
    Log.type.debug("\targ: \(arg)")
    Log.type.debug("\targVal: \(argVal)")
    Log.type.debug("\tcursor: \(String(describing: cursor))")
    Log.type.debug("\tfilter: \(String(describing: filter))")

    // Choose between query [Playlist] or others.
    if filter != nil, withType != 2 {
      // Add the filter.
      cursor?.addFilterPredicate(filter!)

      // Ignore cloud items.
      let cloudFilter = MPMediaPropertyPredicate(
        value: false,
        forProperty: MPMediaItemPropertyIsCloudItem
      )
      cursor?.addFilterPredicate(cloudFilter)

      // Query everything in background for a better performance.
      loadItemsWithFilter(cursor: cursor!, type: withType)
    } else {
      // Ignore cloud items.
      let cloudFilter = MPMediaPropertyPredicate(
        value: false,
        forProperty: MPMediaItemPropertyIsCloudItem
      )
      cursor?.addFilterPredicate(cloudFilter)

      // Query everything in background for a better performance.
      loadPlaylistsWithFilter(cursor: cursor!, argVal: argVal)
    }
  }

  private func loadItemsWithFilter(cursor: MPMediaQuery, type: Int) {
    DispatchQueue.global(qos: .userInitiated).async {
      var listOfItems: [[String: Any?]] = Array()

      // 0 -> Song -> We use [MPMediaItem].
      // 1, 3 or 4 -> Album, Artist or Genre - We use [MPMediaItemCollection].
      if type == 0 {
        // For each item(song) inside this "cursor", take one and "format"
        // into a [Map<String, dynamic>], all keys are based on [Android]
        // platforms so, if you change some key, will have to change the [Android] too.
        for song in (cursor.items ?? []) {
          // If the song file don't has a assetURL, is a Cloud item.
          if !song.isCloudItem, song.assetURL != nil {
            let songData = loadSongItem(song: song)
            listOfItems.append(songData)
          }
        }
        //
      } else {
        // For each item inside "cursor", take one and choose between [Album],
        // [Artist] and [Genre], after this, "format" into a [Map<String, dynamic>],
        // all keys are based on [Android] platforms so, if you change some key, will
        // have to change the [Android] too.
        for item in (cursor.collections ?? []) {
          var itemData: [String: Any?] = [:]
          // Ignore cloud items.
          if let first = item.items.first, !first.isCloudItem, first.assetURL != nil {
            switch type {
            case 1:
              itemData = loadAlbumItem(album: item)
            case 3:
              itemData = loadArtistItem(artist: item)
            case 4:
              itemData = loadGenreItem(genre: item)
            default:
              break
            }
          }
          if !itemData.isEmpty { listOfItems.append(itemData) }
        }
      }

      DispatchQueue.main.async {
        self.result(listOfItems)
      }
    }
  }

  private func loadPlaylistsWithFilter(cursor: MPMediaQuery, argVal: String) {
    DispatchQueue.global(qos: .userInitiated).async {
      var listOfPlaylist: [[String: Any?]] = Array()

      // For each item(playlist) inside this "cursor", take one and check
      // if contains the defined argument, after this "format"
      // into a [Map<String, dynamic>], all keys are based on [Android]
      // platforms so, if you change some key, will have to change the [Android] too.
      for playlist in cursor.collections ?? [] {
        var playlistData: [String: Any?] = [:]
        let iPlaylist = playlist as! MPMediaPlaylist

        // Check if some playlist contains the defined argument.
        if iPlaylist.name?.localizedCaseInsensitiveContains(argVal) == true,
          iPlaylist.items.first?.isCloudItem != true
        {
          playlistData = loadPlaylistItem(playlist: playlist)
        }
        if !playlistData.isEmpty { listOfPlaylist.append(playlistData) }
      }

      DispatchQueue.main.async {
        self.result(listOfPlaylist)
      }
    }
  }
}
