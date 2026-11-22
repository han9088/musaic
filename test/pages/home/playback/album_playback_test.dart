import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/music/playback/album_playback.dart';
import 'package:musaic/features/music/playback/now_playing_capsule.dart';
import 'package:musaic/features/music/playback/now_playing_controls.dart';
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

ProviderSong _song(String id, String title, String artist) => (
  reference: _reference(id, MusicKind.song),
  title: title,
  artist: artist,
  artworkUrl: null,
  duration: null,
  playable: true,
);

ProviderAlbum _album(List<ProviderSong> tracks) => (
  reference: _reference('album', MusicKind.album),
  title: 'Album',
  artist: 'Album artist',
  artworkUrl: null,
  trackCount: tracks.length,
  tracks: tracks,
);

class _Player extends Fake implements MusicProvider {
  final events = StreamController<MusicPlayback>.broadcast(sync: true);
  int pauses = 0;
  int resumes = 0;
  final skips = <bool>[];
  final seekPositions = <Duration>[];
  late MusicPlayback _state;

  @override
  Stream<MusicPlayback> get playback => events.stream;

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
    Duration position = Duration.zero,
    Duration? duration,
  }) {
    _state = (
      status: playing
          ? MusicPlaybackStatus.playing
          : MusicPlaybackStatus.paused,
      currentItem: song,
      position: position,
      duration: duration,
      isPlaying: playing,
      isBuffering: false,
      error: null,
    );
    events.add(_state);
  }
}
