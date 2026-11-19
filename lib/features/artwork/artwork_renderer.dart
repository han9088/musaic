// 文件职责：为画布、Cover Flow 和布局过渡提供统一的专辑封面渲染入口。

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'model/artwork_identity.dart';
import 'model/artwork_source.dart';
import 'pipeline/artwork_image_pipeline.dart';
import 'source/artwork_resolver.dart';
import 'source/directory_artwork.dart';

/// 根据来源类型选择占位、本地目录或统一图片管线。
///
/// [artworkIdentity] 用于让同一专辑在 Grid、Cover Flow 和过渡动画中共享缓存身份；
/// [artworkVersion] 在上游能够提供 ETag 或资源版本时用于主动失效旧结果。
Widget albumArtwork(
  String asset, {
  double? width,
  double? height,
  BoxFit? fit,
  FilterQuality filterQuality = FilterQuality.medium,
  String? semanticLabel,
  bool excludeFromSemantics = false,
  bool xerox = false,
  double scale = 1,
  ArtworkIdentity? artworkIdentity,
  ArtworkVersion? artworkVersion,
}) {
  // 占位标识只用于 UI 兜底，必须在解析 ArtworkSource 前单独处理。
  if (asset.startsWith('local:')) {
    return Semantics(
      label: excludeFromSemantics ? null : semanticLabel,
      excludeSemantics: excludeFromSemantics,
      child: SizedBox(
        width: width,
        height: height,
        child: const ColoredBox(
          color: Color(0xff292929),
          child: Center(
            child: Icon(
              PhosphorIcons.vinylRecord,
              color: Colors.white38,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }

  final source = ArtworkSource.parse(
    asset,
    identity: artworkIdentity,
    version: artworkVersion,
  );

  if (source.isDirectory) {
    return DirectoryArtwork(
      identity: asset,
      artworkIdentity: artworkIdentity,
      artworkVersion: artworkVersion,
      width: width,
      height: height,
      fit: fit,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      xerox: xerox,
      scale: scale,
      filterQuality: filterQuality,
      placeholder: albumArtwork(
        'local:placeholder',
        width: width,
        height: height,
        fit: fit,
      ),
    );
  }

  const resolver = ArtworkResolver();
  final image = resolver.providerFor(source);
  if (image == null) return const SizedBox.shrink();

  return ArtworkImage(
    identity: source.identity,
    sourceKey: resolver.sourceKeyFor(source, image),
    image: image,
    width: width,
    height: height,
    fit: fit,
    filterQuality: filterQuality,
    semanticLabel: semanticLabel,
    excludeFromSemantics: excludeFromSemantics,
    xerox: xerox,
    scale: scale,
  );
}
