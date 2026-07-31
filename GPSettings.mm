#import "GPSettings.h"

static NSString * const GPDefaultsSuite = @"com.wolfox.gpsplusmm";

@implementation GPSettings
+ (instancetype)shared {
    static GPSettings *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [GPSettings new]; [instance load]; });
    return instance;
}
- (NSUserDefaults *)defaults { return [[NSUserDefaults alloc] initWithSuiteName:GPDefaultsSuite]; }
- (void)load {
    NSUserDefaults *d = [self defaults];
    self.simulationEnabled = [d boolForKey:@"simulationEnabled"];
    self.driftEnabled = [d boolForKey:@"driftEnabled"];
    self.scheduleEnabled = [d boolForKey:@"scheduleEnabled"];
    double lat = [d objectForKey:@"latitude"] ? [d doubleForKey:@"latitude"] : 24.7136;
    double lon = [d objectForKey:@"longitude"] ? [d doubleForKey:@"longitude"] : 46.6753;
    self.selectedCoordinate = CLLocationCoordinate2DMake(lat, lon);
    self.selectedName = [d stringForKey:@"selectedName"] ?: @"الرياض";
}
- (void)save {
    NSUserDefaults *d = [self defaults];
    [d setBool:self.simulationEnabled forKey:@"simulationEnabled"];
    [d setBool:self.driftEnabled forKey:@"driftEnabled"];
    [d setBool:self.scheduleEnabled forKey:@"scheduleEnabled"];
    [d setDouble:self.selectedCoordinate.latitude forKey:@"latitude"];
    [d setDouble:self.selectedCoordinate.longitude forKey:@"longitude"];
    [d setObject:self.selectedName ?: @"" forKey:@"selectedName"];
    [d synchronize];
}
@end
