#import <Foundation/Foundation.h>

@interface GPSQNetworkManager : NSObject
+ (NSURLSession *)sharedSession;
@end

@implementation GPSQNetworkManager
+ (NSURLSession *)sharedSession {
    return [NSURLSession sharedSession];
}
@end
