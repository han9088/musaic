// 文件职责：提供画布、Cover Flow 和布局过渡共用的专辑封面入口。

import 'package:material_ui/material_ui.dart';

import 'model/artwork_identity.dart';
import 'model/artwork_request.dart';
import 'presentation/artwork_accent.dart';
import 'presentation/artwork_placeholder.dart';
import 'presentation/artwork_source_view.dart';
import 'presentation/custom_artwork_scope.dart';

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
  Widget? placeholder,
  ArtworkAccentBuilder? accentBuilder,
  bool prepareXerox = true,
}) {
  final fallback = previewResolution != null
      ? const SizedBox.shrink()
      : Semantics(
          label: excludeFromSemantics ? null : semanticLabel,
          excludeSemantics: excludeFromSemantics,
          child: SizedBox(
            width: width,
            height: height,
            child: placeholder ?? ArtworkPlaceholder.standard,
          ),
        );

  final artwork = ArtworkSourceView(
    request: ArtworkRequest(
      source: asset,
      identity: artworkIdentity,
      version: artworkVersion,
      fixedResolution: fixedResolution,
      previewResolution: previewResolution,
    ),
    placeholder: fallback,
    width: width,
    height: height,
    fit: fit,
    filterQuality: filterQuality,
    semanticLabel: semanticLabel,
    excludeFromSemantics: excludeFromSemantics,
    xerox: xerox,
    scale: scale,
    accentBuilder: accentBuilder,
    prepareXerox: prepareXerox,
  );

  if (!asset.startsWith('local:')) return artwork;
  return Builder(
    builder: (context) =>
        CustomArtworkScope.watch(context)
                ?.revisionOf(artwork.request.customArtworkKey) ==
            null
        ? accentBuilder?.call(context, fallback, null) ?? fallback
        : artwork,
  );
}
