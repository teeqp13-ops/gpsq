#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WFFavoriteItem : NSObject <NSSecureCoding>
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) CLLocationDegrees latitude;
@property (nonatomic, assign) CLLocationDegrees longitude;
@property (nonatomic, strong) NSDate *createdAt;
- (CLLocationCoordinate2D)coordinate;
@end

@interface WFFavoritesStore : NSObject
+ (instancetype)shared;
- (NSArray<WFFavoriteItem *> *)allItems;
- (WFFavoriteItem *)addCoordinate:(CLLocationCoordinate2D)coordinate name:(nullable NSString *)name;
- (BOOL)updateItem:(WFFavoriteItem *)item name:(NSString *)name;
- (BOOL)deleteItem:(WFFavoriteItem *)item;
@end

NS_ASSUME_NONNULL_END
