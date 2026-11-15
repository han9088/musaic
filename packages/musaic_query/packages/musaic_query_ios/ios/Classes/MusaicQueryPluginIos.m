#import "MusaicQueryPluginIos.h"
#if __has_include(<musaic_query_ios/musaic_query_ios-Swift.h>)
#import <musaic_query_ios/musaic_query_ios-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "musaic_query_ios-Swift.h"
#endif

@implementation MusaicQueryPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftMusaicQueryPlugin registerWithRegistrar:registrar];
}
@end
