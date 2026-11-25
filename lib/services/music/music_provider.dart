// 文件职责：音乐源、媒体库、播放及切换流程。

import 'music_models.dart';

export 'music_models.dart';

/// 封装或定义音乐提供器相关类型与行为，负责音乐源、媒体库、播放及切换流程。
abstract interface class MusicProvider {
  /// 执行当前模块中的id操作，用于音乐源、媒体库、播放及切换流程。
  String get id;

  /// 执行当前模块中的initialize操作，用于音乐源、媒体库、播放及切换流程。
  Future<void> initialize();

  /// 执行当前模块中的authorizationstatus操作，用于音乐源、媒体库、播放及切换流程。
  Future<MusicAccess> authorizationStatus();

  /// 执行当前模块中的requestauthorization操作，用于音乐源、媒体库、播放及切换流程。
  Future<MusicAccess> requestAuthorization();

  /// 执行当前模块中的capabilities操作，用于音乐源、媒体库、播放及切换流程。
  Future<MusicFeatures> capabilities();

  /// 获取所需数据或资源，用于音乐源、媒体库、播放及切换流程。
  Future<List<ProviderAlbum>> searchAlbums(String query, {int limit = 25});

  /// 执行当前模块中的媒体库albums操作，用于音乐源、媒体库、播放及切换流程。
  Future<MusicPage<ProviderAlbum>> libraryAlbums({
    int limit = 25,
    String? cursor,
  });

  /// 执行当前模块中的专辑操作，用于音乐源、媒体库、播放及切换流程。
  Future<ProviderAlbum> album(MusicReference reference);

  /// 协调动画进度与状态过渡，用于音乐源、媒体库、播放及切换流程。
  Future<List<MusicAnimatedArtwork>> animatedArtwork(MusicReference reference);

  /// 执行当前模块中的播放操作，用于音乐源、媒体库、播放及切换流程。
  Stream<MusicPlayback> get playback;

  /// 执行当前模块中的播放操作，用于音乐源、媒体库、播放及切换流程。
  Future<void> play(List<MusicReference> items, {int startIndex = 0});

  /// 控制流程的开始、暂停、取消或结束，用于音乐源、媒体库、播放及切换流程。
  Future<void> resume();

  /// 控制流程的开始、暂停、取消或结束，用于音乐源、媒体库、播放及切换流程。
  Future<void> pause();

  /// 执行当前模块中的seek操作，用于音乐源、媒体库、播放及切换流程。
  Future<void> seek(Duration position);

  /// 执行当前模块中的next操作，用于音乐源、媒体库、播放及切换流程。
  Future<void> next();

  /// 执行当前模块中的previous操作，用于音乐源、媒体库、播放及切换流程。
  Future<void> previous();

  /// 释放控制器、订阅、动画及其他持有资源，用于音乐源、媒体库、播放及切换流程。
  Future<void> dispose();
}
