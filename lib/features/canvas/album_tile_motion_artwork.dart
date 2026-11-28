// 文件职责：从画布已经显示的封面资源借用动效帧。
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../services/music/directory_music_library.dart';
import '../artwork/model/artwork_request.dart';
import '../artwork/pipeline/artwork_pipeline.dart';
import 'album_artwork_atlas.dart';
import 'album_grid_snapshot.dart';

class AlbumTileMotionCover {
  const AlbumTileMotionCover(this.paint, this.release);

  final void Function(Canvas, Rect) paint;
  final VoidCallback release;

  static AlbumTileMotionCover? fromAtlas(
    CanvasArtworkAtlas atlas,
    Object album,
  ) {
    final source = atlas.sources[album];
    if (source == null) return null;
    final image = atlas.image.clone();
    final paint = Paint()..filterQuality = FilterQuality.medium;
    return AlbumTileMotionCover(
      (canvas, rect) => canvas.drawImageRect(image, source, rect, paint),
      image.dispose,
    );
  }

  static AlbumTileMotionCover? borrow({
    required ArtworkRequest request,
    required DirectoryMusicLibrary? directories,
    required int directoryRevision,
    required ImageConfiguration configuration,
    required bool xerox,
    required ColorFilter? filter,
  }) {
    final pipeline = ArtworkPipeline.instance;
    final borrowed = pipeline.tryBorrowDisplayed(
      request,
      directories: directories,
      directoryRevision: directoryRevision,
    );
    if (borrowed == null) return null;
    final plan = pipeline.createDisplayPlan(
      resource: borrowed.resource,
      targetSize: Size.zero,
      devicePixelRatio: configuration.devicePixelRatio ?? 1,
      fixedResolution: albumCanvasArtworkResolution,
    );
    if (xerox) {
      final raster = pipeline.tryAcquireXerox(plan.xeroxRequest);
      if (raster != null) {
        return AlbumTileMotionCover(
          (canvas, rect) => paintImage(
            canvas: canvas,
            rect: rect,
            image: raster.image,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            colorFilter: filter,
          ),
          () {
            raster.release();
            borrowed.release();
          },
        );
      }
    } else {
      final provider = ResizeImage(
        borrowed.resource.image,
        width: plan.originalDecodeResolution,
        height: plan.originalDecodeResolution,
        policy: ResizeImagePolicy.fit,
      );
      final key = provider.obtainKey(configuration);
      if (key is SynchronousFuture<ResizeImageKey>) {
        var ready = false;
        key.then((value) {
          final status = PaintingBinding.instance.imageCache.statusForKey(
            value,
          );
          ready = !status.pending && (status.live || status.keepAlive);
        });
        if (ready) {
          final stream = provider.resolve(configuration);
          ImageInfo? firstFrame;
          final listener = ImageStreamListener((info, _) {
            if (firstFrame == null) {
              firstFrame = info;
            } else {
              info.dispose();
            }
          }, onError: (_, _) {});
          stream.addListener(listener);
          final frame = firstFrame;
          if (frame != null) {
            // 保持解码帧与显示资源存活，直到新的静态格位接管画面。
            return AlbumTileMotionCover(
              (canvas, rect) => paintImage(
                canvas: canvas,
                rect: rect,
                image: frame.image,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
              () {
                stream.removeListener(listener);
                frame.dispose();
                borrowed.release();
              },
            );
          }
          stream.removeListener(listener);
        }
      } else {
        key.ignore();
      }
    }
    borrowed.release();
    return null;
  }
}
