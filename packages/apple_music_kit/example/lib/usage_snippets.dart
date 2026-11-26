/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
///
/// Compiled usage snippets — every code block in docs/usage.md and
/// docs/usage.zh-CN.md lives here so `dart analyze` proves the
/// documentation examples actually compile against the current API.
library;

import 'dart:async';

import 'package:apple_music_kit/apple_music_kit.dart';
import 'package:apple_music_kit/mock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// 1. Creating and initializing the client
// ---------------------------------------------------------------------------

Future<void> createClient() async {
  final music = AppleMusicClient(
    config: AppleMusicConfig(
      appName: 'My Music',
      appBuild: '1.0.0',
      // Required on Android and Web. On iOS, omit it and MusicKit
      // manages tokens automatically.
      developerTokenProvider: _ServerTokenProvider(),
    ),
  );

  // Idempotent; concurrent calls share one initialization.
  await music.initialize();

  // ... use it ...

  // Releases Dart listeners. Does NOT stop shared native playback unless
  // asked to.
  await music.dispose();
}

Future<String> fetchDeveloperTokenFromMyServer() async => throw UnimplementedError();

// ---------------------------------------------------------------------------
// 2. Token provider with caching + single-flight
// ---------------------------------------------------------------------------

Future<void> tokenProviderUsage() async {
  final provider = CachingDeveloperTokenProvider(
    delegate: _ServerTokenProvider(),
    leadTime: const Duration(minutes: 5), // refresh 5 min before exp
    fallbackTtl: const Duration(minutes: 30), // when exp is unparseable
  );

  final music = AppleMusicClient(
    config: AppleMusicConfig(developerTokenProvider: provider),
  );
  await music.initialize();

  // Force a refetch on the next getToken (e.g. after a 401).
  provider.invalidate();
}

final class _ServerTokenProvider implements DeveloperTokenProvider {
  @override
  Future<String> getToken() async => fetchDeveloperTokenFromMyServer();
}

// ---------------------------------------------------------------------------
// 3. Authorization and subscription
// ---------------------------------------------------------------------------

Future<void> authorizationUsage(AppleMusicClient music) async {
  // Current status without prompting.
  final status = await music.authorization.getStatus();
  debugPrint('status: ${status.name}');

  // Prompt the user (system sheet on iOS; browser flow on Web — must be
  // triggered by a real user gesture).
  final result = await music.authorization.request();
  debugPrint('request -> ${result.name}');

  // Observe changes (stream starts with the current status).
  final sub = music.authorization.statusChanges.listen((s) {
    debugPrint('auth: ${s.name}');
  });

  // Subscription is independent of authorization.
  final subscription = await music.subscription.status;
  if (subscription.status == MusicSubscriptionStatus.subscribed) {
    debugPrint('canPlayCatalogContent: ${subscription.canPlayCatalogContent}');
  }

  await sub.cancel();
}

// ---------------------------------------------------------------------------
// 4. Catalog: search, fetch, charts, storefront
// ---------------------------------------------------------------------------

Future<void> catalogUsage(AppleMusicClient music) async {
  // Search — each requested type gets its own page.
  final result = await music.catalog.search(
    'Taylor Swift',
    types: {MusicResourceType.song, MusicResourceType.album},
    limit: 25,
    storefront: 'us', // optional; defaults to the user's storefront
  );
  final songs = result.songs?.items ?? const <MusicSong>[];
  final albums = result.albums?.items ?? const <MusicAlbum>[];
  debugPrint('found ${songs.length} songs, ${albums.length} albums');

  // Fetch a single resource.
  final song = await music.catalog.getSong('1440843637');
  final album = await music.catalog.getAlbum(albums.first.id, includeTracks: true);
  final artist = await music.catalog.getArtist(song.artistId ?? '');
  final playlist = await music.catalog.getPlaylist('pl.1234');
  debugPrint('${song.title} / ${album.title} / ${artist.name} / ${playlist.name}');

  // Charts.
  final charts = await music.catalog.getCharts(MusicChartKind.songs, limit: 20);
  final topSongs = charts.first.songs?.items ?? const <MusicSong>[];
  debugPrint('top songs: ${topSongs.length}');

  // Storefront (catalog ids are storefront-scoped!).
  final storefront = await music.catalog.getCurrentStorefront();
  debugPrint('storefront: ${storefront.id}');
}

// ---------------------------------------------------------------------------
// 5. Pagination
// ---------------------------------------------------------------------------

Future<void> paginationUsage(AppleMusicClient music) async {
  var page = await music.library.getSongs(limit: 50);
  final all = [...page.items];
  while (page.hasMore) {
    page = await music.library.getSongs(limit: 50, offset: page.nextOffset);
    all.addAll(page.items);
  }
}

// ---------------------------------------------------------------------------
// 6. Library: list, search, add, playlists
// ---------------------------------------------------------------------------

Future<void> libraryUsage(AppleMusicClient music) async {
  // Requires authorization; otherwise throws
  // MusicKitException(authorizationDenied).
  final songs = await music.library.getSongs(limit: 25);
  final albums = await music.library.getAlbums();
  final playlists = await music.library.getPlaylists();
  debugPrint('${songs.items.length} songs, ${albums.items.length} albums, '
      '${playlists.items.length} playlists');

  // Search the user's library.
  final found = await music.library.search(
    'road trip',
    types: {MusicResourceType.song, MusicResourceType.playlist},
  );
  debugPrint('library search: ${found.songs?.items.length ?? 0} songs');

  // Add catalog songs to the user's library.
  await music.library.addSongs([
    const MusicItemRef(id: '1440843637', type: MusicResourceType.song),
  ]);

  // Create a playlist (optionally seeded with tracks).
  final created = await music.library.createPlaylist(
    'Road Trip',
    description: 'Highway anthems',
    tracks: songs.items.take(5).map((s) => s.ref).toList(),
  );

  // Append tracks to an existing library playlist.
  await music.library.addToPlaylist(created.id, [
    const MusicItemRef(id: '1440843638', type: MusicResourceType.song),
  ]);
}

// ---------------------------------------------------------------------------
// 7. Player: queue, transport, modes
// ---------------------------------------------------------------------------

Future<void> playerUsage(AppleMusicClient music) async {
  final player = music.player;

  // Replace the queue and start playing.
  await player.setQueue([
    const MusicItemRef(id: '1440843637', type: MusicResourceType.song),
    const MusicItemRef(id: '1440843638', type: MusicResourceType.song),
  ], startIndex: 0, autoplay: true);

  // Or play a single item.
  await player.playItem(
    const MusicItemRef(id: '1440843637', type: MusicResourceType.song),
  );

  // Transport.
  await player.pause();
  await player.play();
  await player.togglePlayPause();
  await player.seekTo(const Duration(seconds: 42));
  await player.skipToNext();
  await player.skipToPrevious();
  await player.stop();

  // Queue editing (throws unsupportedFeature where unavailable).
  await player.append([
    const MusicItemRef(id: '1440843639', type: MusicResourceType.song),
  ]);
  await player.removeAt(0);
  final queue = await player.getQueue();
  debugPrint('queue length: ${queue.length}, current: ${queue.currentIndex}');

  // Modes.
  await player.setShuffleMode(MusicShuffleMode.on);
  await player.setRepeatMode(MusicRepeatMode.one);
}

// ---------------------------------------------------------------------------
// 8. Player state stream
// ---------------------------------------------------------------------------

StreamSubscription<MusicPlayerState>? stateSub;

void stateUsage(AppleMusicClient music) {
  // Broadcast stream: new subscribers immediately receive the latest
  // snapshot; identical consecutive states are deduplicated; nothing is
  // emitted after dispose.
  stateSub = music.player.states.listen((state) {
    debugPrint('${state.status.name} '
        'item=${state.currentItem?.id} '
        'index=${state.currentIndex} '
        'pos=${state.position} dur=${state.duration} '
        'queue=${state.queueLength}');
    if (state.isPlaying) {
      // update progress bar
    }
  });

  // One-off read without subscribing.
  final now = music.player.currentState;

  // In widgets, prefer a StreamBuilder:
  // StreamBuilder<MusicPlayerState>(
  //   stream: music.player.states,
  //   initialData: music.player.currentState,
  //   builder: (context, snapshot) { ... },
  // )
  debugPrint('$now');
}

// ---------------------------------------------------------------------------
// 9. Capabilities
// ---------------------------------------------------------------------------

Future<void> capabilitiesUsage(AppleMusicClient music) async {
  final caps = await music.capabilities.get();

  if (caps.canSeek.supported) {
    await music.player.seekTo(const Duration(seconds: 10));
  } else {
    // Distinguish "why": unsupportedOnPlatform / sdkMissing /
    // authorizationRequired / subscriptionRequired / restrictedBySystem.
    debugPrint('seek unavailable: ${caps.canSeek.reason.name}');
    debugPrint(caps.canSeek.detail ?? '');
  }

  // Disable UI accordingly, e.g.:
  // seekButton.enabled = caps.canSeek.supported;
}

// ---------------------------------------------------------------------------
// 10. Error handling
// ---------------------------------------------------------------------------

Future<void> errorHandlingUsage(AppleMusicClient music) async {
  try {
    await music.player.play();
  } on MusicKitException catch (e) {
    switch (e.code) {
      case MusicKitErrorCode.authorizationDenied:
        // Guide the user to Settings; re-prompting won't help.
        break;
      case MusicKitErrorCode.subscriptionRequired:
        // Offer upsell; previews may still be playable.
        break;
      case MusicKitErrorCode.sdkUnavailable:
        // Android without provisioned Apple AARs — show setup guidance.
        debugPrint(e.message);
        break;
      case MusicKitErrorCode.rateLimited:
        final wait = e.retryAfter;
        debugPrint('retry after $wait');
        break;
      default:
        debugPrint('${e.code}: ${e.message}');
    }
    // User-presentable text for snackbars/dialogs:
    debugPrint(e.userMessage);
  }
}

// ---------------------------------------------------------------------------
// 11. Item refs and artwork
// ---------------------------------------------------------------------------

void refsAndArtworkUsage(MusicSong song) {
  // Refs are the lightweight way to address resources.
  final ref = song.ref; // carries id + type + source + storefront
  final fromUrl = MusicItemRef.fromUrl(
    'https://api.music.apple.com/v1/catalog/us/songs/1440843637',
  );

  // Catalog vs library ids are NOT interchangeable:
  const catalogRef = MusicItemRef(
    id: '1440843637',
    type: MusicResourceType.song,
    source: MusicItemSource.catalog,
  );
  const libraryRef = MusicItemRef(
    id: 'i.abc123',
    type: MusicResourceType.song,
    source: MusicItemSource.library,
  );

  // Artwork: build concrete URLs from the {w}x{h} template.
  final art = song.artwork;
  final square = art?.url(size: 300); // 300x300
  final fitted = art?.urlFitted(maxWidth: 640, maxHeight: 320);

  debugPrint('$ref $fromUrl $catalogRef $libraryRef $square $fitted');
}

// ---------------------------------------------------------------------------
// 12. Mock mode (no Apple credentials)
// ---------------------------------------------------------------------------

void mockUsage() {
  // Debug/demo builds only. Loudly labeled; never a real MusicKit.
  installMusicKitMock();

  // Deny-mode variant for testing the denied-authorization UI:
  installMusicKitMock(autoGrantAuthorization: false);
}
