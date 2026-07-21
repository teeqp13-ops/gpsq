#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

static CFStringRef const FGDomain = CFSTR("fun.p3nd.fakegps");

static id FGRead(NSString *key) {
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, FGDomain));
}

static BOOL FGEnabledShared(void) {
    id value = FGRead(@"enabled");
    return [value respondsToSelector:@selector(boolValue)] && [value boolValue];
}

static CLLocationCoordinate2D FGCoordinateShared(void) {
    id latValue = FGRead(@"latitude");
    id lonValue = FGRead(@"longitude");
    double lat = [latValue respondsToSelector:@selector(doubleValue)] ? [latValue doubleValue] : 24.7136;
    double lon = [lonValue respondsToSelector:@selector(doubleValue)] ? [lonValue doubleValue] : 46.6753;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return CLLocationCoordinate2DMake(24.7136, 46.6753);
    return CLLocationCoordinate2DMake(lat, lon);
}

%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    if (FGEnabledShared()) return FGCoordinateShared();
    return %orig;
}
%end

%hook CLLocationManager
- (CLLocation *)location {
    CLLocation *original = %orig;
    if (!FGEnabledShared()) return original;
    CLLocationCoordinate2D c = FGCoordinateShared();
    return [[CLLocation alloc] initWithCoordinate:c
                                        altitude:(original ? original.altitude : 0)
                              horizontalAccuracy:(original ? original.horizontalAccuracy : 5)
                                verticalAccuracy:(original ? original.verticalAccuracy : 5)
                                       timestamp:[NSDate date]];
}
%end
