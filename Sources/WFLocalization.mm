#import "WFLocalization.h"

NSString *const WFLanguageDidChangeNotification = @"WFLanguageDidChangeNotification";
static NSString *const WFLanguageKey = @"WFLanguage";

@implementation WFLocalization

+ (NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *)strings {
    static NSDictionary *strings;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        strings = @{
            @"title": @{ @"ar": @"Wolf GPS Pro", @"en": @"Wolf GPS Pro" },
            @"search_placeholder": @{ @"ar": @"ابحث عن موقع أو أدخل إحداثيات", @"en": @"Search a place or enter coordinates" },
            @"gps_on": @{ @"ar": @"إيقاف تغيير الموقع", @"en": @"Stop location spoofing" },
            @"gps_off": @{ @"ar": @"تفعيل تغيير الموقع", @"en": @"Enable location spoofing" },
            @"gps_active": @{ @"ar": @"GPS متصل — التغيير نشط", @"en": @"GPS connected — spoofing active" },
            @"gps_ready": @{ @"ar": @"GPS جاهز — التغيير متوقف", @"en": @"GPS ready — spoofing stopped" },
            @"favorites": @{ @"ar": @"المفضلة", @"en": @"Favorites" },
            @"save_favorite": @{ @"ar": @"حفظ الموقع", @"en": @"Save location" },
            @"saved": @{ @"ar": @"تم حفظ الموقع", @"en": @"Location saved" },
            @"rename": @{ @"ar": @"تعديل الاسم", @"en": @"Rename" },
            @"delete": @{ @"ar": @"حذف", @"en": @"Delete" },
            @"cancel": @{ @"ar": @"إلغاء", @"en": @"Cancel" },
            @"done": @{ @"ar": @"تم", @"en": @"Done" },
            @"close": @{ @"ar": @"إغلاق", @"en": @"Close" },
            @"empty_favorites": @{ @"ar": @"لا توجد مواقع محفوظة", @"en": @"No saved locations" },
            @"movement": @{ @"ar": @"حركة GPX", @"en": @"GPX movement" },
            @"load_gpx": @{ @"ar": @"اختيار ملف GPX", @"en": @"Choose GPX file" },
            @"start_movement": @{ @"ar": @"بدء الحركة", @"en": @"Start movement" },
            @"stop_movement": @{ @"ar": @"إيقاف الحركة", @"en": @"Stop movement" },
            @"gpx_loaded": @{ @"ar": @"تم تحميل المسار", @"en": @"Route loaded" },
            @"gpx_invalid": @{ @"ar": @"ملف GPX غير صالح", @"en": @"Invalid GPX file" },
            @"theme": @{ @"ar": @"المظهر", @"en": @"Theme" },
            @"language": @{ @"ar": @"English", @"en": @"العربية" },
            @"hide_tool": @{ @"ar": @"إخفاء زر الأداة", @"en": @"Hide tool button" },
            @"map_standard": @{ @"ar": @"خريطة", @"en": @"Map" },
            @"map_satellite": @{ @"ar": @"قمر صناعي", @"en": @"Satellite" },
            @"map_hybrid": @{ @"ar": @"هجين", @"en": @"Hybrid" },
            @"current_location": @{ @"ar": @"الموقع الحقيقي", @"en": @"Real location" },
            @"edit_favorite": @{ @"ar": @"تعديل الموقع المحفوظ", @"en": @"Edit saved location" },
            @"name": @{ @"ar": @"الاسم", @"en": @"Name" },
            @"speed": @{ @"ar": @"السرعة", @"en": @"Speed" },
        };
    });
    return strings;
}

+ (NSString *)languageCode {
    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:WFLanguageKey];
    if ([saved isEqualToString:@"ar"] || [saved isEqualToString:@"en"]) return saved;
    NSString *preferred = NSLocale.preferredLanguages.firstObject.lowercaseString;
    return [preferred hasPrefix:@"ar"] ? @"ar" : @"en";
}

+ (BOOL)isArabic {
    return [[self languageCode] isEqualToString:@"ar"];
}

+ (void)setLanguageCode:(NSString *)languageCode {
    NSString *normalized = [languageCode.lowercaseString hasPrefix:@"ar"] ? @"ar" : @"en";
    [[NSUserDefaults standardUserDefaults] setObject:normalized forKey:WFLanguageKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:WFLanguageDidChangeNotification object:nil];
}

+ (void)toggleLanguage {
    [self setLanguageCode:[self isArabic] ? @"en" : @"ar"];
}

+ (NSString *)text:(NSString *)key {
    NSDictionary *entry = [self strings][key];
    if (!entry) return key;
    return entry[[self languageCode]] ?: entry[@"en"] ?: key;
}

+ (void)applyDirectionToView:(UIView *)view {
    UISemanticContentAttribute attribute = [self isArabic]
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;
    view.semanticContentAttribute = attribute;
}

@end
