import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:musaic_audio_platform_interface/musaic_audio_platform_interface.dart';

const _hopByHopHeaders = {
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
};

/// Serves progressive media through the Windows decoder's loopback URL.
Future<void> proxyWindowsHttpAudio(
  HttpRequest request,
  Uri uri, {
  required Map<String, String> headers,
  required void Function(IcyMetadataMessage) onMetadata,
}) async {
  final client = HttpClient()..autoUncompress = false;
  final response = request.response;
  unawaited(response.done.then<void>(
    (_) => client.close(force: true),
    onError: (Object _) => client.close(force: true),
  ));
  var sendingBody = false;

  Future<HttpClientResponse> open({required bool requestIcy}) async {
    var location = uri;
    for (var redirects = 0; redirects <= 10; redirects++) {
      if (location.scheme != 'http' && location.scheme != 'https') {
        throw const HttpException('Unsupported audio redirect scheme.');
      }
      final origin = await client.openUrl(request.method, location);
      origin.followRedirects = false;
      origin.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null) origin.headers.set(HttpHeaders.rangeHeader, range);
      if (location.origin == uri.origin) {
        for (final entry in headers.entries) {
          final name = entry.key.toLowerCase();
          if (!_hopByHopHeaders.contains(name) &&
              name != HttpHeaders.hostHeader &&
              name != HttpHeaders.contentLengthHeader) {
            origin.headers.set(name, entry.value);
          }
        }
      }
      origin.headers.set('icy-metadata', requestIcy ? '1' : '0');
      final result = await origin.close();
      final target = result.headers.value(HttpHeaders.locationHeader);
      if (!result.isRedirect || target == null) return result;
      await result.listen(null).cancel();
      location = location.resolve(target);
    }
    throw const HttpException('Too many audio redirects.');
  }

  try {
    final head = request.method == 'HEAD';
    final range = request.headers.value(HttpHeaders.rangeHeader);
    var origin = await open(
      requestIcy: !head && (range == null || range == 'bytes=0-'),
    );
    if (origin.statusCode == HttpStatus.partialContent &&
        origin.headers.value('icy-metaint') != null) {
      await origin.listen(null).cancel();
      origin = await open(requestIcy: false);
    }
    final interval = int.tryParse(origin.headers.value('icy-metaint') ?? '');
    final interleaved = !head && interval != null && interval > 0;
    if (interleaved &&
        (origin.statusCode != HttpStatus.ok ||
            origin.headers.value(HttpHeaders.contentEncodingHeader) != null)) {
      throw const HttpException('Invalid ICY audio response.');
    }

    origin.headers.forEach((name, values) {
      if (_hopByHopHeaders.contains(name) ||
          name.startsWith('icy-') ||
          name == HttpHeaders.contentLengthHeader ||
          (interleaved && name == HttpHeaders.acceptRangesHeader)) {
        return;
      }
      response.headers.set(name, values);
    });
    response.statusCode = origin.statusCode;
    response.contentLength = interleaved ? -1 : origin.contentLength;
    if (head) {
      await origin.drain<void>();
      return;
    }

    sendingBody = true;
    if (interleaved) {
      final h = origin.headers;
      final isPublic = h.value('icy-pub');
      final bitrate = int.tryParse(h.value('icy-br') ?? '');
      final station = IcyHeadersMessage(
        bitrate: bitrate == null ? null : bitrate * 1000,
        genre: h.value('icy-genre'),
        name: h.value('icy-name'),
        metadataInterval: interval,
        url: h.value('icy-url'),
        isPublic: isPublic == null ? null : isPublic == '1',
      );
      onMetadata(IcyMetadataMessage(info: null, headers: station));
      await response.addStream(_stripIcyMetadata(origin, interval, (info) {
        onMetadata(IcyMetadataMessage(info: info, headers: station));
      }));
    } else {
      await response.addStream(origin);
    }
  } on Exception {
    if (!sendingBody) response.statusCode = HttpStatus.badGateway;
  } finally {
    client.close(force: true);
    try {
      await response.close();
    } on IOException {
      // WinRT may close the connection when switching sources.
    }
  }
}

final _icyField = RegExp(
  r"(?:^|;)\s*(StreamTitle|StreamUrl)='(.*?)'(?=;|$)",
  caseSensitive: false,
  dotAll: true,
);

Stream<List<int>> _stripIcyMetadata(
  Stream<List<int>> stream,
  int interval,
  void Function(IcyInfoMessage) onMetadata,
) async* {
  var audioRemaining = interval;
  var metadataRemaining = 0;
  final metadata = BytesBuilder();
  await for (final chunk in stream) {
    var cursor = 0;
    while (cursor < chunk.length) {
      if (audioRemaining > 0) {
        final end = min(cursor + audioRemaining, chunk.length);
        yield chunk is Uint8List
            ? Uint8List.sublistView(chunk, cursor, end)
            : chunk.sublist(cursor, end);
        audioRemaining -= end - cursor;
        cursor = end;
      } else if (metadataRemaining == 0) {
        metadataRemaining = chunk[cursor++] * 16;
        if (metadataRemaining == 0) audioRemaining = interval;
      } else {
        final end = min(cursor + metadataRemaining, chunk.length);
        metadata.add(chunk.sublist(cursor, end));
        metadataRemaining -= end - cursor;
        cursor = end;
        if (metadataRemaining == 0) {
          final bytes = metadata.takeBytes();
          final padding = bytes.indexOf(0);
          final unpadded = padding < 0 ? bytes : bytes.sublist(0, padding);
          var value = utf8.decode(unpadded, allowMalformed: true);
          if (value.contains('\uFFFD')) value = latin1.decode(unpadded);
          final fields = {
            for (final match in _icyField.allMatches(value))
              match[1]!.toLowerCase(): match[2],
          };
          if (fields.isNotEmpty) {
            onMetadata(IcyInfoMessage(
              title: fields['streamtitle'],
              url: fields['streamurl'],
            ));
          }
          audioRemaining = interval;
        }
      }
    }
  }
}
