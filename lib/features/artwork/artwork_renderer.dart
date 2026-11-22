// 文件职责：提供画布、Cover Flow 和布局过渡共用的专辑封面入口。

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'model/artwork_identity.dart';
import 'model/artwork_request.dart';
import 'presentation/artwork_source_view.dart';

/// 所有专辑封面统一从这里进入 Artwork Pipeline。
///
/// 本函数只负责构造请求和占位 UI；来源解析、缓存、LOD、Xerox 处理由 Pipeline 管理。
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
  int? fixedResolution,
  int? previewResolution,
  ArtworkIdentity? artworkIdentity,
  ArtworkVersion? artworkVersion,
}) {
  final placeholder = previewResolution != null
      ? const SizedBox.shrink()
      : Semantics(
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

  if (asset.startsWith('local:')) return placeholder;

  return ArtworkSourceView(
    request: ArtworkRequest(
      source: asset,
      identity: artworkIdentity,
      version: artworkVersion,
      fixedResolution: fixedResolution,
      previewResolution: previewResolution,
    ),
    placeholder: placeholder,
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
