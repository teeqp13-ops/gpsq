#import "GPFavoritesStore.h"
@implementation GPFavoritesStore
+ (instancetype)shared { static id x; static dispatch_once_t once; dispatch_once(&once, ^{x=[self new];}); return x; }
- (NSUserDefaults *)d { return [[NSUserDefaults alloc] initWithSuiteName:@"com.wolfox.gpsplusmm"]; }
- (NSArray *)all { return [[self.d arrayForKey:@"favorites"] copy] ?: @[]; }
- (void)addName:(NSString *)name latitude:(double)lat longitude:(double)lon {
    NSMutableArray *a = [[self all] mutableCopy];
    [a addObject:@{@"name":name ?: @"موقع", @"latitude":@(lat), @"longitude":@(lon)}];
    [self.d setObject:a forKey:@"favorites"];
}
- (void)removeAtIndex:(NSUInteger)index {
    NSMutableArray *a = [[self all] mutableCopy]; if (index<a.count) [a removeObjectAtIndex:index]; [self.d setObject:a forKey:@"favorites"];
}
@end
