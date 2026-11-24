import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private(set) var desktopWallpaper: DesktopWallpaper?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.backgroundColor = .black
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 360, height: 400)
    self.styleMask.insert(.fullSizeContentView)
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.isMovableByWindowBackground = false

    RegisterGeneratedPlugins(registry: flutterViewController)
    AppIconPlugin.register(with: flutterViewController.registrar(forPlugin: "AppIconPlugin"))
    desktopWallpaper = DesktopWallpaper(window: self, messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
