import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class AlbumPlayback extends ChangeNotifier {
  String? asset;
  String? title;
  bool playing = false;

  bool isPlaying(String asset, String title) =>
      this.asset == asset && this.title == title && playing;

  void toggle(String asset, String title) {
    playing = !isPlaying(asset, title);
    this.asset = asset;
    this.title = title;
    notifyListeners();
  }
}

class AlbumPlayButton extends StatefulWidget {
  const AlbumPlayButton({
    super.key,
    required this.asset,
    required this.title,
    required this.playback,
    this.diameter = 30,
  });
  final double diameter;
  final String asset;
  final String title;
  final AlbumPlayback playback;
  @override
  State<AlbumPlayButton> createState() => _AlbumPlayButtonState();
}

class _AlbumPlayButtonState extends State<AlbumPlayButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.playback,
    builder: (context, child) {
      return Center(
        child: Semantics(
          button: true,
          label:
              '${widget.playback.isPlaying(widget.asset, widget.title) ? '暂停' : '播放'} ${widget.title}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: () => widget.playback.toggle(widget.asset, widget.title),
            child: SizedBox(
              width: widget.diameter < 44 ? 44 : widget.diameter,
              height: widget.diameter < 44 ? 44 : widget.diameter,
              child: Center(
                child: AnimatedScale(
                  scale: _pressed ? 0.88 : 1,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 100),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: ColoredBox(
                        color: const Color(0x28FFFFFF),
                        child: SizedBox(
                          width: widget.diameter,
                          height: widget.diameter,
                          child: Icon(
                            widget.playback.isPlaying(
                                  widget.asset,
                                  widget.title,
                                )
                                ? PhosphorIcons.pauseFill
                                : PhosphorIcons.playFill,
                            color: Colors.white,
                            size: widget.diameter * 16 / 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
