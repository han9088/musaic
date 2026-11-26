import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class TestBundle extends CachingAssetBundle {
  TestBundle(this.files);
  final Map<String, Uint8List> files;
  final reads = <String, int>{};
  bool failNextLoad = false;

  @override
  Future<ByteData> load(String key) async {
    reads.update(key, (count) => count + 1, ifAbsent: () => 1);
    if (failNextLoad) {
      failNextLoad = false;
      throw StateError('Transient asset failure');
    }
    if (key == 'AssetManifest.bin' || key == 'AssetManifest.bin.json') {
      final manifest = const StandardMessageCodec().encodeMessage({
        for (final asset in files.keys)
          asset: [
            {'asset': asset}
          ],
      })!;
      if (key.endsWith('.json')) {
        return ByteData.sublistView(Uint8List.fromList(utf8.encode(jsonEncode(
            base64Encode(manifest.buffer.asUint8List(
                manifest.offsetInBytes, manifest.lengthInBytes))))));
      }
      return manifest;
    }
    return ByteData.sublistView(files[key]!);
  }
}

Uint8List mp3(String title,
    {String artist = '',
    String album = '',
    String albumArtist = '',
    String genre = '',
    Uint8List? picture}) {
  final frames = BytesBuilder();
  for (final entry in {
    'TIT2': title,
    'TPE1': artist,
    'TPE2': albumArtist,
    'TALB': album,
    'TCON': genre
  }.entries) {
    if (entry.value.isEmpty) continue;
    final text = [0, ...latin1.encode(entry.value)];
    frames
        .add([...ascii.encode(entry.key), 0, 0, 0, text.length, 0, 0, ...text]);
  }
  if (picture != null) {
    final payload = [0, ...ascii.encode('image/png'), 0, 3, 0, ...picture];
    frames.add(
        [...ascii.encode('APIC'), 0, 0, 0, payload.length, 0, 0, ...payload]);
  }
  final payload = frames.takeBytes();
  final length = payload.length;
  return Uint8List.fromList([
    ...ascii.encode('ID3'),
    3,
    0,
    0,
    (length >> 21) & 127,
    (length >> 14) & 127,
    (length >> 7) & 127,
    length & 127,
    ...payload,
    ...List.filled(128, 0),
  ]);
}
