import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/features/artwork/model/artwork_resource.dart';
import 'package:musaic/features/artwork/pipeline/artwork_pipeline.dart';
import 'package:musaic/features/artwork/xerox/xerox_raster_request.dart';

void main() {
  test('pipeline builds one display plan from a resolved resource', () {
    final resource = ArtworkResource(
      identity: 'apple:album:42',
      sourceKey: 'original-file:v1',
      image: AssetImage('assets/albums/cover.png'),
    );

    final plan = ArtworkPipeline.instance.createDisplayPlan(
      resource: resource,
      targetSize: const Size.square(80),
      devicePixelRatio: 1,
      fit: BoxFit.cover,
      priority: XeroxRasterPriority.visible,
    );

    expect(plan.originalDecodeResolution, 256);
    expect(plan.xeroxRequest.resolution, 128);
    expect(plan.xeroxRequest.originalDecodeResolution, 256);
    expect(plan.xeroxRequest.identity, resource.identity);
    expect(plan.xeroxRequest.sourceKey, resource.sourceKey);
    expect(plan.xeroxRequest.priority, XeroxRasterPriority.visible);
  });

  test('LOD selection remains independent for original and Xerox outputs', () {
    final resource = ArtworkResource(
      identity: 'album',
      sourceKey: 'source',
      image: AssetImage('assets/albums/cover.png'),
    );
    final small = ArtworkPipeline.instance.createDisplayPlan(
      resource: resource,
      targetSize: const Size.square(40),
      devicePixelRatio: 1,
    );
    final large = ArtworkPipeline.instance.createDisplayPlan(
      resource: resource,
      targetSize: const Size.square(400),
      devicePixelRatio: 1,
    );

    expect(small.originalDecodeResolution, 256);
    expect(small.xeroxRequest.resolution, 64);
    expect(large.originalDecodeResolution, 512);
    expect(large.xeroxRequest.resolution, 512);
  });
}
