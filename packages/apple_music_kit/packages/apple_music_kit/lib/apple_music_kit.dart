/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
///
/// Apple MusicKit for Flutter: authorization, catalog, library and playback
/// on iOS, Android and Web.
library;

export 'package:apple_music_kit_platform_interface/apple_music_kit_platform_interface.dart'
    show
        CachingDeveloperTokenProvider,
        DeveloperTokenProvider,
        MusicAuthorizationStatus,
        MusicAddToPlaylistResult,
        MusicAlbum,
        MusicAnimatedArtwork,
        MusicArtist,
        MusicArtwork,
        MusicCapabilities,
        MusicCapability,
        MusicCapabilityReason,
        MusicChart,
        MusicChartKind,
        MusicCreatedPlaylist,
        MusicItemRef,
        MusicItemSource,
        MusicKitErrorCode,
        MusicKitException,
        MusicKitPlatform,
        MusicKitPlatformConfig,
        MusicPage,
        MusicPlayerState,
        MusicPlayerStatus,
        MusicPlaylist,
        MusicQueue,
        MusicQueueEntry,
        MusicRepeatMode,
        MusicResourceType,
        MusicSearchResult,
        MusicShuffleMode,
        MusicSong,
        MusicStorefront,
        MusicSubscription,
        MusicSubscriptionStatus,
        StaticDeveloperTokenProvider;

export 'src/apple_music_client.dart';
export 'src/config/apple_music_config.dart';
export 'src/player/apple_music_player.dart';
export 'src/services/authorization_service.dart';
export 'src/services/capabilities_service.dart';
export 'src/services/catalog_service.dart';
export 'src/services/library_service.dart';
