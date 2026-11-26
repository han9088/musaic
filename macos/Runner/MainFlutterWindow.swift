import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private(set) var desktopWallpaper: DesktopWallpaper?
  private var settingsWindow: MacSettingsWindow?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let engine = flutterViewController.engine
    // Enable secondary views before attaching the implicit view used by the main window.
    engine.viewController = nil
    _ = engine.perform(NSSelectorFromString("enableMultiView"))
    engine.viewController = flutterViewController
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 360, height: 400)
    applyMusaicChrome()

    RegisterGeneratedPlugins(registry: flutterViewController)
    AppIconPlugin.register(with: flutterViewController.registrar(forPlugin: "AppIconPlugin"))
    desktopWallpaper = DesktopWallpaper(window: self, messenger: flutterViewController.engine.binaryMessenger)
    settingsWindow = MacSettingsWindow(engine: engine)

    super.awakeFromNib()
  }
}

private final class MacSettingsWindow: NSObject, NSWindowDelegate {
  private let engine: FlutterEngine
  private let channel: FlutterMethodChannel
  private var window: NSWindow?

  init(engine: FlutterEngine) {
    self.engine = engine
    self.channel = FlutterMethodChannel(
      name: "com.deskbtm.musaic/settings_window", binaryMessenger: engine.binaryMessenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(FlutterMethodNotImplemented) }
      switch call.method {
      case "prepare":
        result(self.prepare(title: call.arguments as? String ?? ""))
      case "show", "close":
        let viewId = (self.window?.contentViewController as? FlutterViewController)?.viewIdentifier
        guard let window = self.window, let id = call.arguments as? NSNumber,
          id.int64Value == viewId
        else {
          result(nil)
          return
        }
        if call.method == "show" {
          if window.isMiniaturized { window.deminiaturize(nil) }
          NSApp.activate(ignoringOtherApps: true)
          window.makeKeyAndOrderFront(nil)
        } else {
          window.close()
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func prepare(title: String) -> FlutterViewIdentifier {
    if let window, let controller = window.contentViewController as? FlutterViewController {
      window.title = title
      return controller.viewIdentifier
    }

    let controller = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    controller.backgroundColor = .black
    // The Flutter regular-window factory orders the window front during creation.
    let contentSize = NSSize(width: 720, height: 560)
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: contentSize),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered, defer: false)
    window.applyMusaicChrome()
    window.title = title
    window.contentMinSize = NSSize(width: 460, height: 380)
    window.isReleasedWhenClosed = false
    window.contentViewController = controller
    window.setContentSize(contentSize)
    window.delegate = self
    window.center()
    self.window = window
    return controller.viewIdentifier
  }

  func windowDidBecomeKey(_ notification: Notification) {
    forwardFocus("windowDidBecomeKey:")
  }

  func windowDidResignKey(_ notification: Notification) {
    forwardFocus("windowDidResignKey:")
  }

  private func forwardFocus(_ name: String) {
    let selector = NSSelectorFromString(name)
    guard let controller = window?.contentViewController as? FlutterViewController,
      let method = engine.method(for: selector)
    else { return }
    // Match the Flutter window delegate's focus events on the shared engine.
    typealias FocusCallback = @convention(c) (FlutterEngine, Selector, FlutterViewIdentifier) -> Void
    unsafeBitCast(method, to: FocusCallback.self)(engine, selector, controller.viewIdentifier)
  }

  func windowWillClose(_ notification: Notification) {
    guard let window, let controller = window.contentViewController as? FlutterViewController
    else { return }
    let viewId = controller.viewIdentifier
    self.window = nil
    window.contentViewController = nil
    channel.invokeMethod("closed", arguments: viewId)
  }
}

private extension NSWindow {
  func applyMusaicChrome() {
    backgroundColor = .black
    styleMask.insert(.fullSizeContentView)
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    isMovableByWindowBackground = false
  }
}
