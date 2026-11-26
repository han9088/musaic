Pod::Spec.new do |s|
  s.name             = 'apple_music_kit_ios'
  s.version          = '0.1.0'
  s.summary          = 'iOS implementation of apple_music_kit using Apple MusicKit.'
  s.description      = <<-DESC
  iOS platform implementation of the apple_music_kit Flutter plugin,
  backed by Apple MusicKit (MusicAuthorization, ApplicationMusicPlayer,
  MusicCatalogSearchRequest, MusicLibraryRequest).
  DESC
  s.homepage         = 'https://github.com/han9088/apple_music_kit'
  s.license          = { :type => 'BSD-3-Clause', :file => '../LICENSE' }
  s.author           = { 'deskbtm' => 'deskbtm@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '16.0'
  s.swift_version    = '5.9'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }

  # MusicKit framework is weak-linked: hosts targeting older iOS versions
  # degrade to explicit `sdkUnavailable` errors rather than crashing.
  s.user_target_xcconfig = { 'OTHER_LDFLAGS' => '-weak_framework MusicKit' }
end
