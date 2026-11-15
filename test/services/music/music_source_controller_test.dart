import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/services/music/music_provider.dart';
import 'package:musaic/services/music/music_source_controller.dart';

class _Local extends Fake implements MusicProvider {
  MusicAccess access = MusicAccess.notDetermined;
  MusicAccess granted = MusicAccess.authorized;
  int requests = 0;
  int scans = 0;
  bool disposed = false;
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<void> initialize() async {}
  @override
  Future<MusicAccess> authorizationStatus() async => access;
  @override
  Future<MusicAccess> requestAuthorization() async {
    requests++;
    return granted;
  }

  @override
  Future<MusicPage<ProviderAlbum>> libraryAlbums({
    int limit = 25,
    String? cursor,
  }) async {
    scans++;
    await gate?.future;
    if (fail) throw StateError('scan failed');
    return (items: <ProviderAlbum>[], nextCursor: null);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  test('default mock never creates or requests the local provider', () async {
    var creations = 0;
    final sources = MusicSourceController(
      createLocal: () {
        creations++;
        return _Local();
      },
    );
    expect(sources.catalog.value, isNull);
    expect(creations, 0);
    await sources.selectMock();
    expect(creations, 0);
    await sources.dispose();
  });

  test('mock stays active until scanning succeeds and switching back disposes local', () async {
    final local = _Local()..gate = Completer<void>();
    final sources = MusicSourceController(createLocal: () => local);
    final switching = sources.selectLocal();
    await Future<void>.delayed(Duration.zero);
    expect(local.requests, 1);
    expect(sources.catalog.value, isNull);
    expect(sources.busy.value, isTrue);
    local.gate!.complete();
    await switching;
    expect(sources.catalog.value, isEmpty);
    expect(sources.provider, same(local));
    await sources.selectMock();
    expect(local.disposed, isTrue);
    expect(sources.catalog.value, isNull);
    await sources.dispose();
  });

  test(
    'denial and scan failure retain mock and clean up the candidate',
    () async {
      final local = _Local()..granted = MusicAccess.denied;
      final sources = MusicSourceController(createLocal: () => local);
      await sources.selectLocal();
      expect(local.scans, 0);
      expect(local.disposed, isTrue);
      expect(sources.catalog.value, isNull);
      expect(sources.problem.value, MusicSourceProblem.denied);
      local.granted = MusicAccess.authorized;
      local.fail = true;
      await sources.selectLocal();
      expect(sources.catalog.value, isNull);
      expect(sources.problem.value, MusicSourceProblem.scanFailed);
      await sources.dispose();
    },
  );

  test('disposed controller ignores a pending scan result', () async {
    final local = _Local()..gate = Completer<void>();
    final sources = MusicSourceController(createLocal: () => local);
    final switching = sources.selectLocal();
    await Future<void>.delayed(Duration.zero);
    await sources.dispose();
    local.gate!.complete();
    await switching;
    expect(local.disposed, isTrue);
  });
}
