import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.deskbtm.musaic/coverflow_photos",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      func reply(_ value: Any?) {
        DispatchQueue.main.async { result(value) }
      }

      switch (call.method, call.arguments) {
      case ("save", let bytes as FlutterStandardTypedData):
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
          guard status == .authorized else {
            reply(FlutterError(code: "photoPermissionDenied", message: nil, details: nil))
            return
          }
          var assetId: String?
          PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = "Musaic_\(UUID().uuidString).png"
            request.addResource(with: .photo, data: bytes.data, options: options)
            assetId = request.placeholderForCreatedAsset?.localIdentifier
          } completionHandler: { success, error in
            if success, let assetId {
              reply(assetId)
            } else {
              reply(FlutterError(code: "photoSaveFailed", message: error?.localizedDescription, details: nil))
            }
          }
        }
      case ("delete", let assetId as String):
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
          guard status == .authorized || status == .limited else {
            reply(FlutterError(code: "photoPermissionDenied", message: nil, details: nil))
            return
          }
          let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
          guard assets.count == 1 else {
            reply(FlutterError(code: "photoUnavailable", message: nil, details: nil))
            return
          }
          PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
          } completionHandler: { success, error in
            if let error, (error as? PHPhotosError)?.code != .userCancelled {
              reply(FlutterError(code: "photoDeleteFailed", message: error.localizedDescription, details: nil))
            } else {
              reply(success)
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
