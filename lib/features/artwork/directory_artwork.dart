import 'package:flutter/material.dart';

import '../../services/music/directory_music_library.dart';
import 'artwork_image.dart';
import 'artwork_image_provider.dart';
import 'artwork_file_provider_stub.dart'
    if (dart.library.io) 'artwork_file_provider_io.dart' as file_provider;

class DirectoryArtworkScope extends InheritedWidget {
  const DirectoryArtworkScope({
    super.key,
    required this.library,
    required super.child,
  });
  final DirectoryMusicLibrary? library;
  @override
  bool updateShouldNotify(DirectoryArtworkScope oldWidget) =>
      library != oldWidget.library;
}

class DirectoryArtwork extends StatefulWidget {
  const DirectoryArtwork({
    super.key,
    required this.identity,
    required this.placeholder,
    this.width,
    this.height,
    this.fit,
    this.semanticLabel,
    this.xerox = false,
    this.scale = 1,
    this.filterQuality = FilterQuality.medium,
  });
  final String identity;
  final Widget placeholder;
  final double? width, height;
  final BoxFit? fit;
  final String? semanticLabel;
  final bool xerox;
  final double scale;
  final FilterQuality filterQuality;
  @override
  State<DirectoryArtwork> createState() => _DirectoryArtworkState();
}

class _DirectoryArtworkState extends State<DirectoryArtwork> {
  Future<String?>? _image;
  DirectoryMusicLibrary? _library;
  void Function()? _unsubscribe;
  void _load() {
    final library = _library;
    final id = Uri.decodeComponent(
      widget.identity.substring('directory:'.length),
    );
    final track = library?.track(id);
    _image = track == null ? Future.value() : library!.artwork(track);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final library = context
        .dependOnInheritedWidgetOfExactType<DirectoryArtworkScope>()
        ?.library;
    if (library != _library || _image == null) {
      _unsubscribe?.call();
      _library = library;
      _unsubscribe = library?.tracks.subscribe((_) {
        if (mounted) setState(_load);
      });
      _load();
    }
  }

  @override
  void didUpdateWidget(DirectoryArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.identity != oldWidget.identity) _load();
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    key: ValueKey(widget.identity),
    future: _image,
    builder: (context, snapshot) {
      final uri = snapshot.data;
      if (uri == null) return widget.placeholder;
      final provider = file_provider.fileArtworkProvider(uri);
      if (provider == null) return widget.placeholder;
      return ArtworkImage(
        key: ValueKey(widget.identity),
        identity: widget.identity,
        image: provider,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        filterQuality: widget.filterQuality,
        semanticLabel: widget.semanticLabel,
        xerox: widget.xerox,
        scale: widget.scale,
        errorBuilder: (_, error, stack) => widget.placeholder,
      );
    },
  );
}
