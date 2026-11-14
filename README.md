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

## Code structure

```text
lib/
  main.dart                    # Entry point
  app/                         # App assembly, lifecycle, shared sheet host
  pages/home/
    home_page.dart             # Home orchestration and state ownership
    home_sheet.dart            # Bottom handle and icon picker
    glass_icon_button.dart     # Button shared within the home page
    canvas/                    # Album grid, selection, sensor tilt, snapshots
    cover_flow/                # CoverFlow rendering and scroll physics
    playback/                  # Mock playback state and playback button
    layout/                    # Canvas/CoverFlow transitions and switch overlay
  services/                    # Album cache, haptics, tick audio, logging
  ui/                          # Reusable UI and design tokens
    bottom_sheet/              # Sheet engine, controller, presentation widgets
    dialogs/
    theme/
    thinking_orbs/
    widgets/
  l10n/                        # Translations and generated localization code
test/                          # Mirrors the owning source directories
```

Home owns the playback state and passes it to both the canvas and CoverFlow.
Page-specific UI stays with its page; reusable UI has no dependency on pages.
Services do not import pages, UI, or app assembly. iOS and Android share the Dart
implementation; platform integrations stay in the platform projects or services.
App startup and localization tests live in `test/app/`; home interactions live in
`test/pages/home/`, and haptics/cache tests live in `test/services/`.

## App icons

`ios/Runner/musaic.icon` is the primary Icon Composer resource, included in the
Runner resource phase and selected by `ASSETCATALOG_COMPILER_APPICON_NAME` for
Debug, Profile, and Release. Preserve its layers and appearance settings.

Icon switching uses `dynamic_app_icon_flutter_plus`, matching Loive.
`AppIconService.read()` returns `supported` and the current `AppIconChoice`, matching
Loive. `change(AppIconChoice.classic)` restores the primary icon.
Like Loive, reads first discover native icon names with `getAvailableIcons()` and
check every non-primary `AppIconChoice` against that configuration. The snapshot
contains only `supported` and `current`.
The bottom sheet offers the default icon and the supplied album collage (`MusaicMosaic`).
Both Apple projects include `MusaicMosaic.icon`, preserving the primary Icon Composer
settings. Android supplies a matching adaptive/legacy icon and disabled launcher alias.
To add an iOS alternative, add its `.icon` file to Runner's resources and list its
base name in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` for all three build
configurations, and add its native name to `AppIconChoice`. Xcode generates the
alternate icon metadata consumed by the plugin.

Android retains the supplied adaptive/legacy launcher resources. The default and
mosaic icons use `.MainActivity.default` and `.MainActivity.MusaicMosaic` aliases;
the plugin only toggles aliases, leaving the real activity enabled. Flutter reads
the real activity's MAIN/LAUNCHER filter and launches it explicitly. That filter
requires the `musaic-tooling` URI scheme, so ordinary launcher queries (without
data) only match the icon aliases. This keeps Flutter launches independent of the
currently selected icon, without adding a second desktop icon. Existing installs affected by the old layout
need MainActivity re-enabled once with `adb shell pm enable
com.deskbtm.musaic/.MainActivity`; app data does not need to be cleared.

macOS uses `macos/Runner/musaic.icon` as its primary app icon. Since the mobile
plugin has no macOS implementation, `AppIconPlugin.swift` implements its channel
contract for Finder and Dock icons. It discovers alternate image asset names from a
`MusaicAlternateIcons` dictionary in the macOS Info.plist (icon name → bundled
image asset name). Add the corresponding `AppIconChoice` when supplying an
alternative. Selection is saved in UserDefaults. Startup restoration and explicit
changes share the same Finder/Dock update path; a removed alternate resets both
to the primary icon. Pending or failed startup synchronization is returned as an
error when reading the current icon, rather than reporting an unsynchronized
selection. Restoring the default clears the saved choice. A change first sets the application bundle's Finder custom
icon through NSWorkspace, then updates the Dock and saved selection. Restoring
the default removes the Finder custom icon as well. If direct writing fails,
a system file panel requests access to this exact running application; cancellation
or a failed write is returned as an error without committing the new selection.
The sandbox remains enabled with user-selected read/write access. Finder custom
icons persist independently of the running app; replacing the app during an update
may remove them. `MusaicMosaicPreview` supplies the collage for Finder and Dock.
