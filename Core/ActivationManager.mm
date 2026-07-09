#import <Foundation/Foundation.h>
#import "../Headers/GPSQConfig.h"

@interface GPSQActivationManager : NSObject
+ (NSURL *)activationURL;
@end

@implementation GPSQActivationManager
+ (NSURL *)activationURL {
    return [NSURL URLWithString:GPSQ_ACTIVATION_URL];
}
@end
