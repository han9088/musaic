import 'package:apple_music_kit_platform_interface/apple_music_kit_platform_interface.dart';

final class AppleMusicKitIos extends MethodChannelMusicKit {
  AppleMusicKitIos() : super('ios');
  static void registerWith() => MusicKitPlatform.instance = AppleMusicKitIos();
}
