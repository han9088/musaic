import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/features/artwork/source/artwork_source.dart';

void main() {
  test('parses directory artwork and preserves its identity', () {
    final source = ArtworkSource.parse('directory:track%2F123');
    expect(source.type, ArtworkSourceType.directory);
    expect(source.value, 'track%2F123');
    expect(source.identity, 'directory:track%2F123');
    expect(source.isDirectory, isTrue);
  });

  test('parses local placeholders separately from asset paths', () {
    final placeholder = ArtworkSource.parse('local:placeholder');
    expect(placeholder.type, ArtworkSourceType.placeholder);
    expect(placeholder.isPlaceholder, isTrue);

    final asset = ArtworkSource.parse('assets/albums/cover.png');
    expect(asset.type, ArtworkSourceType.asset);
    expect(asset.identity, 'assets/albums/cover.png');
  });

  test('recognizes only valid HTTP artwork URLs as network sources', () {
    final network = ArtworkSource.parse('https://example.com/cover.jpg');
    expect(network.type, ArtworkSourceType.network);
    expect(network.identity, 'https://example.com/cover.jpg');
  });
}
