#import <Foundation/Foundation.h>

@interface GPSQManager : NSObject
+ (instancetype)shared;
@end

@implementation GPSQManager
+ (instancetype)shared {
    static GPSQManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [GPSQManager new]; });
    return manager;
}
@end
