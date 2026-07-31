#import "GPLocationEngine.h"
#import "GPSettings.h"

NSNotificationName const GPLocationEngineDidUpdateNotification = @"GPLocationEngineDidUpdateNotification";

@interface GPLocationEngine ()
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, strong, readwrite) CLLocation *currentSimulatedLocation;
@end

@implementation GPLocationEngine
+ (instancetype)shared { static id x; static dispatch_once_t once; dispatch_once(&once, ^{ x=[self new]; }); return x; }
- (void)start {
    [self stop];
    [self applyCoordinate:[GPSettings shared].selectedCoordinate];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(tick) userInfo:nil repeats:YES];
}
- (void)stop { [self.timer invalidate]; self.timer=nil; }
- (void)tick {
    GPSettings *s = [GPSettings shared];
    if (!s.simulationEnabled) return;
    CLLocationCoordinate2D c = s.selectedCoordinate;
    if (s.driftEnabled) {
        c.latitude += ((arc4random_uniform(21)-10) / 1000000.0);
        c.longitude += ((arc4random_uniform(21)-10) / 1000000.0);
    }
    [self applyCoordinate:c];
}
- (void)applyCoordinate:(CLLocationCoordinate2D)coordinate {
    self.currentSimulatedLocation = [[CLLocation alloc] initWithCoordinate:coordinate altitude:0 horizontalAccuracy:5 verticalAccuracy:5 timestamp:[NSDate date]];
    [[NSNotificationCenter defaultCenter] postNotificationName:GPLocationEngineDidUpdateNotification object:self.currentSimulatedLocation];
}
@end
