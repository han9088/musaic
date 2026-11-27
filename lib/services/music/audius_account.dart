import 'dart:async';
import 'dart:convert';

import 'package:audius_sdk/audius_sdk.dart';
import 'package:flutter/foundation.dart';

import 'music_models.dart';

abstract interface class AudiusSessionStore {
  Future<String?> read();
  Future<void> write(String session);
  Future<void> clear();
}

/// Owns the login independently of the active music source and player.
final class AudiusAccount extends ChangeNotifier {
  AudiusAccount({
    required this._oauth,
    required this._store,
    required this._openBrowser,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AudiusOAuth _oauth;
  final AudiusSessionStore _store;
  final Future<Uri?> Function(Uri) _openBrowser;
  final DateTime Function() _now;
  AudiusOAuthTokens? _tokens;
  AudiusUser? _user;
  bool _disposed = false;
  bool _busy = false;
  Object? _error;

  bool get busy => _busy;
  Object? get error => _error;
  AudiusUser? get user => _user;
  bool get canWrite => _tokens?.scope == AudiusOAuthScope.write;

  Future<void> restore() => _run(() async {
    final saved = await _store.read();
    if (saved == null || _disposed) return;
    try {
      final session = jsonDecode(saved) as Map<String, Object?>;
      if (session['client_id'] != _oauth.clientId) {
        await _store.clear();
        return;
      }
      final tokens = AudiusOAuthTokens.fromJson(
        session['tokens'] as Map<String, Object?>,
      );
      final user = AudiusUser.fromJson(session['user'] as Map<String, Object?>);
      if (user.id.isEmpty || !tokens.refreshExpiresAt.isAfter(_now())) {
        await _store.clear();
        return;
      }
      _tokens = tokens;
      _user = user;
    } on FormatException {
      await _store.clear();
      return;
    } on TypeError {
      await _store.clear();
      return;
    } on ArgumentError {
      await _store.clear();
      return;
    }
    await _currentTokens();
  });

  Future<void> connect() => _run(() => _authorize(AudiusOAuthScope.read));

  Future<void> disconnect() => _run(() async {
    final tokens = _tokens;
    await _forget();
    if (tokens != null) await _revokeQuietly(tokens);
  });

  Future<bool> setFavorite({
    required String id,
    required MusicKind kind,
    required bool favorite,
  }) async {
    var updated = false;
    await _run(() async {
      final user = _user;
      if (user == null) return;
      if (kind != MusicKind.song &&
          kind != MusicKind.album &&
          kind != MusicKind.playlist) {
        throw ArgumentError.value(kind, 'kind');
      }
      if (!canWrite &&
          !await _authorize(AudiusOAuthScope.write, userId: user.id)) {
        return;
      }
      final tokens = await _currentTokens();
      if (tokens == null) return;
      await _oauth.setFavorite(
        tokens: tokens,
        userId: user.id,
        id: id,
        collection: kind != MusicKind.song,
        favorite: favorite,
      );
      updated = true;
    });
    return updated;
  }

  Future<bool> _authorize(AudiusOAuthScope scope, {String? userId}) async {
    final next = await _oauth.authorize(scope, _openBrowser);
    if (next == null) return false;
    final previous = _tokens;
    try {
      final profile = await _oauth.profile(next);
      if (scope == AudiusOAuthScope.write && next.scope != scope) {
        throw const AudiusOAuthException('insufficient_scope');
      }
      if (userId != null && profile.id != userId) {
        throw const AudiusOAuthException('account_changed');
      }
      if (_disposed) return false;
      await _save(next, profile);
    } catch (_) {
      await _revokeQuietly(next);
      rethrow;
    }
    if (previous != null) unawaited(_revokeQuietly(previous));
    return true;
  }

  Future<AudiusOAuthTokens?> _currentTokens() async {
    final tokens = _tokens;
    final user = _user;
    if (tokens == null || user == null) return null;
    if (tokens.accessExpiresAt.isAfter(
      _now().add(const Duration(seconds: 30)),
    )) {
      return tokens;
    }
    if (!tokens.refreshExpiresAt.isAfter(_now())) {
      await _forget();
      return null;
    }
    final next = await _oauth.refresh(tokens);
    if (_disposed) return null;
    await _save(next, user);
    return next;
  }

  Future<void> _save(AudiusOAuthTokens tokens, AudiusUser user) async {
    await _store.write(
      jsonEncode({
        'client_id': _oauth.clientId,
        'tokens': tokens.toJson(),
        'user': {'id': user.id, 'handle': user.handle, 'name': user.name},
      }),
    );
    _tokens = tokens;
    _user = user;
  }

  Future<void> _forget() async {
    await _store.clear();
    _tokens = null;
    _user = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> _revokeQuietly(AudiusOAuthTokens tokens) async {
    try {
      await _oauth.revoke(tokens);
    } catch (_) {
      // The local credentials have already been replaced or removed.
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy || _disposed) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await operation();
    } catch (error) {
      _error = error;
      if (error is AudiusOAuthException && error.sessionExpired) {
        try {
          await _forget();
        } catch (storageError) {
          _error = storageError;
        }
      }
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _oauth.close();
    super.dispose();
  }
}
