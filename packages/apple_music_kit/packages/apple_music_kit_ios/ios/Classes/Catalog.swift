import Flutter
import Foundation
import MusicKit

/// Catalog (Apple Music API) bridge using structured MusicKit requests.
final class CatalogBridge {
  private var tasks: Set<Task<Void, Never>> = []

  /// MusicDataRequest.currentCountryCode is a throwing async property.
  private func storefrontCode(_ explicit: String?) async throws -> String {
    if let explicit = explicit, !explicit.isEmpty { return explicit }
    return try await MusicDataRequest.currentCountryCode
  }

  // MARK: Search

  func search(
    _ args: [String: Any],
    fail: @escaping (String, String, [String: Any]?) -> Void,
    reply: @escaping (Any?) -> Void
  ) {
    guard let term = args["term"] as? String, !term.isEmpty else {
      fail(ErrorCodes.unknown, "Missing search term.", nil)
      return
    }
    let types = (args["types"] as? [String]) ?? ["songs"]
    let limit = args["limit"] as? Int ?? 25
    runTask(fail: fail) {
      var searchable: [any MusicCatalogSearchable.Type] = []
      if types.contains("songs") { searchable.append(Song.self) }
      if types.contains("albums") { searchable.append(Album.self) }
      if types.contains("artists") { searchable.append(Artist.self) }
      if types.contains("playlists") { searchable.append(Playlist.self) }
      guard !searchable.isEmpty else {
        throw NSError(
          domain: "deskbtm.apple_music_kit", code: 0,
          userInfo: [NSLocalizedDescriptionKey: "No searchable types requested."])
      }
      var request = MusicCatalogSearchRequest(term: term, types: searchable)
      request.limit = limit
      let response = try await request.response()
      var result: [String: Any] = [:]
      if types.contains("songs") {
        result["songs"] = PageBuilder.page(items: response.songs.map { Serializer.songDict($0) })
      }
      if types.contains("albums") {
        result["albums"] = PageBuilder.page(items: response.albums.map { Serializer.albumDict($0) })
      }
      if types.contains("artists") {
        result["artists"] = PageBuilder.page(items: response.artists.map { Serializer.artistDict($0) })
      }
      if types.contains("playlists") {
        result["playlists"] = PageBuilder.page(items: response.playlists.map { Serializer.playlistDict($0) })
      }
      reply(result)
    }
  }

  func getAlbumAnimatedArtwork(
    _ args: [String: Any],
    fail: @escaping (String, String, [String: Any]?) -> Void,
    reply: @escaping (Any?) -> Void
  ) {
    guard let id = args["id"] as? String,
          id.range(of: "^[0-9]+$", options: .regularExpression) != nil,
          let country = args["storefront"] as? String,
          country.range(of: "^[a-zA-Z]{2}$", options: .regularExpression) != nil else {
      fail(ErrorCodes.unknown, "Expected a catalog album ID and storefront.", nil)
      return
    }
    runTask(fail: fail) {
      let response = try await ApiRequest.get(
        "v1/catalog/\(country.lowercased())/albums/\(id)?extend=editorialVideo")
      reply(response)
    }
  }

  // MARK: Resource fetches

  func getSong(
    _ args: [String: Any],
    fail: @escaping (String, String, [String: Any]?) -> Void,
    reply: @escaping (Any?) -> Void
  ) {
    guard let id = args["id"] as? String else {
      fail(ErrorCodes.unknown, "Missing song id.", nil)
      return
    }
    runTask(fail: fail) {
      let song = try await self.fetchSong(id)
      reply(Serializer.songDict(song))
    }
  }

  private func fetchSong(_ id: String) async throws -> Song {
    let request = MusicCatalogResourceRequest<Song>(
      matching: \Song.FilterType.id, memberOf: [MusicItemID(id)])
    let response = try await request.response()
    guard let song = response.items.first else {
      throw NSError(
        domain: "deskbtm.apple_music_kit", code: 404,
        userInfo: [NSLocalizedDescriptionKey: "Song \(id) not found."])
    }
    return song
  }

  func getAlbum(
    _ args: [String: Any],
    fail: @escaping (String, String, [String: Any]?) -> Void,
    reply: @escaping (Any?) -> Void
  ) {
    guard let id = args["id"] as? String else {
      fail(ErrorCodes.unknown, "Missing album id.", nil)
      return
    }
    let includeTracks = args["includeTracks"] as? Bool ?? false
    runTask(fail: fail) {
      var request = MusicCatalogResourceRequest<Album>(
        matching: \Album.FilterType.id, memberOf: [MusicItemID(id)])
      if includeTracks {
        request.properties = [.tracks]
      }
      let response = try await request.response()
      guard let album = response.items.first else {
        throw NSError(
          domain: "deskbtm.apple_music_kit", code: 404,
          userInfo: [NSLocalizedDescriptionKey: "Album \(id) not found."])
      }
      reply(Serializer.albumDict(album, includeTracks: includeTracks))
    }
  }

  func getArtist(
    _ args: [String: Any],
    fail: @escaping (String, String, [String: Any]?) -> Void,
    reply: @escaping (Any?) -> Void
  ) {
    guard let id = args["id"] as? String else {
      fail(ErrorCodes.unknown, "Missing artist id.", nil)
      return
    }
    runTask(fail: fail) {
      let request = MusicCatalogResourceRequest<Artist>(
        matching: \Artist.FilterType.id, memberOf: [MusicItemID(id)])
      let response = try await request.response()
      guard let artist = response.items.first else {
        throw NSError(
          domain: "deskbtm.apple_music_kit", code: 404,
          userInfo: [NSLocalizedDescriptionKey: "Artist \(id) not found."])
      }
      reply(Serializer.artistDict(artist))
    }
  }

  func getPlaylist(
    _ args: [String: Any],
    fail: @escaping (String, String, [String: Any]?) -> Void,
    reply: @escaping (Any?) -> Void
  ) {
    guard let id = args["id"] as? String else {
      fail(ErrorCodes.unknown, "Missing playlist id.", nil)
      return
    }
    let includeTracks = args["includeTracks"] as? Bool ?? false
    runTask(fail: fail) {
      var request = MusicCatalogResourceRequest<Playlist>(
        matching: \Playlist.FilterType.id, memberOf: [MusicItemID(id)])
      if includeTracks {
        request.properties = [.tracks]
      }
      let response = try await request.response()
      guard let playlist = response.items.first else {
        throw NSError(
          domain: "deskbtm.apple_music_kit", code: 404,
          userInfo: [NSLocalizedDescriptionKey: "Playlist \(id) not found."])
      }
      reply(Serializer.playlistDict(playlist, includeTracks: includeTracks))
    }
  }

  // MARK: Charts

  func getCharts(
    _ args: [String: Any],
    fail: @escaping (String, String, [String: Any]?) -> Void,
    reply: @escaping (Any?) -> Void
  ) {
    // Dart sends MusicChartKind.name: "songs" | "albums" | "musicVideos".
    let kindName = args["kind"] as? String ?? "songs"
    let limit = args["limit"] as? Int ?? 20
    runTask(fail: fail) {
      var types: [any MusicCatalogChartRequestable.Type] = []
      switch kindName {
      case "albums": types.append(Album.self)
      case "musicVideos": types.append(MusicVideo.self)
      default: types.append(Song.self)
      }
      var request = MusicCatalogChartsRequest(kinds: [.mostPlayed], types: types)
      request.limit = limit
      let response = try await request.response()
      var charts: [[String: Any]] = []
      switch kindName {
      case "albums":
        for chart in response.albumCharts {
          charts.append([
            "name": chart.title,
            "albums": PageBuilder.page(items: chart.items.map { Serializer.albumDict($0) }),
          ])
        }
      case "musicVideos":
        // Music videos are not modeled by the Dart layer yet; report the
        // chart names without items rather than fabricating data.
        for chart in response.musicVideoCharts {
          charts.append(["name": chart.title])
        }
      default:
        for chart in response.songCharts {
          charts.append([
            "name": chart.title,
            "songs": PageBuilder.page(items: chart.items.map { Serializer.songDict($0) }),
          ])
        }
      }
      reply(charts)
    }
  }

  // MARK: Storefront

  func currentStorefront(
    fail: @escaping (String, String, [String: Any]?) -> Void,
    reply: @escaping (Any?) -> Void
  ) {
    runTask(fail: fail) {
      let code = try await MusicDataRequest.currentCountryCode
      reply([
        "id": code.uppercased(),
        "type": "storefronts",
        "attributes": ["name": code.uppercased()],
      ])
    }
  }

  // MARK: Task plumbing

  private func runTask(
    fail: @escaping (String, String, [String: Any]?) -> Void,
    operation: @escaping @MainActor () async throws -> Void
  ) {
    var taskRef: Task<Void, Never>!
    let task = Task<Void, Never> { @MainActor in
      do {
        try await operation()
      } catch {
        fail(ErrorMapper.code(for: error), "Request failed: \(error.localizedDescription)", nil)
      }
      self.tasks.remove(taskRef)
    }
    taskRef = task
    tasks.insert(task)
  }
}
