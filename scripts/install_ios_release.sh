cd /Users/han66/deskbtm/musaic

xcrun devicectl list devices
device_id="00008140-000949D13C9B801C"
app_path="build/ios/device-release/Build/Products/Release-iphoneos/Runner.app"

xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -destination "id=$device_id" \
  -derivedDataPath build/ios/device-release \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=H53V63BLAH \
  CODE_SIGN_IDENTITY="Apple Development" \
  build

codesign --verify --deep --strict "$app_path"
xcrun devicectl device install app --device "$device_id" "$app_path"
xcrun devicectl device process launch --device "$device_id" \
  --terminate-existing com.deskbtm.musaic
xcrun devicectl device info apps --device "$device_id" \
  --bundle-id com.deskbtm.musaic