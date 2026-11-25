// 文件职责：向 Artwork 子树提供本地音乐目录，并统一监听媒体库变化。

import 'package:flutter/widgets.dart';

import '../../../services/music/directory_music_library.dart';

/// 应用级 Artwork 作用域。媒体库内容变化时通知资源视图重新解析目录封面。
class DirectoryArtworkScope extends StatefulWidget {
  const DirectoryArtworkScope({
    super.key,
    required this.library,
    required this.child,
  });

  final DirectoryMusicLibrary? library;
  final Widget child;

  /// 在依赖变化时订阅作用域，并取得当前媒体库及其内容版本。
  static ({DirectoryMusicLibrary? library, int revision}) watch(
    BuildContext context,
  ) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_DirectoryArtworkInherited>();
    return (library: scope?.library, revision: scope?.revision ?? 0);
  }

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
