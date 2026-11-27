import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:musaic_query/musaic_query.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
      home: Scaffold(body: Center(child: Text('Directory smoke test')))));
  try {
    await smoke();
    debugPrint('MUSAIC_DIRECTORY_SMOKE_PASS');
  } catch (error, stack) {
    debugPrint('MUSAIC_DIRECTORY_SMOKE_FAIL: $error\n$stack');
  }
}

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> smoke() async {
  final plugin = MusaicQuery().directories;
  check(await plugin.supported, 'directory support');
  final folder = await Directory.systemTemp.createTemp('musaic-smoke-');
  final data = ByteData(44 + 16000);
  void ascii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 16036, Endian.little);
  ascii(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 8000, Endian.little);
  data.setUint32(28, 16000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, 16000, Endian.little);
  final audio = File('${folder.path}/tone.wav');
  await audio.writeAsBytes(data.buffer.asUint8List());
  final sub = await Directory('${folder.path}/Sub').create();
  await File('${sub.path}/child.wav').writeAsBytes(data.buffer.asUint8List());
  try {
    await Link('${folder.path}/cycle').create(folder.path);
  } on FileSystemException {
    if (!Platform.isWindows) rethrow;
  }
  for (var i = 0; i < 260; i++) {
    await File('${folder.path}/ignore$i.txt').writeAsString('ignore');
  }
  await File('${folder.path}/cover.png').writeAsBytes(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEElEQVR4nGM4xOAARAwQCgAeTgQJ9eMRdgAAAABJRU5ErkJggg=='));
  // Generated silent AAC fixture with real iTunes title/album/track/disc tags.
  await File('${folder.path}/tagged.m4a').writeAsBytes(base64Decode(
    'AAAAHGZ0eXBNNEEgAAACAE00QSBpc29taXNvMgAAAAhmcmVlAAAAIW1kYXTeAgBMYXZjNjIuMjguMTAxAAIwQA4BGCAHAAAD+21vb3YAAABsbXZoZAAAAAAAAAAAAAAAAAAAA+gAAABkAAEAAAEAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAItdHJhawAAAFx0a2hkAAAAAwAAAAAAAAAAAAAAAQAAAAAAAABkAAAAAAAAAAAAAAABAQAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAJGVkdHMAAAAcZWxzdAAAAAAAAAABAAAAZAAABAAAAQAAAAABpW1kaWEAAAAgbWRoZAAAAAAAAAAAAAAAAAAAH0AAAAcgVcQAAAAAAC1oZGxyAAAAAAAAAABzb3VuAAAAAAAAAAAAAAAAU291bmRIYW5kbGVyAAAAAVBtaW5mAAAAEHNtaGQAAAAAAAAAAAAAACRkaW5mAAAAHGRyZWYAAAAAAAAAAQAAAAx1cmwgAAAAAQAAARRzdGJsAAAAanN0c2QAAAAAAAAAAQAAAFptcDRhAAAAAAAAAAEAAAAAAAAAAAABABAAAAAAH0AAAAAAADZlc2RzAAAAAAOAgIAlAAEABICAgBdAFQAAAAAAu4AAAANtBYCAgAUViFblAAaAgIABAgAAACBzdHRzAAAAAAAAAAIAAAABAAAEAAAAAAEAAAMgAAAAHHN0c2MAAAAAAAAAAQAAAAEAAAACAAAAAQAAABxzdHN6AAAAAAAAAAAAAAACAAAAFQAAAAQAAAAUc3RjbwAAAAAAAAABAAAALAAAABpzZ3BkAQAAAHJvbGwAAAACAAAAAf//AAAAHHNiZ3AAAAAAcm9sbAAAAAEAAAACAAAAAQAAAVp1ZHRhAAABUm1ldGEAAAAAAAAAIWhkbHIAAAAAAAAAAG1kaXJhcHBsAAAAAAAAAAAAAAABJWlsc3QAAAAlqW5hbQAAAB1kYXRhAAAAAQAAAABGaXh0dXJlIHRpdGxlAAAAJqlBUlQAAAAeZGF0YQAAAAEAAAAARml4dHVyZSBhcnRpc3QAAAAsYUFSVAAAACRkYXRhAAAAAQAAAABGaXh0dXJlIGFsYnVtIGFydGlzdAAAACWpYWxiAAAAHWRhdGEAAAABAAAAAEZpeHR1cmUgYWxidW0AAAAlqXRvbwAAAB1kYXRhAAAAAQAAAABMYXZmNjIuMTIuMTAxAAAAHKlnZW4AAAAUZGF0YQAAAAEAAAAASmF6egAAACB0cmtuAAAAGGRhdGEAAAAAAAAAAAAAAAMADAAAAAAAIGRpc2sAAAAYZGF0YQAAAAAAAAAAAAAAAgADAAA=',
  ));
  final root = await plugin.restore(await plugin.openPath(folder.path));
  final pages = await plugin.scan(root).toList();
  check(pages.every((p) => p.error == null), 'enumeration error');
  final files = pages.expand((p) => p.entries).toList();
  check(files.where((f) => f.isAudio).length == 3, 'recursive audio count');
  check(!files.any((f) => f.name == 'cycle'), 'symbolic cycle skipped');
  final tagged = await plugin.metadata(
      root, files.firstWhere((f) => f.name == 'tagged.m4a'));
  check(tagged['title'] == 'Fixture title', 'real AAC title');
  check(
      tagged['albumArtist'] == 'Fixture album artist', 'real AAC album artist');
  check((tagged['track'] as String).split('/').first == '3', 'real AAC track');
  check((tagged['disc'] as String).split('/').first == '2', 'real AAC disc');
  final one = files.firstWhere((f) => f.name == 'tone.wav');
  final tags = await plugin.metadata(root, one);
  check((tags['durationMs'] as int) > 900, 'real WAV metadata');
  if (Platform.isMacOS || Platform.isWindows) {
    final playback = await plugin.openPlayback(root, one);
    try {
      check(await File.fromUri(playback.uri).length() == await audio.length(),
          'local playback URI can be read');
    } finally {
      await playback.close();
    }
  }
  final cover = files.firstWhere((f) => f.coverPriority != null);
  final art = await plugin.artwork(root, one, cover: cover, size: 64);
  check(art != null && await File.fromUri(Uri.parse(art)).exists(),
      'folder cover extraction');
  check(await plugin.artwork(root, one, cover: cover, size: 64) == art,
      'stable cache identity');
  final coverFile = File('${folder.path}/cover.png');
  await coverFile.setLastModified(
      (await coverFile.lastModified()).add(const Duration(seconds: 5)));
  final changed = await plugin.artwork(root, one, cover: cover, size: 64);
  check(changed != null && changed != art,
      'stale enumerated cover stamp revalidated');
  final unreliable = AudioFileEntry({...one.data, 'reliable': false});
  final unknown1 =
      await plugin.artwork(root, unreliable, cover: cover, size: 64);
  final unknown2 =
      await plugin.artwork(root, unreliable, cover: cover, size: 64);
  check(unknown1 != null && unknown2 != null && unknown1 != unknown2,
      'unreliable stamps do not reuse decoded-image paths');
  await plugin.clearArtworkCache();
  final cleared = await plugin.artwork(root, one, cover: cover, size: 64);
  check(cleared != null && cleared != changed,
      'clear cache invalidates decoded-image path');
  final coverBytes = await coverFile.readAsBytes();
  await coverFile.delete();
  check(await plugin.artwork(root, one, cover: cover, size: 64) == null,
      'deleted cover does not hit old cache');
  await coverFile.writeAsBytes(coverBytes);
  if (Platform.isIOS) {
    try {
      await const MethodChannel('com.deskbtm.muasic.query').invokeMethod(
          'queryWithFilters', {'withType': 3, 'args': 3, 'argsVal': 'invalid'});
      throw StateError('invalid native filter accepted');
    } on PlatformException catch (error) {
      check(
          error.code == 'InvalidArguments' ||
              error.code == 'MissingPermissions',
          'native filter rejects invalid input');
    }
  }
  final cacheDirectory = File.fromUri(Uri.parse(art!)).parent;
  for (var i = 0; i < 520; i++) {
    await File('${cacheDirectory.path}/fixture$i.jpg')
        .writeAsString('cache fixture');
  }
  await plugin.artwork(root, one, cover: cover, size: 65);
  check(await cacheDirectory.list().length <= 512, 'cache entry bound');
  await plugin.clearArtworkCache();
  check(!await File.fromUri(Uri.parse(art)).exists(), 'cache removed');
  check(await audio.exists(), 'source remains');
  final direct = await plugin
      .scan(root, options: const AudioScanOptions(recursive: false))
      .toList();
  check(direct.expand((p) => p.entries).where((e) => e.isAudio).length == 2,
      'nonrecursive');
  for (var i = 0; i < 20; i++) {
    final cancellation = AudioScanCancellation();
    await for (final _ in plugin.scan(root, cancellation: cancellation)) {
      cancellation.cancel();
    }
  }
  await plugin.release(root);
  await folder.delete(recursive: true);
}
