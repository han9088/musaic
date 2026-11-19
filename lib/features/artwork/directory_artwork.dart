// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'package:flutter/widgets.dart';

import '../../services/music/directory_music_library.dart';
import 'artwork_image.dart';
import 'source/artwork_image_resolver.dart';

/// 封装或定义本地目录封面图作用域相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class DirectoryArtworkScope extends StatefulWidget {
  const DirectoryArtworkScope({
    super.key,
    required this.library,
    required this.child,
  });

  final DirectoryMusicLibrary? library;
  final Widget child;

  @override
  State<DirectoryArtworkScope> createState() => _DirectoryArtworkScopeState();
}

/// 封装或定义本地目录封面图作用域状态相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class _DirectoryArtworkScopeState extends State<DirectoryArtworkScope> {
  VoidCallback? _unsubscribe;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(DirectoryArtworkScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.library != widget.library) _subscribe();
  }

  // 将媒体库订阅集中放在作用域层，避免每张专辑卡片各自注册监听。
  /// 注册或添加相关数据与监听关系，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void _subscribe() {
    _unsubscribe?.call();
    _unsubscribe = widget.library?.tracks.subscribe((_) {
      if (mounted) setState(() => _revision++);
    });
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _DirectoryArtworkInherited(
    library: widget.library,
    revision: _revision,
    child: widget.child,
  );
}

/// 封装或定义本地目录封面图inherited相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class _DirectoryArtworkInherited extends InheritedWidget {
  const _DirectoryArtworkInherited({
    required this.library,
    required this.revision,
    required super.child,
  });

  final DirectoryMusicLibrary? library;
  final int revision;

  @override
  bool updateShouldNotify(_DirectoryArtworkInherited oldWidget) =>
      library != oldWidget.library || revision != oldWidget.revision;
}

/// 封装或定义本地目录封面图相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class DirectoryArtwork extends StatefulWidget {
  const DirectoryArtwork({
    super.key,
    required this.identity,
    required this.placeholder,
    this.width,
    this.height,
    this.fit,
    this.filterQuality = FilterQuality.medium,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.xerox = false,
    this.scale = 1,
  });

  final String identity;
  final Widget placeholder;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final FilterQuality filterQuality;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final bool xerox;
  final double scale;

  @override
  State<DirectoryArtwork> createState() => _DirectoryArtworkState();
}

/// 封装或定义本地目录封面图状态相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class _DirectoryArtworkState extends State<DirectoryArtwork> {
  DirectoryMusicLibrary? _library;
  int _revision = -1;
  Future<ResolvedArtwork?>? _resolved;

  // 媒体库版本或曲目身份变化时，重新解析本地封面资源。
  /// 解析输入并转换为内部数据，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void _resolve() {
    _resolved = const ArtworkImageResolver().resolve(
      widget.identity,
      directories: _library,
    );
  }

  @override
  // 继承状态中的版本号用于通知子组件：本地封面数据可能已经变化。
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context.dependOnInheritedWidgetOfExactType<
        _DirectoryArtworkInherited>();
    final library = scope?.library;
    final revision = scope?.revision ?? 0;
    if (library != _library || revision != _revision || _resolved == null) {
      _library = library;
      _revision = revision;
      _resolve();
    }
  }

  @override
  void didUpdateWidget(DirectoryArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) _resolve();
  }

  @override
  // 异步图片提供器解析期间继续显示占位内容，避免界面闪烁。
  Widget build(BuildContext context) => FutureBuilder<ResolvedArtwork?>(
    key: ValueKey('${widget.identity}:$_revision'),
    future: _resolved,
    builder: (context, snapshot) {
      final resolved = snapshot.data;
      if (resolved == null) return widget.placeholder;
      return ArtworkImage(
        identity: resolved.identity,
        sourceKey: resolved.sourceKey,
        image: resolved.image,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        filterQuality: widget.filterQuality,
        semanticLabel: widget.semanticLabel,
        excludeFromSemantics: widget.excludeFromSemantics,
        xerox: widget.xerox,
        scale: widget.scale,
        errorBuilder: (_, error, stack) => widget.placeholder,
      );
    },
  );
}
