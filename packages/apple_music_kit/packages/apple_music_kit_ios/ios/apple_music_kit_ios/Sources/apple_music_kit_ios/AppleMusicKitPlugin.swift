import Flutter
import MusicKit
import UIKit

/// Main plugin entry point for the apple_music_kit iOS implementation.
public final class AppleMusicKitPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AppleMusicKitPlugin()
    instance.attach(to: registrar)
  }

  private let method = MethodBridge()
  private let auth = AuthorizationBridge()
  private let catalog = CatalogBridge()
  private let library = LibraryBridge()
  private let player = PlayerBridge()
  private var capabilities: CapabilitiesBridge { player.capabilitiesBridge }

  private func attach(to registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "deskbtm.apple_music_kit/methods", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(self, channel: channel)

    let authEvents = FlutterEventChannel(
      name: "deskbtm.apple_music_kit/authEvents", binaryMessenger: registrar.messenger())
    authEvents.setStreamHandler(auth)

    let playerEvents = FlutterEventChannel(
      name: "deskbtm.apple_music_kit/playerEvents", binaryMessenger: registrar.messenger())
    playerEvents.setStreamHandler(player)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let reply: (Any?) -> Void = { value in
      DispatchQueue.main.async { result(value) }
    }
    let fail: (String, String, [String: Any]?) -> Void = { code, message, details in
      DispatchQueue.main.async { result(FlutterError(code: code, message: message, details: details)) }
    }

    switch call.method {
    case "initialize":
      method.initialize(args, reply: reply)
    case "dispose":
      method.dispose(args, stopPlaybackHandler: player.stopPlayback, reply: reply)
    case "getAuthorizationStatus":
      guard method.requireInitialized(fail) else { return }
      auth.getStatus(reply: reply)
    case "requestAuthorization":
      guard method.requireInitialized(fail) else { return }
      auth.request(reply: reply)
    case "getSubscription":
      guard method.requireInitialized(fail) else { return }
      auth.subscription(reply: reply)
    case "getCapabilities":
      guard method.requireInitialized(fail) else { return }
      capabilities.snapshot(reply: reply)
    case "searchCatalog":
      guard method.requireInitialized(fail) else { return }
      catalog.search(args, fail: fail, reply: reply)
    case "getCatalogSong":
      guard method.requireInitialized(fail) else { return }
      catalog.getSong(args, fail: fail, reply: reply)
    case "getAlbumAnimatedArtwork":
      guard method.requireInitialized(fail) else { return }
      catalog.getAlbumAnimatedArtwork(args, fail: fail, reply: reply)
    case "getCatalogAlbum":
      guard method.requireInitialized(fail) else { return }
      catalog.getAlbum(args, fail: fail, reply: reply)
    case "getCatalogArtist":
      guard method.requireInitialized(fail) else { return }
      catalog.getArtist(args, fail: fail, reply: reply)
    case "getCatalogPlaylist":
      guard method.requireInitialized(fail) else { return }
      catalog.getPlaylist(args, fail: fail, reply: reply)
    case "getCharts":
      guard method.requireInitialized(fail) else { return }
      catalog.getCharts(args, fail: fail, reply: reply)
    case "getCurrentStorefront":
      guard method.requireInitialized(fail) else { return }
      catalog.currentStorefront(fail: fail, reply: reply)
    case "getLibrarySongs":
      guard method.requireInitialized(fail) else { return }
      library.getSongs(args, fail: fail, reply: reply)
    case "getLibraryAlbums":
      guard method.requireInitialized(fail) else { return }
      library.getAlbums(args, fail: fail, reply: reply)
    case "getLibraryPlaylists":
      guard method.requireInitialized(fail) else { return }
      library.getPlaylists(args, fail: fail, reply: reply)
    case "searchLibrary":
      guard method.requireInitialized(fail) else { return }
      library.search(args, fail: fail, reply: reply)
    case "addToLibrary":
      guard method.requireInitialized(fail) else { return }
      library.addToLibrary(args, fail: fail, reply: reply)
    case "createPlaylist":
      guard method.requireInitialized(fail) else { return }
      library.createPlaylist(args, fail: fail, reply: reply)
    case "addToPlaylist":
      guard method.requireInitialized(fail) else { return }
      library.addToPlaylist(args, fail: fail, reply: reply)
    case "setQueue":
      guard method.requireInitialized(fail) else { return }
      player.setQueue(args, fail: fail, reply: reply)
    case "play":
      guard method.requireInitialized(fail) else { return }
      player.play(reply: reply, fail: fail)
    case "pause":
      guard method.requireInitialized(fail) else { return }
      player.pause(reply: reply)
    case "stop":
      guard method.requireInitialized(fail) else { return }
      player.stop(reply: reply)
    case "togglePlayPause":
      guard method.requireInitialized(fail) else { return }
      player.togglePlayPause(reply, fail: fail)
    case "seekTo":
      guard method.requireInitialized(fail) else { return }
      player.seekTo(args, reply: reply)
    case "skipToNext":
      guard method.requireInitialized(fail) else { return }
      player.skipToNext(reply: reply, fail: fail)
    case "skipToPrevious":
      guard method.requireInitialized(fail) else { return }
      player.skipToPrevious(reply: reply, fail: fail)
    case "getQueue":
      guard method.requireInitialized(fail) else { return }
      player.getQueue(reply: reply)
    case "appendToQueue":
      guard method.requireInitialized(fail) else { return }
      player.appendToQueue(args, fail: fail, reply: reply)
    case "removeFromQueue":
      guard method.requireInitialized(fail) else { return }
      player.removeFromQueue(args, reply: reply)
    case "setShuffleMode":
      guard method.requireInitialized(fail) else { return }
      player.setShuffleMode(args, reply: reply)
    case "setRepeatMode":
      guard method.requireInitialized(fail) else { return }
      player.setRepeatMode(args, reply: reply)
    default:
      reply(FlutterMethodNotImplemented)
    }
  }
}
