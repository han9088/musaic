# musaic_query_web

A web implementation of `musaic_query` plugin.

## Limitations on the web platform:

Since Web Browsers **don't** offer direct access to their user's `file system`, this plugin will use the `assets` folder to "query" the audios files. So, will totally depend of the `developer`.

## Setup:

After installing the `musaic_query` plugin, define the `path` inside the `pubspec.yml`:

```yaml
  # You don't need add every audio file path, just define the folder.
  assets:
    - assets/
    # If your files are in another folder inside the `assets`:
    - assets/audios/
    # - assets/audios/animals/
    # - assets/audios/animals/cat/
    # ...
```




## Query behavior

The plugin indexes MP3 assets once per controller using Flutter's `AssetManifest` API.
`querySongs(path: 'assets/music')` filters by an asset folder prefix.
IDs identify entries within that asset manifest; persist asset paths instead of IDs
across app builds. Metadata queries reuse the index. Artwork keeps its embedded
encoding and dimensions; the Web implementation does not transcode `format`,
`size`, or `quality`. Its byte cache is capped at 8 MiB and 128 entries.
