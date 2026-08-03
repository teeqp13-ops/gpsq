//
//  WFGPSFavoritesManager.mm
//  Wolf GPS — إدارة المفضلة
//

#import "WFGPSFavoritesManager.h"

@implementation WFGPSFavoritesManager

+ (instancetype)shared {
    static WFGPSFavoritesManager *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        inst = [[self alloc] init];
    });
    return inst;
}

- (void)saveFavorite:(NSString *)name coordinate:(CLLocationCoordinate2D)coordinate {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *favorites = [[defaults arrayForKey:@"wolfox_gps_favorites"] mutableCopy];

    if (!favorites) {
        favorites = [NSMutableArray array];
    }

    // الحد الأقصى 20 موقعاً
    if (favorites.count >= 20) {
        return;
    }

    NSDictionary *favorite = @{
        @"name": name ?: @"موقع جديد",
        @"latitude": @(coordinate.latitude),
        @"longitude": @(coordinate.longitude),
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    };

    [favorites addObject:favorite];
    [defaults setObject:favorites forKey:@"wolfox_gps_favorites"];
    [defaults synchronize];
}

- (void)removeFavoriteAtIndex:(NSInteger)index {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *favorites = [[defaults arrayForKey:@"wolfox_gps_favorites"] mutableCopy];

    if (index >= 0 && index < favorites.count) {
        [favorites removeObjectAtIndex:index];
        [defaults setObject:favorites forKey:@"wolfox_gps_favorites"];
        [defaults synchronize];
    }
}

- (void)updateFavoriteAtIndex:(NSInteger)index name:(NSString *)name coordinate:(CLLocationCoordinate2D)coordinate {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *favorites = [[defaults arrayForKey:@"wolfox_gps_favorites"] mutableCopy] ?: [NSMutableArray array];
    if (index < 0 || index >= favorites.count) return;
    NSMutableDictionary *item = [favorites[index] mutableCopy];
    item[@"name"] = name.length ? name : @"موقع";
    item[@"latitude"] = @(coordinate.latitude);
    item[@"longitude"] = @(coordinate.longitude);
    item[@"updatedAt"] = @([[NSDate date] timeIntervalSince1970]);
    favorites[index] = item;
    [defaults setObject:favorites forKey:@"wolfox_gps_favorites"];
}

- (NSArray *)getAllFavorites {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *favorites = [defaults arrayForKey:@"wolfox_gps_favorites"];
    return favorites ?: @[];
}

- (NSInteger)getFavoritesCount {
    return [[self getAllFavorites] count];
}

@end
