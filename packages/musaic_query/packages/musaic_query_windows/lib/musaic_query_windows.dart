import 'package:file_picker/file_picker.dart';
import 'package:musaic_query_desktop/musaic_query_desktop.dart';
import 'package:musaic_query_platform_interface/musaic_query_platform_interface.dart';

class MusaicQueryWindows extends DesktopMusaicQuery {
  MusaicQueryWindows() : super(_WindowsAudioDirectory());

  static void registerWith() {
    MusaicQueryPlatform.instance = MusaicQueryWindows();
  }
}

class _WindowsAudioDirectory extends DesktopAudioDirectory {
  @override
  Future<AudioDirectory?> pickDirectory() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return null;
    return openDirectory(path);
  }
}
