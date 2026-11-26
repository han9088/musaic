import Cocoa
import FlutterMacOS

final class DesktopWallpaper {
  private unowned let mainWindow: NSWindow
  private let channel: FlutterMethodChannel
  private var session: (window: NSWindow, originalFrame: NSRect)?
  private var preparing = false
  private var shortcutReady = false
  private var trayReady = false
  var closeToBackground: Bool { shortcutReady || trayReady }

  init(window: NSWindow, messenger: FlutterBinaryMessenger) {
    mainWindow = window
    channel = FlutterMethodChannel(
      name: "com.deskbtm.musaic/desktop_wallpaper", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "setCloseToBackground": self.shortcutReady = call.arguments as? Bool == true
      case "setTrayReady": self.trayReady = call.arguments as? Bool == true
      case "quit":
        result(nil)
        DispatchQueue.main.async { NSApp.terminate(nil) }
        return
      case "embedWindow": self.embedWindow()
      case "restoreWindow": self.restoreWindow()
      default:
        result(FlutterMethodNotImplemented)
        return
      }
      result(nil)
    }
  }

  var isActive: Bool { session != nil }

  private var canShow: Bool {
    mainWindow.isVisible && !mainWindow.isMiniaturized
      && !mainWindow.styleMask.contains(.fullScreen) && mainWindow.attachedSheet == nil
      && NSApp.modalWindow == nil
  }

  func embedWindow() {
    guard !isActive, !preparing, canShow, closeToBackground else { return }
    preparing = true
    channel.invokeMethod("prepare", arguments: nil) { [weak self] response in
      guard let self else { return }
      self.preparing = false
      guard response as? Bool == true else {
        NSSound.beep()
        return
      }
      if !self.showWallpaper() {
        self.channel.invokeMethod("didRestore", arguments: nil)
        NSSound.beep()
      }
    }
  }

  private func showWallpaper() -> Bool {
    guard canShow,
      let controller = mainWindow.contentViewController,
      let screen = mainWindow.screen ?? NSScreen.main
    else { return false }

    let window = NSWindow(
      contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
    // Place the live view above the system wallpaper and below Finder's icons.
    window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
    window.backgroundColor = .black
    window.hasShadow = false
    window.hidesOnDeactivate = false
    window.ignoresMouseEvents = true
    window.isExcludedFromWindowsMenu = true

    session = (window, mainWindow.frame)
    mainWindow.orderOut(nil)
    mainWindow.contentViewController = nil
    window.contentViewController = controller
    window.setFrame(screen.frame, display: false)
    window.orderFrontRegardless()
    return true
  }

  func restoreWindow() {
    if NSApp.activationPolicy() == .accessory { NSApp.setActivationPolicy(.regular) }
    if NSApp.isHidden { NSApp.unhide(nil) }
    if let session {
      let controller = session.window.contentViewController
      session.window.contentViewController = nil
      mainWindow.contentViewController = controller
      mainWindow.setFrame(session.originalFrame, display: false)
      session.window.orderOut(nil)
      self.session = nil
      channel.invokeMethod("didRestore", arguments: nil)
    }
    if mainWindow.isMiniaturized { mainWindow.deminiaturize(nil) }
    mainWindow.makeKeyAndOrderFront(nil)
    if #available(macOS 14.0, *) {
      NSApp.activate()
    } else {
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  func updateScreenFrame() {
    guard let window = session?.window, let screen = window.screen ?? NSScreen.main else { return }
    window.setFrame(screen.frame, display: true)
  }
}
