import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/features/artwork/cache/artwork_network_cache_manager.dart';
import 'package:musaic/features/artwork/model/artwork_identity.dart';
import 'package:musaic/features/artwork/model/artwork_source.dart';

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

  test('keeps artwork identity stable while source version changes', () {
    final first = ArtworkSource.parse(
      'https://example.com/cover.jpg',
      identity: const ArtworkIdentity('apple:album:123'),
      version: const ArtworkVersion('etag-a'),
    );
    final second = ArtworkSource.parse(
      'https://example.com/cover.jpg',
      identity: const ArtworkIdentity('apple:album:123'),
      version: const ArtworkVersion('etag-b'),
    );

    expect(first.identity, second.identity);
    expect(first.cacheKey, isNot(second.cacheKey));
  });

  test('network cache keys change when an explicit artwork version changes', () {
    final first = ArtworkNetworkCacheManager.cacheKeyFor(
      url: 'https://example.com/cover.jpg',
      identity: 'apple:album:123',
      version: const ArtworkVersion('v1'),
    );
    final second = ArtworkNetworkCacheManager.cacheKeyFor(
      url: 'https://example.com/cover.jpg',
      identity: 'apple:album:123',
      version: const ArtworkVersion('v2'),
    );

    expect(first, isNot(second));
    expect(
      ArtworkNetworkCacheManager.cacheKeyFor(
        url: 'https://example.com/cover.jpg',
        identity: 'https://example.com/cover.jpg',
      ),
      'https://example.com/cover.jpg',
    );
  });
}
