import 'package:flutter/foundation.dart';

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
