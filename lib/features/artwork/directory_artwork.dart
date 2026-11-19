import 'package:flutter/widgets.dart';

import '../../services/music/directory_music_library.dart';
import 'artwork_image.dart';
import 'source/artwork_image_resolver.dart';

/// Subscribes once to directory track changes and fans revisions out to artwork.
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

  // Keep one library subscription at the scope level instead of one per tile.
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

/// Publishes a lightweight revision so dependent directory covers re-resolve.
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

class _DirectoryArtworkState extends State<DirectoryArtwork> {
  DirectoryMusicLibrary? _library;
  int _revision = -1;
  Future<ResolvedArtwork?>? _resolved;

  // Resolve again when the library revision or track identity changes.
  void _resolve() {
    _resolved = const ArtworkImageResolver().resolve(
      widget.identity,
      directories: _library,
    );
  }

  @override
  // The inherited revision is the signal that directory artwork may have changed.
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
  // Keep the previous placeholder visible while the async provider is resolving.
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
