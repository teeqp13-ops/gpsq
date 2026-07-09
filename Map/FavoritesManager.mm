#import <Foundation/Foundation.h>

@interface GPSQFavoritesManager : NSObject
+ (NSArray *)favorites;
@end

@implementation GPSQFavoritesManager
+ (NSArray *)favorites {
    return [[NSUserDefaults standardUserDefaults] arrayForKey:@"GPSQ_Favorites"] ?: @[];
}
@end
