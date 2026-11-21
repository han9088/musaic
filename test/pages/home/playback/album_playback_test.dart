import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/features/music/playback/album_playback.dart';
import 'package:musaic/services/music/music_provider.dart';

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
      (
        reference: _reference('album', MusicKind.album),
        title: 'Album',
        artist: 'Album artist',
        artworkUrl: null,
        trackCount: 2,
        tracks: [first, second],
      ),
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

class _Player extends Fake implements MusicProvider {
  final events = StreamController<MusicPlayback>.broadcast(sync: true);
  int pauses = 0;
  int resumes = 0;

  @override
  Stream<MusicPlayback> get playback => events.stream;

  @override
  Future<void> pause() async => pauses++;

  @override
  Future<void> resume() async => resumes++;

  void emit(MusicReference song, {required bool playing}) => events.add((
    status: playing ? MusicPlaybackStatus.playing : MusicPlaybackStatus.paused,
    currentItem: song,
    position: Duration.zero,
    duration: null,
    isPlaying: playing,
    isBuffering: false,
    error: null,
  ));
}
