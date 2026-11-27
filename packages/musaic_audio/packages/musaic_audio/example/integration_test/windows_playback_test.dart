// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:musaic_audio/musaic_audio.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const timeout = Duration(seconds: 15);

  testWidgets('Windows plays and edits a native queue', (tester) async {
    final directory = await Directory.systemTemp.createTemp('musaic áudio ');
    addTearDown(() => directory.delete(recursive: true));
    final player = AudioPlayer(handleAudioSessionActivation: false);
    addTearDown(player.dispose);
    final asset = await rootBundle.load('audio/nature.mp3');
    final file = await File('${directory.path}\\local track.mp3').writeAsBytes(
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes));
    final source = AudioSource.file(file.path);
    const start = Duration(milliseconds: 300);
    final duration = await player.setAudioSources(
      [
        AudioSource.asset('audio/nature.mp3'),
        source,
        AudioSource.file(file.path),
      ],
      initialIndex: 1,
      initialPosition: start,
    ).timeout(timeout);
    expect(duration, greaterThan(const Duration(seconds: 1)));
    expect(player.currentIndex, 1);
    expect(player.position.inMilliseconds, closeTo(start.inMilliseconds, 100));

    await player.setVolume(0.3);
    await player.setSpeed(1.25);
    var playEnded = false;
    final play = player.play().then((_) => playEnded = true);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(playEnded, isFalse);
    expect(player.position, greaterThanOrEqualTo(start));
    await player.moveAudioSource(0, 2).timeout(timeout);
    await player.currentIndexStream
        .firstWhere((index) => index == 0)
        .timeout(timeout);
    expect(player.sequence.first, same(source));
    expect(player.position, greaterThanOrEqualTo(start));
    await player.pause();
    await play.timeout(timeout);
    expect(player.position, greaterThanOrEqualTo(start));
  }, skip: !Platform.isWindows);

  testWidgets('Windows clips, seeks, and recovers after a load error',
      (tester) async {
    final player = AudioPlayer(handleAudioSessionActivation: false);
    addTearDown(player.dispose);
    final source = AudioSource.asset('audio/nature.mp3');
    await player.setAudioSource(source).timeout(timeout);
    final clip = await player
        .setClip(
          start: const Duration(milliseconds: 500),
          end: const Duration(milliseconds: 1100),
        )
        .timeout(timeout);
    expect(clip?.inMilliseconds, closeTo(600, 30));
    expect(player.position.inMilliseconds, closeTo(0, 30));
    await player.seek(const Duration(milliseconds: 200)).timeout(timeout);
    expect(player.position.inMilliseconds, closeTo(200, 100));
    await player.play().timeout(timeout);
    expect(player.processingState, ProcessingState.completed);
    expect(player.playing, isTrue);

    await player.pause();
    final directory = await Directory.systemTemp.createTemp('musaic áudio ');
    addTearDown(() => directory.delete(recursive: true));
    await expectLater(
      player.setFilePath('${directory.path}\\missing.mp3').timeout(timeout),
      throwsA(isA<PlayerException>()),
    );
    expect(player.processingState, ProcessingState.idle);
    expect(await player.setAudioSource(source).timeout(timeout), isNotNull);
  }, skip: !Platform.isWindows);

  testWidgets('Windows loads byte streams and forwards proxy headers',
      (tester) async {
    final asset = await rootBundle.load('audio/nature.mp3');
    final bytes =
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes);
    final player = AudioPlayer(handleAudioSessionActivation: false);
    addTearDown(player.dispose);
    expect(await player.setAudioSource(_ByteSource(bytes)).timeout(timeout),
        isNotNull);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final authorized = Completer<void>();
    server.listen((request) async {
      final response = request.response;
      if (request.headers.value('x-musaic-test') != 'play') {
        response.statusCode = HttpStatus.forbidden;
      } else {
        if (!authorized.isCompleted) authorized.complete();
        response.headers.contentType = ContentType('audio', 'mpeg');
        response.contentLength = bytes.length;
        if (request.method != 'HEAD') response.add(bytes);
      }
      await response.close();
    });
    final url = 'http://127.0.0.1:${server.port}/audio.mp3';
    expect(
      await player
          .setUrl(url, headers: {'x-musaic-test': 'play'}).timeout(timeout),
      isNotNull,
    );
    await authorized.future.timeout(timeout);
  }, skip: !Platform.isWindows);
}

class _ByteSource extends StreamAudioSource {
  _ByteSource(this.bytes);

  final Uint8List bytes;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final from = start ?? 0;
    final to = (end ?? bytes.length).clamp(from, bytes.length);
    return StreamAudioResponse(
      sourceLength: start == null ? null : bytes.length,
      offset: start,
      contentLength: to - from,
      stream: Stream.value(bytes.sublist(from, to)),
      contentType: 'audio/mpeg',
    );
  }
}
