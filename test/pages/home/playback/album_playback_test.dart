import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/features/music/playback/album_playback.dart';

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
}
