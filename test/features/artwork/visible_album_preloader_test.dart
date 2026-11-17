import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/artwork/visible_album_preloader.dart';

void main() {
  test('visible preloader preserves grid order and deduplicates assets', () {
    const loader = VisibleAlbumPreloader();
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
    final result = loader.visibleAssets(albums, cells);
    expect(result, hasLength(3));
    expect(result.toSet(), hasLength(3));
  });

  test('visible preloader skips local placeholders', () {
    const loader = VisibleAlbumPreloader();
    final albums = [
      {'asset': 'local:missing'},
    ];
    const cells = [(row: 0, column: 0, rect: Rect.fromLTWH(0, 0, 100, 100))];
    expect(loader.visibleAssets(albums, cells), isEmpty);
  });
}
