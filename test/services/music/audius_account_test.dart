import 'dart:convert';

import 'package:audius_sdk/audius_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musaic/services/music/audius_account.dart';
import 'package:musaic/services/music/music_provider.dart';

void main() {
  final redirect = Uri.parse('com.deskbtm.musaic.audius://oauth/callback');

  test(
    'connects read-only, restores, requests write on demand, then revokes',
    () async {
      final store = _Store();
      final scopes = <String>[];
      final requests = <String>[];
      var allowWrite = false;
      final client = MockClient((request) async {
        final method = '${request.method} ${request.url.path}';
        requests.add(method);
        if (method == 'GET /v1/me') {
          expect(
            request.headers['authorization'],
            startsWith('Bearer access-'),
          );
          return http.Response(
            '{"data":{"id":"user-123","handle":"listener"}}',
            200,
          );
        }
        if (method == 'POST /v1/oauth/token') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['client_id'], 'public-client');
          expect(body['redirect_uri'], redirect.toString());
          expect(
            body['code_verifier'],
            isA<String>().having((v) => v.length, 'length', 43),
          );
          final scope = body['code'];
          return http.Response(
            jsonEncode({
              'access_token': 'access-$scope',
              'refresh_token': 'refresh-$scope',
              'expires_in': 3600,
              'refresh_expires_in': 86400,
              'scope': scope,
            }),
            200,
          );
        }
        if (method == 'POST /v1/tracks/track-1/favorites' ||
            method == 'DELETE /v1/tracks/track-1/favorites') {
          expect(request.url.queryParameters['user_id'], 'user-123');
          expect(request.headers['authorization'], 'Bearer access-write');
          return http.Response('{}', 200);
        }
        if (method == 'POST /v1/oauth/revoke') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['token'], startsWith('refresh-'));
          return http.Response('', 200);
        }
        fail('Unexpected request: $method');
      });
      AudiusAccount account() => AudiusAccount(
        oauth: AudiusOAuth(
          clientId: 'public-client',
          redirectUri: redirect,
          client: client,
        ),
        store: store,
        openBrowser: (url) async {
          final params = url.queryParameters;
          final scope = params['scope']!;
          scopes.add(scope);
          expect(params['api_key'], 'public-client');
          expect(params['code_challenge_method'], 'S256');
          if (scope == 'write' && !allowWrite) return null;
          return redirect.replace(
            queryParameters: {'state': params['state'], 'code': scope},
          );
        },
      );

      final first = account();
      await first.connect();
      expect(first.user?.id, 'user-123');
      expect(scopes, ['read']);
      expect(first.canWrite, isFalse);
      first.dispose();

      final restored = account();
      addTearDown(restored.dispose);
      await restored.restore();
      expect(restored.user?.handle, 'listener');
      expect(scopes, ['read']);
      expect(
        await restored.setFavorite(
          id: 'track-1',
          kind: MusicKind.song,
          favorite: true,
        ),
        isFalse,
      );
      expect(restored.user?.id, 'user-123');
      expect(restored.canWrite, isFalse);
      expect(requests, isNot(contains('POST /v1/tracks/track-1/favorites')));
      allowWrite = true;
      expect(
        await restored.setFavorite(
          id: 'track-1',
          kind: MusicKind.song,
          favorite: true,
        ),
        isTrue,
      );
      expect(
        await restored.setFavorite(
          id: 'track-1',
          kind: MusicKind.song,
          favorite: false,
        ),
        isTrue,
      );
      expect(scopes, ['read', 'write', 'write']);
      await restored.disconnect();
      expect(restored.user, isNull);
      expect(store.value, isNull);
      expect(requests.last, 'POST /v1/oauth/revoke');
    },
  );

  test(
    'rejects a callback with mismatched state before exchanging a code',
    () async {
      final oauth = AudiusOAuth(
        clientId: 'public-client',
        redirectUri: redirect,
        client: MockClient(
          (_) async =>
              fail('Invalid callbacks must never reach the token endpoint'),
        ),
      );
      await expectLater(
        oauth.authorize(
          AudiusOAuthScope.read,
          (_) async => redirect.replace(
            queryParameters: {'code': 'some-code', 'state': 'unexpected-state'},
          ),
        ),
        throwsA(
          isA<AudiusOAuthException>().having(
            (e) => e.code,
            'code',
            'invalid_callback',
          ),
        ),
      );
    },
  );

  test(
    'restoring an expired access token rotates and stores the refresh token',
    () async {
      final store = _Store();
      var clock = DateTime.utc(2026);
      var refreshes = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/v1/me') {
          return http.Response(
            '{"data":{"id":"owner-id","handle":"owner"}}',
            200,
          );
        }
        final body = jsonDecode(request.body) as Map<String, Object?>;
        if (request.url.path == '/v1/oauth/revoke') {
          expect(body['token'], 'refresh-1');
          return http.Response('', 200);
        }
        expect(request.url.path, '/v1/oauth/token');
        if (body['grant_type'] == 'refresh_token') {
          expect(body['refresh_token'], 'refresh-0');
          refreshes++;
        }
        return http.Response(
          jsonEncode({
            'access_token': 'access-$refreshes',
            'refresh_token': 'refresh-$refreshes',
            'expires_in': 3600,
            'refresh_expires_in': 86400,
            'scope': 'read',
          }),
          200,
        );
      });
      AudiusAccount account() => AudiusAccount(
        oauth: AudiusOAuth(
          clientId: 'public-client',
          redirectUri: redirect,
          client: client,
          now: () => clock,
        ),
        store: store,
        now: () => clock,
        openBrowser: (url) async => redirect.replace(
          queryParameters: {
            'state': url.queryParameters['state'],
            'code': 'one-time-code',
          },
        ),
      );
      final first = account();
      await first.connect();
      first.dispose();
      clock = clock.add(const Duration(hours: 2));
      final restored = account();
      await restored.restore();
      expect(restored.user?.id, 'owner-id');
      expect(refreshes, 1);
      restored.dispose();
      final subsequent = account();
      addTearDown(subsequent.dispose);
      await subsequent.restore();
      expect(refreshes, 1);
      await subsequent.disconnect();
      expect(store.value, isNull);
    },
  );
}

final class _Store implements AudiusSessionStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String session) async => value = session;

  @override
  Future<void> clear() async => value = null;
}
