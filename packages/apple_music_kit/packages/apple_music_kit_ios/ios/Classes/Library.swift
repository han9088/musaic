import Flutter
import Foundation
import MusicKit

/// User library bridge. Reads use MusicLibraryRequest; writes (add to
/// library, playlist CRUD) go through the Apple Music API via
/// MusicDataRequest, since the current SDK has no structured write
/// requests.
final class LibraryBridge {
  private var tasks: Set<Task<Void, Never>> = []

  private func requireAuthorized(
    _ fail: (String, String, [String: Any]?) -> Void
  ) -> Bool {
    guard MusicAuthorization.currentStatus == .authorized else {
      fail(ErrorCodes.authorizationDenied, "Apple Music authorization required.", nil)
      return false
    }
    return true
  }

  func getSongs(
    _ args: [String: Any],
    fail: @escaping (String, String, [String: Any]?) -> Void,
    reply: @escaping (Any?) -> Void
  ) {
    guard requireAuthorized(fail) else { return }
    let limit = args["limit"] as? Int ?? 25
    let offset = args["offset"] as? Int ?? 0
    runTask(fail: fail) {
      var request = MusicLibraryRequest<Song>()
      request.limit = limit
      request.offset = offset
      let response = try await request.response()
      let items = response.items.map { Serializer.songDict($0) }
      reply(PageBuilder.page(items: items, offset: offset, limit: limit))
    }
  }

  func getAlbums(
    _ args: [String: Any],
    fail: @escaping (String, String, [String: Any]?) -> Void,
    reply: @escaping (Any?) -> Void
  ) {
    guard requireAuthorized(fail) else { return }
    let limit = args["limit"] as? Int ?? 25
    let offset = args["offset"] as? Int ?? 0
    runTask(fail: fail) {
      var request = MusicLibraryRequest<Album>()
      request.limit = limit
      request.offset = offset
      let response = try await request.response()
      let items = response.items.map { Serializer.albumDict($0) }
      reply(PageBuilder.page(items: items, offset: offset, limit: limit))
    }
  }

  func getPlaylists(
    _ args: [String: Any],
    fail: @escaping (String, String, [String: Any]?) -> Void,
    reply: @escaping (Any?) -> Void
  ) {
    guard requireAuthorized(fail) else { return }
    let limit = args["limit"] as? Int ?? 25
    let offset = args["offset"] as? Int ?? 0
    runTask(fail: fail) {
      var request = MusicLibraryRequest<Playlist>()
      request.limit = limit
      request.offset = offset
      let response = try await request.response()
      let items = response.items.map { Serializer.playlistDict($0) }
      reply(PageBuilder.page(items: items, offset: offset, limit: limit))
    }
  }

  func search(
    _ args: [String: Any],
    fail: @escaping (String, String, [String: Any]?) -> Void,
    reply: @escaping (Any?) -> Void
  ) {
    guard requireAuthorized(fail) else { return }
    guard let term = args["term"] as? String, !term.isEmpty else {
      fail(ErrorCodes.unknown, "Missing search term.", nil)
      return
    }
    let types = (args["types"] as? [String]) ?? ["songs"]
    runTask(fail: fail) {
      var result: [String: Any] = [:]
      if types.contains("songs") {
        var request = MusicLibraryRequest<Song>()
        request.filter(text: term)
        let response = try await request.response()
        result["songs"] = PageBuilder.page(items: response.items.map { Serializer.songDict($0) })
      }
      if types.contains("albums") {
        var request = MusicLibraryRequest<Album>()
        request.filter(text: term)
        let response = try await request.response()
        result["albums"] = PageBuilder.page(items: response.items.map { Serializer.albumDict($0) })
      }
      if types.contains("playlists") {
        var request = MusicLibraryRequest<Playlist>()
        request.filter(text: term)
        let response = try await request.response()
        result["playlists"] = PageBuilder.page(items: response.items.map { Serializer.playlistDict($0) })
      }
      reply(result)
    }
  }

  func addToLibrary(
    _ args: [String: Any],
    fail: @escaping (String, String, [String: Any]?) -> Void,
    reply: @escaping (Any?) -> Void
  ) {
    guard requireAuthorized(fail) else { return }
    guard let songs = args["songs"] as? [[String: Any]], !songs.isEmpty else {
      fail(ErrorCodes.unknown, "Missing songs.", nil)
      return
    }
    runTask(fail: fail) {
      // POST /v1/me/library with a list of catalog ids.
      _ = try await ApiRequest.post("v1/me/library?ids[songs]=\(songs.compactMap { $0["id"] as? String }.joined(separator: ","))", body: [:])
      reply(nil)
    }
  }

  func createPlaylist(
    _ args: [String: Any],
    fail: @escaping (String, String, [String: Any]?) -> Void,
    reply: @escaping (Any?) -> Void
  ) {
    guard requireAuthorized(fail) else { return }
    guard let name = args["name"] as? String, !name.isEmpty else {
      fail(ErrorCodes.unknown, "Missing playlist name.", nil)
      return
    }
    let description = args["description"] as? String
    let tracks = args["tracks"] as? [[String: Any]]
    runTask(fail: fail) {
      var attributes: [String: Any] = ["name": name]
      if let description = description {
        attributes["description"] = description
      }
      var body: [String: Any] = ["attributes": attributes]
      if let tracks = tracks, !tracks.isEmpty {
        body["relationships"] = [
          "tracks": [
            "data": tracks.map { t in
              ["id": t["id"] as? String ?? "", "type": (t["source"] as? String == "library" ? "library-" : "") + (t["type"] as? String ?? "songs")]
            }
          ]
        ]
      }
      let json = try await ApiRequest.post("v1/me/library/playlists", body: body)
      // POST /v1/me/playlists returns a single resource object under "data".
      let created: [String: Any]
      if let single = json["data"] as? [String: Any] {
        created = single
      } else if let list = json["data"] as? [[String: Any]], let first = list.first {
        created = first
      } else {
        created = [:]
      }
      let createdAttrs = (created["attributes"] as? [String: Any]) ?? [:]
      let createdDesc = (createdAttrs["description"] as? [String: Any])?["standard"] as? String
      reply([
        "id": created["id"] ?? "",
        "name": createdAttrs["name"] ?? name,
        "description": createdDesc ?? NSNull(),
      ])
    }
  }

  func addToPlaylist(
    _ args: [String: Any],
    fail: @escaping (String, String, [String: Any]?) -> Void,
    reply: @escaping (Any?) -> Void
  ) {
    guard requireAuthorized(fail) else { return }
    guard let playlistId = args["playlistId"] as? String else {
      fail(ErrorCodes.unknown, "Missing playlist id.", nil)
      return
    }
    guard let tracks = args["tracks"] as? [[String: Any]], !tracks.isEmpty else {
      fail(ErrorCodes.unknown, "Missing tracks.", nil)
      return
    }
    runTask(fail: fail) {
      let body: [String: Any] = [
        "data": tracks.map { t in
          ["id": t["id"] as? String ?? "", "type": (t["source"] as? String == "library" ? "library-" : "") + (t["type"] as? String ?? "songs")]
        }
      ]
      _ = try await ApiRequest.post("v1/me/library/playlists/\(playlistId)/tracks", body: body)
      reply([
        "playlistId": playlistId,
        "added": tracks,
      ])
    }
  }

  private func runTask(
    fail: @escaping (String, String, [String: Any]?) -> Void,
    operation: @escaping @MainActor () async throws -> Void
  ) {
    var taskRef: Task<Void, Never>!
    let task = Task<Void, Never> { @MainActor in
      do {
        try await operation()
      } catch {
        fail(ErrorMapper.code(for: error), "Library request failed: \(error.localizedDescription)", nil)
      }
      self.tasks.remove(taskRef)
    }
    taskRef = task
    tasks.insert(task)
  }
}
