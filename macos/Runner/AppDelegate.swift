import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate, NSMenuItemValidation {
  private var windowKeptInBackground: MainFlutterWindow?

  private var desktopWallpaper: DesktopWallpaper? {
    (windowKeptInBackground ?? mainFlutterWindow as? MainFlutterWindow)?.desktopWallpaper
  }

  @IBAction func toggleDesktopWallpaper(_ sender: NSMenuItem) {
    desktopWallpaper?.toggle()
  }

  func validateMenuItem(_ item: NSMenuItem) -> Bool {
    guard item.action == #selector(toggleDesktopWallpaper(_:)) else { return true }
    if let title = desktopWallpaper?.menuTitle { item.title = title }
    return desktopWallpaper?.canToggle == true
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag, windowKeptInBackground != nil, let desktopWallpaper, !desktopWallpaper.isActive {
      desktopWallpaper.restoreWindow()
      return false
    }
    return desktopWallpaper?.isActive != true
  }

  override func applicationDidChangeScreenParameters(_ notification: Notification) {
    desktopWallpaper?.updateScreenFrame()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    guard let window = mainFlutterWindow as? MainFlutterWindow,
      window.desktopWallpaper?.closeToBackground == true
    else { return true }

    windowKeptInBackground = window
    // Switch Dock visibility after AppKit finishes closing the visible window.
    DispatchQueue.main.async { [weak window] in
      guard window?.isVisible == false else { return }
      sender.setActivationPolicy(.accessory)
    }
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
