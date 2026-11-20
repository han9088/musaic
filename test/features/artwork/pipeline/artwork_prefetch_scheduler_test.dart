import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/features/artwork/model/artwork_identity.dart';
import 'package:musaic/features/artwork/model/artwork_request.dart';
import 'package:musaic/features/artwork/pipeline/artwork_prefetch_scheduler.dart';

void main() {
  test('prefetch scheduler deduplicates requests in input order', () {
    const scheduler = ArtworkPrefetchScheduler();
    final requests = [
      const ArtworkRequest(source: 'assets/a.png'),
      const ArtworkRequest(source: 'assets/a.png'),
      const ArtworkRequest(source: 'assets/b.png'),
      const ArtworkRequest(source: 'assets/c.png'),
    ];

    expect(
      scheduler.deduplicate(requests).map((request) => request.source),
      ['assets/a.png', 'assets/b.png', 'assets/c.png'],
    );
  });

  test('prefetch scheduler skips presentation placeholders', () {
    const scheduler = ArtworkPrefetchScheduler();
    final requests = [
      const ArtworkRequest(source: 'local:missing'),
      const ArtworkRequest(source: 'https://example.com/cover.jpg'),
    ];

    expect(
      scheduler.deduplicate(requests).map((request) => request.source),
      ['https://example.com/cover.jpg'],
    );
  });

  test('prefetch scheduler keeps identity and version in request equality', () {
    const scheduler = ArtworkPrefetchScheduler();
    final requests = [
      const ArtworkRequest(
        source: 'https://example.com/cover.jpg',
        identity: ArtworkIdentity('album-1'),
        version: ArtworkVersion('v1'),
      ),
      const ArtworkRequest(
        source: 'https://example.com/cover.jpg',
        identity: ArtworkIdentity('album-1'),
        version: ArtworkVersion('v2'),
      ),
    ];

    expect(scheduler.deduplicate(requests), hasLength(2));
  });
}
