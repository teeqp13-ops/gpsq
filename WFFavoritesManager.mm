//
//  WFFavoritesManager.mm
//  WolFox GPS
//

#import "WFFavoritesManager.h"

static NSString * const kWFFavoritesKey = @"WFFavoriteLocations";

@implementation WFFavoriteLocation

- (NSDictionary *)toDictionary {
    return @{
        @"name": self.name ?: @"",
        @"lat": @(self.coordinate.latitude),
        @"lng": @(self.coordinate.longitude),
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    WFFavoriteLocation *loc = [[WFFavoriteLocation alloc] init];
    loc.name = dict[@"name"];
    loc.coordinate = CLLocationCoordinate2DMake([dict[@"lat"] doubleValue], [dict[@"lng"] doubleValue]);
    return loc;
}

@end

@interface WFFavoritesManager ()
@property (nonatomic, strong) NSMutableArray<WFFavoriteLocation *> *items;
@end

@implementation WFFavoritesManager

+ (instancetype)shared {
    static WFFavoritesManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WFFavoritesManager alloc] init];
        [instance load];
    });
    return instance;
}

- (void)load {
    NSArray *raw = [[NSUserDefaults standardUserDefaults] arrayForKey:kWFFavoritesKey] ?: @[];
    NSMutableArray *result = [NSMutableArray array];
    for (NSDictionary *dict in raw) {
        [result addObject:[WFFavoriteLocation fromDictionary:dict]];
    }
    self.items = result;
}

- (void)persist {
    NSMutableArray *raw = [NSMutableArray array];
    for (WFFavoriteLocation *loc in self.items) {
        [raw addObject:[loc toDictionary]];
    }
    [[NSUserDefaults standardUserDefaults] setObject:raw forKey:kWFFavoritesKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSArray<WFFavoriteLocation *> *)all {
    return [self.items copy];
}

- (void)addWithName:(NSString *)name coordinate:(CLLocationCoordinate2D)coordinate {
    WFFavoriteLocation *loc = [[WFFavoriteLocation alloc] init];
    loc.name = name;
    loc.coordinate = coordinate;
    [self.items addObject:loc];
    [self persist];
}

- (void)removeAtIndex:(NSInteger)index {
    if (index < 0 || index >= self.items.count) return;
    [self.items removeObjectAtIndex:index];
    [self persist];
}

- (void)renameAtIndex:(NSInteger)index newName:(NSString *)name {
    if (index < 0 || index >= self.items.count) return;
    self.items[index].name = name;
    [self persist];
}

@end
