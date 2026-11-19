// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'directory_artwork.dart';
import 'artwork_image.dart';
import 'source/artwork_image_resolver.dart';
import 'source/artwork_source.dart';

/// 执行当前模块中的专辑封面图操作，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
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
}) {
  // 先将来源解析为明确类型，避免后续逻辑反复判断字符串前缀。
  // 统一解析来源类型，让后续分支直接使用结构化信息。
  final source = ArtworkSource.parse(asset);
  if (source.isDirectory) {
    return DirectoryArtwork(
      identity: asset,
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

  // 占位内容只负责界面兜底，不是真实图片来源，因此不参与图片解码或 Xerox 光栅化。
  if (source.isPlaceholder) {
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

  final image = const ArtworkImageResolver().providerFor(source);
  if (image == null) return const SizedBox.shrink();

  return ArtworkImage(
    identity: source.identity,
    sourceKey: image.toString(),
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
