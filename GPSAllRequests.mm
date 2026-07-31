#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// جميع طلبات GPS API في ملف واحد، بدون تكرار.
// ضع مفتاحك في إعدادات البناء: -DGPS_API_TOKEN='@"YOUR_TOKEN"'
#ifndef GPS_API_BASE_URL
#define GPS_API_BASE_URL @"https://ipa.p3nd.fun/api"
#endif

#ifndef GPS_API_TOKEN
#define GPS_API_TOKEN @"PUT_YOUR_API_TOKEN_HERE"
#endif

typedef void (^GPSAPICompletion)(NSDictionary *json, NSHTTPURLResponse *response, NSError *error);

typedef NS_ENUM(NSInteger, GPSAPIRequestType) {
    GPSAPIRequestTypeActivate,
    GPSAPIRequestTypeCheck,
    GPSAPIRequestTypeHeartbeat
};

static NSString *GPSEndpointForType(GPSAPIRequestType type) {
    switch (type) {
        case GPSAPIRequestTypeActivate:  return @"activate.php";
        case GPSAPIRequestTypeCheck:     return @"check.php";
        case GPSAPIRequestTypeHeartbeat: return @"heartbeat.php";
    }
}

static NSDictionary *GPSBuildPayload(NSString *code) {
    UIDevice *device = UIDevice.currentDevice;
    NSDictionary *info = NSBundle.mainBundle.infoDictionary ?: @{};

    return @{
        @"code": code ?: @"",
        @"device_uuid": device.identifierForVendor.UUIDString ?: @"",
        @"app_version": info[@"CFBundleShortVersionString"] ?: @"1.0.0",
        @"device_name": device.name ?: @"iPhone",
        @"ios_version": device.systemVersion ?: @"",
        @"bundle_id": NSBundle.mainBundle.bundleIdentifier ?: @""
    };
}

static void GPSSendRequest(GPSAPIRequestType type,
                           NSString *code,
                           GPSAPICompletion completion) {
    NSString *baseURL = GPS_API_BASE_URL;
    if ([baseURL hasSuffix:@"/"]) {
        baseURL = [baseURL substringToIndex:baseURL.length - 1];
    }

    NSString *endpoint = GPSEndpointForType(type);
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", baseURL, endpoint]];

    if (!url) {
        NSError *error = [NSError errorWithDomain:@"GPSAPI"
                                             code:-1
                                         userInfo:@{NSLocalizedDescriptionKey: @"رابط API غير صالح"}];
        if (completion) completion(nil, nil, error);
        return;
    }

    NSError *serializationError = nil;
    NSData *body = [NSJSONSerialization dataWithJSONObject:GPSBuildPayload(code)
                                                    options:0
                                                      error:&serializationError];
    if (!body) {
        if (completion) completion(nil, nil, serializationError);
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 20.0;
    request.HTTPBody = body;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:GPS_API_TOKEN forHTTPHeaderField:@"X-GPS-API-Key"];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSDictionary *json = nil;
            NSError *jsonError = nil;

            if (data.length > 0) {
                id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                if ([object isKindOfClass:NSDictionary.class]) {
                    json = (NSDictionary *)object;
                }
            }

            NSError *finalError = error ?: jsonError;
            NSHTTPURLResponse *httpResponse = [response isKindOfClass:NSHTTPURLResponse.class]
                ? (NSHTTPURLResponse *)response
                : nil;

            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(json, httpResponse, finalError);
            });
        }];

    [task resume];
}

#pragma mark - الطلبات الفريدة

void GPSActivateCode(NSString *code, GPSAPICompletion completion) {
    GPSSendRequest(GPSAPIRequestTypeActivate, code, completion);
}

void GPSCheckStatus(NSString *code, GPSAPICompletion completion) {
    GPSSendRequest(GPSAPIRequestTypeCheck, code, completion);
}

void GPSHeartbeat(NSString *code, GPSAPICompletion completion) {
    GPSSendRequest(GPSAPIRequestTypeHeartbeat, code, completion);
}
