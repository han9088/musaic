import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

}

final class MusaicFlutterViewController: FlutterViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    // Keep the last Flutter frame proportional while UIKit rotates its bounds.
    view.layer.contentsGravity = .resizeAspect
  }
}
