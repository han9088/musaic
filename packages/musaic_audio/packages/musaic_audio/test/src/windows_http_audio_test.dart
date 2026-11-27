import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:musaic_audio/src/windows_http_audio.dart';
import 'package:musaic_audio_platform_interface/musaic_audio_platform_interface.dart';

void main() {
  Future<HttpServer> server(void Function(HttpRequest) handler) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen(handler);
    return server;
  }

  Uri url(HttpServer server) => Uri.http('127.0.0.1:${server.port}', '/track');

  test('strips split ICY packets and emits station and track metadata',
      () async {
    final metadata = <IcyMetadataMessage>[];
    final origin = await server((request) async {
      final response = request.response;
      response.headers
        ..set('icy-metaint', '4')
        ..set('icy-name', 'Example Radio')
        ..set('icy-br', '128');
      final fields = utf8.encode(
          "StreamTitle='Musica d’autore';StreamUrl='https://example.com/';");
      final blocks = (fields.length + 15) ~/ 16;
      final body = [
        ...ascii.encode('aaaa'),
        blocks,
        ...fields,
        ...List<int>.filled(blocks * 16 - fields.length, 0),
        ...ascii.encode('bbbb'),
        0,
        ...ascii.encode('cccc'),
      ];
      response.bufferOutput = false;
      for (var i = 0; i < body.length; i += 3) {
        response.add(body.skip(i).take(3).toList());
        await response.flush();
      }
      await response.close();
    });
    final proxy = await server((request) => proxyWindowsHttpAudio(
          request,
          url(origin),
          headers: {},
          onMetadata: metadata.add,
        ));
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final response = await (await client.getUrl(url(proxy))).close();

    expect(await response.transform(ascii.decoder).join(), 'aaaabbbbcccc');
    expect(response.headers.value('icy-metaint'), isNull);
    expect(metadata, hasLength(2));
    expect(metadata.first.headers?.name, 'Example Radio');
    expect(metadata.first.headers?.bitrate, 128000);
    expect(metadata.last.info?.title, 'Musica d’autore');
    expect(metadata.last.info?.url, 'https://example.com/');
  });

  test('preserves byte ranges and HEAD without forwarding redirect credentials',
      () async {
    final initialHeaders = <String?>[];
    final redirectedHeaders = <String?>[];
    final destination = await server((request) async {
      redirectedHeaders.add(request.headers.value('x-audio-token'));
      expect(request.headers.value('icy-metadata'), '0');
      final response = request.response;
      if (request.method == 'GET') {
        expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=2-3');
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(HttpHeaders.contentRangeHeader, 'bytes 2-3/8');
        response.contentLength = 2;
        response.add([2, 3]);
      } else {
        response.contentLength = 8;
      }
      await response.close();
    });
    final origin = await server((request) async {
      initialHeaders.add(request.headers.value('x-audio-token'));
      await request.response.redirect(url(destination));
    });
    final proxy = await server((request) => proxyWindowsHttpAudio(
          request,
          url(origin),
          headers: {'X-Audio-Token': 'private'},
          onMetadata: (_) {},
        ));
    final client = HttpClient();
    addTearDown(() => client.close(force: true));

    final head = await (await client.headUrl(url(proxy))).close();
    expect(head.contentLength, 8);
    expect(await head.toList(), isEmpty);

    final request = await client.getUrl(url(proxy));
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=2-3');
    final response = await request.close();
    expect(response.statusCode, HttpStatus.partialContent);
    expect(
        response.headers.value(HttpHeaders.contentRangeHeader), 'bytes 2-3/8');
    expect(await response.expand((chunk) => chunk).toList(), [2, 3]);
    expect(initialHeaders, ['private', 'private']);
    expect(redirectedHeaders, [null, null]);
  });
}
