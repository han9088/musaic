import 'package:musaic_audio_platform_interface/musaic_audio_platform_interface.dart';

/// Placeholder for the Windows and Linux playback implementation.
final class MusaicAudioDesktop extends MusaicAudioPlatform {
  static void registerWith() {
    MusaicAudioPlatform.instance = MusaicAudioDesktop();
  }
}
