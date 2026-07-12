#import <Foundation/Foundation.h>

#ifndef GPS_API_BASE_URL
#define GPS_API_BASE_URL @"https://ipa.p3nd.fun/api"
#endif

// GPS_API_TOKEN must be injected at build time via -DGPS_API_TOKEN=...
// No hardcoded fallback — fail loudly if missing
#ifndef GPS_API_TOKEN
#error "GPS_API_TOKEN must be defined at build time. Do not hardcode it."
#endif

NSString *GPSApiBaseURL(void) { return GPS_API_BASE_URL; }
NSString *GPSApiAccessToken(void) { return GPS_API_TOKEN; }
