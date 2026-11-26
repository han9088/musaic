/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../errors/music_kit_error.dart';
import '../models/animated_artwork.dart';
import '../models/capabilities.dart';
import '../models/charts.dart';
import '../models/library_models.dart';
import '../models/music_item_ref.dart';
import '../models/page.dart';
import '../models/player_state.dart';
import '../models/queue.dart';
import '../models/resource_models.dart';
import '../models/subscription.dart';
import '../tokens/developer_token_provider.dart';

export '../tokens/developer_token_provider.dart';

/// The interface every apple_music_kit platform implements.
///
/// End-users consume [AppleMusicClient] from `apple_music_kit`; platform
/// packages subclass [MusicKitPlatform] and register with
/// [MusicKitPlatform.instance]. The default instance throws
/// [UnimplementedError] with actionable guidance until a platform package
/// registers itself (or the bundled mock is installed).
abstract class MusicKitPlatform extends PlatformInterface {
  /// Constructs a platform interface.
  MusicKitPlatform() : super(token: _token);

  static final Object _token = Object();

  static MusicKitPlatform _instance = _UnimplementedMusicKitPlatform();

  /// The registered platform implementation.
  static MusicKitPlatform get instance => _instance;

  /// Sets the platform implementation. Called by `apple_music_kit_ios`,
  /// `apple_music_kit_android`, `apple_music_kit_web`, or the mock.
  static set instance(MusicKitPlatform value) {
    PlatformInterface.verifyToken(value, _token);
    _instance = value;
  }

  // ---------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------

  /// Initializes the platform SDK.
  ///
  /// Must be idempotent. [config] carries app metadata and the developer
  /// token provider. Throws [MusicKitException] with
  /// `developerTokenMissing` when no token can be obtained and the platform
  /// requires one.
  Future<void> initialize(MusicKitPlatformConfig config) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Releases platform resources. Must be idempotent and must not stop
  /// shared playback unless [stopPlayback] is true.
  Future<void> dispose({bool stopPlayback = false}) {
    throw UnimplementedError('dispose() has not been implemented.');
  }

  // ---------------------------------------------------------------
  // Authorization & subscription
  // ---------------------------------------------------------------

  /// Current authorization status without prompting.
  Future<MusicAuthorizationStatus> getAuthorizationStatus() {
    throw UnimplementedError(
        'getAuthorizationStatus() has not been implemented.');
  }

  /// Prompts the user for Apple Music access when needed and returns the
  /// resulting status.
  Future<MusicAuthorizationStatus> requestAuthorization() {
    throw UnimplementedError(
        'requestAuthorization() has not been implemented.');
  }

  /// A stream of authorization status changes, starting with the current
  /// status.
  Stream<MusicAuthorizationStatus> get onAuthorizationChanged {
    throw UnimplementedError(
        'onAuthorizationChanged has not been implemented.');
  }

  /// The user's Apple Music subscription snapshot.
  Future<MusicSubscription> getSubscription() {
    throw UnimplementedError('getSubscription() has not been implemented.');
  }

  // ---------------------------------------------------------------
  // Capabilities
  // ---------------------------------------------------------------

  /// Capability snapshot for the current platform, SDK availability,
  /// authorization and subscription state.
  Future<MusicCapabilities> getCapabilities() {
    throw UnimplementedError('getCapabilities() has not been implemented.');
  }

  // ---------------------------------------------------------------
  // Catalog / Library API
  // ---------------------------------------------------------------

  /// Searches the storefront catalog.
  Future<MusicSearchResult> searchCatalog(
    String term, {
    Set<MusicResourceType> types = const {
      MusicResourceType.song,
      MusicResourceType.album,
      MusicResourceType.artist,
      MusicResourceType.playlist
    },
    int limit = 25,
    String? storefront,
  }) {
    throw UnimplementedError('searchCatalog() has not been implemented.');
  }

  /// Fetches animated variants on demand, using a catalog ID and storefront.
  /// Platforms without this implementation must fail explicitly.
  Future<List<MusicAnimatedArtwork>> getAlbumAnimatedArtwork(String id,
      {required String storefront}) {
    throw const MusicKitException(MusicKitErrorCode.unsupportedFeature,
        message: 'Animated album artwork is not implemented on this platform.');
  }

  /// Fetches one catalog song.
  Future<MusicSong> getCatalogSong(String id, {String? storefront}) {
    throw UnimplementedError('getCatalogSong() has not been implemented.');
  }

  /// Fetches one catalog album, optionally including its tracks.
  Future<MusicAlbum> getCatalogAlbum(String id,
      {String? storefront, bool includeTracks = false}) {
    throw UnimplementedError('getCatalogAlbum() has not been implemented.');
  }

  /// Fetches one catalog artist.
  Future<MusicArtist> getCatalogArtist(String id, {String? storefront}) {
    throw UnimplementedError('getCatalogArtist() has not been implemented.');
  }

  /// Fetches one catalog playlist, optionally including its tracks.
  Future<MusicPlaylist> getCatalogPlaylist(String id,
      {String? storefront, bool includeTracks = false}) {
    throw UnimplementedError('getCatalogPlaylist() has not been implemented.');
  }

  /// Fetches storefront charts.
  Future<List<MusicChart>> getCharts(MusicChartKind kind,
      {String? storefront, int limit = 20}) {
    throw UnimplementedError('getCharts() has not been implemented.');
  }

  /// Resolves the user's current storefront.
  Future<MusicStorefront> getCurrentStorefront() {
    throw UnimplementedError(
        'getCurrentStorefront() has not been implemented.');
  }

  /// Lists library songs.
  Future<MusicPage<MusicSong>> getLibrarySongs({int limit = 25, int? offset}) {
    throw UnimplementedError('getLibrarySongs() has not been implemented.');
  }

  /// Lists library albums.
  Future<MusicPage<MusicAlbum>> getLibraryAlbums(
      {int limit = 25, int? offset}) {
    throw UnimplementedError('getLibraryAlbums() has not been implemented.');
  }

  /// Lists library playlists.
  Future<MusicPage<MusicPlaylist>> getLibraryPlaylists(
      {int limit = 25, int? offset}) {
    throw UnimplementedError('getLibraryPlaylists() has not been implemented.');
  }

  /// Searches the user's library.
  Future<MusicSearchResult> searchLibrary(String term,
      {Set<MusicResourceType> types = const {MusicResourceType.song},
      int limit = 25}) {
    throw UnimplementedError('searchLibrary() has not been implemented.');
  }

  /// Adds catalog songs to the user's library ("Add to Library").
  Future<void> addToLibrary(List<MusicItemRef> songs) {
    throw UnimplementedError('addToLibrary() has not been implemented.');
  }

  /// Creates a playlist in the user's library.
  Future<MusicCreatedPlaylist> createPlaylist(String name,
      {String? description, List<MusicItemRef>? tracks}) {
    throw UnimplementedError('createPlaylist() has not been implemented.');
  }

  /// Appends tracks to a library playlist.
  Future<MusicAddToPlaylistResult> addToPlaylist(
      String playlistLibraryId, List<MusicItemRef> tracks) {
    throw UnimplementedError('addToPlaylist() has not been implemented.');
  }

  // ---------------------------------------------------------------
  // Player
  // ---------------------------------------------------------------

  /// Sets the player queue and (optionally) starts playback at [startIndex].
  Future<void> setQueue(List<MusicItemRef> items,
      {int startIndex = 0, bool autoplay = true}) {
    throw UnimplementedError('setQueue() has not been implemented.');
  }

  /// Begins or resumes playback.
  Future<void> play() {
    throw UnimplementedError('play() has not been implemented.');
  }

  /// Pauses playback, keeping position.
  Future<void> pause() {
    throw UnimplementedError('pause() has not been implemented.');
  }

  /// Stops playback and clears position (queue may be retained).
  Future<void> stop() {
    throw UnimplementedError('stop() has not been implemented.');
  }

  /// Toggles play/pause.
  Future<void> togglePlayPause() {
    throw UnimplementedError('togglePlayPause() has not been implemented.');
  }

  /// Seeks within the current item.
  Future<void> seekTo(Duration position) {
    throw UnimplementedError('seekTo() has not been implemented.');
  }

  /// Skips to the next queue item.
  Future<void> skipToNext() {
    throw UnimplementedError('skipToNext() has not been implemented.');
  }

  /// Skips to the previous queue item (restarts the item when early in it,
  /// per platform behavior).
  Future<void> skipToPrevious() {
    throw UnimplementedError('skipToPrevious() has not been implemented.');
  }

  /// The current queue snapshot.
  Future<MusicQueue> getQueue() {
    throw UnimplementedError('getQueue() has not been implemented.');
  }

  /// Appends [items] to the end of the queue. Throws
  /// `MusicKitException(unsupportedFeature)` where queue editing is not
  /// supported.
  Future<void> appendToQueue(List<MusicItemRef> items) {
    throw UnimplementedError('appendToQueue() has not been implemented.');
  }

  /// Removes the queue entry at [index].
  Future<void> removeFromQueue(int index) {
    throw UnimplementedError('removeFromQueue() has not been implemented.');
  }

  /// Sets shuffle mode.
  Future<void> setShuffleMode(MusicShuffleMode mode) {
    throw UnimplementedError('setShuffleMode() has not been implemented.');
  }

  /// Sets repeat mode.
  Future<void> setRepeatMode(MusicRepeatMode mode) {
    throw UnimplementedError('setRepeatMode() has not been implemented.');
  }

  /// A broadcast stream of player state snapshots.
  ///
  /// Implementations must: emit the last known state to new subscribers,
  /// never emit after dispose, deduplicate identical consecutive states,
  /// and serialize events so ordering is guaranteed.
  Stream<MusicPlayerState> get playerStates {
    throw UnimplementedError('playerStates has not been implemented.');
  }
}

/// Platform-agnostic initialization configuration.
///
/// [developerTokenProvider] may be null on iOS where MusicKit manages the
/// developer token automatically.
@immutable
final class MusicKitPlatformConfig {
  /// Creates the config.
  const MusicKitPlatformConfig({
    this.appName,
    this.appBuild,
    this.developerTokenProvider,
  });

  /// Display name used in attribution headers where applicable.
  final String? appName;

  /// App build/version string.
  final String? appBuild;

  /// Source of developer tokens; null lets iOS MusicKit manage tokens
  /// automatically and makes Web/Android fail fast at initialize.
  final DeveloperTokenProvider? developerTokenProvider;
}

/// Thrown-by-default instance used until a real platform registers.
final class _UnimplementedMusicKitPlatform extends MusicKitPlatform {
  Never _fail(String method) => throw MusicKitException(
        MusicKitErrorCode.platformUnavailable,
        message: '$method is not available. No apple_music_kit platform '
            'implementation is registered for this build. Add the '
            'apple_music_kit_ios / _android / _web / _desktop dependency matching your '
            'target, or install the mock via installMusicKitMock().',
        platform: 'none',
      );

  @override
  Future<void> initialize(MusicKitPlatformConfig config) async =>
      _fail('initialize');

  @override
  Future<MusicAuthorizationStatus> getAuthorizationStatus() async =>
      _fail('getAuthorizationStatus');

  @override
  Future<MusicAuthorizationStatus> requestAuthorization() async =>
      _fail('requestAuthorization');

  @override
  Stream<MusicAuthorizationStatus> get onAuthorizationChanged =>
      _fail('onAuthorizationChanged');

  @override
  Future<MusicSubscription> getSubscription() async => _fail('getSubscription');

  @override
  Future<MusicCapabilities> getCapabilities() async => _fail('getCapabilities');

  @override
  Future<MusicSearchResult> searchCatalog(String term,
      {Set<MusicResourceType> types = const {
        MusicResourceType.song,
        MusicResourceType.album,
        MusicResourceType.artist,
        MusicResourceType.playlist
      },
      int limit = 25,
      String? storefront}) async {
    _fail('searchCatalog');
  }

  @override
  Future<MusicSong> getCatalogSong(String id, {String? storefront}) async =>
      _fail('getCatalogSong');

  @override
  Future<MusicAlbum> getCatalogAlbum(String id,
          {String? storefront, bool includeTracks = false}) async =>
      _fail('getCatalogAlbum');

  @override
  Future<MusicArtist> getCatalogArtist(String id, {String? storefront}) async =>
      _fail('getCatalogArtist');

  @override
  Future<MusicPlaylist> getCatalogPlaylist(String id,
          {String? storefront, bool includeTracks = false}) async =>
      _fail('getCatalogPlaylist');

  @override
  Future<List<MusicChart>> getCharts(MusicChartKind kind,
          {String? storefront, int limit = 20}) async =>
      _fail('getCharts');

  @override
  Future<MusicStorefront> getCurrentStorefront() async =>
      _fail('getCurrentStorefront');

  @override
  Future<MusicPage<MusicSong>> getLibrarySongs(
          {int limit = 25, int? offset}) async =>
      _fail('getLibrarySongs');

  @override
  Future<MusicPage<MusicAlbum>> getLibraryAlbums(
          {int limit = 25, int? offset}) async =>
      _fail('getLibraryAlbums');

  @override
  Future<MusicPage<MusicPlaylist>> getLibraryPlaylists(
          {int limit = 25, int? offset}) async =>
      _fail('getLibraryPlaylists');

  @override
  Future<MusicSearchResult> searchLibrary(String term,
      {Set<MusicResourceType> types = const {MusicResourceType.song},
      int limit = 25}) async {
    _fail('searchLibrary');
  }

  @override
  Future<void> addToLibrary(List<MusicItemRef> songs) async =>
      _fail('addToLibrary');

  @override
  Future<MusicCreatedPlaylist> createPlaylist(String name,
      {String? description, List<MusicItemRef>? tracks}) async {
    _fail('createPlaylist');
  }

  @override
  Future<MusicAddToPlaylistResult> addToPlaylist(
          String playlistLibraryId, List<MusicItemRef> tracks) async =>
      _fail('addToPlaylist');

  @override
  Future<void> setQueue(List<MusicItemRef> items,
          {int startIndex = 0, bool autoplay = true}) async =>
      _fail('setQueue');

  @override
  Future<void> play() async => _fail('play');

  @override
  Future<void> pause() async => _fail('pause');

  @override
  Future<void> stop() async => _fail('stop');

  @override
  Future<void> togglePlayPause() async => _fail('togglePlayPause');

  @override
  Future<void> seekTo(Duration position) async => _fail('seekTo');

  @override
  Future<void> skipToNext() async => _fail('skipToNext');

  @override
  Future<void> skipToPrevious() async => _fail('skipToPrevious');

  @override
  Future<MusicQueue> getQueue() async => _fail('getQueue');

  @override
  Future<void> appendToQueue(List<MusicItemRef> items) async =>
      _fail('appendToQueue');

  @override
  Future<void> removeFromQueue(int index) async => _fail('removeFromQueue');

  @override
  Future<void> setShuffleMode(MusicShuffleMode mode) async =>
      _fail('setShuffleMode');

  @override
  Future<void> setRepeatMode(MusicRepeatMode mode) async =>
      _fail('setRepeatMode');

  @override
  Stream<MusicPlayerState> get playerStates => _fail('playerStates');
}
