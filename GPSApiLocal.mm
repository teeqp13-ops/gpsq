#import <Foundation/Foundation.h>

/**
 * ملاحظة: يتم جلب هذه القيم من متغيرات البيئة أثناء البناء على GitHub Actions.
 * محلياً، يمكنك تعديلها للاختبار.
 */

NSString *GPSApiBaseURL(void) {
    char *env_url = getenv("GPS_API_BASE_URL");
    if (env_url) {
        return [NSString stringWithUTF8String:env_url];
    }
    // القيمة الافتراضية في حال عدم وجود متغير بيئة
    return @"https://your-domain.com/api";
}

NSString *GPSApiAccessToken(void) {
    char *env_token = getenv("GPS_API_TOKEN");
    if (env_token) {
        return [NSString stringWithUTF8String:env_token];
    }
    // القيمة الافتراضية في حال عدم وجود متغير بيئة
    return @"YOUR_DEFAULT_SECRET_TOKEN";
}
