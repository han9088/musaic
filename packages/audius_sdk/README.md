# audius_sdk

A pure Dart client for the Audius REST API, inspired by the official
@audius/sdk. The package follows the official SDK's resource-oriented API
shape while using Dart models and package:http. It has no Flutter UI dependency
and can be used by Flutter, Dart CLI, desktop and Web applications.

## Features

- Search tracks, users and playlists.
- Fetch tracks, users, playlists and creator catalogs.
- Fetch trending and underground-trending tracks.
- Fetch trending playlists and new releases.
- Resolve Audius canonical URLs.
- Build stream URLs with the request headers needed by an audio player.
- Typed track, user, artwork, playlist and resolved-resource models.
- Preserve unknown response fields in each model's raw map.
- Injectable HTTP client, configurable API base URL and request timeout.
- Structured HTTP errors, including status code and Retry-After.

## Installation

For this repository, add the local package to the host application's pubspec.yaml:

    dependencies:
      audius_sdk:
        path: packages/audius_sdk

## Quick start

Create an API Key from the Audius API Plans page:
https://api.audius.co/plans

Read-only endpoints may work without a key, but the key provides the documented
free-tier rate limit.

    import 'package:audius_sdk/audius_sdk.dart';

    Future<void> main() async {
      final audius = AudiusSdk(
        apiKey: const String.fromEnvironment('AUDIUS_API_KEY'),
      );

      try {
        final response = await audius.tracks.searchTracks(
          query: 'lofi',
          limit: 20,
          sortMethod: 'popular',
        );

        for (final track in response.data) {
          print(track.title + ' — ' + (track.user?.name ?? 'Unknown artist'));
          print(track.artwork?.best);
        }
      } finally {
        audius.close();
      }
    }

## Get a track and its stream

    final trackResponse = await audius.tracks.getTrack(trackId: 'D7KyD');
    final track = trackResponse.data;

    final stream = audius.tracks.getTrackStream(trackId: track.id);

    // Pass both values to the audio player. The stream endpoint may redirect
    // to an Audius audio node, so retain the headers when creating the source.
    final streamUri = stream.uri;
    final streamHeaders = stream.headers;

For an audio package that accepts URL headers, pass streamUri and streamHeaders
to its URL source. This SDK does not depend on or control the playback engine.

## Resource APIs

    final artist = await audius.users.getUserByHandle(handle: 'audius');
    final artistTracks = await audius.users.getTracksByUser(
      id: artist.data.id,
      limit: 30,
    );

    final playlist = await audius.playlists.getPlaylist(
      playlistId: 'PLAYLIST_ID',
    );
    final playlistTracks = await audius.playlists.getPlaylistTracks(
      playlistId: playlist.data.id,
    );

    final album = await audius.albums.getAlbum(albumId: 'ALBUM_ID');
    final resolved = await audius.resolve.resolveUrl(
      url: Uri.parse('https://audius.co/artist/track-slug'),
    );

Audius models albums as playlists with is_album: true. The albums namespace is
a semantic convenience over the official playlist and user endpoints; it does
not invent a separate Album REST resource.

## Authentication and security

- apiKey is sent as the x-api-key header. Audius documents API Keys as safe for
  frontend/mobile use.
- This package deliberately does not accept an API Secret or server Bearer
  Token. Audius documents Bearer Tokens as backend-only credentials.
- Do not embed an API Secret or a server Bearer Token in a Flutter, desktop or
  Web application.
- Supply a custom baseUrl only when intentionally using an Audius API
  deployment or discovery provider.

## Scope

This first version implements the read-only functionality needed by a music
client: catalog discovery, metadata, playlists/albums, URL resolution and
stream URL construction.

The official JavaScript SDK also exposes uploads, OAuth and account mutations
such as favorites, reposts and follows. Those are intentionally not included
yet: uploads require a separate upload workflow, while user actions require a
proper OAuth/PKCE integration and secure token lifecycle. They should not be
implemented by placing a server credential in a client app.

## Errors and HTTP client ownership

Non-2xx responses throw AudiusApiException, which exposes:

- statusCode
- message
- requestUri
- responseBody
- retryAfter (when supplied by Audius)

You can inject an http.Client for testing or custom networking:

    import 'package:http/http.dart' as http;

    final client = http.Client();
    final audius = AudiusSdk(
      apiKey: 'YOUR_PUBLIC_API_KEY',
      httpClient: client,
    );

    try {
      // Use audius...
    } finally {
      audius.close(); // Does not close an injected client.
      client.close();
    }

## Validation

Run from this package directory:

    dart format .
    dart analyze
    dart test

## Official references

- Audius JavaScript SDK: https://docs.audius.co/sdk/
- Audius REST API reference: https://docs.audius.co/api/
- Audius API plans: https://api.audius.co/plans
