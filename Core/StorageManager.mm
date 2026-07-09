#import <Foundation/Foundation.h>

@interface GPSQStorageManager : NSObject
+ (BOOL)isActivated;
+ (void)setActivated:(BOOL)value;
@end

@implementation GPSQStorageManager
+ (BOOL)isActivated {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"GPSQ_Activated"];
}
+ (void)setActivated:(BOOL)value {
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:@"GPSQ_Activated"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
@end
