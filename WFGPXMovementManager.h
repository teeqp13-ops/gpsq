#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WFGPXMovementManager : NSObject
@property (nonatomic, assign, readonly, getter=isRunning) BOOL running;
@property (nonatomic, assign, readonly) NSUInteger pointCount;
@property (nonatomic, assign) BOOL loops;
@property (nonatomic, copy, nullable) void (^coordinateHandler)(CLLocationCoordinate2D coordinate);
@property (nonatomic, copy, nullable) void (^completionHandler)(void);
- (BOOL)loadGPXData:(NSData *)data error:(NSError **)error;
- (void)startWithSpeedMetersPerSecond:(CLLocationSpeed)speed;
- (void)stop;
@end

NS_ASSUME_NONNULL_END
