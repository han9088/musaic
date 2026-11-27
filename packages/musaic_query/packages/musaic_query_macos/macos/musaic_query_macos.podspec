Pod::Spec.new do |s|
  s.name             = 'musaic_query_macos'
  s.version          = '3.0.7'
  s.summary          = 'System Music library and local audio directory support for macOS.'
  s.homepage         = 'https://github.com/han9088/musaic'
  s.license          = { :type => 'MIT', :file => '../../musaic_query/LICENSE' }
  s.author           = { 'Musaic' => 'https://musaic.deskbtm.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'musaic_query_macos/Sources/musaic_query_macos/**/*.swift'
  s.dependency 'FlutterMacOS'
  s.frameworks = 'iTunesLibrary'
  s.platform = :osx, '12.0'
  s.swift_version = '5.0'
end
