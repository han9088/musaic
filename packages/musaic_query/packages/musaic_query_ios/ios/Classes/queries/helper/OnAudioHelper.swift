import MediaPlayer

// This will "clean" the main method and help all query methods.

public func loadSongItem(song: MPMediaItem) -> [String: Any?] {
  let fileExt = song.assetURL?.pathExtension ?? ""
  let sizeInBytes = song.value(forProperty: "fileSize") as? Int
  let songData: [String: Any?] = [
    "_id": Int64(bitPattern: song.persistentID),
    "_data": song.assetURL?.absoluteString,
    "_uri": song.assetURL?.absoluteString,
    "_display_name": "\(song.artist ?? "") - \(song.title ?? "").\(fileExt)",
    "_display_name_wo_ext": "\(song.artist ?? "") - \(song.title ?? "")",
    "_size": sizeInBytes ?? 0,
    "album": song.albumTitle,
    "album_id": Int64(bitPattern: song.albumPersistentID),
    "artist": song.artist,
    "artist_id": Int64(bitPattern: song.artistPersistentID),
    "genre": song.genre,
    "genre_id": Int64(bitPattern: song.genrePersistentID),
    "bookmark": Int(song.bookmarkTime),
    "composer": song.composer,
    "date_added": Int(song.dateAdded.timeIntervalSince1970),
    "date_modified": 0,
    "duration": Int(song.playbackDuration * 1000),
    "title": song.title ?? "",
    "track": song.albumTrackNumber,
    "disc": song.discNumber,
    "is_protected": song.hasProtectedAsset,
    "file_extension": fileExt,
  ]
  return songData
}

public func formatSongList(args: [String: Any], allSongs: [[String: Any?]]) -> [[String: Any?]] {
  let keys = ["title", "artist", "album", "duration", "date_added", "_size", "_display_name"]
  let index = args["sortType"] as? Int ?? 0
  let safeIndex = keys.indices.contains(index) ? index : 0
  return sortMedia(
    allSongs, key: keys[safeIndex], numeric: [3, 4, 5].contains(safeIndex), args: args)
}

// Albums

func loadAlbumItem(album: MPMediaItemCollection) -> [String: Any?] {
  let albumData: [String: Any?] = [
    "numsongs": album.count,
    "artist": album.items.first?.albumArtist,
    "_id": Int64(bitPattern: album.persistentID),
    "album": album.items.first?.albumTitle,
    "artist_id": album.items.first.map { Int64(bitPattern: $0.artistPersistentID) },
    "album_id": album.items.first.map { Int64(bitPattern: $0.albumPersistentID) },
  ]
  return albumData
}

public func formatAlbumList(args: [String: Any], allAlbums: [[String: Any?]]) -> [[String: Any?]] {
  let keys = ["album", "artist", "numsongs"]
  let index = args["sortType"] as? Int ?? 0
  let safeIndex = keys.indices.contains(index) ? index : 0
  return sortMedia(allAlbums, key: keys[safeIndex], numeric: [2].contains(safeIndex), args: args)
}

// Artists

func loadArtistItem(artist: MPMediaItemCollection) -> [String: Any?] {
  let albumIds = Set(artist.items.filter { $0.albumTitle != nil }.map { $0.albumPersistentID })

  //
  let artistData: [String: Any?] = [
    "_id": artist.items.first.map { Int64(bitPattern: $0.artistPersistentID) },
    "artist": artist.items.first?.artist,
    "number_of_albums": albumIds.count,
    "number_of_tracks": artist.count,
  ]
  return artistData
}

public func formatArtistList(args: [String: Any], allArtists: [[String: Any?]]) -> [[String: Any?]]
{
  let keys = ["artist", "number_of_tracks", "number_of_albums"]
  let index = args["sortType"] as? Int ?? 0
  let safeIndex = keys.indices.contains(index) ? index : 0
  return sortMedia(
    allArtists, key: keys[safeIndex], numeric: [1, 2].contains(safeIndex), args: args)
}

// Genres

func loadGenreItem(genre: MPMediaItemCollection) -> [String: Any?] {
  //
  let genreData: [String: Any?] = [
    "_id": genre.items.first.map { Int64(bitPattern: $0.genrePersistentID) },
    "name": genre.items.first?.genre,
    "num_of_songs": genre.count,
  ]
  return genreData
}

public func formatGenreList(args: [String: Any], allGenres: [[String: Any?]]) -> [[String: Any?]] {
  let keys = ["name"]
  let index = args["sortType"] as? Int ?? 0
  let safeIndex = keys.indices.contains(index) ? index : 0
  return sortMedia(allGenres, key: keys[safeIndex], numeric: false, args: args)
}

func loadPlaylistItem(playlist: MPMediaItemCollection) -> [String: Any?] {
  // Get the artwork from the first song inside the playlist
  var artwork: Data?
  if playlist.items.count >= 1 {
    artwork = playlist.items[0].artwork?.image(at: CGSize(width: 150, height: 150))?.jpegData(
      compressionQuality: 1)
  }
  //
  let id = Int64(bitPattern: playlist.persistentID)
  let dateAdded = playlist.value(forProperty: "dateCreated") as? Date
  let dateModified = playlist.value(forProperty: "dateModified") as? Date
  let playlistData: [String: Any?] = [
    "_id": id,
    "name": playlist.value(forProperty: MPMediaPlaylistPropertyName),
    "date_added": dateAdded.map { Int($0.timeIntervalSince1970) },
    "date_modified": dateModified.map { Int($0.timeIntervalSince1970) },
    "number_of_tracks": playlist.items.count,
    "artwork": artwork,
  ]
  return playlistData
}

extension String {
  func isCase(ignoreCase: Bool) -> String {
    if ignoreCase {
      return self.lowercased()
    } else {
      return self
    }
  }
}

private func sortMedia(
  _ items: [[String: Any?]], key: String, numeric: Bool,
  args: [String: Any]
) -> [[String: Any?]] {
  let ignoreCase = args["ignoreCase"] as? Bool ?? true
  let descending = args["orderType"] as? Int == 1
  return items.sorted { left, right in
    let a = left[key] ?? nil
    let b = right[key] ?? nil
    if a == nil { return false }
    if b == nil { return true }
    if numeric {
      let x = (a as? NSNumber)?.doubleValue ?? 0
      let y = (b as? NSNumber)?.doubleValue ?? 0
      return descending ? x > y : x < y
    }
    let x = (a as? String ?? "").isCase(ignoreCase: ignoreCase)
    let y = (b as? String ?? "").isCase(ignoreCase: ignoreCase)
    return descending ? x > y : x < y
  }
}
