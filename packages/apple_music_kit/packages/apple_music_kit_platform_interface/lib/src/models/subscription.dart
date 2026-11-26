/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

/// Apple Music user authorization status, mirroring
/// `MusicAuthorization.Status` on iOS and the SDK states on Android/Web.
enum MusicAuthorizationStatus {
  /// The user has not yet been asked (or made) a decision.
  notDetermined,

  /// The user granted access to Apple Music.
  authorized,

  /// The user explicitly denied access.
  ///
  /// Re-requesting shows system UI telling the user to change the setting;
  /// guide them to Settings rather than re-prompting.
  denied,

  /// Access is restricted, e.g. parental controls; requesting is pointless.
  restricted,

  /// Apple Music is unavailable on this device/account/region.
  unavailable;

  /// Deserializes from transport.
  static MusicAuthorizationStatus fromName(String? name) => switch (name) {
        'authorized' => MusicAuthorizationStatus.authorized,
        'denied' => MusicAuthorizationStatus.denied,
        'restricted' => MusicAuthorizationStatus.restricted,
        'unavailable' => MusicAuthorizationStatus.unavailable,
        _ => MusicAuthorizationStatus.notDetermined,
      };

  /// Serializes for transport.
  String get name => switch (this) {
        MusicAuthorizationStatus.notDetermined => 'notDetermined',
        MusicAuthorizationStatus.authorized => 'authorized',
        MusicAuthorizationStatus.denied => 'denied',
        MusicAuthorizationStatus.restricted => 'restricted',
        MusicAuthorizationStatus.unavailable => 'unavailable',
      };
}

/// Apple Music subscription status of the signed-in user.
///
/// This is independent from [MusicAuthorizationStatus]: a user can be
/// authorized but not subscribed (they can still play previews).
enum MusicSubscriptionStatus {
  /// The subscription state could not be determined yet.
  unknown,

  /// Active Apple Music subscription.
  subscribed,

  /// No Apple Music subscription (previews may still be playable).
  notSubscribed;

  /// Deserializes from transport.
  static MusicSubscriptionStatus fromName(String? name) => switch (name) {
        'subscribed' => MusicSubscriptionStatus.subscribed,
        'notSubscribed' => MusicSubscriptionStatus.notSubscribed,
        _ => MusicSubscriptionStatus.unknown,
      };

  /// Serializes for transport.
  String get name => switch (this) {
        MusicSubscriptionStatus.unknown => 'unknown',
        MusicSubscriptionStatus.subscribed => 'subscribed',
        MusicSubscriptionStatus.notSubscribed => 'notSubscribed',
      };
}

/// Full subscription snapshot from MusicKit.
final class MusicSubscription {
  /// Creates a subscription snapshot.
  const MusicSubscription({
    required this.status,
    this.canPlayCatalogContent = false,
    this.canUseCloudLibrary = false,
    this.hasCloudLibraryEnabled = false,
  });

  /// A snapshot with [MusicSubscriptionStatus.unknown].
  const MusicSubscription.unknown()
      : status = MusicSubscriptionStatus.unknown,
        canPlayCatalogContent = false,
        canUseCloudLibrary = false,
        hasCloudLibraryEnabled = false;

  /// Coarse subscription status.
  final MusicSubscriptionStatus status;

  /// Whether the user can play full catalog content (has subscription).
  final bool canPlayCatalogContent;

  /// Whether the device/account supports iCloud Music Library.
  final bool canUseCloudLibrary;

  /// Whether the user has enabled iCloud Music Library.
  final bool hasCloudLibraryEnabled;

  /// Deserializes from transport.
  static MusicSubscription fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MusicSubscription.unknown();
    return MusicSubscription(
      status: MusicSubscriptionStatus.fromName(json['status'] as String?),
      canPlayCatalogContent: json['canPlayCatalogContent'] as bool? ?? false,
      canUseCloudLibrary: json['canUseCloudLibrary'] as bool? ?? false,
      hasCloudLibraryEnabled: json['hasCloudLibraryEnabled'] as bool? ?? false,
    );
  }

  /// Serializes for transport.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'status': status.name,
        'canPlayCatalogContent': canPlayCatalogContent,
        'canUseCloudLibrary': canUseCloudLibrary,
        'hasCloudLibraryEnabled': hasCloudLibraryEnabled,
      };

  @override
  bool operator ==(Object other) =>
      other is MusicSubscription &&
      other.status == status &&
      other.canPlayCatalogContent == canPlayCatalogContent &&
      other.canUseCloudLibrary == canUseCloudLibrary &&
      other.hasCloudLibraryEnabled == hasCloudLibraryEnabled;

  @override
  int get hashCode => Object.hash(status, canPlayCatalogContent,
      canUseCloudLibrary, hasCloudLibraryEnabled);
}
