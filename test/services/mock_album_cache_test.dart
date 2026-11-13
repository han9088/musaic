import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/services/mock_album_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'catalog and all covers are reused; clear permits warming again',
    () async {
      final cache = MockAlbumCache();
      final catalog = await cache.load();
      expect(identical(catalog, await cache.load()), isTrue);
      final images = <ImageProvider>[];
      Future<void> warm(ImageProvider image) async => images.add(image);
      await cache.warmImages(warm);
      expect(images.length, catalog.length);
      expect(images.toSet().length, catalog.length);
      await cache.warmImages(warm);
      expect(images.length, catalog.length);
      await cache.clear();
      await cache.warmImages(warm);
      expect(images.length, catalog.length * 2);
    },
  );

  test(
    'clearing stops a pending warmup before loading further covers',
    () async {
      final cache = MockAlbumCache();
      final started = Completer<void>();
      final release = Completer<void>();
      var count = 0;
      final warming = cache.warmImages((_) async {
        count++;
        started.complete();
        await release.future;
      });
      await started.future;
      final clearing = cache.clear();
      release.complete();
      await warming;
      await clearing;
      expect(count, 1);
    },
  );
}
