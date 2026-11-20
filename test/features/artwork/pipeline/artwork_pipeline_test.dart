import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musaic/features/artwork/model/artwork_resource.dart';
import 'package:musaic/features/artwork/pipeline/artwork_pipeline.dart';
import 'package:musaic/features/artwork/xerox/xerox_raster_request.dart';

void main() {
  final resource = ArtworkResource(
    identity: 'apple:album:42',
    sourceKey: 'original-file:v1',
    image: AssetImage('assets/albums/cover.png'),
  );

  test(
    'pipeline uses the shared LOD for original and Xerox at initial selection',
    () {
      final plan = ArtworkPipeline.instance.createDisplayPlan(
        resource: resource,
        targetSize: const Size.square(80),
        devicePixelRatio: 1,
        fit: BoxFit.cover,
        priority: XeroxRasterPriority.visible,
      );

      expect(plan.originalDecodeResolution, 128);
      expect(plan.xeroxRequest.resolution, 128);
      expect(plan.xeroxRequest.originalDecodeResolution, 128);
      expect(plan.xeroxRequest.identity, resource.identity);
      expect(plan.xeroxRequest.sourceKey, resource.sourceKey);
      expect(plan.xeroxRequest.priority, XeroxRasterPriority.visible);
    },
  );

  test(
    'both resource paths can reach 1024 when the physical size requires it',
    () {
      final plan = ArtworkPipeline.instance.createDisplayPlan(
        resource: resource,
        targetSize: const Size.square(800),
        devicePixelRatio: 1,
      );

      expect(plan.originalDecodeResolution, 1024);
      expect(plan.xeroxRequest.originalDecodeResolution, 1024);
      expect(plan.xeroxRequest.resolution, 1024);
    },
  );

  test('source decode and final Xerox output remain independent parameters', () {
    final plan = ArtworkPipeline.instance.createDisplayPlan(
      resource: resource,
      targetSize: const Size.square(340),
      devicePixelRatio: 1,
      currentOriginalDecodeResolution: 256,
      currentXeroxResolution: 512,
    );

    // 340px 位于 256 升级与 512 降级的迟滞区间。
    // Rasterizer 使用 256px 输入，最终仍可生成 512px 输出。
    expect(plan.originalDecodeResolution, 256);
    expect(plan.xeroxRequest.originalDecodeResolution, 256);
    expect(plan.xeroxRequest.resolution, 512);
  });

  test('a fixed cover tier keeps one decode and Xerox key between zooms', () {
    final plans = [
      for (final zoom in [0.4, 1.0, 2.5])
        ArtworkPipeline.instance.createDisplayPlan(
          resource: resource,
          targetSize: const Size.square(100),
          devicePixelRatio: 3,
          scale: zoom,
          currentOriginalDecodeResolution: 128,
          currentXeroxResolution: 512,
          fixedResolution: 256,
        ),
    ];
    expect(
      plans.map((plan) => plan.originalDecodeResolution),
      everyElement(256),
    );
    expect(
      plans.map((plan) => plan.xeroxRequest.resolution),
      everyElement(256),
    );
    expect(plans.map((plan) => plan.xeroxRequest.key).toSet(), hasLength(1));
  });

  test('Xerox can use a 1024px source decode and produce a 512px raster', () {
    final plan = ArtworkPipeline.instance.createDisplayPlan(
      resource: resource,
      targetSize: const Size.square(680),
      devicePixelRatio: 1,
      currentOriginalDecodeResolution: 1024,
      currentXeroxResolution: 512,
    );

    expect(plan.originalDecodeResolution, 1024);
    expect(plan.xeroxRequest.originalDecodeResolution, 1024);
    expect(plan.xeroxRequest.resolution, 512);
  });

  test('Xerox cache identity includes both input and output resolutions', () {
    final input256 = XeroxRasterRequest(
      identity: resource.identity,
      sourceKey: resource.sourceKey,
      image: resource.image,
      originalDecodeResolution: 256,
      resolution: 512,
    );
    final input1024 = XeroxRasterRequest(
      identity: resource.identity,
      sourceKey: resource.sourceKey,
      image: resource.image,
      originalDecodeResolution: 1024,
      resolution: 512,
    );
    final output1024 = XeroxRasterRequest(
      identity: resource.identity,
      sourceKey: resource.sourceKey,
      image: resource.image,
      originalDecodeResolution: 1024,
      resolution: 1024,
    );

    expect(input256.key.diskCacheKey, isNot(input1024.key.diskCacheKey));
    expect(input1024.key.diskCacheKey, isNot(output1024.key.diskCacheKey));
  });
}
