#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint musaic_query.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'musaic_query_ios'
  s.version          = '0.0.1'
  s.summary          = 'musaic_query flutter plugin for ios.'
  s.description      = <<-DESC
  Flutter Plugin used to query audios/songs infos [title, artist, album, etc..] from device storage.
                       DESC
  s.homepage         = 'https://github.com/LucJosin'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Lucas Josino' => 'contact@lucasjosino.com' }
  s.source           = { :path => '.' }
  s.source_files = 'musaic_query_ios/Sources/musaic_query_ios/**/*.swift'
  s.dependency 'Flutter'
  s.dependency 'SwiftyBeaver'
  s.platform = :ios, '11.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  s.test_spec 'Tests' do |test|
    test.source_files = 'Tests/**/*.swift'
  end
end
