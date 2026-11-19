import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/features/artwork/source/artwork_image_resolver.dart';
import 'package:musaic/features/artwork/source/artwork_network_cache.dart';
import 'package:musaic/features/artwork/source/artwork_source.dart';

void main() {
  test('artwork references distinguish assets, network, directories and placeholders', () {
    final asset = ArtworkSource.parse('assets/albums/one.png');
    final network = ArtworkSource.parse('https://example.com/cover.jpg');
    final directory = ArtworkSource.parse('directory:track%2Fone');
    final placeholder = ArtworkSource.parse('local:missing');

    expect(asset.type, ArtworkSourceType.asset);
    expect(network.type, ArtworkSourceType.network);
    expect(directory.type, ArtworkSourceType.directory);
    expect(directory.value, 'track%2Fone');
    expect(placeholder.type, ArtworkSourceType.placeholder);
  });

  test('network artwork resolves through CachedNetworkImageProvider', () {
    const resolver = ArtworkImageResolver();
    final source = ArtworkSource.parse('https://example.com/cover.jpg');
    final provider = resolver.providerFor(source);

    expect(provider, isA<CachedNetworkImageProvider>());
    final network = provider! as CachedNetworkImageProvider;
    expect(network.url, source.value);
    expect(network.cacheKey, source.cacheKey);
    expect(network.cacheManager, same(ArtworkNetworkCache.instance));
  });

  test('mock assets continue to resolve through AssetImage', () {
    const resolver = ArtworkImageResolver();
    final source = ArtworkSource.parse('assets/albums/mock.png');

    expect(resolver.providerFor(source), isA<AssetImage>());
  });

  test('directory and placeholder references require the directory resolver', () {
    const resolver = ArtworkImageResolver();
    expect(
      resolver.providerFor(ArtworkSource.parse('directory:track-1')),
      isNull,
    );
    expect(
      resolver.providerFor(ArtworkSource.parse('local:missing')),
      isNull,
    );
  });
}
