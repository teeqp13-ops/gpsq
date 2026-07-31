#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WFFavoritesViewController : UIViewController
@property (nonatomic, copy, nullable) void (^selectionHandler)(CLLocationCoordinate2D coordinate);
@end

NS_ASSUME_NONNULL_END
