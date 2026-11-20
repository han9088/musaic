import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musaic/features/artwork/model/artwork_identity.dart';
import 'package:musaic/features/artwork/model/artwork_resource.dart';
import 'package:musaic/features/artwork/xerox/xerox_raster_request.dart';
import 'package:musaic/features/artwork/xerox/xerox_visible_artwork_planner.dart';

void main() {
  test('planner prioritizes selected and visible tiles before overscan', () async {
    const viewport = Size(200, 200);
    final cells = [
      (row: 0, column: 0, rect: const Rect.fromLTWH(10, 10, 40, 40)),
      (row: 1, column: 1, rect: const Rect.fromLTWH(80, 80, 40, 40)),
      (row: 2, column: 2, rect: const Rect.fromLTWH(240, 240, 40, 40)),
      (row: 3, column: 3, rect: const Rect.fromLTWH(100, 100, 40, 40)),
    ];
    final assets = {
      (0, 0): 'far',
      (1, 1): 'center',
      (2, 2): 'overscan',
      (3, 3): 'center',
    };

    final requests = await const XeroxVisibleArtworkPlanner().build(
      cells: cells,
      viewport: viewport,
      scale: 1,
      tileExtent: 100,
      devicePixelRatio: 1,
      assetAt: (row, column) => assets[(row, column)]!,
      identityAt: (row, column) =>
          row == 1 ? const ArtworkIdentity('album-center') : null,
      resolveArtwork: (request) async {
        final provider = AssetImage('assets/${request.source}.png');
        return ArtworkResource(
          identity: request.identity?.value ?? request.source,
          sourceKey: provider.toString(),
          image: provider,
        );
      },
      selectedAsset: 'selected',
      selectedIdentity: const ArtworkIdentity('album-selected'),
    );

    expect(requests.map((request) => request.identity).toList(), [
      'album-selected',
      'album-center',
      'far',
      'overscan',
    ]);
    expect(
      requests.map((request) => request.priority).toList(),
      [
        XeroxRasterPriority.selected,
        XeroxRasterPriority.visible,
        XeroxRasterPriority.visible,
        XeroxRasterPriority.overscan,
      ],
    );
    expect(requests.map((request) => request.key).toSet(), hasLength(4));
  });

  test('planner stops resolving artwork after its owner is disposed', () async {
    var active = true;
    var resolved = 0;
    final cells = [
      for (var i = 0; i < 8; i++)
        (
          row: i,
          column: 0,
          rect: Rect.fromLTWH(0, i * 100, 100, 100),
        ),
    ];

    await expectLater(
      const XeroxVisibleArtworkPlanner(maxProviderConcurrency: 1).build(
        cells: cells,
        viewport: const Size(100, 100),
        scale: 1,
        tileExtent: 100,
        devicePixelRatio: 1,
        assetAt: (row, column) => 'asset-$row',
        resolveArtwork: (request) async {
          resolved++;
          active = false;
          final provider = AssetImage('assets/${request.source}.png');
          return ArtworkResource(
            identity: request.identity?.value ?? request.source,
            sourceKey: provider.toString(),
            image: provider,
          );
        },
        isActive: () => active,
      ),
      throwsA(isA<StateError>()),
    );
    expect(resolved, 1);
  });
}
