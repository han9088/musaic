import 'dart:async';

import 'package:flutter/rendering.dart' show ImageFilterLayer, RenderBox;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/music/catalog/album_catalog_mapper.dart';
import 'package:musaic/features/music/catalog/album_track_edge_blur.dart';
import 'package:musaic/features/music/catalog/album_track_list.dart';
import 'package:musaic/features/music/playback/album_playback.dart';
import 'package:musaic/features/music/playback/now_playing_capsule.dart';
import 'package:musaic/features/music/playback/now_playing_controls.dart';
import 'package:musaic/features/music/playback/screensaver/now_playing_screensaver.dart';
import 'package:musaic/features/music/playback/screensaver/screensaver_view.dart';
import 'package:musaic/l10n/generated/app_localizations.dart';
import 'package:musaic/services/music/music_provider.dart';
import 'package:musaic/ui/widgets/frosted_control_surface.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

void main() {
  test('browse-only catalog never falls back to simulated playback', () {
    final playback = AlbumPlayback();
    playback.bind(null, const []);
    expect(playback.supportsPlayback, false);
    playback.toggle('directory:track', 'Track');
    expect(playback.playing, false);
    playback.bind(null, null);
    expect(playback.supportsPlayback, true);
    playback.toggle('mock', 'Mock');
    expect(playback.playing, true);
    playback.dispose();
  });

  test('current song follows the queue and toggles the provider', () async {
    final playback = AlbumPlayback();
    final provider = _Player();
    addTearDown(provider.events.close);
    addTearDown(playback.dispose);
    final first = _song('1', 'First song', 'First singer');
    final second = _song('2', 'Second song', 'Second singer');
    playback.bind(provider, [
      _album([first, second]),
    ]);

    provider.emit(first.reference, playing: true);
    expect(playback.currentTitle, 'First song');
    expect(playback.currentArtist, 'First singer');
    expect(playback.isPlaying('local:album', 'Album'), isTrue);
    provider.emit(second.reference, playing: true);
    expect(playback.currentTitle, 'Second song');
    expect(playback.currentArtist, 'Second singer');

    playback.toggleCurrent();
    await Future<void>.delayed(Duration.zero);
    expect(provider.pauses, 1);
    provider.emit(second.reference, playing: false);
    playback.toggleCurrent();
    await Future<void>.delayed(Duration.zero);
    expect(provider.resumes, 1);
    playback.bind(null, null);
    expect(playback.currentTitle, isNull);
    expect(playback.currentArtist, isNull);
  });

  testWidgets(
    'inactivity shows monochrome artwork and live progress through a queue change',
    (tester) async {
      final playback = AlbumPlayback();
      final provider = _Player();
      addTearDown(provider.events.close);
      addTearDown(playback.dispose);
      final first = _song('1', 'First song', 'First singer');
      final second = _song('2', 'Second song', 'Second singer');
      const firstCover = 'assets/albums/0.jpg';
      const secondCover = 'assets/albums/1.jpg';
      playback.bind(provider, [
        _album([first], artwork: firstCover),
        _album([second], id: 'second', artwork: secondCover),
      ]);
      var homeTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: NowPlayingScreensaver(
            playback: playback,
            enabled: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => homeTaps++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

      final screen = find.byType(ScreensaverView);
      await tester.pump(const Duration(minutes: 1));
      expect(screen, findsNothing);
      provider.emit(
        first.reference,
        playing: true,
        position: const Duration(seconds: 42),
        duration: const Duration(minutes: 3, seconds: 1),
      );
      await tester.pump(const Duration(seconds: 59));
      await tester.tapAt(const Offset(100, 100));
      await tester.pump(const Duration(seconds: 59));
      expect(screen, findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('First song'), findsNothing);
      expect(tester.widget<ScreensaverView>(screen).artwork, firstCover);
      expect(
        find.descendant(of: screen, matching: find.byType(ColorFiltered)),
        findsOneWidget,
      );
      expect(find.text('0:42'), findsOneWidget);
      expect(find.text('3:01'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      provider.emit(
        first.reference,
        playing: true,
        position: const Duration(seconds: 43),
        duration: const Duration(minutes: 3, seconds: 1),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('0:43'), findsOneWidget);

      provider.emit(second.reference, playing: false, buffering: true);
      await tester.pump();
      expect(tester.widget<ScreensaverView>(screen).artwork, secondCover);
      expect(find.text('Second song'), findsNothing);
      provider.emit(second.reference, playing: true);
      await tester.pump();
      expect(screen, findsOneWidget);
      await tester.tapAt(const Offset(100, 100));
      await tester.pump();
      expect(screen, findsNothing);
      expect(homeTaps, 1);
      expect(playback.playing, isTrue);
      expect(provider.pauses, 0);

      await tester.pump(const Duration(minutes: 1));
      expect(screen, findsOneWidget);
      provider.emit(second.reference, playing: false);
      await tester.pump();
      expect(screen, findsNothing);
    },
  );

  testWidgets('backgrounding cancels idle entry and a key wakes the screen', (
    tester,
  ) async {
    final playback = AlbumPlayback()..bind(null, null);
    addTearDown(playback.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: NowPlayingScreensaver(
          playback: playback,
          enabled: true,
          child: const SizedBox.expand(),
        ),
      ),
    );

    final screen = find.byType(ScreensaverView);
    playback.toggle('assets/albums/0.jpg', 'Demo');
    await tester.pump(const Duration(seconds: 59));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(minutes: 2));
    expect(screen, findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 59));
    expect(screen, findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(screen, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(screen, findsNothing);
    expect(playback.playing, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'tapping an album track queues the album and highlights playback',
    (tester) async {
      final playback = AlbumPlayback();
      final provider = _Player();
      addTearDown(provider.events.close);
      addTearDown(playback.dispose);
      final first = _song('1', 'First song', 'Singer');
      final unavailable = _song(
        '2',
        'Unavailable song',
        'Singer',
        playable: false,
      );
      final second = _song('3', 'Second song', 'Singer');
      final third = _song('4', 'Third song', 'Singer');
      final albums = [
        _album([first, unavailable, second, third]),
      ];
      playback.bind(provider, albums);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Center(
            child: SizedBox.square(
              dimension: 360,
              child: AlbumTrackList(
                album: mapProviderAlbums(albums).single,
                playback: playback,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Color? textColor(String title) =>
          tester.widget<Text>(find.text(title)).style?.color;
      final accent = textColor('Album artist');
      final unselected = textColor('Second song');
      expect(unselected, isNot(accent));
      expect(find.byType(ShaderMask), findsOneWidget);

      await tester.tap(find.text('Unavailable song'));
      await tester.pump();
      expect(provider.queue, isEmpty);

      await tester.tap(find.text('Second song'));
      await tester.pumpAndSettle();
      expect(provider.queue, [
        first.reference,
        second.reference,
        third.reference,
      ]);
      expect(provider.startIndex, 1);
      expect(playback.currentTrack, second.reference);
      expect(textColor('Second song'), accent);

      provider.emit(third.reference, playing: true);
      await tester.pump();
      expect(textColor('Second song'), unselected);
      expect(textColor('Third song'), accent);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('compact album rows blur as they leave the viewport', (
    tester,
  ) async {
    final album = _album([
      for (var i = 1; i <= 15; i++) _song('$i', 'Song $i', 'Singer'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: SizedBox.square(
            dimension: 360,
            child: AlbumTrackList(album: mapProviderAlbums([album]).single),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = find.text('Song 1');
    final pitch =
        tester.getCenter(find.text('Song 2')).dy - tester.getCenter(title).dy;
    expect(pitch, inExclusiveRange(30, 36));
    final row = tester.renderObject<RenderBox>(
      find.ancestor(of: title, matching: find.byType(AlbumTrackEdgeBlur)),
    );
    final scroller = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(row.debugLayer, isNull);

    scroller.position.jumpTo(12);
    await tester.pump();
    final firstBlur = (row.debugLayer! as ImageFilterLayer).imageFilter;
    expect(firstBlur, isNotNull);
    scroller.position.jumpTo(25);
    await tester.pump();
    expect((row.debugLayer! as ImageFilterLayer).imageFilter, isNot(firstBlur));
    scroller.position.jumpTo(0);
    await tester.pump();
    expect(row.debugLayer, isNull);
  });

  testWidgets('playback pulls skip on release or seek while held', (
    tester,
  ) async {
    final playback = AlbumPlayback();
    final provider = _Player();
    addTearDown(provider.events.close);
    addTearDown(playback.dispose);
    final first = _song('1', 'First song', 'First singer');
    final second = _song('2', 'Second song', 'Second singer');
    playback.bind(provider, [
      _album([first, second]),
    ]);
    const trackDuration = Duration(minutes: 1);
    provider.emit(
      first.reference,
      playing: true,
      position: const Duration(seconds: 15),
      duration: trackDuration,
    );
    var settingsOpens = 0;
    const switchKey = ValueKey('layout-switch');
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: NowPlayingControls(
            playback: playback,
            visible: true,
            onOpenSheet: () => settingsOpens++,
            companionVisible: true,
            companion: FrostedControlSurface(
              visible: true,
              child: IconButton(
                key: switchKey,
                onPressed: () {},
                icon: const Icon(PhosphorIcons.cards),
              ),
            ),
          ),
        ),
      ),
    );

    final capsule = find.byType(NowPlayingCapsule);
    final layoutSwitch = find.byKey(switchKey);
    final layoutSwitchOpacity = find.ancestor(
      of: layoutSwitch,
      matching: find.byType(Opacity),
    );
    double switchOpacity() =>
        tester.widget<Opacity>(layoutSwitchOpacity).opacity;
    final restingBounds = tester.getRect(capsule);
    final restingCenter = restingBounds.center;
    for (final (dx, icon, expectedSkips) in [
      (-56.0, PhosphorIcons.skipBackFill, <bool>[]),
      (56.0, PhosphorIcons.skipForwardFill, [false]),
    ]) {
      final drag = await tester.startGesture(restingCenter);
      await drag.moveBy(Offset(dx.sign * 16, 0));
      await tester.pump();
      expect(layoutSwitch.hitTestable(), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(switchOpacity(), inExclusiveRange(0, 1));

      await drag.moveBy(Offset(dx - dx.sign * 16, 0));
      await tester.pump();
      final feedback = find.widgetWithIcon(IconButton, icon);
      expect(feedback, findsOneWidget);
      expect(provider.skips, expectedSkips);
      await drag.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getCenter(capsule), isNot(restingCenter));
      expect(feedback, findsOneWidget);
      expect(layoutSwitch.hitTestable(), findsNothing);

      for (var frame = 0; frame < 25; frame++) {
        if (tester.getRect(capsule) == restingBounds) break;
        expect(feedback, findsOneWidget);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.getRect(capsule), restingBounds);
      expect(feedback, findsNothing);
      expect(switchOpacity(), 0);
      expect(layoutSwitch.hitTestable(), findsNothing);
      expect(
        find.widgetWithIcon(IconButton, PhosphorIcons.pauseFill),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 999));
      expect(switchOpacity(), 0);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(switchOpacity(), inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(switchOpacity(), 1);
      expect(layoutSwitch.hitTestable(), findsOneWidget);
    }
    expect(provider.skips, [false, true]);
    expect(provider.seekPositions, isEmpty);

    final fastForward = await tester.startGesture(tester.getCenter(capsule));
    await fastForward.moveBy(const Offset(56, 0));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byIcon(PhosphorIcons.fastForwardFill), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(provider.seekPositions, const [
      Duration(seconds: 20),
      Duration(seconds: 25),
    ]);
    await fastForward.up();
    await tester.pump();
    expect(find.byIcon(PhosphorIcons.fastForwardFill), findsOneWidget);
    for (var frame = 0; frame < 32; frame++) {
      if (tester.getRect(capsule) == restingBounds) break;
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.getRect(capsule), restingBounds);
    expect(find.byIcon(PhosphorIcons.fastForwardFill), findsNothing);
    await tester.pump(const Duration(milliseconds: 950));
    expect(switchOpacity(), 0);

    provider.emit(
      first.reference,
      playing: true,
      position: const Duration(seconds: 3),
      duration: trackDuration,
    );
    final rewind = await tester.startGesture(tester.getCenter(capsule));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(switchOpacity(), 0);
    expect(layoutSwitch.hitTestable(), findsNothing);
    await rewind.moveBy(const Offset(-56, 0));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byIcon(PhosphorIcons.rewindFill), findsOneWidget);
    expect(provider.seekPositions.last, Duration.zero);
    await rewind.cancel();
    await tester.pump();
    expect(find.byIcon(PhosphorIcons.rewindFill), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byIcon(PhosphorIcons.rewindFill), findsNothing);
    expect(provider.seekPositions, hasLength(3));
    expect(provider.skips, [false, true]);
    expect(settingsOpens, 0);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(switchOpacity(), 1);
    final pullUp = await tester.startGesture(restingCenter);
    await pullUp.moveBy(const Offset(0, -8));
    await tester.pump();
    expect(layoutSwitch.hitTestable(), findsNothing);
    await pullUp.moveBy(const Offset(0, -132));
    await tester.pump(const Duration(milliseconds: 100));
    expect(switchOpacity(), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(switchOpacity(), 0);
    expect(settingsOpens, 0);
    await pullUp.up();
    await tester.pumpAndSettle();
    expect(settingsOpens, 1);
    expect(switchOpacity(), 0);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(switchOpacity(), 1);
  });
}

MusicReference _reference(String id, MusicKind kind) => (
  provider: 'local',
  id: id,
  kind: kind,
  source: MusicSource.library,
  storefront: null,
);

ProviderSong _song(
  String id,
  String title,
  String artist, {
  bool playable = true,
}) => (
  reference: _reference(id, MusicKind.song),
  title: title,
  artist: artist,
  artworkUrl: null,
  duration: null,
  playable: playable,
);

ProviderAlbum _album(
  List<ProviderSong> tracks, {
  String id = 'album',
  String? artwork,
}) => (
  reference: _reference(id, MusicKind.album),
  title: 'Album',
  artist: 'Album artist',
  artworkUrl: artwork,
  trackCount: tracks.length,
  tracks: tracks,
);

class _Player extends Fake implements MusicProvider {
  final events = StreamController<MusicPlayback>.broadcast(sync: true);
  List<MusicReference> queue = const [];
  int? startIndex;
  int pauses = 0;
  int resumes = 0;
  final skips = <bool>[];
  final seekPositions = <Duration>[];
  late MusicPlayback _state;

  @override
  Stream<MusicPlayback> get playback => events.stream;

  @override
  Future<void> play(List<MusicReference> items, {int startIndex = 0}) async {
    queue = List.of(items);
    this.startIndex = startIndex;
    emit(queue[startIndex], playing: true);
  }

  @override
  Future<void> pause() async => pauses++;

  @override
  Future<void> resume() async => resumes++;

  @override
  Future<void> next() async => skips.add(true);

  @override
  Future<void> previous() async => skips.add(false);

  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
    emit(
      _state.currentItem!,
      playing: _state.isPlaying,
      position: position,
      duration: _state.duration,
    );
  }

  void emit(
    MusicReference song, {
    required bool playing,
    bool buffering = false,
    Duration position = Duration.zero,
    Duration? duration,
  }) {
    _state = (
      status: playing
          ? MusicPlaybackStatus.playing
          : buffering
          ? MusicPlaybackStatus.buffering
          : MusicPlaybackStatus.paused,
      currentItem: song,
      position: position,
      duration: duration,
      isPlaying: playing,
      isBuffering: buffering,
      error: null,
    );
    events.add(_state);
  }
}
