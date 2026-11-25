# Changelog

## Unreleased

- Encode repeated query parameters using Dart's supported URI API.
- Add paged album-specific search using the full search endpoint.
- Parse public stream access from track metadata.
- Accept single-resource responses wrapped in a one-element array.
- Resolve stream metadata via authenticated SDK requests for URL-only players.

## 0.1.0

- Add a pure Dart Audius REST API client.
- Add track, user, playlist, album convenience and URL resolver APIs.
- Add typed catalog models, stream request details and HTTP error handling.
- Add injectable HTTP client and unit tests.
