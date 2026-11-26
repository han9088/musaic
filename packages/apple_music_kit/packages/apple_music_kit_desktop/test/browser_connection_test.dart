import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:apple_music_kit_desktop/apple_music_kit_desktop.dart';
import 'package:apple_music_kit_desktop/src/browser_connection.dart';
import 'package:apple_music_kit_platform_interface/apple_music_kit_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop registration and missing-token failure', () async {
    final previous = MusicKitPlatform.instance;
    addTearDown(() => MusicKitPlatform.instance = previous);
    AppleMusicKitDesktop.registerWith();
    expect(MusicKitPlatform.instance, isA<AppleMusicKitDesktop>());
    await expectLater(
        MusicKitPlatform.instance.initialize(const MusicKitPlatformConfig()),
        throwsA(isA<MusicKitException>().having(
            (e) => e.code, 'code', MusicKitErrorCode.developerTokenMissing)));
  });

  test('authenticates loopback socket, routes RPC/events and disconnects',
      () async {
    late WebSocket browser;
    late Uri address;
    final events = <String>[];
    final connection = BrowserConnection(
      platform: 'linux',
      loadAsset: (name) async => name,
      onEvent: (name, _) => events.add(name),
      launch: (uri) async {
        address = uri;
        final ws = uri.replace(scheme: 'ws', path: '/bridge', fragment: '');
        final origin = 'http://${uri.authority}';
        await expectLater(
            WebSocket.connect(ws.toString(),
                protocols: ['musickit', 'wrong'], headers: {'Origin': origin}),
            throwsA(isA<WebSocketException>()));
        await expectLater(
            WebSocket.connect(ws.toString(),
                protocols: ['musickit', uri.fragment],
                headers: {'Origin': 'https://evil.example'}),
            throwsA(isA<WebSocketException>()));
        browser = await WebSocket.connect(ws.toString(),
            protocols: ['musickit', uri.fragment], headers: {'Origin': origin});
        browser.listen((dynamic raw) {
          final request = jsonDecode(raw as String) as Map<String, dynamic>;
          if (request['method'] == 'never') return;
          if (request['method'] == 'error') {
            browser.add(jsonEncode({
              'id': request['id'],
              'error': {
                'code': 'authorizationDenied',
                'message': 'secret must not leak'
              }
            }));
          } else {
            browser.add(
                jsonEncode({'id': request['id'], 'result': request['args']}));
          }
        });
        browser.add(jsonEncode({'event': 'ready'}));
        browser
            .add(jsonEncode({'event': 'authorization', 'value': 'authorized'}));
      },
    );
    addTearDown(connection.close);
    await connection.connect();
    expect(address.host, '127.0.0.1');
    expect(address.fragment.length, greaterThanOrEqualTo(43));
    expect(await connection.call('echo', {'value': 4}), {'value': 4});
    expect(events, contains('authorization'));
    await expectLater(
        connection.call('error'),
        throwsA(isA<MusicKitException>()
            .having(
                (e) => e.code, 'code', MusicKitErrorCode.authorizationDenied)
            .having(
                (e) => e.toString(), 'safe error', isNot(contains('secret')))));
    final client = HttpClient();
    addTearDown(client.close);
    final response = await (await client
            .getUrl(address.replace(fragment: '', path: '/companion.js')))
        .close();
    expect(response.statusCode, 200);
    expect(await utf8.decoder.bind(response).join(), 'companion.js');
    final badHost = await client.getUrl(address.replace(fragment: ''));
    badHost.headers.set('host', 'evil.example');
    expect((await badHost.close()).statusCode, 403);
    final pending = expectLater(
        connection.call('never'), throwsA(isA<MusicKitException>()));
    await browser.close();
    await pending;
    await connection.close();
    await connection.close();
  });

  test('request timeout fails closed and never retries a mutation', () async {
    late WebSocket browser;
    var calls = 0;
    final events = <String>[];
    final connection = BrowserConnection(
      platform: 'windows',
      timeout: const Duration(milliseconds: 100),
      loadAsset: (_) async => '',
      onEvent: (event, _) => events.add(event),
      launch: (uri) async {
        browser = await WebSocket.connect(
            uri.replace(scheme: 'ws', path: '/bridge', fragment: '').toString(),
            protocols: ['musickit', uri.fragment],
            headers: {'Origin': 'http://${uri.authority}'});
        browser.listen((_) => calls++);
        browser.add(jsonEncode({'event': 'ready'}));
      },
    );
    addTearDown(connection.close);
    await connection.connect();
    await expectLater(
        connection.call('createPlaylist'),
        throwsA(isA<MusicKitException>()
            .having((e) => e.code, 'code', MusicKitErrorCode.requestTimeout)));
    expect(calls, 1);
    expect(events, ['disconnected']);
    await expectLater(
        connection.call('createPlaylist'), throwsA(isA<MusicKitException>()));
    await browser.close();
  });

  test('browser connection timeout closes the listening server', () async {
    late Uri uri;
    final connection = BrowserConnection(
      platform: 'linux',
      timeout: const Duration(milliseconds: 50),
      loadAsset: (_) async => '',
      onEvent: (_, __) {},
      launch: (value) async {
        uri = value;
      },
    );
    await expectLater(
        connection.connect(),
        throwsA(isA<MusicKitException>()
            .having((e) => e.code, 'code', MusicKitErrorCode.requestTimeout)));
    await expectLater(
        Socket.connect(uri.host, uri.port), throwsA(isA<SocketException>()));
  });

  test('browser launch failure is sanitized and releases its listener',
      () async {
    late Uri address;
    final connection = BrowserConnection(
      platform: 'windows',
      loadAsset: (_) async => '',
      onEvent: (_, __) {},
      launch: (uri) async {
        address = uri;
        throw ProcessException(
            'browser', [uri.toString()], 'secret launch detail');
      },
    );
    await expectLater(
        connection.connect(),
        throwsA(isA<MusicKitException>()
            .having(
                (e) => e.code, 'code', MusicKitErrorCode.platformUnavailable)
            .having((e) => e.toString(), 'safe message',
                isNot(contains('secret')))));
    await expectLater(Socket.connect(address.host, address.port),
        throwsA(isA<SocketException>()));
  });

  test('a long-lived Linux URL handler does not delay a connected browser',
      () async {
    final launcherExit = Completer<void>();
    late WebSocket browser;
    final connection = BrowserConnection(
      platform: 'linux',
      timeout: const Duration(seconds: 1),
      loadAsset: (_) async => '',
      onEvent: (_, __) {},
      launch: (uri) async {
        browser = await WebSocket.connect(
            uri.replace(scheme: 'ws', path: '/bridge', fragment: '').toString(),
            protocols: ['musickit', uri.fragment],
            headers: {'Origin': 'http://${uri.authority}'});
        browser.listen((_) {});
        browser.add(jsonEncode({'event': 'ready'}));
        await launcherExit.future;
      },
    );
    addTearDown(() async {
      launcherExit.complete();
      await connection.close();
      await browser.close();
    });
    await connection.connect().timeout(const Duration(seconds: 2));
    expect(launcherExit.isCompleted, false);
  });
}
