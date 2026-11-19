import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/artwork/pipeline/artwork_prefetch_scheduler.dart';

void main() {
  test('prefetch scheduler preserves grid order and deduplicates artwork', () {
    const scheduler = ArtworkPrefetchScheduler();
    final albums = [
      {'asset': 'assets/a.png'},
      {'asset': 'assets/b.png'},
      {'asset': 'assets/c.png'},
    ];
    const rect = Rect.fromLTWH(0, 0, 100, 100);
    final cells = [
      (row: 0, column: 0, rect: rect),
      (row: 0, column: 0, rect: rect),
      (row: 0, column: 1, rect: rect),
      (row: 0, column: 2, rect: rect),
    ];
    final result = scheduler.visibleArtwork(albums, cells);
    expect(result.map((item) => item.source).toList(), [
      'assets/a.png',
      'assets/b.png',
      'assets/c.png',
    ]);
    expect(result.toSet(), hasLength(3));
  });

  test('prefetch scheduler skips placeholders but retains network sources', () {
    const scheduler = ArtworkPrefetchScheduler();
    final albums = [
      {'asset': 'local:missing'},
      {'asset': 'https://example.com/cover.jpg'},
    ];
    const cells = [
      (row: 0, column: 0, rect: Rect.fromLTWH(0, 0, 100, 100)),
      (row: 0, column: 1, rect: Rect.fromLTWH(100, 0, 100, 100)),
    ];
    expect(
      scheduler.visibleArtwork(albums, cells).map((item) => item.source),
      ['https://example.com/cover.jpg'],
    );
  });

  test('prefetch scheduler preserves provider artwork identity', () {
    const scheduler = ArtworkPrefetchScheduler();
    final albums = [
      {'asset': 'https://example.com/cover.jpg', 'id': 'apple:album:123'},
    ];
    const cells = [
      (row: 0, column: 0, rect: Rect.fromLTWH(0, 0, 100, 100)),
    ];
    expect(
      scheduler.visibleArtwork(albums, cells).single.identity?.value,
      'apple:album:123',
    );
  });
}
