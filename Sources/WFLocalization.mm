#import "WFLocalization.h"

static NSString * const WFLanguageKey = @"wolfox_gps_language";

@implementation WFLocalization

+ (instancetype)shared {
    static WFLocalization *localization;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ localization = [WFLocalization new]; });
    return localization;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _languageCode = [NSUserDefaults.standardUserDefaults stringForKey:WFLanguageKey] ?: @"ar";
    }
    return self;
}

- (void)setLanguageCode:(NSString *)languageCode {
    _languageCode = [languageCode isEqualToString:@"en"] ? @"en" : @"ar";
    [NSUserDefaults.standardUserDefaults setObject:_languageCode forKey:WFLanguageKey];
}

- (BOOL)isArabic { return [self.languageCode isEqualToString:@"ar"]; }

- (NSString *)text:(NSString *)key {
    NSDictionary *ar = @{
        @"search": @"البحث", @"favorites": @"المفضلة", @"save": @"حفظ", @"edit": @"تعديل",
        @"delete": @"حذف", @"speed": @"السرعة", @"movement": @"الحركة", @"appearance": @"المظهر",
        @"language": @"اللغة", @"dark": @"داكن", @"light": @"فاتح", @"close": @"إغلاق"
    };
    NSDictionary *en = @{
        @"search": @"Search", @"favorites": @"Favorites", @"save": @"Save", @"edit": @"Edit",
        @"delete": @"Delete", @"speed": @"Speed", @"movement": @"Movement", @"appearance": @"Appearance",
        @"language": @"Language", @"dark": @"Dark", @"light": @"Light", @"close": @"Close"
    };
    return (self.isArabic ? ar : en)[key] ?: key;
}

@end
