/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

/// Stable error codes for [MusicKitException].
///
/// These deliberately match the requirement's taxonomy and are stable API:
/// never rename existing values.
enum MusicKitErrorCode {
  /// `initialize()` has not completed for this client.
  notInitialized,

  /// The object was disposed and can no longer be used.
  alreadyDisposed,

  /// The user denied Apple Music authorization.
  authorizationDenied,

  /// The user cancelled the authorization flow.
  authorizationCancelled,

  /// Authentication failed (token rejected, sign-in required, etc.).
  authenticationFailed,

  /// No developer token is available from the provider.
  developerTokenMissing,

  /// The developer token is expired.
  developerTokenExpired,

  /// The music user token is missing, expired, or invalid.
  userTokenInvalid,

  /// The action needs an active Apple Music subscription.
  subscriptionRequired,

  /// The requested storefront is unavailable for this account.
  storefrontUnavailable,

  /// 404 — the resource does not exist.
  resourceNotFound,

  /// 409/410 — the resource exists but cannot be used right now.
  resourceUnavailable,

  /// The playback engine failed to play the item.
  playbackFailed,

  /// Network-level failure.
  networkError,

  /// The request timed out.
  requestTimeout,

  /// HTTP 429 with Retry-After.
  rateLimited,

  /// The current platform does not implement this feature.
  unsupportedFeature,

  /// The Apple SDK (e.g. Android MusicKit AARs) is missing.
  sdkUnavailable,

  /// No platform implementation is registered for this build.
  platformUnavailable,

  /// Anything else.
  unknown;

  /// Deserializes from transport / API `code` strings.
  static MusicKitErrorCode fromName(String? name) => switch (name) {
        'notInitialized' => MusicKitErrorCode.notInitialized,
        'alreadyDisposed' => MusicKitErrorCode.alreadyDisposed,
        'authorizationDenied' => MusicKitErrorCode.authorizationDenied,
        'authorizationCancelled' => MusicKitErrorCode.authorizationCancelled,
        'authenticationFailed' => MusicKitErrorCode.authenticationFailed,
        'developerTokenMissing' => MusicKitErrorCode.developerTokenMissing,
        'developerTokenExpired' => MusicKitErrorCode.developerTokenExpired,
        'userTokenInvalid' => MusicKitErrorCode.userTokenInvalid,
        'subscriptionRequired' => MusicKitErrorCode.subscriptionRequired,
        'storefrontUnavailable' => MusicKitErrorCode.storefrontUnavailable,
        'resourceNotFound' => MusicKitErrorCode.resourceNotFound,
        'resourceUnavailable' => MusicKitErrorCode.resourceUnavailable,
        'playbackFailed' => MusicKitErrorCode.playbackFailed,
        'networkError' => MusicKitErrorCode.networkError,
        'requestTimeout' => MusicKitErrorCode.requestTimeout,
        'rateLimited' => MusicKitErrorCode.rateLimited,
        'unsupportedFeature' => MusicKitErrorCode.unsupportedFeature,
        'sdkUnavailable' => MusicKitErrorCode.sdkUnavailable,
        'platformUnavailable' => MusicKitErrorCode.platformUnavailable,
        _ => MusicKitErrorCode.unknown,
      };
}

/// The single exception type thrown across the whole plugin.
///
/// Native/JS errors are always mapped into this type with a stable [code]
/// and a developer-facing [message]. No tokens or credentials are ever
/// embedded in [message] or [details].
final class MusicKitException implements Exception {
  /// Creates the exception.
  const MusicKitException(
    this.code, {
    required this.message,
    this.platform,
    this.details,
    this.retryAfter,
  });

  /// Stable machine-readable code.
  final MusicKitErrorCode code;

  /// Developer-facing explanation (English), safe for logs.
  final String message;

  /// Which platform raised the error (`ios`, `android`, `web`, `dart`).
  final String? platform;

  /// Structured context (e.g. HTTP status, resource id). Never contains
  /// tokens.
  final Map<String, Object?>? details;

  /// For [MusicKitErrorCode.rateLimited]: server-provided retry delay.
  final Duration? retryAfter;

  /// A short, user-presentable message suitable for UI surfaces.
  String get userMessage => switch (code) {
        MusicKitErrorCode.authorizationDenied =>
          'Apple Music access was denied. Enable it in Settings and try again.',
        MusicKitErrorCode.authorizationCancelled =>
          'The sign-in was cancelled.',
        MusicKitErrorCode.subscriptionRequired =>
          'An Apple Music subscription is required for this.',
        MusicKitErrorCode.networkError =>
          'Network unavailable. Check your connection and retry.',
        MusicKitErrorCode.requestTimeout =>
          'The request took too long. Please retry.',
        MusicKitErrorCode.rateLimited =>
          'Too many requests. Please wait a moment.',
        MusicKitErrorCode.resourceNotFound =>
          'This item is no longer available.',
        MusicKitErrorCode.resourceUnavailable =>
          'This item cannot be played in your region or on your plan.',
        MusicKitErrorCode.playbackFailed =>
          'Playback failed. Try another item.',
        _ => 'Something went wrong with Apple Music.',
      };

  @override
  String toString() {
    final b = StringBuffer('MusicKitException($code): $message');
    if (platform != null) b.write(' [platform: $platform]');
    if (details != null && details!.isNotEmpty) b.write(' $details');
    return b.toString();
  }
}
