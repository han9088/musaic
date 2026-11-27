import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'api_utils.dart';
import 'json_utils.dart';
import 'models.dart';

enum AudiusOAuthScope { read, write }

class AudiusOAuthException implements Exception {
  const AudiusOAuthException(this.code, {this.statusCode});

  final String code;
  final int? statusCode;

  bool get sessionExpired => code == 'invalid_grant' || statusCode == 401;
}

class AudiusOAuthTokens {
  const AudiusOAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
    required this.scope,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final DateTime refreshExpiresAt;
  final AudiusOAuthScope scope;

  factory AudiusOAuthTokens.fromJson(Map<String, Object?> json) =>
      AudiusOAuthTokens(
        accessToken: _requiredString(json, 'access_token'),
        refreshToken: _requiredString(json, 'refresh_token'),
        accessExpiresAt: DateTime.parse(
          _requiredString(json, 'access_expires_at'),
        ),
        refreshExpiresAt: DateTime.parse(
          _requiredString(json, 'refresh_expires_at'),
        ),
        scope: AudiusOAuthScope.values.byName(_requiredString(json, 'scope')),
      );

  Map<String, Object?> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'access_expires_at': accessExpiresAt.toIso8601String(),
    'refresh_expires_at': refreshExpiresAt.toIso8601String(),
    'scope': scope.name,
  };
}

/// Public-client OAuth. The caller supplies the platform browser and storage.
class AudiusOAuth {
  AudiusOAuth({
    required this.clientId,
    required this.redirectUri,
    http.Client? client,
    DateTime Function()? now,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _now = now ?? DateTime.now;

  final String clientId;
  final Uri redirectUri;
  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _now;

  Future<AudiusOAuthTokens?> authorize(
    AudiusOAuthScope scope,
    Future<Uri?> Function(Uri url) openBrowser,
  ) async {
    final state = _randomSecret();
    final verifier = _randomSecret();
    final challenge = _base64Url(sha256.convert(utf8.encode(verifier)).bytes);
    final redirect = await openBrowser(
      Uri.https('api.audius.co', '/v1/oauth/authorize', {
        'api_key': clientId,
        'redirect_uri': redirectUri.toString(),
        'response_type': 'code',
        'response_mode': 'query',
        'code_challenge_method': 'S256',
        'code_challenge': challenge,
        'scope': scope.name,
        'state': state,
        'display': 'fullScreen',
      }),
    );
    if (redirect == null) return null;
    final params = redirect.queryParametersAll;
    if (redirect.scheme != redirectUri.scheme ||
        redirect.authority != redirectUri.authority ||
        redirect.path != redirectUri.path ||
        params['state']?.length != 1 ||
        params['state']!.single != state) {
      throw const AudiusOAuthException('invalid_callback');
    }
    if (params['error']?.length == 1 &&
        params['error']!.single == 'access_denied') {
      return null;
    }
    final codes = params['code'];
    if (params.containsKey('error') ||
        codes?.length != 1 ||
        codes!.single.isEmpty) {
      throw const AudiusOAuthException('invalid_callback');
    }
    return _token({
      'grant_type': 'authorization_code',
      'code': codes.single,
      'code_verifier': verifier,
      'client_id': clientId,
      'redirect_uri': redirectUri.toString(),
    });
  }

  Future<AudiusOAuthTokens> refresh(AudiusOAuthTokens tokens) => _token({
    'grant_type': 'refresh_token',
    'refresh_token': tokens.refreshToken,
    'client_id': clientId,
  });

  Future<AudiusUser> profile(AudiusOAuthTokens tokens) async {
    final response = await _request('GET', '/v1/me', tokens: tokens);
    final user = AudiusUser.fromJson(requireJsonMap(response['data']));
    if (user.id.isEmpty) throw const FormatException('Missing Audius user id.');
    return user;
  }

  Future<void> revoke(AudiusOAuthTokens tokens) async {
    await _request(
      'POST',
      '/v1/oauth/revoke',
      body: {'token': tokens.refreshToken, 'client_id': clientId},
    );
  }

  Future<void> setFavorite({
    required AudiusOAuthTokens tokens,
    required String userId,
    required String id,
    required bool collection,
    required bool favorite,
  }) async {
    if (tokens.scope != AudiusOAuthScope.write) {
      throw const AudiusOAuthException('insufficient_scope');
    }
    final resource = collection ? 'playlists' : 'tracks';
    await _request(
      favorite ? 'POST' : 'DELETE',
      '/v1/$resource/${pathSegment(id, 'id')}/favorites',
      tokens: tokens,
      query: {'user_id': userId},
    );
  }

  Future<AudiusOAuthTokens> _token(Map<String, String> body) async {
    final json = await _request('POST', '/v1/oauth/token', body: body);
    final now = _now().toUtc();
    return AudiusOAuthTokens(
      accessToken: _requiredString(json, 'access_token'),
      refreshToken: _requiredString(json, 'refresh_token'),
      accessExpiresAt: now.add(_lifetime(json, 'expires_in')),
      refreshExpiresAt: now.add(_lifetime(json, 'refresh_expires_in')),
      scope: AudiusOAuthScope.values.byName(_requiredString(json, 'scope')),
    );
  }

  Future<Map<String, Object?>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, String>? body,
    AudiusOAuthTokens? tokens,
  }) async {
    final request =
        http.Request(method, Uri.https('api.audius.co', path, query))
          ..followRedirects = false
          ..headers['accept'] = 'application/json';
    if (tokens != null) {
      request.headers['authorization'] = 'Bearer ${tokens.accessToken}';
      request.headers['x-api-key'] = clientId;
    }
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Keep server messages and response bodies out of diagnostics.
      final code = switch (response.statusCode) {
        400
            when path == '/v1/oauth/token' &&
                body?['grant_type'] == 'refresh_token' =>
          _refreshError(response.body),
        _ => 'request_failed',
      };
      throw AudiusOAuthException(code, statusCode: response.statusCode);
    }
    return response.bodyBytes.isEmpty
        ? const {}
        : requireJsonMap(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

String _refreshError(String body) {
  try {
    if (requireJsonMap(jsonDecode(body))['error'] == 'invalid_grant') {
      return 'invalid_grant';
    }
  } on FormatException {
    // Preserve only the status code when the server sends a non-JSON error.
  }
  return 'request_failed';
}

Duration _lifetime(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int && value > 0) return Duration(seconds: value);
  throw FormatException('Invalid Audius token lifetime: $key');
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Missing Audius OAuth field: $key');
}

String _base64Url(List<int> bytes) =>
    base64UrlEncode(bytes).replaceAll('=', '');

String _randomSecret() {
  final random = Random.secure();
  return _base64Url(List.generate(32, (_) => random.nextInt(256)));
}
