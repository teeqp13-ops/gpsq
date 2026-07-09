#import <Foundation/Foundation.h>

@interface GPSQSecureStore : NSObject
+ (void)setString:(NSString *)value forKey:(NSString *)key;
+ (NSString *)stringForKey:(NSString *)key;
@end

@implementation GPSQSecureStore
+ (void)setString:(NSString *)value forKey:(NSString *)key {
    if (key.length == 0) return;
    [[NSUserDefaults standardUserDefaults] setObject:value ?: @"" forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
+ (NSString *)stringForKey:(NSString *)key {
    if (key.length == 0) return @"";
    return [[NSUserDefaults standardUserDefaults] stringForKey:key] ?: @"";
}
@end
