# Local audio directories

`MusaicQuery().directories` is separate from the existing system-media-library
queries. It does not request MediaStore/music-library permission and does not own
a music database. Android uses persisted SAF read grants (API 21+); iOS directory
selection requires iOS 13+. Existing system-library APIs keep their earlier OS
support. Web reports `supported == false` and rejects directory operations.

```dart
final directories = MusaicQuery().directories;
if (!await directories.supported) return;
final picked = await directories.pick(); // null means the user cancelled
if (picked == null) return;
// Persist picked.toMap() privately in the application database.
final source = await directories.restore(picked); // persist renewed token
final cancellation = AudioScanCancellation();
final summaries = AudioFolderSummaries(source);
await for (final page in directories.scan(
  source,
  options: const AudioScanOptions(
    recursive: true,
    includeHidden: false,
    excludedDirectories: {'Recordings'},
    extensions: {'mp3', 'm4a', 'flac'},
    minSize: 1024,
  ),
  cancellation: cancellation,
)) {
  summaries.add(page); // reuse pages, do not enumerate again
  if (page.error != null) {
    // Mark scan incomplete. Do not reconcile deletions.
    continue;
  }
  for (final file in page.entries.where((e) => e.isAudio)) {
    // Compare file identity/size/modified/reliable with your persisted index.
    // Only read metadata if new, changed, forced, or due for revalidation.
    final metadata = await directories.metadata(source, file);
    // Save metadata separately from file.name (a presentation fallback).
  }
}
final folders = summaries.snapshot(recursive: true);
// Call cancellation.cancel() from a cancel action. No fake total is reported.
```

The example reads tags to demonstrate the interface; Musaic's index coordinator
skips unchanged entries. Pages contain at most 128 raw native entries. Scanning
pulls one page at a time, closes native enumerators in `finally`, and skips symbolic
links. Only one directory cursor is open per scan. The traversal retains pending
subdirectory IDs and a visited set, not every audio file. Native sessions are
limited to 16. Android before API 26 must materialize one directory because the
older filesystem API has no streaming directory iterator; SAF remains paged.

`openPath(path)` is available for ordinary directories the app already has access
to; it does not grant new privileges. Resource IDs and grants are opaque. SAF
identities use provider authority + document ID and can deduplicate overlapping
grants. File URL identities change on rename/move; these become remove + add.
Do not persist Dart/Java/Swift hash values as identities. A moved/expired directory
must be authorized again; restoring a different root never silently replaces it.

Provider errors, missing files, broken metadata and revoked grants throw or appear
as page errors. Cloud files may be unavailable until downloaded by their provider;
retry later. A provider reporting that its listing is still loading is treated as
incomplete, not empty. Cancellation is cooperative between pages/metadata reads;
an OS/provider read already in progress must return before its resource closes.

## Filters and unknown values

Scan options combine with AND; extension inclusion is case-insensitive and an
explicit exclusion wins. Size boundaries are inclusive. A constrained field that
is unknown does not match. Excluded directories can be exact resource IDs or
names. Hidden entries are omitted by default. Changing scan options changes scope;
applications must not treat a narrower scan as evidence of physical deletion.
Musaic indexes the default full audio scope and applies display filters separately.

`AudioFilter` supplies inclusive duration/size/extension filters and category
matching. `MusaicQuery().querySongsFiltered(filter)` filters existing system-index
results; it does not traverse files. Requested categories are ORed, other criteria
are ANDed. A category must be known true. Ordinary directory files have unknown
classification. System fields depend on OS support (e.g. Android audiobook API29+),
and unknown categories must not be inferred from names. Folder summaries count
only enumerated matching audio; bytes are null if a size is unknown. `complete`
is false if enumeration failed or a requested descendant was not enumerated.
Duration-filtered summaries require the application's stored metadata.

## Artwork

```dart
final uri = await directories.artwork(source, file, cover: folderCover, size: 512);
await directories.clearArtworkCache();
await directories.release(source); // after removing application's grant reference
```

Collect `entry.coverPriority != null` candidates from the same directory pages.
Choose lowest priority, then ID as a deterministic tie-breaker. Priority is
`cover`, `folder`, `front`, `album`, `artwork`, each JPG, JPEG, PNG, ignoring case.
Embedded artwork takes precedence; folder images are fallback. No image is decoded
during enumeration. Native output is bounded JPEG (quality 85), max size 1–4096;
there is deliberately no unused format/quality option. Caches are private, atomic,
serialized and capped at 64 MiB / 512 entries per platform with oldest-accessed eviction. Cache
identity includes file/cover identity, stamps and requested size. Source access is
checked even on a cache hit. Native calls with untrusted stamps are regenerated;
Musaic also coalesces same-key requests and bounds its future cache to 128 entries.
No image bytes are stored in the catalog database. Clear only removes this plugin's
cache directory; it never removes source files. Web retains its existing cache.

Sources: [Android SAF](https://developer.android.com/training/data-storage/shared/documents-files),
[Apple directory access](https://developer.apple.com/documentation/uikit/providing-access-to-directories).

## Native self-check

From the Musaic app root, run on an emulator/simulator or a test device:

```sh
mise exec -- flutter run -d DEVICE_ID -t packages/musaic_query/packages/musaic_query/test/native_directory_smoke.dart
```

It generates a temporary WAV and cover, exercises native metadata, recursive and
nonrecursive enumeration, symlink exclusion, cancellation, cache bounds and cleanup,
and prints `MUSAIC_DIRECTORY_SMOKE_PASS`. This does not exercise the OS directory
picker or external provider grants. Relaunch the ordinary app entry point afterward.

## Failure and cache guarantees

A page can contain both usable entries and `error`: process the entries, mark that
range incomplete, and never confirm deletion from that scan. Native enumerators
continue after per-entry failures; Android rejects both `EXTRA_LOADING` and
`EXTRA_ERROR` provider cursors rather than reporting them as empty directories.
Directory names ending in an audio/image extension are still directories, not files.

Native artwork requests re-read lightweight audio/cover stamps before cache lookup
and check them again before committing output. Deleted folder covers cannot return
a previous cache hit. iOS clears URL resource-value caches before those checks.
Unreliable stamps use a fresh output path, and clearing caches changes the output
namespace, so Flutter's decoded-image cache cannot retain an old image under the
same filename. These extra stamp reads are intentional; no audio content hash or
full tag read is needed for a reliable cache hit. Embedded artwork that cannot be
decoded falls back to the directory cover.

The legacy Android `queryFromFolder` entry point queries MediaStore with a bound
folder predicate; it is not a replacement for SAF enumeration.
On iOS, `querySongs(path: ...)` rejects directory filters. Use
`MusaicQuery().directories` to enumerate a folder granted by the document picker.

References: [Android cursor errors](https://developer.android.com/reference/android/provider/DocumentsContract#EXTRA_ERROR),
[Apple URL resource cache](https://developer.apple.com/documentation/foundation/url/removeallcachedresourcevalues()).

System text filtering treats `%` and `_` as literal search characters, matching
iOS/Web contains semantics. Filter enum/type mismatches fail before native calls.

The native 128-entry page budget counts skipped symbolic links and failed entries
as well as returned entries; a directory full of links cannot consume the whole
traversal in one page. Android API <26 still materializes one directory using
File.listFiles, as documented above.
