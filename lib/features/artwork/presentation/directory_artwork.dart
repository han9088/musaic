// 文件职责：集中订阅本地音乐媒体库，并将目录封面接入统一图片管线。

import 'package:flutter/widgets.dart';

import '../../../services/music/directory_music_library.dart';
import '../model/artwork_identity.dart';
import '../pipeline/artwork_image_pipeline.dart';
import '../source/artwork_resolver.dart';

/// 在应用级作用域中维护一份媒体库订阅，避免每张专辑卡片重复监听。
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

/// 负责将本地曲目封面异步解析为 FileImage，并在媒体库更新后重新解析。
class DirectoryArtwork extends StatefulWidget {
  const DirectoryArtwork({
    super.key,
    required this.identity,
    required this.placeholder,
    this.artworkIdentity,
    this.artworkVersion,
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
  final ArtworkIdentity? artworkIdentity;
  final ArtworkVersion? artworkVersion;
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

class _DirectoryArtworkState extends State<DirectoryArtwork> {
  DirectoryMusicLibrary? _library;
  int _revision = -1;
  Future<ResolvedArtwork?>? _resolved;

  void _resolve() {
    _resolved = const ArtworkResolver().resolve(
      widget.identity,
      directories: _library,
      identity: widget.artworkIdentity,
      version: widget.artworkVersion,
    );
  }

  @override
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
    if (oldWidget.identity != widget.identity ||
        oldWidget.artworkIdentity != widget.artworkIdentity ||
        oldWidget.artworkVersion != widget.artworkVersion) {
      _resolve();
    }
  }

  @override
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
