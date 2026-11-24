import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate, NSMenuItemValidation {
  private var desktopWallpaper: DesktopWallpaper? {
    (mainFlutterWindow as? MainFlutterWindow)?.desktopWallpaper
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
    desktopWallpaper?.isActive != true
  }

  override func applicationDidChangeScreenParameters(_ notification: Notification) {
    desktopWallpaper?.updateScreenFrame()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
