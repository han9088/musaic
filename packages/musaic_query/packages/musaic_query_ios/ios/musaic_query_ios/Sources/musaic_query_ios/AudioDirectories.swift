import AVFoundation
import CryptoKit
import Flutter
import ImageIO
import UIKit

@available(iOS 13.0, *)
final class AudioDirectories: NSObject, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
  private let channel: FlutterMethodChannel
  private weak var registrar: FlutterPluginRegistrar?
  private let worker = DispatchQueue(label: "com.deskbtm.muasic.query.directories", qos: .utility)
  private weak var activePicker: UIDocumentPickerViewController?
  private var pickerResult: FlutterResult?
  private var replies: [UUID: FlutterResult] = [:]
  private final class EnumerationError { var value: Error? }
  private struct Listing {
    let failure: EnumerationError
    let iterator: FileManager.DirectoryEnumerator
    let root: URL
    let directory: URL
    let accessed: Bool
  }
  private var listings: [String: Listing] = [:]
  private var playbackScopes: [String: URL] = [:]
  private let keys: Set<URLResourceKey> = [
    .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey,
  ]
  private var cacheGeneration = 0
  private var cache: URL {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent(
      "musaic_query_artwork", isDirectory: true)
  }
  init(registrar: FlutterPluginRegistrar) {
    channel = FlutterMethodChannel(
      name: "com.deskbtm.muasic.query/directories", binaryMessenger: registrar.messenger())
    self.registrar = registrar
    super.init()
    channel.setMethodCallHandler { [weak self] call, callback in
      guard let self = self else {
        callback(FlutterError(code: "detached", message: "Plugin detached", details: nil))
        return
      }
      let id = UUID()
      self.replies[id] = callback
      let result: FlutterResult = { [weak self] value in
        self?.replies.removeValue(forKey: id)?(value)
      }
      if call.method == "supported" {
        result(true)
        return
      }
      if call.method == "pick" {
        self.pick(result)
        return
      }
      self.worker.async {
        do {
          let value = try self.handle(call)
          DispatchQueue.main.async { result(value) }
        } catch { DispatchQueue.main.async { result(self.flutterError(error)) } }
      }
    }
  }
  func dispose() {
    channel.setMethodCallHandler(nil)
    pickerResult?(FlutterError(code: "cancelled", message: "Plugin detached", details: nil))
    pickerResult = nil
    activePicker?.dismiss(animated: false)
    activePicker = nil
    let pending = Array(replies.values)
    replies.removeAll()
    for reply in pending {
      reply(FlutterError(code: "detached", message: "Plugin detached", details: nil))
    }
    worker.async {
      for listing in self.listings.values where listing.accessed {
        listing.root.stopAccessingSecurityScopedResource()
      }
      self.listings.removeAll()
      for root in self.playbackScopes.values { root.stopAccessingSecurityScopedResource() }
      self.playbackScopes.removeAll()
    }
  }
  private func failure(_ message: String, code: String = "directoryError") -> NSError {
    NSError(
      domain: "musaic_query", code: 1,
      userInfo: [NSLocalizedDescriptionKey: message, "musaicCode": code])
  }
  private func flutterError(_ error: Error) -> FlutterError {
    let native = error as NSError
    let code =
      native.userInfo["musaicCode"] as? String
      ?? (native.domain == NSCocoaErrorDomain && native.code == NSFileReadNoPermissionError
        ? "permissionDenied"
        : native.domain == NSCocoaErrorDomain
          && (native.code == NSFileNoSuchFileError || native.code == NSFileReadNoSuchFileError)
          ? "notFound" : "directoryError")
    return FlutterError(code: code, message: native.localizedDescription, details: nil)
  }
  private func pick(_ result: @escaping FlutterResult) {
    guard pickerResult == nil else {
      result(FlutterError(code: "busy", message: "Directory picker already open", details: nil))
      return
    }
    guard var host = registrar?.viewController else {
      result(FlutterError(code: "unavailable", message: "No foreground view", details: nil))
      return
    }
    while let presented = host.presentedViewController { host = presented }
    guard host.viewIfLoaded?.window != nil, !host.isBeingDismissed else {
      result(FlutterError(code: "unavailable", message: "No foreground view", details: nil))
      return
    }
    let picker = UIDocumentPickerViewController(documentTypes: ["public.folder"], in: .open)
    picker.delegate = self
    picker.allowsMultipleSelection = false
    activePicker = picker
    pickerResult = result
    host.present(picker, animated: true)
    picker.presentationController?.delegate = self
  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    takePickerResult(controller)?(nil)
  }
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    takePickerResult(presentationController.presentedViewController)?(nil)
  }
  private func takePickerResult(_ controller: UIViewController) -> FlutterResult? {
    guard controller === activePicker else { return nil }
    let result = pickerResult
    pickerResult = nil
    activePicker = nil
    return result
  }
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
  {
    guard let result = takePickerResult(controller) else { return }
    guard let url = urls.first else {
      result(nil)
      return
    }
    worker.async {
      let accessed = url.startAccessingSecurityScopedResource()
      defer { if accessed { url.stopAccessingSecurityScopedResource() } }
      do {
        guard accessed else { throw self.failure("Directory authorization unavailable") }
        let token = try url.bookmarkData(
          options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil
        ).base64EncodedString()
        let value: [String: Any] = [
          "id": url.standardizedFileURL.absoluteString, "name": url.lastPathComponent,
          "token": token,
        ]
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "permissionDenied", message: error.localizedDescription, details: nil))
        }
      }
    }
  }
  private func root(_ source: [String: Any]) throws -> URL {
    guard let token = source["token"] as? String else { throw failure("Missing grant") }
    if token.hasPrefix("file:") {
      guard let url = URL(string: token), url.isFileURL else { throw failure("Invalid path") }
      return url
    }
    guard let data = Data(base64Encoded: token) else { throw failure("Invalid bookmark") }
    var stale = false
    let url = try URL(
      resolvingBookmarkData: data, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &stale
    )
    // A stale bookmark must be renewed through restore before scanning.
    return url
  }
  private func child(_ id: String, root: URL) throws -> URL {
    guard let url = URL(string: id), url.isFileURL else { throw failure("Invalid file identity") }
    let base = root.resolvingSymlinksInPath().standardizedFileURL.path
    let path = url.resolvingSymlinksInPath().standardizedFileURL.path
    guard path == base || path.hasPrefix((base == "/" ? "" : base) + "/") else {
      throw failure("Resource outside authorized directory")
    }
    return url
  }
  private func access(_ source: [String: Any]) throws -> (root: URL, scoped: Bool) {
    let url = try root(source)
    let accessed = url.startAccessingSecurityScopedResource()
    if !(source["token"] as? String ?? "").hasPrefix("file:") && !accessed {
      throw failure("Directory authorization expired", code: "permissionDenied")
    }
    return (url, accessed)
  }
  private func scoped<T>(_ source: [String: Any], _ body: (URL) throws -> T) throws -> T {
    let (url, accessed) = try access(source)
    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
    return try body(url)
  }
  private func handle(_ call: FlutterMethodCall) throws -> Any? {
    let args = call.arguments as? [String: Any] ?? [:]
    let source = args["source"] as? [String: Any] ?? [:]
    switch call.method {
    case "mediaPaths": return [String: String]()
    case "openPath":
      guard let path = args["path"] as? String else { throw failure("Missing path") }
      let url = URL(fileURLWithPath: path).standardizedFileURL
      guard try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
        throw failure("Not a directory")
      }
      return ["id": url.absoluteString, "token": url.absoluteString, "name": url.lastPathComponent]
    case "restore":
      return try scoped(source) { url -> [String: Any] in
        guard try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
          throw failure("Directory unavailable")
        }
        let plain = (source["token"] as? String ?? "").hasPrefix("file:")
        let token =
          plain
          ? url.absoluteString
          : try url.bookmarkData(
            options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil
          ).base64EncodedString()
        return [
          "id": url.standardizedFileURL.absoluteString, "token": token,
          "name": url.lastPathComponent,
        ]
      }
    case "release": return nil  // Bookmarks are owned by the caller; remove the persisted token.
    case "open":
      guard listings.count < 16, let id = args["directory"] as? String else {
        throw failure("Invalid enumerator request")
      }
      let url = try root(source)
      let accessed = url.startAccessingSecurityScopedResource()
      do {
        if !(source["token"] as? String ?? "").hasPrefix("file:") && !accessed {
          throw failure("Directory authorization expired", code: "permissionDenied")
        }
        let directory = try child(id, root: url)
        guard FileManager.default.isReadableFile(atPath: directory.path) else {
          throw failure(
            "Directory unavailable",
            code: FileManager.default.fileExists(atPath: directory.path)
              ? "permissionDenied" : "notFound")
        }
        let enumerationError = EnumerationError()
        guard
          let iterator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: Array(keys),
            options: [.skipsSubdirectoryDescendants],
            errorHandler: { _, error in
              enumerationError.value = error
              return false
            })
        else { throw failure("Cannot enumerate directory") }
        let session = UUID().uuidString
        listings[session] = Listing(
          failure: enumerationError, iterator: iterator, root: url, directory: directory,
          accessed: accessed)
        return session
      } catch {
        if accessed { url.stopAccessingSecurityScopedResource() }
        throw error
      }
    case "next":
      guard let id = args["session"] as? String, let listing = listings[id] else {
        throw failure("Enumerator closed")
      }
      var rows: [[String: Any]] = []
      var done = false
      var errors: [String] = []
      for _ in 0..<128 {
        guard let url = listing.iterator.nextObject() as? URL else {
          done = true
          break
        }
        do {
          let values = try url.resourceValues(forKeys: keys)
          if values.isSymbolicLink == true { continue }
          var row: [String: Any] = [
            "id": url.standardizedFileURL.absoluteString, "uri": url.absoluteString,
            "reliable": url.path.hasPrefix(NSHomeDirectory() + "/"),
            "parent": listing.directory.standardizedFileURL.absoluteString,
            "name": url.lastPathComponent, "directory": values.isDirectory == true,
          ]
          if let size = values.fileSize, values.isDirectory != true { row["size"] = size }
          if let modified = values.contentModificationDate {
            row["modified"] = Int64(modified.timeIntervalSince1970 * 1000)
          }
          rows.append(row)
        } catch { errors.append(error.localizedDescription) }
      }
      if let error = listing.failure.value { throw error }
      return ["entries": rows, "done": done, "errors": errors]
    case "close":
      if let id = args["session"] as? String, let listing = listings.removeValue(forKey: id),
        listing.accessed
      {
        listing.root.stopAccessingSecurityScopedResource()
      }
      return nil
    case "openPlayback":
      guard let file = args["file"] as? [String: Any], let id = file["id"] as? String else {
        throw failure("Missing file")
      }
      let (root, accessed) = try access(source)
      do {
        let url = try child(id, root: root)
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
          FileManager.default.isReadableFile(atPath: url.path)
        else { throw failure("Audio file unavailable", code: "notFound") }
        var result = ["uri": url.absoluteString]
        // AVPlayer can read lazily, including after seeking or resuming.
        if accessed {
          let session = UUID().uuidString
          playbackScopes[session] = root
          result["session"] = session
        }
        return result
      } catch {
        if accessed { root.stopAccessingSecurityScopedResource() }
        throw error
      }
    case "closePlayback":
      if let session = args["session"] as? String {
        playbackScopes.removeValue(forKey: session)?.stopAccessingSecurityScopedResource()
      }
      return nil
    case "metadata", "artwork":
      guard let file = args["file"] as? [String: Any], let id = file["id"] as? String else {
        throw failure("Missing file")
      }
      return try scoped(source) { root in
        let url = try child(id, root: root)
        guard FileManager.default.isReadableFile(atPath: url.path) else {
          throw failure("File unavailable", code: "notFound")
        }
        if call.method == "metadata" { return try metadata(url) }
        return try artwork(
          url, root: root, file: file, cover: args["cover"] as? [String: Any],
          size: args["size"] as? Int ?? 512)
      }
    case "clearCache":
      cacheGeneration += 1
      if FileManager.default.fileExists(atPath: cache.path) {
        try FileManager.default.removeItem(at: cache)
      }
      return nil
    default: throw failure("Unsupported directory operation")
    }
  }
  private func fingerprint(_ url: URL) throws -> [Int64?] {
    var fresh = url
    fresh.removeAllCachedResourceValues()
    let values = try fresh.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
    return [
      values.fileSize.map { Int64($0) },
      values.contentModificationDate.map { Int64($0.timeIntervalSince1970 * 1000) },
    ]
  }
  private func metadata(_ url: URL) throws -> [String: Any] {
    let before = try fingerprint(url)
    let asset = AVURLAsset(url: url)
    guard asset.isReadable else {
      throw failure("Unsupported or damaged audio", code: "metadataFailed")
    }
    var output: [String: Any] = [:]
    let mapping: [String: String] = [
      "title": "title", "artist": "artist", "albumName": "album",
    ]
    for item in asset.commonMetadata {
      if let key = item.commonKey?.rawValue, let name = mapping[key], let value = item.stringValue {
        output[name] = value
      }
    }
    for format in asset.availableMetadataFormats {
      for item in asset.metadata(forFormat: format) {
        let name: String?
        switch item.identifier {
        case .id3MetadataBand, .iTunesMetadataAlbumArtist: name = "albumArtist"
        case .id3MetadataTrackNumber, .iTunesMetadataTrackNumber: name = "track"
        case .id3MetadataPartOfASet, .iTunesMetadataDiscNumber: name = "disc"
        case .id3MetadataContentType, .iTunesMetadataUserGenre: name = "genre"
        default: name = nil
        }
        if let name = name {
          if item.identifier == .iTunesMetadataTrackNumber
            || item.identifier == .iTunesMetadataDiscNumber,
            let data = item.dataValue, data.count == 6 || data.count == 8
          {
            let number = Int(data[2]) << 8 | Int(data[3])
            if number > 0 { output[name] = String(number) }
          } else if let value = item.stringValue {
            output[name] = value
          }
        }
      }
    }
    let seconds = CMTimeGetSeconds(asset.duration)
    if seconds.isFinite && seconds >= 0 { output["durationMs"] = Int64(seconds * 1000) }
    guard try before == fingerprint(url) else {
      throw failure("File changed while reading metadata", code: "fileChanged")
    }
    return output
  }
  private func artwork(_ url: URL, root: URL, file: [String: Any], cover: [String: Any]?, size: Int)
    throws -> String?
  {
    guard (1...4096).contains(size) else { throw failure("Invalid artwork size") }
    let fm = FileManager.default
    try fm.createDirectory(at: cache, withIntermediateDirectories: true)
    let stamp = try fingerprint(url)
    var currentFile = file
    currentFile["size"] = stamp[0]
    currentFile["modified"] = stamp[1]
    let coverURL = try (cover?["id"] as? String).map { try child($0, root: root) }
    let coverStamp = coverURL.flatMap { try? fingerprint($0) }
    var currentCover = coverStamp == nil ? nil : cover
    currentCover?["size"] = coverStamp?[0]
    currentCover?["modified"] = coverStamp?[1]
    let key: [String: Any] = [
      "file": currentFile, "cover": currentCover ?? [:], "size": size,
      "generation": cacheGeneration,
    ]
    let digest = SHA256.hash(
      data: try JSONSerialization.data(withJSONObject: key, options: .sortedKeys)
    ).map { String(format: "%02x", $0) }.joined()
    let reliable =
      file["reliable"] as? Bool == true && stamp.allSatisfy({ $0 != nil })
      && (currentCover == nil
        || currentCover?["reliable"] as? Bool == true
          && coverStamp?.allSatisfy({ $0 != nil }) == true)
    let filename = reliable ? digest : digest + "-" + UUID().uuidString
    let target = cache.appendingPathComponent(filename + ".jpg")
    if reliable && fm.fileExists(atPath: target.path) {
      try fm.setAttributes([.modificationDate: Date()], ofItemAtPath: target.path)
      return target.absoluteString
    }
    var imageSource: CGImageSource?
    for item in AVURLAsset(url: url).commonMetadata where item.commonKey == .commonKeyArtwork {
      if let data = item.dataValue, data.count <= 32 * 1024 * 1024 {
        imageSource = CGImageSourceCreateWithData(data as CFData, nil)
        break
      }
    }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: size,
      kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceShouldCacheImmediately: true,
    ]
    var thumbnail = imageSource.flatMap {
      CGImageSourceCreateThumbnailAtIndex($0, 0, options as CFDictionary)
    }
    if thumbnail == nil, currentCover != nil, let coverURL = coverURL,
      let bytes = coverStamp?[0], bytes <= 32 * 1024 * 1024
    {
      imageSource = CGImageSourceCreateWithURL(coverURL as CFURL, nil)
      thumbnail = imageSource.flatMap {
        CGImageSourceCreateThumbnailAtIndex($0, 0, options as CFDictionary)
      }
    }
    guard let image = thumbnail else { return nil }
    guard let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.85) else {
      throw failure("Cannot encode artwork")
    }
    guard try stamp == fingerprint(url) else {
      throw failure("Audio changed while reading artwork", code: "fileChanged")
    }
    if currentCover != nil, let coverURL = coverURL {
      guard try coverStamp == fingerprint(coverURL) else {
        throw failure("Cover changed while reading artwork", code: "fileChanged")
      }
    }
    try data.write(to: target, options: .atomic)
    let files = try fm.contentsOfDirectory(
      at: cache, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
    let sorted = try files.map {
      ($0, try $0.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]))
    }.sorted {
      if ($0.0 == target) != ($1.0 == target) { return $0.0 == target }
      return ($0.1.contentModificationDate ?? .distantPast)
        > ($1.1.contentModificationDate ?? .distantPast)
    }
    var total = 0
    for (index, item) in sorted.enumerated() {
      let (file, values) = item
      total += values.fileSize ?? 0
      if index >= 512 || total > 64 * 1024 * 1024 { try fm.removeItem(at: file) }
    }
    return target.absoluteString
  }
}
