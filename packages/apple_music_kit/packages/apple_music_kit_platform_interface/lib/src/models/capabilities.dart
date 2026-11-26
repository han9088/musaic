/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

/// Why a capability is (or is not) available right now.
enum MusicCapabilityReason {
  /// The feature is supported and currently usable.
  available,

  /// The platform implementation structurally lacks this feature.
  unsupportedOnPlatform,

  /// The OS/browser version is too old for this feature.
  requiresNewerSystem,

  /// The official SDK needed for this feature is missing (e.g. the Apple
  /// Android MusicKit AARs were not provisioned).
  sdkMissing,

  /// The feature requires user authorization that has not been granted.
  authorizationRequired,

  /// The feature requires an active Apple Music subscription.
  subscriptionRequired,

  /// The user disabled this capability at the OS level.
  restrictedBySystem;

  /// Deserializes from transport.
  static MusicCapabilityReason fromName(String? name) => switch (name) {
        'unsupportedOnPlatform' => MusicCapabilityReason.unsupportedOnPlatform,
        'requiresNewerSystem' => requiresNewerSystem,
        'sdkMissing' => MusicCapabilityReason.sdkMissing,
        'authorizationRequired' => MusicCapabilityReason.authorizationRequired,
        'subscriptionRequired' => MusicCapabilityReason.subscriptionRequired,
        'restrictedBySystem' => MusicCapabilityReason.restrictedBySystem,
        _ => MusicCapabilityReason.available,
      };

  /// Serializes for transport.
  String get name => switch (this) {
        available => 'available',
        unsupportedOnPlatform => 'unsupportedOnPlatform',
        requiresNewerSystem => 'requiresNewerSystem',
        sdkMissing => 'sdkMissing',
        authorizationRequired => 'authorizationRequired',
        subscriptionRequired => 'subscriptionRequired',
        restrictedBySystem => 'restrictedBySystem',
      };
}

/// The availability of a single capability.
final class MusicCapability {
  /// Creates a capability descriptor.
  const MusicCapability(
      {required this.supported,
      this.reason = MusicCapabilityReason.available,
      this.detail});

  /// A supported capability.
  const MusicCapability.supported() : this(supported: true);

  /// An unsupported capability with a reason.
  const MusicCapability.unsupported(this.reason, {this.detail})
      : supported = false;

  /// Whether the feature is supported **and** currently usable.
  final bool supported;

  /// Why the capability is unavailable.
  final MusicCapabilityReason reason;

  /// Optional human-readable extra context.
  final String? detail;

  /// Deserializes from transport.
  static MusicCapability fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MusicCapability.supported();
    return MusicCapability(
      supported: json['supported'] as bool? ?? false,
      reason: MusicCapabilityReason.fromName(json['reason'] as String?),
      detail: json['detail'] as String?,
    );
  }

  /// Serializes for transport.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'supported': supported,
        'reason': reason.name,
        if (detail != null) 'detail': detail,
      };

  @override
  String toString() => supported
      ? 'supported'
      : 'unsupported($reason${detail == null ? '' : ', $detail'})';
}

/// Aggregate capability snapshot for the current platform and state.
final class MusicCapabilities {
  /// Creates a capabilities snapshot.
  const MusicCapabilities({
    required this.canPlayCatalog,
    required this.canAccessLibrary,
    required this.canSeek,
    required this.canSetQueue,
    required this.canEditQueue,
    required this.canShuffle,
    required this.canRepeat,
    required this.canControlVolume,
    required this.canPlayInBackground,
    required this.canCreatePlaylist,
  });

  /// Deserializes from transport.
  factory MusicCapabilities.fromJson(Map<String, dynamic> json) =>
      MusicCapabilities(
        canPlayCatalog: MusicCapability.fromJson(
            json['canPlayCatalog'] as Map<String, dynamic>?),
        canAccessLibrary: MusicCapability.fromJson(
            json['canAccessLibrary'] as Map<String, dynamic>?),
        canSeek:
            MusicCapability.fromJson(json['canSeek'] as Map<String, dynamic>?),
        canSetQueue: MusicCapability.fromJson(
            json['canSetQueue'] as Map<String, dynamic>?),
        canEditQueue: MusicCapability.fromJson(
            json['canEditQueue'] as Map<String, dynamic>?),
        canShuffle: MusicCapability.fromJson(
            json['canShuffle'] as Map<String, dynamic>?),
        canRepeat: MusicCapability.fromJson(
            json['canRepeat'] as Map<String, dynamic>?),
        canControlVolume: MusicCapability.fromJson(
            json['canControlVolume'] as Map<String, dynamic>?),
        canPlayInBackground: MusicCapability.fromJson(
            json['canPlayInBackground'] as Map<String, dynamic>?),
        canCreatePlaylist: MusicCapability.fromJson(
            json['canCreatePlaylist'] as Map<String, dynamic>?),
      );

  /// Whether catalog playback is possible.
  final MusicCapability canPlayCatalog;

  /// Whether the user's library is accessible (needs authorization).
  final MusicCapability canAccessLibrary;

  /// Whether seek works.
  final MusicCapability canSeek;

  /// Whether queues can be set.
  final MusicCapability canSetQueue;

  /// Whether queue editing (append/insert/remove/move) is supported.
  final MusicCapability canEditQueue;

  /// Whether shuffle is supported.
  final MusicCapability canShuffle;

  /// Whether repeat modes are supported.
  final MusicCapability canRepeat;

  /// Whether programmatic volume control is supported.
  final MusicCapability canControlVolume;

  /// Whether playback continues in the background.
  final MusicCapability canPlayInBackground;

  /// Whether playlists can be created in the user's library.
  final MusicCapability canCreatePlaylist;

  /// Serializes for transport.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'canPlayCatalog': canPlayCatalog.toJson(),
        'canAccessLibrary': canAccessLibrary.toJson(),
        'canSeek': canSeek.toJson(),
        'canSetQueue': canSetQueue.toJson(),
        'canEditQueue': canEditQueue.toJson(),
        'canShuffle': canShuffle.toJson(),
        'canRepeat': canRepeat.toJson(),
        'canControlVolume': canControlVolume.toJson(),
        'canPlayInBackground': canPlayInBackground.toJson(),
        'canCreatePlaylist': canCreatePlaylist.toJson(),
      };
}
