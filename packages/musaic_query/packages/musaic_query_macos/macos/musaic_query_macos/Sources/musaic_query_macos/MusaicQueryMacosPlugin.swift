import AppKit
import FlutterMacOS

public final class MusaicQueryMacosPlugin: NSObject, FlutterPlugin {
  private struct Scope {
    let url: URL
    let token: String
    let active: Bool

    func close() {
      if active { url.stopAccessingSecurityScopedResource() }
    }
  }

  private enum DirectoryError: LocalizedError {
    case badBookmark, moved, unreadable

    var errorDescription: String? {
      switch self {
      case .badBookmark: return "Invalid audio directory bookmark"
      case .moved: return "Audio directory moved; select it again"
      case .unreadable: return "Audio directory is unavailable"
      }
    }
  }

  private var directories: [String: Scope] = [:]
  private var playback: [String: Scope] = [:]
  private var openPanel: NSOpenPanel?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let library = MacosMusicLibrary()
    FlutterMethodChannel(
      name: "com.deskbtm.muasic.query",
      binaryMessenger: registrar.messenger
    ).setMethodCallHandler(library.handle)

    let channel = FlutterMethodChannel(
      name: "com.deskbtm.musaic.query/macos_directories",
      binaryMessenger: registrar.messenger
    )
    registrar.addMethodCallDelegate(MusaicQueryMacosPlugin(), channel: channel)
  }

  deinit {
    for scope in directories.values { scope.close() }
    for scope in playback.values { scope.close() }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: String]
    let path = args?["path"].map { URL(fileURLWithPath: $0).standardizedFileURL.path }
    do {
      switch call.method {
      case "pick":
        pick(result)
      case "restore", "retainPlayback":
        guard let path, let token = args?["token"] else {
          throw DirectoryError.badBookmark
        }
        if call.method == "restore" {
          if let current = directories[path] {
            result(current.token)
            return
          }
          let scope = try resolve(token, expected: path)
          directories[path] = scope
          result(scope.token)
        } else {
          let currentToken = directories[path]?.token ?? token
          let scope = try resolve(currentToken, expected: path)
          let session = UUID().uuidString
          playback[session] = scope
          result(session)
        }
      case "release":
        if let path { directories.removeValue(forKey: path)?.close() }
        result(nil)
      case "releasePlayback":
        if let session = args?["session"] {
          playback.removeValue(forKey: session)?.close()
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      result(pluginError(error))
    }
  }

  private func pick(_ result: @escaping FlutterResult) {
    guard openPanel == nil else {
      result(FlutterError(code: "busy", message: "An audio folder picker is open", details: nil))
      return
    }
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = false
    openPanel = panel
    let complete: (NSApplication.ModalResponse) -> Void = { [weak self] response in
      guard let self else {
        result(nil)
        return
      }
      self.openPanel = nil
      guard response == .OK, let selected = panel.url else {
        result(nil)
        return
      }
      defer { selected.stopAccessingSecurityScopedResource() }
      do {
        let path = self.canonicalPath(selected)
        let scope = try self.resolve(self.bookmark(selected), expected: path)
        self.directories.updateValue(scope, forKey: path)?.close()
        result(["path": path, "token": scope.token])
      } catch {
        result(self.pluginError(error))
      }
    }
    if let window = NSApp.keyWindow {
      panel.beginSheetModal(for: window, completionHandler: complete)
    } else {
      panel.begin(completionHandler: complete)
    }
  }

  private func canonicalPath(_ url: URL) -> String {
    url.resolvingSymlinksInPath().standardizedFileURL.path
  }

  private func bookmark(_ url: URL) throws -> String {
    try url.bookmarkData(
      options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    ).base64EncodedString()
  }

  private func resolve(_ token: String, expected: String) throws -> Scope {
    guard let data = Data(base64Encoded: token) else { throw DirectoryError.badBookmark }
    var stale = false
    let url = try URL(
      resolvingBookmarkData: data,
      options: [.withSecurityScope, .withoutUI, .withoutMounting],
      relativeTo: nil,
      bookmarkDataIsStale: &stale
    )
    let active = url.startAccessingSecurityScopedResource()
    do {
      guard canonicalPath(url) == expected else { throw DirectoryError.moved }
      guard try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true,
        FileManager.default.isReadableFile(atPath: url.path)
      else { throw DirectoryError.unreadable }
      return Scope(url: url, token: stale ? try bookmark(url) : token, active: active)
    } catch {
      if active { url.stopAccessingSecurityScopedResource() }
      throw error
    }
  }

  private func pluginError(_ error: Error) -> FlutterError {
    FlutterError(code: "directoryUnavailable", message: error.localizedDescription, details: nil)
  }
}
