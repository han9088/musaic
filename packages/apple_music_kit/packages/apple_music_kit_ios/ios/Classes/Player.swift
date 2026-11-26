import Combine
import Flutter
import Foundation
import MusicKit

/// Player bridge over ApplicationMusicPlayer (third-party-app-scoped; does
/// not hijack the system Music app's queue).
final class PlayerBridge: NSObject, FlutterStreamHandler {
  let capabilitiesBridge = CapabilitiesBridge()

  private var sink: FlutterEventSink?
  private var cancellables: Set<AnyCancellable> = []
  private var positionTimer: Timer?
  private var lastEmittedState: [String: Any]?

  // Queue bookkeeping: refs as the Dart layer sees them, so the queue view
  // stays consistent even when native entries lack full metadata.
  private var queueRefs: [[String: Any]] = []
  private var pendingTasks: Set<Task<Void, Never>> = []

  /// Runs [body] on the main actor and removes the task from
  /// [pendingTasks] when it finishes, so the set never grows unboundedly.
  private func runTracked(_ body: @escaping @MainActor () async -> Void) {
    var taskRef: Task<Void, Never>!
    let task = Task<Void, Never> { @MainActor in
      await body()
      self.pendingTasks.remove(taskRef)
    }
    taskRef = task
    pendingTasks.insert(task)
  }

  // MARK: FlutterStreamHandler

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
    sink = eventSink
    lastEmittedState = nil
    startObserving()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopObserving()
    return nil
  }

  deinit {
    stopObserving()
  }

  // MARK: State observation

  private func startObserving() {
    stopObserving()
    let player = ApplicationMusicPlayer.shared

    // MusicKit State and Queue are Combine ObservableObjects; there is no
    // async stateChanges sequence in the current SDK.
    player.state.objectWillChange
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in self?.emitState() }
      .store(in: &cancellables)

    player.queue.objectWillChange
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in self?.emitState() }
      .store(in: &cancellables)

    // Initial snapshot for the new subscriber.
    emitState()

    // Position ticking while playing (UI sampling only).
    positionTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
      guard let self = self,
            ApplicationMusicPlayer.shared.state.playbackStatus == .playing else { return }
      self.emitState()
    }
  }

  private func stopObserving() {
    cancellables.removeAll()
    positionTimer?.invalidate()
    positionTimer = nil
  }

  private func emitState() {
    let snapshot = currentStateDict()
    if let last = lastEmittedState, NSDictionary(dictionary: last).isEqual(to: snapshot) { return }
    lastEmittedState = snapshot
    sink?(snapshot)
  }

  private func currentStateDict() -> [String: Any] {
    let player = ApplicationMusicPlayer.shared
    let state = player.state
    let entry = player.queue.currentEntry

    let statusName: String
    let isBuffering: Bool
    switch state.playbackStatus {
    case .playing: statusName = "playing"; isBuffering = false
    case .paused: statusName = "paused"; isBuffering = false
    case .stopped: statusName = "stopped"; isBuffering = false
    case .interrupted: statusName = "buffering"; isBuffering = true
    case .seekingForward, .seekingBackward: statusName = "buffering"; isBuffering = true
    @unknown default: statusName = "stopped"; isBuffering = false
    }

    var currentItem: [String: Any]? = nil
    if let entry = entry {
      if let index = queueEntries.firstIndex(where: { $0.id == entry.id }) {
        currentItem = queueRefs.indices.contains(index) ? queueRefs[index] : nil
      }
      if currentItem == nil {
        // Queue set outside our bookkeeping; derive from the entry.
        var type = "songs"
        if case .musicVideo = entry.item { type = "music-videos" }
        currentItem = [
          "id": entry.id,
          "type": type,
          "source": "catalog",
        ]
      }
    }

    let duration: Int? = {
      guard let entry = entry else { return nil }
      if case .song(let song) = entry.item {
        return song.duration.map { Int($0 * 1000) }
      }
      return nil
    }()

    let currentIndex: Int? = {
      guard let entry = entry,
            let index = queueEntries.firstIndex(where: { $0.id == entry.id }) else { return nil }
      return index
    }()

    return [
      "status": statusName,
      "currentItem": currentItem ?? NSNull(),
      "currentIndex": currentIndex ?? NSNull(),
      "positionMillis": Int(player.playbackTime * 1000),
      "durationMillis": duration ?? NSNull(),
      "queueLength": max(player.queue.entries.count, queueRefs.count),
      "shuffleMode": (state.shuffleMode ?? .off) == .off ? "off" : "on",
      "repeatMode": repeatName(state.repeatMode ?? .none),
      "isPlaying": state.playbackStatus == .playing,
      "isBuffering": isBuffering,
    ]
  }

  private var queueEntries: [ApplicationMusicPlayer.Queue.Entry] {
    Array(ApplicationMusicPlayer.shared.queue.entries)
  }

  private func repeatName(_ mode: MusicPlayer.RepeatMode) -> String {
    switch mode {
    case .none: return "off"
    case .one: return "one"
    case .all: return "all"
    }
  }

  // MARK: Queue operations

  @MainActor
  private func resolveSongs(_ items: [[String: Any]]) async throws -> [Song] {
    guard items.allSatisfy({ $0["type"] as? String == "songs" && !($0["id"] as? String ?? "").isEmpty }) else {
      throw NSError(domain: "deskbtm.apple_music_kit", code: 404)
    }
    var resolved: [String: Song] = [:]
    for library in [false, true] {
      let ids = items.filter { ($0["source"] as? String == "library") == library }
        .map { MusicItemID($0["id"] as! String) }
      for start in stride(from: 0, to: ids.count, by: 100) {
        let batch = Array(ids[start..<min(start + 100, ids.count)])
        let songs: MusicItemCollection<Song>
        if library {
          var request = MusicLibraryRequest<Song>()
          request.filter(matching: \.id, memberOf: batch)
          request.limit = 100
          songs = try await request.response().items
        } else {
          let request = MusicCatalogResourceRequest<Song>(matching: \Song.FilterType.id, memberOf: batch)
          songs = try await request.response().items
        }
        for song in songs { resolved["\(library):\(song.id.rawValue)"] = song }
      }
    }
    return try items.map { item in
      let key = "\(item["source"] as? String == "library"):\(item["id"] as! String)"
      guard let song = resolved[key] else { throw NSError(domain: "deskbtm.apple_music_kit", code: 404) }
      return song
    }
  }

  func setQueue(
    _ args: [String: Any],
    fail: @escaping (String, String, [String: Any]?) -> Void,
    reply: @escaping (Any?) -> Void
  ) {
    guard let items = args["items"] as? [[String: Any]], !items.isEmpty else {
      fail(ErrorCodes.unknown, "Missing queue items.", nil)
      return
    }
    let startIndex = args["startIndex"] as? Int ?? 0
    let autoplay = args["autoplay"] as? Bool ?? true
    runTracked {
      do {
        let songs = try await self.resolveSongs(items)
        let startSong: Song? = (startIndex >= 0 && startIndex < songs.count) ? songs[startIndex] : nil
        let queue = ApplicationMusicPlayer.Queue(for: songs, startingAt: startSong)
        self.queueRefs = items
        ApplicationMusicPlayer.shared.queue = queue
        if autoplay {
          try await ApplicationMusicPlayer.shared.play()
        }
        reply(nil)
      } catch {
        fail(
          ErrorMapper.code(for: error),
          "Failed to set queue: \(error.localizedDescription)", nil)
      }
    }
  }

  func play(reply: @escaping (Any?) -> Void, fail: @escaping (String, String, [String: Any]?) -> Void) {
    runTracked {
      do {
        try await ApplicationMusicPlayer.shared.play()
        reply(nil)
      } catch {
        fail(ErrorMapper.code(for: error), "Playback failed: \(error.localizedDescription)", nil)
      }
    }
  }

  func pause(reply: @escaping (Any?) -> Void) {
    Task { @MainActor in
      ApplicationMusicPlayer.shared.pause()
      reply(nil)
    }
  }

  func stop(reply: @escaping (Any?) -> Void) {
    Task { @MainActor in
      ApplicationMusicPlayer.shared.stop()
      reply(nil)
    }
  }

  func stopPlayback(_ stop: Bool, _ reply: @escaping (Any?) -> Void) {
    Task { @MainActor in
      if stop {
        ApplicationMusicPlayer.shared.stop()
      }
      self.stopObserving()
      reply(nil)
    }
  }

  func togglePlayPause(
    _ reply: @escaping (Any?) -> Void,
    fail: @escaping (String, String, [String: Any]?) -> Void
  ) {
    runTracked {
      let player = ApplicationMusicPlayer.shared
      if player.state.playbackStatus == .playing {
        player.pause()
        reply(nil)
      } else {
        do {
          try await player.play()
          reply(nil)
        } catch {
          fail(ErrorMapper.code(for: error), "Playback failed: \(error.localizedDescription)", nil)
        }
      }
    }
  }

  func seekTo(_ args: [String: Any], reply: @escaping (Any?) -> Void) {
    let millis = args["positionMillis"] as? Int ?? 0
    Task { @MainActor in
      ApplicationMusicPlayer.shared.playbackTime = TimeInterval(millis) / 1000
      reply(nil)
    }
  }

  func skipToNext(reply: @escaping (Any?) -> Void, fail: @escaping (String, String, [String: Any]?) -> Void) {
    runTracked {
      do {
        try await ApplicationMusicPlayer.shared.skipToNextEntry()
        reply(nil)
      } catch {
        fail(ErrorMapper.code(for: error), "skipToNext failed: \(error.localizedDescription)", nil)
      }
    }
  }

  func skipToPrevious(reply: @escaping (Any?) -> Void, fail: @escaping (String, String, [String: Any]?) -> Void) {
    runTracked {
      do {
        try await ApplicationMusicPlayer.shared.skipToPreviousEntry()
        reply(nil)
      } catch {
        fail(ErrorMapper.code(for: error), "skipToPrevious failed: \(error.localizedDescription)", nil)
      }
    }
  }

  func getQueue(reply: @escaping (Any?) -> Void) {
    Task { @MainActor in
      let current = ApplicationMusicPlayer.shared.queue.currentEntry
      var currentIndex: Int? = nil
      if let current = current {
        currentIndex = queueEntries.firstIndex(where: { $0.id == current.id })
      }
      let entries = queueRefs.map { ["ref": $0] }
      var replyDict: [String: Any] = ["entries": entries]
      if let currentIndex = currentIndex {
        replyDict["currentIndex"] = currentIndex
      } else {
        replyDict["currentIndex"] = NSNull()
      }
      reply(replyDict)
    }
  }

  func appendToQueue(
    _ args: [String: Any],
    fail: @escaping (String, String, [String: Any]?) -> Void,
    reply: @escaping (Any?) -> Void
  ) {
    guard let items = args["items"] as? [[String: Any]], !items.isEmpty else {
      fail(ErrorCodes.unknown, "Missing items.", nil)
      return
    }
    runTracked {
      do {
        let songs = try await self.resolveSongs(items)
        try await ApplicationMusicPlayer.shared.queue.insert(
          songs, position: .tail)
        self.queueRefs.append(contentsOf: items)
        reply(nil)
      } catch {
        fail(
          ErrorCodes.unsupportedFeature,
          "Queue editing failed: \(error.localizedDescription)",
          nil)
      }
    }
  }

  func removeFromQueue(_ args: [String: Any], reply: @escaping (Any?) -> Void) {
    let index = args["index"] as? Int ?? -1
    Task { @MainActor in
      let entries = queueEntries
      if index >= 0, index < entries.count {
        // Entries collection is mutable via replaceSubrange.
        var collection = ApplicationMusicPlayer.shared.queue.entries
        collection.remove(at: collection.index(collection.startIndex, offsetBy: index))
        ApplicationMusicPlayer.shared.queue.entries = collection
        if queueRefs.indices.contains(index) {
          queueRefs.remove(at: index)
        }
      }
      reply(nil)
    }
  }

  func setShuffleMode(_ args: [String: Any], reply: @escaping (Any?) -> Void) {
    let on = (args["mode"] as? String) == "on"
    Task { @MainActor in
      ApplicationMusicPlayer.shared.state.shuffleMode = on ? .songs : .off
      reply(nil)
    }
  }

  func setRepeatMode(_ args: [String: Any], reply: @escaping (Any?) -> Void) {
    let mode: MusicPlayer.RepeatMode
    switch args["mode"] as? String {
    case "one": mode = .one
    case "all": mode = .all
    default: mode = .none
    }
    Task { @MainActor in
      ApplicationMusicPlayer.shared.state.repeatMode = mode
      reply(nil)
    }
  }
}

/// Capability snapshotting for iOS.
final class CapabilitiesBridge {
  func snapshot(reply: @escaping (Any?) -> Void) {
    Task { @MainActor in
      let authorized = MusicAuthorization.currentStatus == .authorized
      var subscriptionCanUseLibrary = false
      if let subscription = try? await MusicSubscription.current {
        subscriptionCanUseLibrary = subscription.hasCloudLibraryEnabled
      }
      func conditional(_ ok: Bool, _ reason: String) -> [String: Any] {
        ok ? ["supported": true, "reason": "available"] : ["supported": false, "reason": reason]
      }
      reply([
        "canPlayCatalog": ["supported": true, "reason": "available"],
        "canAccessLibrary": conditional(
          authorized,
          authorized ? "available" : "authorizationRequired"),
        "canSeek": ["supported": true, "reason": "available"],
        "canSetQueue": ["supported": true, "reason": "available"],
        "canEditQueue": ["supported": true, "reason": "available"],
        "canShuffle": ["supported": true, "reason": "available"],
        "canRepeat": ["supported": true, "reason": "available"],
        "canControlVolume": [
          "supported": false, "reason": "unsupportedOnPlatform",
          "detail": "Volume is controlled by the system on iOS.",
        ],
        "canPlayInBackground": [
          "supported": true, "reason": "available",
          "detail": "Requires the Audio background mode in the host app.",
        ],
        "canCreatePlaylist": conditional(
          authorized && subscriptionCanUseLibrary,
          authorized ? "subscriptionRequired" : "authorizationRequired"),
      ])
    }
  }
}
