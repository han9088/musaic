# Musaic

Where Music Becomes Mosaic.

Flutter app for Android, iOS, and macOS with the application ID `com.deskbtm.musaic`.

```sh
mise install
mise exec -- flutter pub get
mise exec -- flutter run
```

## macOS

```sh
mise exec -- flutter run -d macos
mise exec -- flutter build macos --release
```

The release app is `build/macos/Build/Products/Release/Musaic.app`. macOS opens the album canvas, including in wide windows. Playback controls
currently simulate playback. macOS keeps album tick sounds but does not use the
mobile haptics plugin or device-tilt sensors.
