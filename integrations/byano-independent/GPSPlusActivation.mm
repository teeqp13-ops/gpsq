#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static NSString *const GPLicenseDomain = @"com.byano.activation";
static NSString *const GPCodeKey = @"activation_code";
static NSString *const GPTokenKey = @"access_token";
static NSString *const GPTokenExpiryKey = @"expires_at";
static NSString *const GPDeviceUUIDKey = @"device_uuid";
static NSString *const GPActiveKey = @"activation_active";

static NSArray<NSString *> *GPExternalLicensePaths(void) {
    return @[
        @"/var/mobile/Library/Preferences/com.byano.activation.plist",
        @"/var/jb/var/mobile/Library/Preferences/com.byano.activation.plist",
        @"/Library/Application Support/BYANOActivation/ExternalLicense.plist",
        @"/var/jb/Library/Application Support/BYANOActivation/ExternalLicense.plist"
    ];
}

static NSDictionary *GPReadExternalLicense(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *path in GPExternalLicensePaths()) {
        if (![fm fileExistsAtPath:path]) continue;
        NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:path];
        if ([config isKindOfClass:NSDictionary.class]) return config;
    }
    return nil;
}

static NSString *GPString(id value) {
    if ([value isKindOfClass:NSString.class]) {
        return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    }
    if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
    return nil;
}

static void GPWritePreference(NSString *key, id value) {
    if (key.length == 0) return;
    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             value ? (__bridge CFPropertyListRef)value : NULL,
                             (__bridge CFStringRef)GPLicenseDomain);
    CFPreferencesAppSynchronize((__bridge CFStringRef)GPLicenseDomain);
}

static NSString *GPDeviceUUID(void) {
    id saved = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)GPDeviceUUIDKey,
                                                            (__bridge CFStringRef)GPLicenseDomain));
    NSString *uuid = GPString(saved);
    if (uuid.length > 0) return uuid;
    uuid = UIDevice.currentDevice.identifierForVendor.UUIDString ?: NSUUID.UUID.UUIDString;
    GPWritePreference(GPDeviceUUIDKey, uuid);
    return uuid;
}

static id GPValue(NSDictionary *json, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        id value = json[key];
        if (value && value != NSNull.null) return value;
    }
    NSDictionary *data = [json[@"data"] isKindOfClass:NSDictionary.class] ? json[@"data"] : nil;
    for (NSString *key in keys) {
        id value = data[key];
        if (value && value != NSNull.null) return value;
    }
    return nil;
}

static BOOL GPSuccess(NSDictionary *json, NSInteger statusCode) {
    if (statusCode < 200 || statusCode >= 300) return NO;
    if ([json[@"success"] respondsToSelector:@selector(boolValue)] && [json[@"success"] boolValue]) return YES;
    NSString *status = [GPString(json[@"status"]) lowercaseString];
    return [@[@"success", @"active", @"valid", @"ok", @"approved"] containsObject:status ?: @""];
}

@interface BYANOExternalActivation : NSObject
@property(nonatomic, assign) BOOL requestRunning;
@property(nonatomic, copy) NSString *lastCode;
+ (instancetype)shared;
- (void)reloadAndActivate;
@end

@implementation BYANOExternalActivation
+ (instancetype)shared {
    static BYANOExternalActivation *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [BYANOExternalActivation new]; });
    return instance;
}

- (void)reloadAndActivate {
    if (self.requestRunning) return;
    NSDictionary *config = GPReadExternalLicense();
    if (![config isKindOfClass:NSDictionary.class]) return;
    if ([config[@"enabled"] respondsToSelector:@selector(boolValue)] && ![config[@"enabled"] boolValue]) return;

    NSString *code = GPString(config[@"activation_code"]);
    if (code.length < 8 || [code isEqualToString:@"PUT_NEW_CODE_HERE"] || [self.lastCode isEqualToString:code]) return;

    NSString *apiBase = GPString(config[@"apiBase"]);
    if (apiBase.length == 0) apiBase = @"https://key.p3nd.fun/api";
    while ([apiBase hasSuffix:@"/"]) apiBase = [apiBase substringToIndex:apiBase.length - 1];

    self.requestRunning = YES;
    NSURL *url = [NSURL URLWithString:[apiBase stringByAppendingString:@"/activate.php"]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20.0];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:code forHTTPHeaderField:@"X-API-Key"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", code] forHTTPHeaderField:@"Authorization"];

    NSString *uuid = GPDeviceUUID();
    NSDictionary *payload = @{
        @"app": code,
        @"code": code,
        @"license_code": code,
        @"device_uuid": uuid,
        @"uuid": uuid,
        @"project": @"BYANO",
        @"platform": @"ios",
        @"bundle_id": NSBundle.mainBundle.bundleIdentifier ?: @"com.t2.AvailoHader"
    };
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];

    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        NSDictionary *json = nil;
        if (data.length) {
            id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([object isKindOfClass:NSDictionary.class]) json = object;
        }
        BOOL success = !error && json && GPSuccess(json, statusCode);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.requestRunning = NO;
            if (!success) return;
            NSString *token = GPString(GPValue(json, @[@"access_token", @"token"]));
            id expiry = GPValue(json, @[@"expires_at", @"expiry_date"]);
            if (token.length == 0) token = code;
            GPWritePreference(GPCodeKey, code);
            GPWritePreference(GPTokenKey, token);
            GPWritePreference(GPActiveKey, @YES);
            if (expiry) GPWritePreference(GPTokenExpiryKey, expiry);
            self.lastCode = code;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"BYANOActivationCompleted" object:nil];
        });
    }] resume];
}
@end

%hook UIApplication
- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[BYANOExternalActivation shared] reloadAndActivate];
    });
}
%end

%ctor {
    @autoreleasepool {
        (void)GPDeviceUUID();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[BYANOExternalActivation shared] reloadAndActivate];
        });
    }
}
