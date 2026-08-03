//
//  WFFavoritesManager.h
//  WolFox GPS
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface WFFavoriteLocation : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;
@end

@interface WFFavoritesManager : NSObject

+ (instancetype)shared;

- (NSArray<WFFavoriteLocation *> *)all;
- (void)addWithName:(NSString *)name coordinate:(CLLocationCoordinate2D)coordinate;
- (void)removeAtIndex:(NSInteger)index;
- (void)renameAtIndex:(NSInteger)index newName:(NSString *)name;

@end
