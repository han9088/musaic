import FlutterMacOS
import Foundation
import iTunesLibrary

final class MacosMusicLibrary {
  private typealias Row = [String: Any]

  private enum LibraryError: LocalizedError {
    case unavailable, unavailableTrack, unsupportedPath

    var errorDescription: String? {
      switch self {
      case .unavailable: return "Could not refresh the Music library"
      case .unavailableTrack: return "The Music library track has no readable local file"
      case .unsupportedPath: return "Use directories to query audio in a folder on macOS"
      }
    }
  }

  private let queue = DispatchQueue(label: "com.deskbtm.musaic.query.music-library", qos: .userInitiated)
  private var library: ITLibrary?
  private var songs: [Int64: ITLibMediaItem]?
  private var playback: [String: URL] = [:]

  deinit {
    for url in playback.values { url.stopAccessingSecurityScopedResource() }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    queue.async {
      let value: Any?
      do {
        value = try self.perform(call)
      } catch {
        value = FlutterError(
          code: "music_library", message: error.localizedDescription, details: nil)
      }
      DispatchQueue.main.async { result(value) }
    }
  }

  private func perform(_ call: FlutterMethodCall) throws -> Any? {
    let args = call.arguments as? Row ?? [:]
    switch call.method {
    case "permissionsStatus":
      // Initializing ITLibrary can prompt. Only a request or a query opens it.
      return library != nil
    case "permissionsRequest":
      return (try? openLibrary()) != nil
    case "querySongs":
      if let path = args["path"] as? String, !path.isEmpty {
        throw LibraryError.unsupportedPath
      }
      return sorted(
        try refreshSongs().map(songRow), args: args,
        keys: ["title", "artist", "album", "duration", "date_added", "_size", "_display_name"])
    case "queryAlbums":
      return sorted(
        albumRows(try refreshSongs()), args: args, keys: ["album", "artist", "numsongs"])
    case "openSongPlayback":
      return try openPlayback(args["id"] as? Int64)
    case "closeSongPlayback":
      if let session = args["session"] as? String {
        playback.removeValue(forKey: session)?.stopAccessingSecurityScopedResource()
      }
      return nil
    default:
      return FlutterMethodNotImplemented
    }
  }

  private func openLibrary() throws -> ITLibrary {
    if let library { return library }
    let opened = try ITLibrary(apiVersion: "1.0")
    library = opened
    return opened
  }

  private func refreshSongs() throws -> [ITLibMediaItem] {
    let current = try openLibrary()
    if songs != nil && !current.reloadData() {
      library = nil
      songs = nil
      throw LibraryError.unavailable
    }
    let rows = current.allMediaItems.filter { item in
      item.mediaKind == .kindSong && item.locationType == .file &&
        item.location?.isFileURL == true
    }
    songs = Dictionary(rows.map { ($0.persistentID.int64Value, $0) }, uniquingKeysWith: { first, _ in first })
    return rows
  }

  private func songRow(_ item: ITLibMediaItem) -> Row {
    let url = item.location
    var row: Row = [
      "_id": item.persistentID.int64Value,
      "_data": url?.path ?? "",
      "_display_name": url?.lastPathComponent ?? item.title,
      "_display_name_wo_ext": url?.deletingPathExtension().lastPathComponent ?? item.title,
      "_size": Int64(clamping: item.fileSize),
      "album": item.album.title as Any?,
      "artist": item.artist?.name as Any?,
      "artist_id": item.artist?.persistentID.int64Value as Any?,
      "composer": item.composer,
      "date_added": item.addedDate.map { Int64($0.timeIntervalSince1970) } as Any?,
      "date_modified": item.modifiedDate.map { Int64($0.timeIntervalSince1970) } as Any?,
      "duration": Int64(clamping: item.totalTime),
      "title": item.title,
      "track": Int64(clamping: item.trackNumber),
      "disc": Int64(clamping: item.album.discNumber),
      "genre": item.genre,
      "file_extension": url?.pathExtension.lowercased() ?? "",
      "is_music": true,
      "is_protected": item.isDRMProtected,
    ].compactMapValues { $0 }
    row["_uri"] = url?.absoluteString
    if let title = item.album.title, !title.isEmpty {
      row["album_id"] = item.album.persistentID.int64Value
    }
    return row
  }

  private func albumRows(_ items: [ITLibMediaItem]) -> [Row] {
    var albums: [Int64: Row] = [:]
    var counts: [Int64: Int] = [:]
    for item in items {
      let album = item.album
      guard let title = album.title, !title.isEmpty else { continue }
      let id = album.persistentID.int64Value
      counts[id, default: 0] += 1
      if albums[id] == nil {
        var row: Row = ["_id": id, "album_id": id, "album": title]
        row["artist"] = album.albumArtist ?? item.artist?.name
        row["artist_id"] = item.artist?.persistentID.int64Value
        albums[id] = row
      }
    }
    return albums.map { id, album in
      var row = album
      row["numsongs"] = counts[id]
      return row
    }
  }

  private func sorted(_ rows: [Row], args: Row, keys: [String]) -> [Row] {
    let index = args["sortType"] as? Int ?? 0
    let key = keys.indices.contains(index) ? keys[index] : keys[0]
    let descending = args["orderType"] as? Int == 1
    let options: String.CompareOptions = (args["ignoreCase"] as? Bool ?? true)
      ? .caseInsensitive : []
    return rows.sorted { lhs, rhs in
      let order: ComparisonResult
      switch (lhs[key], rhs[key]) {
      case (let a as String, let b as String): order = a.compare(b, options: options)
      case (let a as NSNumber, let b as NSNumber): order = a.compare(b)
      case (nil, .some): return false
      case (.some, nil): return true
      default: order = .orderedSame
      }
      if order == .orderedSame {
        return (lhs["_id"] as? Int64 ?? 0) < (rhs["_id"] as? Int64 ?? 0)
      }
      return order == (descending ? .orderedDescending : .orderedAscending)
    }
  }

  private func openPlayback(_ id: Int64?) throws -> [String: String] {
    guard let id, let item = songs?[id], !item.isDRMProtected, let url = item.location else {
      throw LibraryError.unavailableTrack
    }
    let scoped = url.startAccessingSecurityScopedResource()
    guard FileManager.default.isReadableFile(atPath: url.path) else {
      if scoped { url.stopAccessingSecurityScopedResource() }
      throw LibraryError.unavailableTrack
    }
    let session = UUID().uuidString
    if scoped { playback[session] = url }
    return ["uri": url.absoluteString, "session": session]
  }
}
