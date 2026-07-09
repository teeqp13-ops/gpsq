#import <UIKit/UIKit.h>

@interface GPSQUUIDManager : NSObject
+ (NSString *)deviceID;
@end

@implementation GPSQUUIDManager
+ (NSString *)deviceID {
    NSString *vendorID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    if (vendorID.length > 0) return vendorID;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *savedID = [defaults stringForKey:@"GPSQ_FallbackUDID"];
    if (savedID.length == 0) {
        savedID = [[NSUUID UUID] UUIDString];
        [defaults setObject:savedID forKey:@"GPSQ_FallbackUDID"];
        [defaults synchronize];
    }
    return savedID;
}
@end
