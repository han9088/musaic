import Foundation
import MusicKit

/// Shared error codes and mapping helpers. Values must stay in sync with
/// `MusicKitErrorCode` in the Dart platform interface.
enum ErrorCodes {
  static let notInitialized = "notInitialized"
  static let alreadyDisposed = "alreadyDisposed"
  static let authorizationDenied = "authorizationDenied"
  static let authorizationCancelled = "authorizationCancelled"
  static let authenticationFailed = "authenticationFailed"
  static let developerTokenMissing = "developerTokenMissing"
  static let developerTokenExpired = "developerTokenExpired"
  static let userTokenInvalid = "userTokenInvalid"
  static let subscriptionRequired = "subscriptionRequired"
  static let storefrontUnavailable = "storefrontUnavailable"
  static let resourceNotFound = "resourceNotFound"
  static let resourceUnavailable = "resourceUnavailable"
  static let playbackFailed = "playbackFailed"
  static let networkError = "networkError"
  static let requestTimeout = "requestTimeout"
  static let rateLimited = "rateLimited"
  static let unsupportedFeature = "unsupportedFeature"
  static let sdkUnavailable = "sdkUnavailable"
  static let platformUnavailable = "platformUnavailable"
  static let unknown = "unknown"
}

/// Maps MusicKit / URL errors to the plugin's stable error codes.
enum ErrorMapper {
  static func code(for error: Error) -> String {
    // MusicDataRequest can throw before returning an HTTP response.
    if let apiError = error as? MusicDataRequest.Error {
      return httpCode(for: apiError.status)
    }
    if let urlError = error as? URLError {
      switch urlError.code {
      case .timedOut: return ErrorCodes.requestTimeout
      default: return ErrorCodes.networkError
      }
    }
    if let nsError = error as? NSError,
       nsError.domain == "deskbtm.apple_music_kit",
       (400...599).contains(nsError.code) {
      return httpCode(for: nsError.code)
    }
    return ErrorCodes.unknown
  }

  static func httpCode(for status: Int) -> String {
    switch status {
    case 401: return ErrorCodes.authenticationFailed
    case 403: return ErrorCodes.authorizationDenied
    case 404: return ErrorCodes.resourceNotFound
    case 409, 410: return ErrorCodes.resourceUnavailable
    case 429: return ErrorCodes.rateLimited
    case 408: return ErrorCodes.requestTimeout
    case 500...599: return ErrorCodes.networkError
    default: return ErrorCodes.unknown
    }
  }
}

/// Serializes MusicKit catalog/library types into the plain dictionaries the
/// Dart layer expects (Apple Music API JSON shapes).
enum Serializer {
  static func songDict(_ song: Song) -> [String: Any] {
    var attributes: [String: Any] = [:]
    attributes["name"] = song.title
    attributes["artistName"] = song.artistName
    attributes["albumName"] = song.albumTitle
    attributes["durationInMillis"] = song.duration.map { Int($0 * 1000) }
    attributes["trackNumber"] = song.trackNumber
    attributes["discNumber"] = song.discNumber
    attributes["contentRating"] = song.contentRating == .explicit ? "explicit" : "clean"
    attributes["genreNames"] = song.genreNames
    attributes["releaseDate"] = song.releaseDate.map(isoDay)
    attributes["isrc"] = song.isrc
    attributes["composerName"] = song.composerName
    if let artwork = song.artwork {
      attributes["artwork"] = artworkDict(artwork)
    }
    if song.playParameters != nil {
      attributes["playParams"] = ["id": song.id.rawValue]
    }
    if let previews = song.previewAssets, !previews.isEmpty {
      attributes["previews"] = previews.compactMap { $0.url?.absoluteString }.map { ["url": $0] }
    }
    return [
      "id": song.id.rawValue,
      "type": "songs",
      "attributes": attributes,
    ]
  }

  static func albumDict(_ album: Album, includeTracks: Bool = false) -> [String: Any] {
    var attributes: [String: Any] = [:]
    attributes["name"] = album.title
    attributes["artistName"] = album.artistName
    attributes["trackCount"] = album.trackCount
    attributes["releaseDate"] = album.releaseDate.map(isoDay)
    attributes["genreNames"] = album.genreNames
    if let artwork = album.artwork {
      attributes["artwork"] = artworkDict(artwork)
    }
    var dict: [String: Any] = ["id": album.id.rawValue, "type": "albums", "attributes": attributes]
    if includeTracks {
      // Mirror the Apple Music API `relationships.tracks` shape so the
      // Dart layer's MusicAlbum.fromApiJson picks the tracks up.
      // Album.tracks is a MusicItemCollection<Track>; Track is a
      // playable supertype — convert each to a Song via its catalog id.
      let trackDicts: [[String: Any]] = (album.tracks ?? []).compactMap { track in
        guard case .song(let song) = track else { return nil }
        return songDict(song)
      }
      dict["tracks"] = ["data": trackDicts, "href": "v1/catalog/albums/\(album.id.rawValue)/tracks"]
    }
    return dict
  }

  static func artistDict(_ artist: Artist) -> [String: Any] {
    var attributes: [String: Any] = [:]
    attributes["name"] = artist.name
    attributes["genreNames"] = artist.genreNames
    if let artwork = artist.artwork {
      attributes["artwork"] = artworkDict(artwork)
    }
    return ["id": artist.id.rawValue, "type": "artists", "attributes": attributes]
  }

  static func playlistDict(_ playlist: Playlist, includeTracks: Bool = false) -> [String: Any] {
    var attributes: [String: Any] = [:]
    attributes["name"] = playlist.name
    attributes["curatorName"] = playlist.curatorName
    if let description = playlist.standardDescription {
      attributes["description"] = ["standard": description]
    }
    if let artwork = playlist.artwork {
      attributes["artwork"] = artworkDict(artwork)
    }
    var dict: [String: Any] = ["id": playlist.id.rawValue, "type": "playlists", "attributes": attributes]
    if includeTracks {
      // Playlist.tracks is a MusicItemCollection<Track>; keep only songs.
      let trackDicts: [[String: Any]] = (playlist.tracks ?? []).compactMap { track in
        guard case .song(let song) = track else { return nil }
        return songDict(song)
      }
      dict["tracks"] = ["data": trackDicts, "href": "v1/catalog/playlists/\(playlist.id.rawValue)/tracks"]
    }
    return dict
  }

  static func artworkDict(_ artwork: Artwork) -> [String: Any] {
    var dict: [String: Any] = [:]
    // Build a {w}x{h} template from the concrete URL builder so the Dart
    // layer can request arbitrary sizes. Replace only the LAST occurrence
    // of the dimensions so numbers appearing elsewhere in the URL survive.
    if let url = artwork.url(width: artwork.maximumWidth, height: artwork.maximumHeight) {
      let w = "\(artwork.maximumWidth)"
      let h = "\(artwork.maximumHeight)"
      let token = "\(w)x\(h)"
      let absolute = url.absoluteString
      if let range = absolute.range(of: token, options: .backwards) {
        dict["url"] = absolute.replacingCharacters(
          in: range,
          with: "{w}x{h}")
      } else {
        // Fallback: dimensions not found verbatim; keep the concrete URL.
        dict["url"] = absolute
      }
    }
    dict["width"] = artwork.maximumWidth
    dict["height"] = artwork.maximumHeight
    dict["bgColor"] = artwork.backgroundColor.map(cssHex)
    return dict
  }

  static func cssHex(_ color: CGColor) -> String? {
    guard let rgb = color.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil),
          rgb.numberOfComponents >= 3 else { return nil }
    let r = Int((rgb.components?[0] ?? 0) * 255)
    let g = Int((rgb.components?[1] ?? 0) * 255)
    let b = Int((rgb.components?[2] ?? 0) * 255)
    return String(format: "#%02X%02X%02X", r, g, b)
  }

  static func isoDay(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.string(from: date)
  }
}

/// Page building for API-shaped payloads.
enum PageBuilder {
  /// Builds a page document. When [offset] and [limit] are given and the
  /// page is full, reports a `next` link so the Dart layer can continue
  /// with offset-based paging.
  static func page(items: [[String: Any]], offset: Int = 0, limit: Int? = nil) -> [String: Any] {
    var dict: [String: Any] = ["data": items]
    if let limit = limit, items.count >= limit {
      let nextOffset = offset + items.count
      dict["next"] = "v1/me/library?offset=\(nextOffset)&limit=\(limit)"
    }
    return dict
  }
}

/// Runs an Apple Music API request through MusicDataRequest so the SDK
/// manages the developer + user tokens.
enum ApiRequest {
  static func get(_ path: String) async throws -> [String: Any] {
    guard let url = URL(string: "https://api.music.apple.com/\(path)") else {
      throw NSError(domain: "deskbtm.apple_music_kit", code: 0)
    }
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "GET"
    let response = try await MusicDataRequest(urlRequest: urlRequest).response()
    guard (200..<300).contains(response.urlResponse.statusCode) else {
      throw NSError(
        domain: "deskbtm.apple_music_kit", code: response.urlResponse.statusCode,
        userInfo: [NSLocalizedDescriptionKey: "Apple Music API error."])
    }
    let json = try JSONSerialization.jsonObject(with: response.data)
    return (json as? [String: Any]) ?? [:]
  }

  static func post(_ path: String, body: [String: Any]) async throws -> [String: Any] {
    guard let url = URL(string: "https://api.music.apple.com/\(path)") else {
      throw NSError(domain: "deskbtm.apple_music_kit", code: 0)
    }
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
    let response = try await MusicDataRequest(urlRequest: urlRequest).response()
    guard (200..<300).contains(response.urlResponse.statusCode) else {
      throw NSError(
        domain: "deskbtm.apple_music_kit", code: response.urlResponse.statusCode,
        userInfo: [NSLocalizedDescriptionKey: "Apple Music API error."])
    }
    if response.data.isEmpty {
      return [:]
    }
    let json = try JSONSerialization.jsonObject(with: response.data)
    return (json as? [String: Any]) ?? [:]
  }
}
