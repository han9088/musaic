import Flutter
import MediaPlayer

class PermissionController {
  public static func checkPermission() -> Bool {
    let permissionStatus = MPMediaLibrary.authorizationStatus()
    if permissionStatus == MPMediaLibraryAuthorizationStatus.authorized {
      return true
    } else {
      return false
    }
  }

  public static func requestPermission(result: @escaping FlutterResult) {
    MPMediaLibrary.requestAuthorization { status in
      DispatchQueue.main.async { result(status == .authorized) }
    }
  }
}
