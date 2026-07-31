#import "GPSApiClient.h"
#import <UIKit/UIKit.h>

extern NSString *GPSApiBaseURL(void);
extern NSString *GPSApiAccessToken(void);

static NSDictionary *GPSPayload(NSString *code) {
    UIDevice *d = UIDevice.currentDevice;
    NSString *uuid = d.identifierForVendor.UUIDString ?: @"";
    NSString *appVersion = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"1.0.0";
    NSString *bundle = NSBundle.mainBundle.bundleIdentifier ?: @"";
    return @{
        @"code": code ?: @"",
        @"uuid": uuid,
        @"app_version": appVersion,
        @"device_name": d.name ?: @"iPhone",
        @"ios_version": d.systemVersion ?: @"",
        @"bundle_id": bundle
    };
}

static void GPSPost(NSString *endpoint, NSDictionary *payload, void (^done)(NSDictionary *json, NSError *error)) {
    NSString *base = GPSApiBaseURL();
    if ([base hasSuffix:@"/"]) base = [base substringToIndex:base.length - 1];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", base, endpoint]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = 20;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:GPSApiAccessToken() forHTTPHeaderField:@"X-GPS-API-Key"];
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
        NSDictionary *json = nil;
        if (data.length) {
            id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([obj isKindOfClass:NSDictionary.class]) json = obj;
        }
        dispatch_async(dispatch_get_main_queue(), ^{ if (done) done(json, err); });
    }] resume];
}

void GPSActivateCode(NSString *code, void (^done)(NSDictionary *json, NSError *error)) {
    GPSPost(@"activate.php", GPSPayload(code), done);
}

void GPSCheckStatus(NSString *code, void (^done)(NSDictionary *json, NSError *error)) {
    GPSPost(@"status.php", GPSPayload(code), done);
}

void GPSHeartbeat(NSString *code, void (^done)(NSDictionary *json, NSError *error)) {
    GPSPost(@"heartbeat.php", GPSPayload(code), done);
}
