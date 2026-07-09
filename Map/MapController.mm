#import <MapKit/MapKit.h>

@interface GPSQMapController : NSObject
+ (MKCoordinateRegion)defaultRegion;
@end

@implementation GPSQMapController
+ (MKCoordinateRegion)defaultRegion {
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(24.7136, 46.6753);
    return MKCoordinateRegionMakeWithDistance(coordinate, 8000.0, 8000.0);
}
@end
