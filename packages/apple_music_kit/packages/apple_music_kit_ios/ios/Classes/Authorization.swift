import Flutter
import Foundation
import MusicKit

/// Lifecycle bridge: initialize / dispose bookkeeping.
final class MethodBridge: NSObject {
  private(set) var initialized = false

  func initialize(_ args: [String: Any], reply: @escaping (Any?) -> Void) {
    // MusicKit needs no explicit session setup; request nothing here so the
    // app stays in control of when the permission prompt appears. We only
    // warm the ApplicationMusicPlayer reference.
    _ = ApplicationMusicPlayer.shared
    initialized = true
    reply(nil)
  }

  func dispose(
    _ args: [String: Any],
    stopPlaybackHandler: @escaping (Bool, @escaping (Any?) -> Void) -> Void,
    reply: @escaping (Any?) -> Void
  ) {
    let stop = args["stopPlayback"] as? Bool ?? false
    initialized = false
    stopPlaybackHandler(stop, reply)
  }

  /// Fails the call with `notInitialized` when initialize() has not run.
  func requireInitialized(_ fail: (String, String, [String: Any]?) -> Void) -> Bool {
    guard initialized else {
      fail(ErrorCodes.notInitialized, "Call initialize() before using MusicKit.", nil)
      return false
    }
    return true
  }
}

/// Authorization + subscription bridge.
final class AuthorizationBridge: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?

  // MARK: FlutterStreamHandler

  private var updatesTask: Task<Void, Never>?

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
    sink = eventSink
    // Emit the current status immediately. MusicKit exposes no
    // change-notification for authorization status; re-read on every
    // subscription and after requestAuthorization(). Additionally watch
    // subscription updates, which fire when the account changes (a common
    // trigger for authorization changes, e.g. signing out).
    sink?(statusName(MusicAuthorization.currentStatus))
    updatesTask = Task { @MainActor [weak self] in
      for await _ in MusicSubscription.subscriptionUpdates {
        guard let self = self, self.sink != nil else { return }
        self.sink?(self.statusName(MusicAuthorization.currentStatus))
      }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    updatesTask?.cancel()
    updatesTask = nil
    return nil
  }

  // MARK: Methods

  func getStatus(reply: @escaping (Any?) -> Void) {
    reply(statusName(MusicAuthorization.currentStatus))
  }

  func request(reply: @escaping (Any?) -> Void) {
    Task { @MainActor in
      let status = await MusicAuthorization.request()
      self.sink?(statusName(status))
      reply(statusName(status))
    }
  }

  func subscription(reply: @escaping (Any?) -> Void) {
    Task { @MainActor in
      do {
        let subscription = try await MusicSubscription.current
        reply(self.subscriptionDict(subscription))
      } catch {
        reply([
          "status": "unknown",
          "canPlayCatalogContent": false,
          "hasCloudLibraryEnabled": false,
        ])
      }
    }
  }

  // MARK: Helpers

  func statusName(_ status: MusicAuthorization.Status) -> String {
    switch status {
    case .notDetermined: return "notDetermined"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .authorized: return "authorized"
    @unknown default: return "notDetermined"
    }
  }

  func subscriptionDict(_ sub: MusicSubscription) -> [String: Any] {
    let status = sub.canPlayCatalogContent ? "subscribed" : "notSubscribed"
    return [
      "status": status,
      "canPlayCatalogContent": sub.canPlayCatalogContent,
      "hasCloudLibraryEnabled": sub.hasCloudLibraryEnabled,
    ]
  }
}
