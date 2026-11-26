# Album animated artwork (experimental)

Fetch animated artwork only when the caller needs it. Search results and
`getAlbum` continue to return the same static artwork without extra requests.
This API returns metadata and original video URLs, not downloaded videos,
converted MP4 files, or a player.

```dart
// Use the same initialized AppleMusicClient and DeveloperTokenProvider.
final variants = await music.catalog.getAlbumAnimatedArtwork(
  '1234567890', // A catalog album ID, not a library album ID.
  storefront: 'us',
);
for (final variant in variants) {
  print(variant.type);     // e.g. motionDetailSquare or motionDetailTall
  print(variant.videoUrl); // Original HTTPS URL, normally an HLS master playlist.
  // All additional fields supplied by Apple are retained in variant.metadata.
}
```

The storefront is required, validated as a two-letter country code, and
normalized to lowercase. There is no automatic US fallback or account-region
lookup. Numeric catalog album IDs are required; library IDs such as `l.…` are
rejected with `ArgumentError` before any request. Resolve a library album's
catalog identity separately; this method does not guess it.

## Model and response semantics

`MusicAnimatedArtwork.type` preserves the exact `editorialVideo` key.
The source implementations examined use `motionDetailSquare.video` and
`motionDetailTall.video`; boidu also handles `motionSquareVideo1x1.video` and
`motionTallVideo3x4.video`. All returned variants with a valid video URL are
retained, including future variant names. No shape or quality is guessed from
an unknown name.

`metadata` is a recursively immutable copy of the variant object, including
`video` and any additional fields actually supplied by Apple. The reference
models do not establish a dependable preview-image or dimension schema, so
there are no invented preview/width/height properties or default dimensions.
Additional metadata is preserved verbatim rather than discarded. Static album
artwork remains available through the existing `MusicAlbum.artwork` API.
HLS resolution variants are not fetched or parsed; dimensions cannot be inferred
from a master playlist URL.

- A valid album response without `editorialVideo`, with an empty object, or
  without any `video` fields returns an empty list. Null optional fields are
  treated as absent.
- Missing albums (HTTP 404 or an empty `data` array) throw
  `MusicKitException(resourceNotFound)`, rather than claiming the album has no
  animation.
- Invalid response structures, invalid video URLs, and JSON parsing failures
  are errors. The shared model reports `MusicKitException(unknown)` with
  `details.reason = invalidResponse`; native JSON decoding errors use the
  existing platform error mapper.
- Authorization, network, timeout and rate-limit failures retain the platform's
  existing `MusicKitException` classification. iOS maps
  `MusicDataRequest.Error.status`, including failures thrown before a response
  is returned. Android and Web distinguish HTTP 408, 409/410, 429 and 5xx errors.
  Web response-decoding failures are classified separately from transport
  failures, and raw JS rejection descriptions are not included in messages.
  Missing native methods report `unsupportedFeature`; unstructured native error
  details do not replace the original error code with a type error.
  These failures are never converted into an
  empty list. Retry information is preserved when the existing transport
  supplies it; native transports do not currently expose all Retry-After data.
- Invalid caller IDs/storefronts throw `ArgumentError`. Calls through a client
  still require `initialize()` and fail after `dispose()`.

An empty list describes **this response**, not proof that an album has no
animation in every region or through every Apple endpoint. In particular, an
endpoint may omit an undocumented extension even when it returns HTTP 200.

## Request sharing and lifecycle

Within one `MusicCatalogService`, simultaneous calls for the same catalog ID
and normalized storefront share one request, including its failure. Different
storefronts remain independent. Entries are removed on success and failure;
completed results, empty results and errors are **not cached**. Each shared
request has a 30-second waiting deadline. A hung SDK promise therefore cannot
pin the request association forever: callers receive `requestTimeout` and can
retry. This deadline does not cancel the underlying platform operation; late
successes/errors are ignored and cannot remove a newer association. A retry may
overlap with that still-running operation. There is no
persistent cache, cache TTL, stale-result fallback, or video URL storage.

`music.catalog.clearAnimatedArtworkRequests()` clears pending associations.
It does not cancel requests already held by callers; a subsequent call starts
fresh work. An old completion cannot remove a newer request's association.
Client disposal also clears these associations and immediately rejects new
calls through that client. Already-started calls may still succeed or fail after
disposal, bounded by the same 30-second deadline; disposal does not wait for them
or guarantee transport cancellation.

## Platform paths and authorization

All implementations request the catalog album with `extend=editorialVideo`.
No code extracts tokens from Apple's website or contacts the reference projects'
services.

| Platform | Implementation | Limitations |
| --- | --- | --- |
| iOS | Existing `ApiRequest.get` and native `MusicDataRequest` to `api.music.apple.com/v1/catalog/{storefront}/albums/{id}?extend=editorialVideo` | Uses MusicKit's managed developer/user authorization, as existing native API requests do. The Dart DeveloperTokenProvider is not injected into native MusicDataRequest. |
| Android | Existing `AppleMusicApi` REST executor and error mapping, same `api.music.apple.com` path | Reuses the DeveloperTokenProvider token obtained at initialization. Existing token-refresh behavior is unchanged; an expired/rejected token remains an error. Builds without the Apple SDK fail with `sdkUnavailable`. |
| Web | Existing MusicKit JS `api.music` adapter and error mapping, relative `v1/catalog/{storefront}/albums/{id}?extend=editorialVideo` path | Reuses the instance configured from DeveloperTokenProvider. Actual endpoint behavior, browser restrictions and extension availability depend on MusicKit JS. |
| Other/custom implementations, including the bundled mock | Default platform method throws `unsupportedFeature` | No fabricated successful empty response. Custom implementations can override the method. |

The library does not request user authorization as part of this method. Existing
platform/account requirements still apply, and errors propagate to the caller.

## Evidence, licenses, and compatibility boundary

The following actual source files were inspected; implementation code was
written for this library rather than copied:

- **boidushya/artwork.boidu.dev**, commit
  `3aab2687301baa07b6bb62a23bfbec86898dba0f`:
  [`src/album.ts`](https://github.com/boidushya/artwork.boidu.dev/blob/3aab2687301baa07b6bb62a23bfbec86898dba0f/src/album.ts)
  (`fetchAlbum`, `extractAlbumData`), `src/types.ts`, `src/errors.ts`,
  `src/resultCache.ts`, and `src/m3u8.ts`. Confirms the album-ID path, square/tall
  alternatives, storefront-aware cache keys, transient-error distinction and
  downstream HLS resolution. Its multi-year positive cache TTL was not adopted.
  No project license file or package license declaration was found in the
  inspected snapshot; no code was copied.
- **m8tec/apple-music-animated-artworks**, commit
  `8df0f850e159448fc93229af83ab831754abfd2c`:
  [`Infrastructure/AppleMusicClient.cs`](https://github.com/m8tec/apple-music-animated-artworks/blob/8df0f850e159448fc93229af83ab831754abfd2c/apple-music-animated-artworks/Infrastructure/AppleMusicClient.cs)
  (`ParseAppleMusicPageAsync`), and
  [`wwwroot/app.js`](https://github.com/m8tec/apple-music-animated-artworks/blob/8df0f850e159448fc93229af83ab831754abfd2c/apple-music-animated-artworks/wwwroot/app.js)
  (`parseMasterVariants`). Cross-checks square/tall fields and HLS
  `RESOLUTION`/`BANDWIDTH` variants with relative URL resolution. No project
  license file was found in the inspected tree; no code was copied. Its token
  scraping, download and conversion paths were not adopted.
- **Cider 1**, archived, commit `953bb5a9e26080bba2bb20438f0ddf38b0a8b260`:
  [`src/renderer/main/vueapp.js`](https://github.com/ciderapp/Cider/blob/953bb5a9e26080bba2bb20438f0ddf38b0a8b260/src/renderer/main/vueapp.js)
  requests the extension for detail pages;
  [`animatedartwork-view.ejs`](https://github.com/ciderapp/Cider/blob/953bb5a9e26080bba2bb20438f0ddf38b0a8b260/src/renderer/views/components/animatedartwork-view.ejs)
  consumes the HLS URL, chooses quality at playback time, and destroys the HLS
  instance on teardown. Licensed AGPL-3.0; no code was copied. This is historical
  usage evidence, not validation of a current Apple API.

Apple's [resource representation documentation](https://developer.apple.com/documentation/applemusicapi/handling-resource-representation-and-relationships)
confirms the general `extend` mechanism, and its
[developer-token documentation](https://developer.apple.com/documentation/applemusicapi/generating-developer-tokens)
confirms Bearer authorization for the public API. Neither establishes a public
contract for these editorial-video fields. Both current reference fetchers use
`amp-api.music.apple.com` and web-token flows; that does **not** establish that
ordinary DeveloperTokenProvider tokens or native MusicDataRequest can retrieve
the same fields from `api.music.apple.com`. This implementation deliberately
reuses existing authentication and makes no fallback to scraped tokens.

**Not integration-verified:** extension availability on each platform, ordinary
developer-token compatibility, regional coverage, preview/dimension metadata,
URL expiry, and HLS usability. These undocumented fields may change or disappear.
No real Apple Music service or media URL was requested during implementation.
The local fixture tests cover parsing, absent/malformed fields, storefront
forwarding, errors, request sharing and cleanup, plus the Web request path.
Per task constraints, tests, analysis and builds were not run.
