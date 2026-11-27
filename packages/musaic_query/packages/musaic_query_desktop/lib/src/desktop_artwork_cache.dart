import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;
import 'package:metadata_audio/metadata_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<(int, int, int)> fileStamp(String path) async {
  final stat = await File(path).stat();
  if (stat.type != FileSystemEntityType.file) {
    throw FileSystemException('Audio library file is unavailable', path);
  }
  return (
    stat.size,
    stat.modified.microsecondsSinceEpoch,
    stat.changed.microsecondsSinceEpoch,
  );
}

class DesktopArtworkCache {
  static const _capacity = 512;
  static const _maxBytes = 64 * 1024 * 1024;
  Future<void> _pending = Future.value();
  int _generation = 0;
  int _nextUncached = 0;

  Future<Directory> _directory() async => Directory(
    p.join((await getApplicationCacheDirectory()).path, 'musaic_query_desktop'),
  );

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final task = _pending.then((_) => operation());
    _pending = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }

  Future<String?> read(
    String path,
    String? cover,
    int size, {
    required bool reusable,
  }) => _serialize(() async {
    await (await File(path).open()).close();
    if (cover != null) await (await File(cover).open()).close();
    final audioStamp = await fileStamp(path);
    final coverStamp = cover == null ? null : await fileStamp(cover);
    final key = sha256.convert(
      utf8.encode(
        jsonEncode([
          path,
          audioStamp.toString(),
          cover,
          coverStamp.toString(),
          size,
          _generation,
          if (!reusable)
            '${DateTime.now().microsecondsSinceEpoch}:${++_nextUncached}',
        ]),
      ),
    );
    final directory = await _directory();
    final file = File(p.join(directory.path, '$key.jpg'));
    if (await file.exists()) {
      await file.setLastModified(DateTime.now());
      return file.uri.toString();
    }
    final bytes = await _renderCover(path, cover, size);
    if (await fileStamp(path) != audioStamp ||
        (cover != null && await fileStamp(cover) != coverStamp)) {
      throw FileSystemException('Artwork source changed while reading', path);
    }
    if (bytes == null) return null;
    await directory.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
    await _evict(directory);
    return file.uri.toString();
  });

  Future<void> clear() => _serialize(() async {
    _generation++;
    final directory = await _directory();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Future<void> _evict(Directory directory) async {
    final files = <(File, FileStat)>[];
    var total = 0;
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File || !entry.path.endsWith('.jpg')) continue;
      final stat = await entry.stat();
      files.add((entry, stat));
      total += stat.size;
    }
    if (files.length <= _capacity && total <= _maxBytes) return;
    files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    var count = files.length;
    for (final (file, stat) in files) {
      if (count <= _capacity && total <= _maxBytes) break;
      await file.delete();
      count--;
      total -= stat.size;
    }
  }
}

const _maxImageBytes = 32 * 1024 * 1024;

Future<Uint8List?> _renderCover(String path, String? cover, int size) =>
    Isolate.run(() => _readCover(path, cover, size));

Future<Uint8List?> _readCover(String path, String? cover, int size) async {
  try {
    final metadata = await parseFile(path);
    final pictures = metadata.common.picture ?? const [];
    bool isFront(Picture picture) =>
        picture.type?.toLowerCase().contains('front') ?? false;
    for (final picture in [
      ...pictures.where(isFront),
      ...pictures.where((picture) => !isFront(picture)),
    ]) {
      final encoded = _thumbnail(picture.data, size);
      if (encoded != null) return encoded;
    }
  } on ParseError {
    // The folder image can still provide artwork.
  }
  if (cover == null) return null;
  final file = File(cover);
  if (file.lengthSync() > _maxImageBytes) return null;
  return _thumbnail(file.readAsBytesSync(), size);
}

Uint8List? _thumbnail(List<int> bytes, int size) {
  if (bytes.length > _maxImageBytes) return null;
  try {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final decoder = image.findDecoderForData(data);
    final info = decoder?.startDecode(data);
    if (info == null || info.width * info.height > 32 * 1024 * 1024)
      return null;
    final decoded = decoder!.decodeFrame(0);
    if (decoded == null) return null;
    final resized = decoded.width <= size && decoded.height <= size
        ? decoded
        : decoded.width >= decoded.height
        ? image.copyResize(decoded, width: size)
        : image.copyResize(decoded, height: size);
    return image.encodeJpg(resized, quality: 85);
  } on Exception {
    return null;
  }
}
