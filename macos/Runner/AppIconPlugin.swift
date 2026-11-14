import Cocoa
import FlutterMacOS

/// Implements the mobile plugin's channel contract for macOS app icons.
final class AppIconPlugin: NSObject, FlutterPlugin {
  private static let selectionKey = "MusaicSelectedAppIcon"
  private let icons = Bundle.main.object(forInfoDictionaryKey: "MusaicAlternateIcons")
    as? [String: String] ?? [:]
  private var current: String?
  private var changing = false
  private var restorationError: FlutterError?

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = AppIconPlugin()
    let channel = FlutterMethodChannel(
      name: "flutter_dynamic_icon", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(plugin, channel: channel)
    if let saved = UserDefaults.standard.string(forKey: selectionKey) {
      let image = plugin.icons[saved].flatMap { NSImage(named: NSImage.Name($0)) }
      plugin.changing = true
      // Defer permission UI until the Flutter window has finished initializing.
      DispatchQueue.main.async {
        plugin.applyIcon(image, name: image == nil ? nil : saved) { error in
          plugin.restorationError = error
        }
      }
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "mSupportsAlternateIcons":
      result(true)
    case "mGetAvailableIcons":
      result(icons.keys.sorted())
    case "mGetAlternateIconName":
      if changing {
        result(FlutterError(code: "ICON_CHANGE_PENDING", message: "Icon synchronization is pending", details: nil))
      } else if let error = restorationError {
        result(error)
      } else {
        result(current)
      }
    case "mSetAlternateIconName":
      guard !changing else {
        result(FlutterError(code: "ICON_CHANGE_PENDING", message: "An icon change is already pending", details: nil))
        return
      }
      guard let arguments = call.arguments as? [String: Any],
        let value = arguments["iconName"], value is String || value is NSNull
      else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing iconName", details: nil))
        return
      }
      let name = value as? String
      let image: NSImage?
      if let name = name {
        guard let asset = icons[name], let loaded = NSImage(named: NSImage.Name(asset)) else {
          result(FlutterError(code: "ICON_NOT_FOUND", message: "Icon is not configured: \(name)", details: nil))
          return
        }
        image = loaded
      } else {
        image = nil
      }
      changing = true
      applyIcon(image, name: name) { error in
        result(error)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func applyIcon(_ image: NSImage?, name: String?, completion: @escaping (FlutterError?) -> Void) {
    updateFinderIcon(image) { error in
      self.changing = false
      if let error = error {
        completion(error)
        return
      }
      NSApp.applicationIconImage = image
      if let name = name {
        UserDefaults.standard.set(name, forKey: Self.selectionKey)
      } else {
        UserDefaults.standard.removeObject(forKey: Self.selectionKey)
      }
      self.current = name
      self.restorationError = nil
      completion(nil)
    }
  }

  private func updateFinderIcon(_ image: NSImage?, completion: @escaping (FlutterError?) -> Void) {
    let appURL = Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL
    if NSWorkspace.shared.setIcon(image, forFile: appURL.path, options: []) {
      completion(nil)
      return
    }

    // A sandboxed app needs user-selected write access to its own installed bundle.
    let panel = NSOpenPanel()
    panel.message = "请选择当前运行的 \(appURL.lastPathComponent)，以更新 Finder 中的图标。"
    panel.prompt = "允许更新图标"
    panel.directoryURL = appURL.deletingLastPathComponent()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.treatsFilePackagesAsDirectories = false
    panel.begin { response in
      guard response == .OK, let selected = panel.url else {
        completion(FlutterError(code: "ICON_CHANGE_CANCELLED", message: "Icon change cancelled", details: nil))
        return
      }
      guard selected.resolvingSymlinksInPath().standardizedFileURL == appURL else {
        completion(FlutterError(code: "WRONG_APPLICATION", message: "Select the currently running Musaic application", details: nil))
        return
      }
      let accessing = selected.startAccessingSecurityScopedResource()
      defer { if accessing { selected.stopAccessingSecurityScopedResource() } }
      guard NSWorkspace.shared.setIcon(image, forFile: selected.path, options: []) else {
        completion(FlutterError(code: "ICON_WRITE_FAILED", message: "Unable to update the Finder icon; the application must be writable", details: nil))
        return
      }
      completion(nil)
    }
  }
}
