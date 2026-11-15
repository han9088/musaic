import Flutter
import UIKit

public class SwiftMusaicQueryPlugin: NSObject, FlutterPlugin {
  private var directories: AnyObject?
  private static let CHANNEL_NAME: String = "com.deskbtm.muasic.query"

  override public init() {
    Log.setLogLevel(level: .warning)
  }

  // Dart <-> Swift communication.
  public static func register(with registrar: FlutterPluginRegistrar) {
    Log.type.info("Called register")

    let channel = FlutterMethodChannel(
      name: "\(CHANNEL_NAME)",
      binaryMessenger: registrar.messenger()
    )
    let instance = SwiftMusaicQueryPlugin()
    if #available(iOS 13.0, *) { instance.directories = AudioDirectories(registrar: registrar) }

    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    if #available(iOS 13.0, *) { (directories as? AudioDirectories)?.dispose() }
    directories = nil
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    Log.type.debug("Started method call (\(call.method))")

    Log.type.info("Method call: \(call.method)")
    switch call.method {
    // This is a basic permission handler, will return [true] if has permission and
    // [false] if don't.
    //
    // The others status will be ignored and replaced with [false].
    case Method.PERMISSION_STATUS:
      result(PermissionController.checkPermission())
    // The same as [permissionStatus], this is a basic permission handler and will only
    // return [true] or [false].
    //
    // When adding the necessary [permissions] inside [Info.plist], [IOS] will automatically
    // request but, in any case, you can call this method.
    case Method.PERMISSION_REQUEST:
      PermissionController.requestPermission(result: result)
    // Some basic information about the platform, in this case, [IOS]
    //   * Model (Only return the "type", like: IPhone, MacOs, IPod..)
    //   * Version (IOS version)
    //   * Type (IOS)
    case Method.QUERY_DEVICE_INFO:
      let device = UIDevice.current
      result([
        "device_model": device.model,
        "device_sys_type": device.systemName,
        "device_sys_version": device.systemVersion,
      ])
    // Set logging level.
    case Method.SET_LOG_CONFIG:
      let args = call.arguments as? [String: Any] ?? [:]

      // Log level
      let level = args["level"] as? Int ?? 2
      Log.setLogLevel(dartLevel: level)

      result(true)
    default:
      Log.type.debug("Checking permissions...")

      let hasPermission = PermissionController.checkPermission()
      Log.type.debug("Application has permissions: \(hasPermission)")

      if !hasPermission {
        Log.type.error("The application doesn't have access to the library")
        result(
          FlutterError(
            code: "MissingPermissions",
            message: "Application doesn't have access to the library",
            details:
              "Call the [permissionsRequest] method or install a external plugin to handle the app permission."
          )
        )
        break
      }

      MethodController().find(call: call, result: result)
    }

    Log.type.debug("Ended method call (\(call.method))")
  }
}
