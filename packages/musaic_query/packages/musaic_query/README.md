<div align=center>

# musaic_query
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20IOS%20%7C%20Web-9cf?&style=flat-square)]()
[![Languages](https://img.shields.io/badge/Languages-Dart%20%7C%20Kotlin%20%7C%20Swift-9cf?&style=flat-square)]()

[Flutter](https://flutter.dev/) Plugin used to query audios/songs 🎶 infos [title, artist, album, etc..] from device storage. <br>


</div>

### Topics:

* [Installation](#installation)
* [Platforms](#platforms)
* [Overview](#overview)
* [Examples](#examples)
* [Gif Examples](#gif-examples)
* [License](#license)

## Platforms:

macOS and Windows expose `MusaicQuery().directories` for local folders,
including metadata, cover art and playback URLs. See the
[directory API](../../DIRECTORIES.md) for platform configuration.

macOS also supports system Music library queries through `querySongs` and
`queryAlbums`. See the [macOS host requirements](../../README.md#implementation-and-validation).

<!-- ✔️ | ❌ -->
|  Methods  |   Android   |   IOS   |   Web   |
|-------|:----------:|:----------:|:----------:|
| `querySongs` | `✔️` | `✔️` | `✔️` | <br>
| `queryAlbums` | `✔️` | `✔️` | `✔️` | <br>
| `queryArtists` | `✔️` | `✔️` | `✔️` | <br>
| `queryPlaylists` | `✔️` | `✔️` | `❌` | <br>
| `queryGenres` | `✔️` | `✔️` | `✔️` | <br>
| `queryAudiosFrom` | `✔️` | `✔️` | `✔️` | <br>
| `queryWithFilters` | `✔️` | `✔️` | `✔️` | <br>
| `queryArtwork` | `✔️` | `✔️` | `✔️` | <br>
| `createPlaylist` | `✔️` | `✔️` | `❌` | <br>
| `removePlaylist` | `✔️` | `❌` | `❌` | <br>
| `addToPlaylist` | `✔️` | `✔️` | `❌` | <br>
| `removeFromPlaylist` | `✔️` | `❌` | `❌` | <br>
| `renamePlaylist` | `✔️` | `❌` | `❌` | <br>
| `moveItemTo` | `✔️` | `❌` | `❌` | <br>
| `checkAndRequest` | `✔️` | `✔️` | `❌` | <br>
| `permissionsRequest` | `✔️` | `✔️` | `❌` | <br>
| `permissionsStatus` | `✔️` | `✔️` | `❌` | <br>
| `queryDeviceInfo` | `✔️` | `✔️` | `✔️` | <br>
| `scanMedia` | `✔️` | `❌` | `❌` | <br>

✔️ -> Supported <br>
❌ -> Not Supported <br>


## Installation:

Add the following code to your `pubspec.yaml`:
```yaml
dependencies:
  musaic_query:
    path: packages/musaic_query/packages/musaic_query
```

### Request Permission:

#### Android:
The permission API requests read access only. Legacy playlist writes on Android 9
and older require the host to obtain WRITE_EXTERNAL_STORAGE separately.
To use this plugin add the following code to your AndroidManifest.xml
```xml
<manifest>
  
  <!-- Android 9 and below: playlist writes -->
  <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>
  <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>

  <!-- Android 13 or greater  -->
  <uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>

</manifest>
```

#### IOS:
To use this plugin add the following code to your Info.plist
```
<dict>

	<key>NSAppleMusicUsageDescription</key>
	<string>$(PROJECT_NAME) requires access to media library</string>

</dict>
```

## Some Features:

* Optional and Built-in storage `READ` and `WRITE` permission request
* Get all audios/songs.
* Get all albums and album-specific audios.
* Get all artists and artist-specific audios.
* Get all playlists and playlists-specific audios.
* Get all genres and genres-specific audios.
* Get all query methods with specific `keys` [Search].
* Create/Delete/Rename playlists.
* Add/Remove/Move specific audios to playlists.
* Specific sort types for all query methods.

## Overview:

All types of methods on this plugin:

### Artwork Widget

```dart
  Widget someOtherName() async {
    return QueryArtworkWidget(
      id: <audioId>,
      type: ArtworkType.AUDIO,
    );
  }
```


## Examples:

#### MusaicQuery

```dart
final MusaicQuery _audioQuery = MusaicQuery();
```

#### Query methods:

- queryAudios();
- queryAlbums();
- queryArtists();
- queryPlaylists();
- queryGenres().

```dart
  someName() async {
    // Query Audios
    List<AudioModel> audios = await _audioQuery.queryAudios();

    // Query Albums
    List<AlbumModel> albums = await _audioQuery.queryAlbums();
  }
```

#### scanMedia

You'll use this method when updating a media from storage. This method will update the media 'state' and
Android `MediaStore` will be able to know this 'state'.

```dart
  someName() async {
    MusaicQuery _audioQuery = MusaicQuery();
    File file = File('path');
    try {
      if (file.existsSync()) {
        file.deleteSync();
        _audioQuery.scanMedia(file.path); // Scan the media 'path'
      }
    } catch (e) {
      debugPrint('$e');
    }
  }
```

#### queryArtwork

```dart
  someName() async {
    // DEFAULT: ArtworkFormat.JPEG, 200 and false
    Uint8List something = await _audioQuery.queryArtwork(
        <audioId>,
        ArtworkType.AUDIO,
        ...,
      );
  }
```

Or you can use a basic and custom Widget.
**See example [QueryArtworkWidget](#artwork-widget)**

## Gif Examples:
| <img src="https://user-images.githubusercontent.com/76869974/129740857-33f38b27-06a3-4959-bb31-2ae97d6b66ff.gif"/> | <img src="https://user-images.githubusercontent.com/76869974/129741012-1215b292-d700-466f-9c41-552df0ad5e89.gif"/> | <img src="https://user-images.githubusercontent.com/76869974/129741188-e6803432-24d7-4e39-bfde-cc6765e13663.gif"/> | <img src="https://user-images.githubusercontent.com/76869974/129741151-b820edc9-ddbf-4446-b67a-6e254cb5a46d.gif"/> |
|:---:|:---:|:---:|:---:|
| <img src="https://user-images.githubusercontent.com/76869974/129763885-c0cb3871-39af-45fa-aebf-ebf4113effa2.gif"/> | <img src="https://user-images.githubusercontent.com/76869974/129763519-497cab72-6a95-42fd-8237-3f83e954ea50.gif"/> | <img src="https://user-images.githubusercontent.com/76869974/129763577-9037d16f-f940-4bcb-ba37-879a0eecf2ac.gif"/> | <img src="https://user-images.githubusercontent.com/76869974/129763551-726512a9-bc10-4c75-a167-8928f0c0c212.gif"/> |
| Songs | Albums | Playlists | Artists |

## LICENSE:

* [LICENSE](LICENSE)

> * [Back to top](#musaic_query)
