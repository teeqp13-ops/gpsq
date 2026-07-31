#import "WFFavoritesStore.h"

static NSString *const WFFavoritesArchiveKey = @"WFFavoritesArchiveV2";
static NSString *const WFLegacyFavoritesKey = @"FGFavorites";
static NSString *const WFFavoritesMigrationKey = @"WFFavoritesMigrationV2Completed";

@implementation WFFavoriteItem

+ (BOOL)supportsSecureCoding { return YES; }

- (instancetype)init {
    if ((self = [super init])) {
        _identifier = NSUUID.UUID.UUIDString;
        _name = @"موقع محفوظ";
        _createdAt = NSDate.date;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super init])) {
        _identifier = [coder decodeObjectOfClass:NSString.class forKey:@"identifier"] ?: NSUUID.UUID.UUIDString;
        _name = [coder decodeObjectOfClass:NSString.class forKey:@"name"] ?: @"موقع محفوظ";
        _latitude = [coder decodeDoubleForKey:@"latitude"];
        _longitude = [coder decodeDoubleForKey:@"longitude"];
        _createdAt = [coder decodeObjectOfClass:NSDate.class forKey:@"createdAt"] ?: NSDate.date;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.identifier forKey:@"identifier"];
    [coder encodeObject:self.name forKey:@"name"];
    [coder encodeDouble:self.latitude forKey:@"latitude"];
    [coder encodeDouble:self.longitude forKey:@"longitude"];
    [coder encodeObject:self.createdAt forKey:@"createdAt"];
}

- (CLLocationCoordinate2D)coordinate {
    return CLLocationCoordinate2DMake(self.latitude, self.longitude);
}

@end

@interface WFFavoritesStore ()
@property (nonatomic, strong) NSMutableArray<WFFavoriteItem *> *items;
@end

@implementation WFFavoritesStore

+ (instancetype)shared {
    static WFFavoritesStore *store;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ store = [WFFavoritesStore new]; });
    return store;
}

- (instancetype)init {
    if ((self = [super init])) {
        _items = [NSMutableArray array];
        [self load];
    }
    return self;
}

- (void)load {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSData *data = [defaults dataForKey:WFFavoritesArchiveKey];
    BOOL loadedArchive = NO;
    if (data.length) {
        NSSet *classes = [NSSet setWithObjects:NSArray.class, NSMutableArray.class, WFFavoriteItem.class, NSString.class, NSDate.class, nil];
        NSError *error = nil;
        NSArray *decoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:data error:&error];
        if (!error && [decoded isKindOfClass:NSArray.class]) {
            [self.items addObjectsFromArray:decoded];
            loadedArchive = YES;
        }
    }
    if (!loadedArchive && ![defaults boolForKey:WFFavoritesMigrationKey]) {
        [self migrateLegacyItems];
    }
}

- (void)migrateLegacyItems {
    NSArray *legacy = [[NSUserDefaults standardUserDefaults] arrayForKey:WFLegacyFavoritesKey] ?: @[];
    for (id raw in legacy) {
        CLLocationDegrees lat = 0, lon = 0;
        NSString *name = @"موقع محفوظ";
        BOOL valid = NO;
        if ([raw isKindOfClass:NSString.class]) {
            NSArray *parts = [raw componentsSeparatedByString:@","];
            if (parts.count == 2) { lat = [parts[0] doubleValue]; lon = [parts[1] doubleValue]; valid = YES; }
        } else if ([raw isKindOfClass:NSDictionary.class]) {
            lat = [raw[@"lat"] doubleValue]; lon = [raw[@"lon"] doubleValue];
            if ([raw[@"name"] isKindOfClass:NSString.class]) name = raw[@"name"];
            valid = YES;
        }
        if (valid && CLLocationCoordinate2DIsValid(CLLocationCoordinate2DMake(lat, lon))) {
            WFFavoriteItem *item = [WFFavoriteItem new];
            item.name = name;
            item.latitude = lat;
            item.longitude = lon;
            [self.items addObject:item];
        }
    }
    [self save];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setBool:YES forKey:WFFavoritesMigrationKey];
    [defaults removeObjectForKey:WFLegacyFavoritesKey];
    [defaults synchronize];
}

- (void)save {
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.items requiringSecureCoding:YES error:&error];
    if (!error && data) {
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:WFFavoritesArchiveKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (NSArray<WFFavoriteItem *> *)allItems {
    @synchronized (self) { return [self.items copy]; }
}

- (WFFavoriteItem *)addCoordinate:(CLLocationCoordinate2D)coordinate name:(NSString *)name {
    WFFavoriteItem *item = [WFFavoriteItem new];
    item.latitude = coordinate.latitude;
    item.longitude = coordinate.longitude;
    NSString *trimmed = [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length) item.name = trimmed;
    @synchronized (self) { [self.items insertObject:item atIndex:0]; [self save]; }
    return item;
}

- (BOOL)updateItem:(WFFavoriteItem *)item name:(NSString *)name {
    NSString *trimmed = [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!item.identifier.length || !trimmed.length) return NO;
    @synchronized (self) {
        WFFavoriteItem *target = [self.items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(WFFavoriteItem *candidate, NSDictionary *bindings) {
            return [candidate.identifier isEqualToString:item.identifier];
        }]].firstObject;
        if (!target) return NO;
        target.name = trimmed;
        [self save];
        return YES;
    }
}

- (BOOL)deleteItem:(WFFavoriteItem *)item {
    if (!item.identifier.length) return NO;
    @synchronized (self) {
        NSUInteger index = [self.items indexOfObjectPassingTest:^BOOL(WFFavoriteItem *candidate, NSUInteger idx, BOOL *stop) {
            return [candidate.identifier isEqualToString:item.identifier];
        }];
        if (index == NSNotFound) return NO;
        [self.items removeObjectAtIndex:index];
        [self save];
        return YES;
    }
}

@end
