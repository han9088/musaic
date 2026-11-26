/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'dart:async';
import 'dart:convert';

/// Supplies Apple Music **developer tokens** (JWT) to the plugin.
///
/// The plugin never creates or signs developer tokens itself — that
/// requires the .p8 private key which must stay on your server. Implement
/// this interface to fetch a token from your backend.
///
/// Implementations should be fast; the plugin handles caching, refresh
/// ahead of expiry, and single-flighting concurrent requests.
abstract interface class DeveloperTokenProvider {
  /// Returns a valid, unexpired developer token (JWT string).
  ///
  /// Throw an [Exception] with a descriptive message when the token cannot
  /// be obtained; the plugin maps failures to
  /// `MusicKitErrorCode.developerTokenMissing`.
  Future<String> getToken();
}

/// A static in-memory token, for development and tests.
final class StaticDeveloperTokenProvider implements DeveloperTokenProvider {
  /// Creates a provider returning [token] forever.
  const StaticDeveloperTokenProvider(this.token);

  /// The token string.
  final String token;

  @override
  Future<String> getToken() async => token;
}

/// Caches a token and refreshes it ahead of expiry, single-flighting
/// concurrent requests.
///
/// Expiry is derived from the JWT `exp` claim when parseable; otherwise
/// tokens are considered valid for [fallbackTtl]. Refresh happens
/// [leadTime] before expiry.
final class CachingDeveloperTokenProvider implements DeveloperTokenProvider {
  /// Creates a caching wrapper around [delegate].
  CachingDeveloperTokenProvider({
    required DeveloperTokenProvider delegate,
    this.leadTime = const Duration(minutes: 5),
    this.fallbackTtl = const Duration(minutes: 30),
  }) : _delegate = delegate;

  final DeveloperTokenProvider _delegate;

  /// How long before expiry a refresh is triggered.
  final Duration leadTime;

  /// Assumed TTL when the JWT `exp` claim cannot be parsed.
  final Duration fallbackTtl;

  String? _cachedToken;
  DateTime? _refreshAt;
  Future<String>? _inFlight;

  @override
  Future<String> getToken() {
    final now = DateTime.now();
    if (_cachedToken != null &&
        _refreshAt != null &&
        now.isBefore(_refreshAt!)) {
      return Future.value(_cachedToken);
    }
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  Future<String> _fetch() async {
    final token = await _delegate.getToken();
    _cachedToken = token;
    final expiry = jwtExpiry(token);
    final ttl = expiry != null
        ? DateTime.fromMillisecondsSinceEpoch(expiry * 1000)
            .difference(DateTime.now())
        : fallbackTtl;
    _refreshAt = DateTime.now().add(ttl - leadTime);
    return token;
  }

  /// Parses the `exp` claim of a JWT without verifying it, or null when
  /// malformed.
  static int? jwtExpiry(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      var normalized = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      final pad = normalized.length % 4;
      if (pad != 0) normalized += '=' * (4 - pad);
      final payload = utf8.decode(base64.decode(normalized));
      final exp = RegExp(r'"exp"\s*:\s*(\d+)').firstMatch(payload)?.group(1);
      return exp == null ? null : int.tryParse(exp);
    } catch (_) {
      return null;
    }
  }

  /// Drops the cached token, forcing the next [getToken] to hit the
  /// delegate provider.
  void invalidate() {
    _cachedToken = null;
    _refreshAt = null;
  }
}
