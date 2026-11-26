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
    guard
      let reason = Bundle.main.object(forInfoDictionaryKey: "NSAppleMusicUsageDescription") as? String,
      !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      result(FlutterError(
        code: "MissingUsageDescription",
        message: "Set NSAppleMusicUsageDescription in the host app's Info.plist.",
        details: nil))
      return
    }
    MPMediaLibrary.requestAuthorization { status in
      DispatchQueue.main.async { result(status == .authorized) }
    }
  }
}
