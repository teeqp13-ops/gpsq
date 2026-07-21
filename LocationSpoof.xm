#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <math.h>

static CFStringRef const FGDomain = CFSTR("fun.p3nd.fakegps");

static id FGRead(NSString *key) {
    if (key.length == 0) return nil;
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
    if (!isfinite(lat) || !isfinite(lon) || lat < -90.0 || lat > 90.0 || lon < -180.0 || lon > 180.0) {
        return CLLocationCoordinate2DMake(24.7136, 46.6753);
    }
    return CLLocationCoordinate2DMake(lat, lon);
}

static CLLocation *FGSpoofedLocation(CLLocation *original) {
    CLLocationCoordinate2D coordinate = FGCoordinateShared();
    CLLocationDistance altitude = original ? original.altitude : 0.0;
    CLLocationAccuracy horizontal = original && original.horizontalAccuracy >= 0 ? original.horizontalAccuracy : 5.0;
    CLLocationAccuracy vertical = original && original.verticalAccuracy >= 0 ? original.verticalAccuracy : 5.0;
    NSDate *timestamp = original.timestamp ?: [NSDate date];

    return [[CLLocation alloc] initWithCoordinate:coordinate
                                        altitude:altitude
                              horizontalAccuracy:horizontal
                                verticalAccuracy:vertical
                                       timestamp:timestamp];
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
    return FGSpoofedLocation(original);
}

%end
