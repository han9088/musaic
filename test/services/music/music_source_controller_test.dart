import 'dart:async';

import 'package:audius_sdk/audius_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/canvas/album_canvas_viewport.dart';
import 'package:musaic/features/music/presentation/music_source_picker.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/pages/home/home_page.dart';
import 'package:musaic/services/mock_album_cache.dart';
import 'package:musaic/services/music/directory_music_library.dart';
import 'package:musaic/services/music/music_provider.dart';
import 'package:musaic/services/music/music_source_controller.dart';
import 'package:musaic/storage/music/music_index.dart';
import 'package:musaic/ui/theme/app_theme.dart';
import 'package:musaic_query/musaic_query.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_audio_directories.dart';

class _Local extends Fake implements MusicProvider {
  _Local({this.items = const []});

  final List<ProviderAlbum> items;

  @override
  String get id => 'local';

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
    return (items: items, nextCursor: null);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class _Audius extends Fake implements MusicProvider {
  _Audius({this.items = const [], this.error, this.failInitialize = false});

  static const ProviderAlbum sampleAlbum = (
    reference: (
      provider: 'audius',
      id: 'album',
      kind: MusicKind.album,
      source: MusicSource.catalog,
      storefront: null,
    ),
    title: 'Album',
    artist: null,
    artworkUrl: null,
    trackCount: 2,
    tracks: null,
  );

  final List<ProviderAlbum> items;
  final Object? error;
  final bool failInitialize;
  int initialized = 0;
  bool disposed = false;
  Completer<void>? gate;

  @override
  Stream<MusicPlayback> get playback => const Stream.empty();

  @override
  String get id => 'audius';

  @override
  Future<void> initialize() async {
    initialized++;
    if (failInitialize) throw StateError('Audius initialization failed');
  }

  @override
  Future<MusicPage<ProviderAlbum>> libraryAlbums({
    int limit = 25,
    String? cursor,
  }) async {
    expect(limit, 24);
    await gate?.future;
    if (error case final failure?) throw failure;
    return (items: items, nextCursor: null);
  }

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  testWidgets('folder actions are available after selecting Local music', (
    tester,
  ) async {
    final local = _Local(
      items: [
        for (final count in [2, 1])
          (
            reference: (
              provider: 'local',
              id: 'album-$count',
              kind: MusicKind.album,
              source: MusicSource.library,
              storefront: null,
            ),
            title: 'Collection $count',
            artist: null,
            artworkUrl: null,
            trackCount: count,
            tracks: null,
          ),
      ],
    );
    final sources = MusicSourceController(createLocal: () => local);
    addTearDown(sources.dispose);
    sqfliteFfiInit();
    await tester.runAsync(() async {
      final index = await MusicIndex.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final library = DirectoryMusicLibrary(
        index: index,
        directories: AudioDirectories(FakeDirectories()),
      );
      addTearDown(library.dispose);
      await index.saveSource(root);
      await library.loadCached();
      await sources.attachDirectories(library);
    });
    Future<void>? selection;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MusicSourcePicker(
            sources: sources,
            onSourceSelection: (select) => selection = select(),
          ),
        ),
      ),
    );

    final entry = find.byKey(const ValueKey('music-source-local'));
    final folderName = find.text(root.name);
    final add = find.text('Add folder');
    final rescan = find.text('Rescan');
    expect(local.scans, 0);
    expect(folderName, findsNothing);
    expect(add, findsNothing);
    expect(rescan, findsNothing);
    await tester.runAsync(() async {
      await tester.tap(entry);
      await selection;
    });
    await tester.pumpAndSettle();
    expect(local.scans, 1);
    expect(tester.widget<ListTile>(entry).selected, isTrue);
    expect(find.text('1 album · 1 single'), findsOneWidget);
    expect(folderName, findsOneWidget);
    expect(add, findsOneWidget);
    expect(rescan, findsOneWidget);
    expect(find.byIcon(PhosphorIcons.arrowsClockwise), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.folderSimplePlus), findsOneWidget);
    expect(
      tester.getCenter(rescan).dy,
      lessThan(tester.getCenter(folderName).dy),
    );
    expect(tester.getCenter(rescan).dy, tester.getCenter(add).dy);
    expect(tester.getCenter(rescan).dx, lessThan(tester.getCenter(add).dx));
    expect(find.text('Rescan all files'), findsNothing);
    expect(find.text('Restore folder access'), findsNothing);
    expect(find.byTooltip('Remove from library'), findsNothing);
  });

  test(
    'saved folders can be selected even when system access is denied',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      sqfliteFfiInit();
      final index = await MusicIndex.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final native = FakeDirectories();
      final library = DirectoryMusicLibrary(
        index: index,
        directories: AudioDirectories(native),
      );
      final local = _Local()..granted = MusicAccess.denied;
      final sources = MusicSourceController(createLocal: () => local);
      addTearDown(library.dispose);
      addTearDown(sources.dispose);
      await index.saveSource(root);
      await library.refresh();
      await sources.attachDirectories(library);

      await sources.selectLocal();

      expect(local.scans, 0);
      expect(sources.localSelected.value, isTrue);
      expect(sources.catalog.value!.single.trackCount, 2);
      expect(native.closes, 1);

      native.folders[root.id]!.add(entry('new-song'));
      await sources.rescanLocal();
      expect(local.requests, 1);
      expect(sources.catalog.value!.single.trackCount, 3);
      expect(native.closes, 2);
    },
  );

  test('system library and folder imports stay selected together', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    final index = await MusicIndex.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final native = FakeDirectories();
    const saved = AudioDirectory(id: 'saved', name: 'Saved', token: 'grant');
    native.folders[saved.id] = [entry('saved-song', parent: saved.id)];
    final library = DirectoryMusicLibrary(
      index: index,
      directories: AudioDirectories(native),
    );
    final systemAlbum = (
      reference: (
        provider: 'local',
        id: 'system-album',
        kind: MusicKind.album,
        source: MusicSource.library,
        storefront: null,
      ),
      title: 'System album',
      artist: null,
      artworkUrl: null,
      trackCount: 0,
      tracks: const <ProviderSong>[],
    );
    final local = _Local(items: [systemAlbum]);
    final rescanned = _Local(items: [systemAlbum]);
    final providers = [local, rescanned].iterator;
    final sources = MusicSourceController(
      createLocal: () {
        providers.moveNext();
        return providers.current;
      },
    );
    addTearDown(library.dispose);
    addTearDown(sources.dispose);
    await index.saveSource(saved);
    await library.refresh();
    native.parsed.clear();
    await sources.attachDirectories(library);
    await sources.selectDirectories(add: true);
    expect(native.picks, 0);
    await sources.selectLocal();
    expect(await index.isSelected(), isFalse);
    await sources.selectDirectories(add: true);
    expect(native.picks, 1);
    expect(native.closes, 2);
    expect(native.parsed, ['a', 'b']);
    expect(local.scans, 1);
    expect(sources.provider, same(local));
    expect(local.disposed, isFalse);
    expect(sources.catalog.value!.map((album) => album.reference.provider), [
      'local',
      'directory',
      'directory',
    ]);

    await sources.rescanLocal();
    expect(sources.provider, same(rescanned));
    expect(sources.catalog.value, hasLength(3));
    expect(native.closes, 4);
    expect(native.parsed, ['a', 'b']);
    expect(
      (await index.sources()).map((source) => source.id),
      unorderedEquals([root.id, saved.id]),
    );
    expect(await index.isSelected(), isTrue);
    expect(await index.selectedSource(), MusicIndexSource.systemAndDirectories);
    final restoredProvider = _Local(items: local.items)
      ..access = MusicAccess.authorized;
    final restored = MusicSourceController(
      restoreOnStartup: true,
      createLocal: () => restoredProvider,
    );
    addTearDown(restored.dispose);
    await restored.attachDirectories(library);
    expect(restored.startup.value, MusicSourceStartup.ready);
    expect(restored.catalog.value, hasLength(3));
    expect(restoredProvider.requests, 0);
  });

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
    await sources.selectMock2();
    expect(sources.catalog.value, isNull);
    expect(sources.mock2Selected.value, isTrue);
    expect(creations, 0);
    await sources.selectMock();
    expect(sources.mock2Selected.value, isFalse);
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

  test('Audius loads before transition and releases the old provider after activation', () async {
    final local = _Local();
    final audius = _Audius(items: [_Audius.sampleAlbum])
      ..gate = Completer<void>();
    final sources = MusicSourceController(
      createLocal: () => local,
      createAudius: () => audius,
    );
    addTearDown(sources.dispose);
    await sources.selectLocal();
    final catalog = sources.catalog.value;
    var transitions = 0;
    final selecting = sources.selectAudius(
      transition: (activate) async {
        transitions++;
        expect(sources.provider, same(local));
        expect(local.disposed, isFalse);
        await activate();
      },
    );
    await Future<void>.delayed(Duration.zero);
    expect(sources.audiusLoading.value, isTrue);
    expect(sources.catalog.value, same(catalog));
    await sources.selectAudius();
    expect(audius.initialized, 1);
    audius.gate!.complete();
    await selecting;
    expect(transitions, 1);
    expect(sources.audiusLoading.value, isFalse);
    expect(local.disposed, isTrue);
    expect(sources.audiusSelected, isTrue);
    expect(sources.catalog.value, [_Audius.sampleAlbum]);
    await sources.selectMock2();
    expect(audius.disposed, isTrue);
    expect(sources.mock2Selected.value, isTrue);
    expect(sources.catalog.value, isNull);
  });

  test('empty, initialization and network failures leave the current source intact', () async {
    final cases = [
      (_Audius(), MusicSourceProblem.audiusEmpty),
      (_Audius(failInitialize: true), MusicSourceProblem.audiusUnavailable),
      (
        _Audius(error: TimeoutException('offline')),
        MusicSourceProblem.audiusUnavailable,
      ),
      (
        _Audius(
          error: AudiusApiException(
            statusCode: 429,
            message: 'limited',
            requestUri: Uri.https('api.audius.co'),
          ),
        ),
        MusicSourceProblem.audiusRateLimited,
      ),
    ];
    final local = _Local();
    var index = 0;
    final sources = MusicSourceController(
      createLocal: () => local,
      createAudius: () => cases[index].$1,
    );
    addTearDown(sources.dispose);
    await sources.selectLocal();
    final catalog = sources.catalog.value;
    for (final (candidate, problem) in cases) {
      await sources.selectAudius(
        transition: (_) async => fail('Transitioned on failure'),
      );
      expect(candidate.disposed, isTrue);
      expect(sources.problem.value, problem);
      expect(sources.provider, same(local));
      expect(sources.catalog.value, same(catalog));
      expect(sources.busy.value, isFalse);
      expect(local.disposed, isFalse);
      index++;
    }
  });

  test(
    'Audius uses the existing index to restore and clear its selection',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      sqfliteFfiInit();
      final index = await MusicIndex.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final library = DirectoryMusicLibrary(
        index: index,
        directories: AudioDirectories(FakeDirectories()),
      );
      final first = MusicSourceController(
        createAudius: () => _Audius(items: [_Audius.sampleAlbum]),
      );
      final restored = MusicSourceController(
        createAudius: () => _Audius(error: TimeoutException('offline')),
      );
      addTearDown(library.dispose);
      addTearDown(first.dispose);
      addTearDown(restored.dispose);

      await first.attachDirectories(library);
      await first.selectAudius();
      expect(await index.selectedSource(), MusicIndexSource.audius);
      expect(await index.readAudiusCatalog(), [_Audius.sampleAlbum]);
      await first.dispose();

      await restored.attachDirectories(library);
      await Future<void>.delayed(Duration.zero);
      expect(restored.audiusSelected, isTrue);
      expect(restored.catalog.value, [_Audius.sampleAlbum]);
      expect(restored.problem.value, isNull);
      await restored.selectMock();
      expect(await index.selectedSource(), MusicIndexSource.none);
      await restored.selectMock2();
      final nextLaunch = MusicSourceController(restoreOnStartup: true);
      addTearDown(nextLaunch.dispose);
      await nextLaunch.attachDirectories(library);
      expect(nextLaunch.startup.value, MusicSourceStartup.ready);
      expect(nextLaunch.mock2Selected.value, isTrue);
    },
  );

  testWidgets(
    'cold Audius startup shows the saved canvas before network refresh',
    (tester) async {
      final ProviderAlbum fresh = (
        reference: _Audius.sampleAlbum.reference,
        title: 'Refreshed album',
        artist: null,
        artworkUrl: null,
        trackCount: 2,
        tracks: null,
      );
      final network = Completer<void>();
      final audius = _Audius(items: [fresh])..gate = network;
      final sources = MusicSourceController(
        restoreOnStartup: true,
        createAudius: () => audius,
      );
      addTearDown(sources.dispose);
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: HomePage(albumCache: MockAlbumCache(), sources: sources),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final canvas = find.byType(AlbumCanvasViewport);
      expect(canvas, findsNothing);

      sqfliteFfiInit();
      late MusicIndex index;
      await tester.runAsync(() async {
        index = await MusicIndex.open(
          factory: databaseFactoryFfi,
          path: inMemoryDatabasePath,
        );
        final library = DirectoryMusicLibrary(
          index: index,
          directories: AudioDirectories(FakeDirectories()),
        );
        addTearDown(library.dispose);
        await index.setAudiusSelected();
        await index.saveAudiusCatalog([_Audius.sampleAlbum]);
        await sources.attachDirectories(library);
      });
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<AlbumCanvasViewport>(canvas).albums.single['title'],
        'Album',
      );
      expect(network.isCompleted, isFalse);
      expect(sources.provider, same(audius));

      await tester.runAsync(() async {
        final refreshed = Completer<void>();
        final stop = sources.catalog.subscribe((albums) {
          if (albums?.single == fresh) refreshed.complete();
        });
        try {
          network.complete();
          await refreshed.future;
          expect(await index.readAudiusCatalog(), [fresh]);
        } finally {
          stop();
        }
      });
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<AlbumCanvasViewport>(canvas).albums.single['title'],
        'Refreshed album',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Audius picker shows loading and errors without dismissing on failure',
    (tester) async {
      final failed = _Audius(error: TimeoutException('offline'))
        ..gate = Completer<void>();
      final ready = _Audius(items: [_Audius.sampleAlbum]);
      var creations = 0;
      final sources = MusicSourceController(
        createAudius: () => creations++ == 0 ? failed : ready,
      );
      final switching = ValueNotifier(false);
      final artworkReady = Completer<void>();
      final preparedAlbums = <ProviderAlbum>[];
      addTearDown(sources.dispose);
      addTearDown(switching.dispose);
      var transitions = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildSettingsContentTheme(ThemeData()),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MusicSourcePicker(
              sources: sources,
              sourceSwitching: switching,
              prepareAudiusArtwork: (albums) {
                preparedAlbums.addAll(albums);
                return artworkReady.future;
              },
              onSourceSelection: (activate) async {
                transitions++;
                await activate();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('music-source-audius'));
      final mock = find.byKey(const ValueKey('music-source-mock'));
      Color? mockTitleColor() => tester
          .widget<RichText>(
            find.descendant(
              of: mock,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is RichText &&
                    widget.text.toPlainText() ==
                        AppLocalizations.of(tester.element(mock))
                            .musicSourceMock,
              ),
            ),
          )
          .text
          .style
          ?.color;

      final local = find.byKey(const ValueKey('music-source-local'));
      Color? leadingColor(Finder tile) => IconTheme.of(
        tester.element(find.descendant(of: tile, matching: find.byType(Icon))),
      ).color;
      final mockIconColor = leadingColor(mock);
      final localIconColor = leadingColor(local);

      final titleColor = mockTitleColor();
      await tester.tap(row);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(mockTitleColor(), titleColor);
      expect(leadingColor(mock), mockIconColor);
      expect(leadingColor(local), localIconColor);
      expect(tester.widget<ListTile>(mock).onTap, isNull);
      expect(tester.widget<ListTile>(local).onTap, isNull);
      expect(
        find.descendant(
          of: row,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      failed.gate!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Couldn’t load Audius. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(transitions, 0);
      expect(preparedAlbums, isEmpty);

      await tester.tap(row);
      await tester.pump();
      expect(preparedAlbums, [_Audius.sampleAlbum]);
      expect(transitions, 0);
      expect(sources.audiusSelected, isFalse);
      expect(
        find.descendant(
          of: row,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      artworkReady.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<ListTile>(row).selected, isTrue);
      expect(transitions, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
