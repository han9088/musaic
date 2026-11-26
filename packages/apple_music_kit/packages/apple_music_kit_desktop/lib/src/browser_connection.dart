import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:apple_music_kit_platform_interface/apple_music_kit_platform_interface.dart';
import 'package:flutter/services.dart';

/// Authenticated, loopback-only transport to the browser that owns playback.
class BrowserConnection {
  BrowserConnection({
    required this.platform,
    required this.onEvent,
    this.launch = openBrowser,
    this.loadAsset = loadBundledAsset,
    this.timeout = const Duration(minutes: 2),
  });

  final String platform;
  final void Function(String, Object?) onEvent;
  final Future<void> Function(Uri) launch;
  final Future<String> Function(String) loadAsset;
  final Duration timeout;
  HttpServer? _server;
  WebSocket? _socket;
  final _pending = <int, Completer<Object?>>{};
  int _nextId = 0;
  bool _closed = false;

  static Future<String> loadBundledAsset(String name) =>
      rootBundle.loadString('packages/apple_music_kit_desktop/assets/$name');

  static Future<void> openBrowser(Uri uri) async {
    final result = await Process.run(
      Platform.isWindows ? 'explorer.exe' : 'xdg-open',
      [uri.toString()],
    );
    // Explorer can return 1 after successfully handing off a URL.
    if (result.exitCode != 0 && !(Platform.isWindows && result.exitCode == 1)) {
      throw const MusicKitException(MusicKitErrorCode.platformUnavailable,
          message: 'Could not open the default browser. Install a browser '
              'and configure the system URL handler.');
    }
  }

  MusicKitException _error(MusicKitErrorCode code, String message) =>
      MusicKitException(code, message: message, platform: platform);

  Future<void> connect() async {
    final html = await loadAsset('index.html');
    final script = await loadAsset('companion.js');
    if (_closed) {
      throw _error(MusicKitErrorCode.alreadyDisposed, 'Connection closed.');
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    final origin = 'http://127.0.0.1:${server.port}';
    final random = Random.secure();
    final secret = base64Url
        .encode(List.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    final connected = Completer<void>();
    // Attach the timeout before launching, so early disconnects are handled.
    final ready = connected.future.timeout(timeout);
    server.listen((request) async {
      try {
        request.response.headers
          ..set('Cache-Control', 'no-store')
          ..set('Referrer-Policy', 'no-referrer')
          ..set('X-Content-Type-Options', 'nosniff')
          ..set('X-Frame-Options', 'DENY');
        if (request.headers.value('host') != '127.0.0.1:${server.port}' ||
            request.method != 'GET') {
          request.response.statusCode = HttpStatus.forbidden;
          await request.response.close();
          return;
        }
        if (request.uri.path == '/bridge') {
          final protocols = request.headers
              .value('sec-websocket-protocol')
              ?.split(',')
              .map((s) => s.trim())
              .toList();
          if (_closed ||
              _socket != null ||
              request.headers.value('origin') != origin ||
              protocols == null ||
              !protocols.contains(secret) ||
              !protocols.contains('musickit') ||
              !WebSocketTransformer.isUpgradeRequest(request)) {
            request.response.statusCode = HttpStatus.forbidden;
            await request.response.close();
            return;
          }
          final socket = await WebSocketTransformer.upgrade(request,
              protocolSelector: (_) => 'musickit');
          if (_closed || _socket != null) {
            await socket.close();
            return;
          }
          _socket = socket;
          socket.pingInterval = const Duration(seconds: 20);
          socket.listen((message) {
            try {
              if (message is! String || message.length > 8 * 1024 * 1024) {
                throw const FormatException();
              }
              final data = jsonDecode(message) as Map<String, dynamic>;
              if (data['event'] == 'ready') {
                if (!connected.isCompleted) connected.complete();
              } else if (data['event'] is String) {
                onEvent(data['event'] as String, data['value']);
              } else {
                final pending = _pending[data['id']];
                if (pending == null) return;
                if (data['error'] case final Map<String, dynamic> error) {
                  pending.completeError(_error(
                    MusicKitErrorCode.fromName(error['code'] as String?),
                    'Browser MusicKit request failed.',
                  ));
                } else {
                  pending.complete(data['result']);
                }
                _pending.remove(data['id']);
              }
            } catch (_) {
              unawaited(socket.close(WebSocketStatus.invalidFramePayloadData));
            }
          }, onDone: () {
            _socket = null;
            final error = _error(
                MusicKitErrorCode.platformUnavailable,
                'The playback browser disconnected. Dispose and initialize '
                'a new client to reconnect.');
            if (!connected.isCompleted) connected.completeError(error);
            _failPending(error);
            if (!_closed) onEvent('disconnected', null);
          }, onError: (Object _) {
            unawaited(socket.close());
          });
          return;
        }
        final content = switch (request.uri.path) {
          '/' => html,
          '/companion.js' => script,
          _ => null,
        };
        if (content == null) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response.headers.contentType = ContentType(
              request.uri.path == '/' ? 'text' : 'application',
              request.uri.path == '/' ? 'html' : 'javascript',
              charset: 'utf-8');
          request.response.write(content);
        }
        await request.response.close();
      } catch (_) {
        request.response.close().ignore();
      }
    });
    try {
      // The secret stays in the fragment, never in HTTP paths or referrers.
      // Some Linux URL handlers stay alive for the browser's whole lifetime.
      // A connected page, not the launcher's exit, determines readiness.
      unawaited(Future<void>.sync(() => launch(Uri.parse('$origin/#$secret')))
          .then<void>((_) {}, onError: (Object error, StackTrace stack) {
        if (!connected.isCompleted) connected.completeError(error, stack);
      }));
      await ready;
    } on TimeoutException {
      await close();
      throw _error(MusicKitErrorCode.requestTimeout,
          'The playback browser did not connect in time.');
    } catch (_) {
      if (!connected.isCompleted) connected.complete();
      await close();
      throw _error(MusicKitErrorCode.platformUnavailable,
          'Could not connect to the playback browser.');
    }
  }

  Future<Object?> call(String method, [Map<String, Object?>? args]) async {
    final socket = _socket;
    if (_closed || socket == null) {
      throw _error(MusicKitErrorCode.platformUnavailable,
          'The playback browser is not connected.');
    }
    final id = ++_nextId;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    try {
      socket.add(jsonEncode({'id': id, 'method': method, 'args': args ?? {}}));
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      // A timed-out mutation may still finish in the SDK. Never retry it.
      onEvent('disconnected', null);
      await close();
      throw _error(
          MusicKitErrorCode.requestTimeout,
          'Browser request timed out; its outcome is unknown. '
          'Create a new client to reconnect.');
    } finally {
      _pending.remove(id);
    }
  }

  void _failPending(Object error) {
    for (final pending in _pending.values) {
      if (!pending.isCompleted) pending.completeError(error);
    }
    _pending.clear();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _failPending(
        _error(MusicKitErrorCode.alreadyDisposed, 'Connection closed.'));
    await _socket?.close();
    _socket = null;
    await _server?.close(force: true);
    _server = null;
  }
}
