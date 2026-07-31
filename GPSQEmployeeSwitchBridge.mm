#import "../Headers/GPSQEmployeeSwitchBridge.h"

@implementation GPSQEmployeeSwitchBridge

+ (NSDictionary *)detectedFeatures {
    return @{
        @"source_type": @"Xamarin iOS app bundle",
        @"maps": @YES,
        @"fingerprint": @YES,
        @"image_loading": @YES,
        @"syncfusion_ui": @YES,
        @"localization": @YES,
        @"cryptography_module": @YES
    };
}

+ (NSArray<NSString *> *)inspiredModules {
    return @[
        @"Activation and identity layer",
        @"Map and search layer",
        @"Resource and localization layer",
        @"Secure storage placeholder",
        @"User interface components"
    ];
}

@end
