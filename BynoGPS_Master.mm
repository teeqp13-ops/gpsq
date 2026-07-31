#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <MapKit/MapKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <UserNotifications/UserNotifications.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import "fishhook/fishhook.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <Security/Security.h>
#import <MediaPlayer/MediaPlayer.h>

#ifndef kUTTypeImage
#define kUTTypeImage CFSTR("public.image")
#endif

#ifndef kUTTypeMovie
#define kUTTypeMovie CFSTR("public.movie")
#endif

#define COL_BG [UIColor clearColor]
#define COL_GLASS [UIColor colorWithRed:0.05 green:0.05 blue:0.08 alpha:0.88]
#define COL_HEADER [UIColor clearColor]
#define COL_PANEL [UIColor colorWithWhite:1.0 alpha:0.08]
#define COL_ACCENT [UIColor colorWithRed:0.15 green:0.42 blue:0.95 alpha:1.0]
#define COL_ACTIVE [UIColor whiteColor]
#define COL_TEXT [UIColor whiteColor]
#define COL_SUBTEXT [UIColor colorWithWhite:0.75 alpha:1.0]
#define COL_RED [UIColor colorWithRed:0.9 green:0.25 blue:0.35 alpha:1.0]
#define COL_PURPLE [UIColor colorWithRed:0.1 green:0.4 blue:0.85 alpha:1.0]

#define MENU_WIDTH 340.0
#define MENU_HEIGHT 720.0

static BOOL kLocationSpoofSupported = NO;
static BOOL kCameraSpoofSupported = NO;
static BOOL kWebViewHookSupported = NO;
static BOOL kUDIDSpoofSupported = NO;
static BOOL kDeviceIDSpoofSupported = NO;

BOOL YHSafeHookMethod(Class cls, SEL sel, IMP newImp, IMP *origImp) {
    if (!cls) return NO;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) m = class_getClassMethod(cls, sel);
    if (!m) return NO;
    if (origImp) *origImp = method_getImplementation(m);
    method_setImplementation(m, newImp);
    return YES;
}

@interface YHJSONHook : NSObject @end
@implementation YHJSONHook
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = object_getClass([NSJSONSerialization class]);
        SEL originalSelector = @selector(JSONObjectWithData:options:error:);
        SEL swizzledSelector = @selector(yh_JSONObjectWithData:options:error:);
        Method originalMethod = class_getClassMethod([NSJSONSerialization class], originalSelector);
        Method swizzledMethod = class_getClassMethod(self, swizzledSelector);
        if (originalMethod && swizzledMethod) {
            class_addMethod(cls, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
            class_replaceMethod(cls, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        }
    });
}
+ (id)yh_JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError *__autoreleasing *)error {
    id result = [self yh_JSONObjectWithData:data options:opt error:error];
    if ([result isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *mutableDict = [result mutableCopy];
        [self cleanDeviceRestrictions:mutableDict];
        return [mutableDict copy];
    }
    return result;
}
+ (void)cleanDeviceRestrictions:(NSMutableDictionary *)dict {
    NSArray *keys = [dict allKeys];
    for (NSString *key in keys) {
        id value = dict[key];
        if ([key containsString:@"wrongUserDevice"] || [key containsString:@"CanOnlyUserFromSameDevice"]) {
            dict[key] = @"";
        } else if ([value isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *subDict = [value mutableCopy];
            [self cleanDeviceRestrictions:subDict];
            dict[key] = [subDict copy];
        } else if ([value isKindOfClass:[NSArray class]]) {
            NSMutableArray *subArray = [value mutableCopy];
            for (int i = 0; i < subArray.count; i++) {
                if ([subArray[i] isKindOfClass:[NSDictionary class]]) {
                    NSMutableDictionary *subDict = [subArray[i] mutableCopy];
                    [self cleanDeviceRestrictions:subDict];
                    subArray[i] = [subDict copy];
                }
            }
            dict[key] = [subArray copy];
        }
    }
}
@end

@interface YHWKWebViewHook : NSObject @end
@implementation YHWKWebViewHook
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class wkClass = NSClassFromString(@"WKWebView");
        if (wkClass) {
            SEL originalSelector = @selector(initWithFrame:configuration:);
            Method originalMethod = class_getInstanceMethod(wkClass, originalSelector);
            if (originalMethod) {
                IMP originalIMP = method_getImplementation(originalMethod);
                IMP newIMP = imp_implementationWithBlock(^WKWebView*(id self, CGRect frame, WKWebViewConfiguration *config) {
                    NSString *spoofedUDID = @"";
                    NSString *spoofedDeviceID = @"";
                    BOOL isUDIDSpoofEnabled = [NSUserDefaults.standardUserDefaults boolForKey:@"YH_UDID_Enabled"];
                    BOOL isDeviceIDSpoofEnabled = [NSUserDefaults.standardUserDefaults boolForKey:@"YH_DeviceID_Enabled"];
                    if (isUDIDSpoofEnabled) { spoofedUDID = [NSUserDefaults.standardUserDefaults stringForKey:@"YH_Custom_UDID"] ?: @""; }
                    if (isDeviceIDSpoofEnabled) { spoofedDeviceID = [NSUserDefaults.standardUserDefaults stringForKey:@"YH_Custom_DeviceID"] ?: @""; }
                    NSMutableString *jsCode = [NSMutableString stringWithString:@"\
                        var origSetItem = Storage.prototype.setItem;\n\
                        Storage.prototype.setItem = function(k, v) {\n\
                            if (k && (k.indexOf('wrongUserDevice') !== -1 || k.indexOf('CanOnlyUserFromSameDevice') !== -1)) return;\n\
                            if (k === 'isSameDevice') v = 'true';\n\
                            origSetItem.call(this, k, v);\n\
                        };\n\
                        var origGetItem = Storage.prototype.getItem;\n\
                        Storage.prototype.getItem = function(k) {\n\
                            if (k && (k.indexOf('wrongUserDevice') !== -1 || k.indexOf('CanOnlyUserFromSameDevice') !== -1)) return null;\n\
                            if (k === 'isSameDevice') return 'true';\n\
                            return origGetItem.call(this, k);\n\
                        };\n\
                        localStorage.removeItem('wrongUserDevice');\n\
                        sessionStorage.removeItem('wrongUserDevice');\n\
                        localStorage.removeItem('CanOnlyUserFromSameDevice');\n\
                        sessionStorage.removeItem('CanOnlyUserFromSameDevice');\n\
                        window.isApprovedDevice = true;\n\
                        window.isSameDevice = true;\n\
                        window.isAppStore = true;\n\
                        window.isOfficial = true;\n\
                        var origJSON = JSON.parse;\n\
                        JSON.parse = function(text, reviver) {\n\
                            var res = origJSON(text, reviver);\n\
                            if (res && typeof res === 'object') {\n\
                                if (res['wrongUserDevice']) res['wrongUserDevice'] = '';\n\
                                if (res['CanOnlyUserFromSameDevice']) res['CanOnlyUserFromSameDevice'] = '';\n\
                            }\n\
                            return res;\n\
                        };\n\
                        var origStringify = JSON.stringify;\n\
                        JSON.stringify = function(value, replacer, space) {\n\
                            if (value && typeof value === 'object') {\n\
                                if (value.hasOwnProperty('wrongUserDevice')) value['wrongUserDevice'] = '';\n\
                                if (value.hasOwnProperty('CanOnlyUserFromSameDevice')) value['CanOnlyUserFromSameDevice'] = '';\n\
                            }\n\
                            return origStringify(value, replacer, space);\n\
                        };\n\
                    "];
                    if (spoofedUDID.length > 0) {
                        [jsCode appendFormat:@"\
                            window.device = window.device || {};\n\
                            window.device.uuid = '%@';\n\
                            if (window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.Device) {\n\
                                window.Capacitor.Plugins.Device.getId = function() { return Promise.resolve({ identifier: '%@' }); };\n\
                            }\n\
                        ", spoofedUDID, spoofedUDID];
                    }
                    if (spoofedDeviceID.length > 0) {
                        [jsCode appendFormat:@"\
                            localStorage.setItem('deviceId', '%@');\n\
                            localStorage.setItem('device_id', '%@');\n\
                            localStorage.setItem('uuid', '%@');\n\
                        ", spoofedDeviceID, spoofedDeviceID, spoofedDeviceID];
                    }
                    WKUserScript *script = [[WKUserScript alloc] initWithSource:jsCode injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
                    [config.userContentController addUserScript:script];
                    return ((WKWebView* (*)(id, SEL, CGRect, WKWebViewConfiguration*))originalIMP)(self, originalSelector, frame, config);
                });
                method_setImplementation(originalMethod, newIMP);
                kWebViewHookSupported = YES;
            } else { kWebViewHookSupported = NO; }
        }
    });
}
@end

static NSMutableSet<id> *retainer = nil;

static OSStatus (*orig_SecTrustEvaluate)(SecTrustRef, SecTrustResultType*);
static OSStatus my_SecTrustEvaluate(SecTrustRef trust, SecTrustResultType *result) {
    orig_SecTrustEvaluate(trust, result);
    if (result) *result = kSecTrustResultProceed;
    return errSecSuccess;
}

static bool (*orig_SecTrustEvaluateWithError)(SecTrustRef, CFErrorRef*);
static bool my_SecTrustEvaluateWithError(SecTrustRef trust, CFErrorRef *error) {
    orig_SecTrustEvaluateWithError(trust, error);
    if (error && *error) { CFRelease(*error); *error = NULL; }
    return true;
}

static NSString * const kSaveKeyGPSEnabled = @"YH_GPS_State";
static NSString * const kSaveKeyLat = @"YH_Lat";
static NSString * const kSaveKeyLng = @"YH_Lng";
static NSString * const kSaveKeyLocations = @"YH_Saved_Locations";
static NSString * const kSaveKeySchedule = @"YH_Schedule_Items";
static NSString * const kSaveKeyUDID = @"YH_Custom_UDID";
static NSString * const kSaveKeyUDIDEnabled = @"YH_UDID_Enabled";
static NSString * const kSaveKeyEngineEnabled = @"YH_Engine_Enabled";
static NSString * const kSaveKeyDeviceID = @"YH_Custom_DeviceID";
static NSString * const kSaveKeyDeviceIDEnabled = @"YH_DeviceID_Enabled";
static NSString * const kSaveKeyJitterEnabled = @"YH_Jitter_Enabled";

static NSString * const kSaveBleUUID = @"YH_Ble_UUID";
static NSString * const kSaveBleMajor = @"YH_Ble_Major";
static NSString * const kSaveBleMinor = @"YH_Ble_Minor";
static NSString * const kSaveBleEnabled = @"YH_Ble_Enabled";

static BOOL kGPSEnabled = NO;
static CLLocationCoordinate2D kBaseLocation = {24.7136, 46.6753};
static CLLocationCoordinate2D kLocation = {24.7136, 46.6753};

@interface YHScheduleItem : NSObject
@property (nonatomic, strong) NSString *title;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL repeatWeekly;
@property (nonatomic, strong) NSDate *targetDate;
@property (nonatomic, assign) NSInteger linkedLocationIndex;
@property (nonatomic, strong) NSString *mediaPath;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;
@end

@implementation YHScheduleItem
- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        self.title = dict[@"title"] ?: @"";
        self.enabled = [dict[@"enabled"] boolValue];
        self.repeatWeekly = [dict[@"repeatWeekly"] boolValue];
        self.targetDate = dict[@"targetDate"] ? [NSDate dateWithTimeIntervalSince1970:[dict[@"targetDate"] doubleValue]] : [NSDate date];
        self.linkedLocationIndex = dict[@"linkedLocationIndex"] ? [dict[@"linkedLocationIndex"] integerValue] : -1;
        self.mediaPath = dict[@"mediaPath"] ?: @"";
    }
    return self;
}
- (NSDictionary *)toDictionary {
    return @{
        @"title": self.title ?: @"",
        @"enabled": @(self.enabled),
        @"repeatWeekly": @(self.repeatWeekly),
        @"targetDate": @([self.targetDate timeIntervalSince1970]),
        @"linkedLocationIndex": @(self.linkedLocationIndex),
        @"mediaPath": self.mediaPath ?: @""
    };
}
@end

@interface YHManager : NSObject
@property (class, readonly) YHManager *shared;
@property (nonatomic) BOOL isEnabled;
@property (nonatomic) BOOL isJitterEnabled;
@property (nonatomic) BOOL isUDIDSpoofEnabled;
@property (nonatomic) BOOL isEngineEnabled;
@property (nonatomic) BOOL isDeviceIDSpoofEnabled;
@property (nonatomic) BOOL isBluetoothSpoofEnabled;
@property (nonatomic, strong) NSString *spoofBeaconUUID;
@property (nonatomic) NSInteger spoofBeaconMajor;
@property (nonatomic) NSInteger spoofBeaconMinor;
@property (nonatomic) double currentJitterDistance;
@property (strong, nonatomic) NSMutableArray<NSDictionary*> *savedLocations;
@property (strong, nonatomic) NSMutableArray<NSDictionary*> *savedBluetoothDevices;
@property (strong, nonatomic) NSMutableArray<YHScheduleItem*> *schedules;
@property (strong, nonatomic) NSTimer *jitterTimer;
@property (strong, nonatomic) NSTimer *scheduleTimer;
@property (strong, nonatomic) UIImage *spoofImage;
@property (strong, nonatomic) NSURL *spoofVideoURL;
@property (nonatomic, assign) NSInteger spoofCameraPosition;
@property (strong, nonatomic) AVPlayer *mediaPlayer;
- (void)overrideWith:(CLLocationDegrees)aLatitude longitude:(CLLocationDegrees)aLongitude;
- (void)saveLocation:(CLLocationCoordinate2D)coord withName:(NSString*)name favorite:(BOOL)fav;
- (void)updateJitterTimer;
- (void)checkSchedules;
- (void)saveSchedules;
- (NSString*)generateRandomUDID;
@end

@implementation YHManager
+ (YHManager *)shared {
    static YHManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sharedInstance = [YHManager new]; });
    return sharedInstance;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        NSArray *savedLocs = [NSUserDefaults.standardUserDefaults arrayForKey:kSaveKeyLocations];
        self.savedLocations = savedLocs ? [savedLocs mutableCopy] : [NSMutableArray new];
        
        NSArray *savedBle = [NSUserDefaults.standardUserDefaults arrayForKey:@"YH_Saved_BLE_Devices"];
        self.savedBluetoothDevices = savedBle ? [savedBle mutableCopy] : [NSMutableArray new];
        
        NSArray *scheds = [NSUserDefaults.standardUserDefaults arrayForKey:kSaveKeySchedule];
        self.schedules = [NSMutableArray new];
        for (NSDictionary *dict in scheds) {
            [self.schedules addObject:[[YHScheduleItem alloc] initWithDictionary:dict]];
        }
        
        self.isEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kSaveKeyGPSEnabled];
        self.isJitterEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kSaveKeyJitterEnabled];
        self.isUDIDSpoofEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kSaveKeyUDIDEnabled];
        self.isEngineEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kSaveKeyEngineEnabled];
        self.isDeviceIDSpoofEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kSaveKeyDeviceIDEnabled];
        
        self.isBluetoothSpoofEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kSaveBleEnabled];
        self.spoofBeaconUUID = [NSUserDefaults.standardUserDefaults stringForKey:kSaveBleUUID] ?: @"";
        self.spoofBeaconMajor = [NSUserDefaults.standardUserDefaults integerForKey:kSaveBleMajor];
        self.spoofBeaconMinor = [NSUserDefaults.standardUserDefaults integerForKey:kSaveBleMinor];
        
        self.spoofCameraPosition = 0;
        self.currentJitterDistance = 0.0;
        kGPSEnabled = self.isEnabled;
        
        double savedLat = [NSUserDefaults.standardUserDefaults doubleForKey:kSaveKeyLat];
        double savedLng = [NSUserDefaults.standardUserDefaults doubleForKey:kSaveKeyLng];
        if (savedLat != 0 && savedLng != 0) {
            kBaseLocation = CLLocationCoordinate2DMake(savedLat, savedLng);
            kLocation = kBaseLocation;
        }
        [self updateJitterTimer];
        
        self.scheduleTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkSchedules) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.scheduleTimer forMode:NSRunLoopCommonModes];
    }
    return self;
}
- (void)setIsEnabled:(BOOL)isEnabled {
    _isEnabled = isEnabled;
    kGPSEnabled = isEnabled;
    [NSUserDefaults.standardUserDefaults setBool:isEnabled forKey:kSaveKeyGPSEnabled];
    [NSUserDefaults.standardUserDefaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"YHOverrideDidChange" object:nil];
}
- (void)setIsJitterEnabled:(BOOL)isJitterEnabled {
    _isJitterEnabled = isJitterEnabled;
    [NSUserDefaults.standardUserDefaults setBool:isJitterEnabled forKey:kSaveKeyJitterEnabled];
    [NSUserDefaults.standardUserDefaults synchronize];
    [self updateJitterTimer];
}
- (void)setIsEngineEnabled:(BOOL)isEngineEnabled {
    _isEngineEnabled = isEngineEnabled;
    [NSUserDefaults.standardUserDefaults setBool:isEngineEnabled forKey:kSaveKeyEngineEnabled];
    [NSUserDefaults.standardUserDefaults synchronize];
}
- (void)setIsUDIDSpoofEnabled:(BOOL)isUDIDSpoofEnabled {
    _isUDIDSpoofEnabled = isUDIDSpoofEnabled;
    [NSUserDefaults.standardUserDefaults setBool:isUDIDSpoofEnabled forKey:kSaveKeyUDIDEnabled];
    [NSUserDefaults.standardUserDefaults synchronize];
}
- (void)setIsDeviceIDSpoofEnabled:(BOOL)isDeviceIDSpoofEnabled {
    _isDeviceIDSpoofEnabled = isDeviceIDSpoofEnabled;
    [NSUserDefaults.standardUserDefaults setBool:isDeviceIDSpoofEnabled forKey:kSaveKeyDeviceIDEnabled];
    [NSUserDefaults.standardUserDefaults synchronize];
}
- (void)setIsBluetoothSpoofEnabled:(BOOL)isBluetoothSpoofEnabled {
    _isBluetoothSpoofEnabled = isBluetoothSpoofEnabled;
    [NSUserDefaults.standardUserDefaults setBool:isBluetoothSpoofEnabled forKey:kSaveBleEnabled];
    [NSUserDefaults.standardUserDefaults synchronize];
}
- (void)setSpoofBeaconUUID:(NSString *)uuid {
    _spoofBeaconUUID = uuid;
    [NSUserDefaults.standardUserDefaults setObject:uuid forKey:kSaveBleUUID];
    [NSUserDefaults.standardUserDefaults synchronize];
}
- (void)setSpoofBeaconMajor:(NSInteger)major {
    _spoofBeaconMajor = major;
    [NSUserDefaults.standardUserDefaults setInteger:major forKey:kSaveBleMajor];
    [NSUserDefaults.standardUserDefaults synchronize];
}
- (void)setSpoofBeaconMinor:(NSInteger)minor {
    _spoofBeaconMinor = minor;
    [NSUserDefaults.standardUserDefaults setInteger:minor forKey:kSaveBleMinor];
    [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)overrideWith:(CLLocationDegrees)aLatitude longitude:(CLLocationDegrees)aLongitude {
    kBaseLocation = CLLocationCoordinate2DMake(aLatitude, aLongitude);
    kLocation = kBaseLocation;
    [NSUserDefaults.standardUserDefaults setDouble:aLatitude forKey:kSaveKeyLat];
    [NSUserDefaults.standardUserDefaults setDouble:aLongitude forKey:kSaveKeyLng];
    [NSUserDefaults.standardUserDefaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"YHOverrideDidChange" object:nil];
}
- (void)saveLocation:(CLLocationCoordinate2D)coord withName:(NSString*)name favorite:(BOOL)fav {
    NSDictionary *locDict = @{ @"name": name, @"lat": @(coord.latitude), @"lng": @(coord.longitude), @"favorite": @(fav) };
    [self.savedLocations addObject:locDict];
    [NSUserDefaults.standardUserDefaults setObject:self.savedLocations forKey:kSaveKeyLocations];
    [NSUserDefaults.standardUserDefaults synchronize];
}
- (void)saveSchedules {
    NSMutableArray *dicts = [NSMutableArray new];
    for (YHScheduleItem *item in self.schedules) {
        [dicts addObject:[item toDictionary]];
    }
    [NSUserDefaults.standardUserDefaults setObject:dicts forKey:kSaveKeySchedule];
    [NSUserDefaults.standardUserDefaults synchronize];
}
- (void)updateJitterTimer {
    if (self.isJitterEnabled) {
        [self.jitterTimer invalidate];
        self.jitterTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
            double randomDistance = ((double)arc4random() / UINT32_MAX) * 14.9 + 0.1;
            self.currentJitterDistance = randomDistance;
            double angle = ((double)arc4random_uniform(360)) * M_PI / 180.0;
            double lat = kBaseLocation.latitude;
            double lon = kBaseLocation.longitude;
            double metersPerDegreeLat = 111320.0;
            double metersPerDegreeLon = metersPerDegreeLat * cos(lat * M_PI / 180.0);
            double deltaLat = (randomDistance * cos(angle)) / metersPerDegreeLat;
            double deltaLon = (randomDistance * sin(angle)) / metersPerDegreeLon;
            kLocation = CLLocationCoordinate2DMake(lat + deltaLat, lon + deltaLon);
            [[NSNotificationCenter defaultCenter] postNotificationName:@"YHMapShouldRefresh" object:nil];
        }];
    } else {
        [self.jitterTimer invalidate];
        self.jitterTimer = nil;
        self.currentJitterDistance = 0.0;
        kLocation = kBaseLocation;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"YHMapShouldRefresh" object:nil];
    }
}
- (void)checkSchedules {
    NSDate *now = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *nowComps = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitWeekday|NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond fromDate:now];
    static NSInteger lastTriggeredMinute = -1;
    BOOL anyTriggered = NO;
    for (YHScheduleItem *item in self.schedules) {
        if (!item.enabled) continue;
        NSDateComponents *targetComps = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitWeekday|NSCalendarUnitHour|NSCalendarUnitMinute fromDate:item.targetDate];
        BOOL shouldTrigger = NO;
        if (item.repeatWeekly) {
            if (nowComps.weekday == targetComps.weekday && nowComps.hour == targetComps.hour && nowComps.minute == targetComps.minute) {
                shouldTrigger = YES;
            }
        } else {
            if (nowComps.year == targetComps.year && nowComps.month == targetComps.month && nowComps.day == targetComps.day && nowComps.hour == targetComps.hour && nowComps.minute == targetComps.minute) {
                shouldTrigger = YES;
            }
        }
        if (shouldTrigger && lastTriggeredMinute != nowComps.minute) {
            if (item.linkedLocationIndex >= 0 && item.linkedLocationIndex < self.savedLocations.count) {
                NSDictionary *loc = self.savedLocations[item.linkedLocationIndex];
                [self overrideWith:[loc[@"lat"] doubleValue] longitude:[loc[@"lng"] doubleValue]];
                self.isEnabled = YES;
            }
            if (item.mediaPath.length > 0) {
                NSURL *url = [NSURL fileURLWithPath:item.mediaPath];
                if (url) {
                    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
                    [[AVAudioSession sharedInstance] setActive:YES error:nil];
                    self.mediaPlayer = [AVPlayer playerWithURL:url];
                    [self.mediaPlayer play];
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"YHScheduleDidTrigger" object:item.title];
            });
            anyTriggered = YES;
        }
    }
    if (anyTriggered) { lastTriggeredMinute = nowComps.minute; }
}
- (NSString*)generateRandomUDID {
    uint32_t p1 = arc4random_uniform(0xFFFFFFFF);
    uint32_t p2 = arc4random_uniform(0xFFFFFFFF);
    uint32_t p3 = arc4random_uniform(0xFFFFFFFF);
    return [NSString stringWithFormat:@"0000%04X-%08X%08X", arc4random_uniform(0xFFFF), p2, p3];
}
@end

@interface YHMockBeacon : NSObject
@property (nonatomic, strong) NSUUID *proximityUUID;
@property (nonatomic, strong) NSNumber *major;
@property (nonatomic, strong) NSNumber *minor;
@property (nonatomic, assign) NSInteger proximity;
@property (nonatomic, assign) double accuracy;
@property (nonatomic, assign) NSInteger rssi;
@end
@implementation YHMockBeacon
- (NSUUID *)UUID { return self.proximityUUID; }
@end

static CLLocationCoordinate2D (*orig_coordinate)(id, SEL);
static CLLocationCoordinate2D my_coordinate(id self, SEL _cmd) {
    if (kGPSEnabled) { return kLocation; }
    return orig_coordinate(self, _cmd);
}

@interface YHProxy : NSProxy <CLLocationManagerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (weak, nonatomic, readonly) id delegate;
- (YHProxy*)initWithDelegate:(id)delegate locationManager:(CLLocationManager*)manager;
@end
@interface YHProxy()
@property (weak, nonatomic, readwrite) id delegate;
@property (weak, nonatomic) CLLocationManager *manager;
@end
@implementation YHProxy
- (YHProxy*)initWithDelegate:(id)delegate locationManager:(CLLocationManager*)manager {
    self.delegate = delegate;
    self.manager = manager;
    return self;
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    if ([NSStringFromSelector(invocation.selector) isEqualToString:@"locationManager:didUpdateLocations:"] ||
        [NSStringFromSelector(invocation.selector) isEqualToString:@"locationProvider:didUpdateLocation:"] ||
        [NSStringFromSelector(invocation.selector) isEqualToString:@"imagePickerController:didFinishPickingMediaWithInfo:"] ||
        [NSStringFromSelector(invocation.selector) isEqualToString:@"locationManager:didRangeBeacons:inRegion:"] ||
        [NSStringFromSelector(invocation.selector) isEqualToString:@"locationManager:didRangeBeacons:satisfyingConstraint:"]) {
        [invocation invokeWithTarget:self];
    } else if ([self.delegate respondsToSelector:invocation.selector]) {
        [invocation invokeWithTarget:self.delegate];
    }
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel { return [self.delegate methodSignatureForSelector:sel]; }
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    if (kGPSEnabled) {
        CLLocation *loc = [[CLLocation alloc] initWithCoordinate:kLocation altitude:15.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]];
        locations = @[loc];
    }
    [self.delegate locationManager:manager didUpdateLocations:locations];
}
- (void)locationProvider:(id)provider didUpdateLocation:(CLLocation*)location {
    if (kGPSEnabled) {
        location = [[CLLocation alloc] initWithCoordinate:kLocation altitude:15.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]];
    }
    [self.delegate locationProvider:provider didUpdateLocation:location];
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region {
    if (beacons.count > 0 && !YHManager.shared.isBluetoothSpoofEnabled) {
        CLBeacon *b = beacons.firstObject;
        [NSUserDefaults.standardUserDefaults setObject:[b.proximityUUID UUIDString] forKey:@"YH_AutoCopiedBeaconUUID"];
        [NSUserDefaults.standardUserDefaults setInteger:[b.major integerValue] forKey:@"YH_AutoCopiedBeaconMajor"];
        [NSUserDefaults.standardUserDefaults setInteger:[b.minor integerValue] forKey:@"YH_AutoCopiedBeaconMinor"];
        [NSUserDefaults.standardUserDefaults synchronize];
    }
    NSArray *finalBeacons = beacons;
    if (YHManager.shared.isBluetoothSpoofEnabled && YHManager.shared.spoofBeaconUUID.length > 0) {
        YHMockBeacon *mock = [YHMockBeacon new];
        mock.proximityUUID = [[NSUUID alloc] initWithUUIDString:YHManager.shared.spoofBeaconUUID];
        mock.major = @(YHManager.shared.spoofBeaconMajor);
        mock.minor = @(YHManager.shared.spoofBeaconMinor);
        mock.proximity = 1;
        mock.accuracy = 1.0;
        mock.rssi = -45;
        finalBeacons = [beacons arrayByAddingObject:mock];
    }
    if ([self.delegate respondsToSelector:@selector(locationManager:didRangeBeacons:inRegion:)]) {
        [self.delegate locationManager:manager didRangeBeacons:finalBeacons inRegion:region];
    }
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons satisfyingConstraint:(id)beaconConstraint {
    if (beacons.count > 0 && !YHManager.shared.isBluetoothSpoofEnabled) {
        CLBeacon *b = beacons.firstObject;
        [NSUserDefaults.standardUserDefaults setObject:[b.UUID UUIDString] forKey:@"YH_AutoCopiedBeaconUUID"];
        [NSUserDefaults.standardUserDefaults setInteger:[b.major integerValue] forKey:@"YH_AutoCopiedBeaconMajor"];
        [NSUserDefaults.standardUserDefaults setInteger:[b.minor integerValue] forKey:@"YH_AutoCopiedBeaconMinor"];
        [NSUserDefaults.standardUserDefaults synchronize];
    }
    NSArray *finalBeacons = beacons;
    if (YHManager.shared.isBluetoothSpoofEnabled && YHManager.shared.spoofBeaconUUID.length > 0) {
        YHMockBeacon *mock = [YHMockBeacon new];
        mock.proximityUUID = [[NSUUID alloc] initWithUUIDString:YHManager.shared.spoofBeaconUUID];
        mock.major = @(YHManager.shared.spoofBeaconMajor);
        mock.minor = @(YHManager.shared.spoofBeaconMinor);
        mock.proximity = 1;
        mock.accuracy = 1.0;
        mock.rssi = -45;
        finalBeacons = [beacons arrayByAddingObject:mock];
    }
    if ([self.delegate respondsToSelector:@selector(locationManager:didRangeBeacons:satisfyingConstraint:)]) {
        [self.delegate locationManager:manager didRangeBeacons:finalBeacons satisfyingConstraint:beaconConstraint];
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    NSMutableDictionary *mutInfo = [info mutableCopy];
    if (picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
        if (YHManager.shared.spoofImage) {
            mutInfo[UIImagePickerControllerOriginalImage] = YHManager.shared.spoofImage;
            mutInfo[UIImagePickerControllerEditedImage] = YHManager.shared.spoofImage;
            mutInfo[UIImagePickerControllerMediaType] = (NSString *)kUTTypeImage;
            [mutInfo removeObjectForKey:UIImagePickerControllerMediaURL];
            [mutInfo removeObjectForKey:UIImagePickerControllerLivePhoto];
        } else if (YHManager.shared.spoofVideoURL) {
            mutInfo[UIImagePickerControllerMediaURL] = YHManager.shared.spoofVideoURL;
            mutInfo[UIImagePickerControllerMediaType] = (NSString *)kUTTypeMovie;
            [mutInfo removeObjectForKey:UIImagePickerControllerOriginalImage];
            [mutInfo removeObjectForKey:UIImagePickerControllerEditedImage];
            [mutInfo removeObjectForKey:UIImagePickerControllerLivePhoto];
        }
    }
    if ([self.delegate respondsToSelector:@selector(imagePickerController:didFinishPickingMediaWithInfo:)]) {
        [self.delegate imagePickerController:picker didFinishPickingMediaWithInfo:[mutInfo copy]];
    }
}
@end

@interface YHCamHook : NSObject @end
@implementation YHCamHook
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ 
        [self swizzleCameraConnections]; 
    });
}
+ (void)swizzleCameraConnections {
    Class stillClass = NSClassFromString(@"AVCaptureStillImageOutput");
    if (stillClass) {
        SEL originalSelector = @selector(captureStillImageAsynchronouslyFromConnection:completionHandler:);
        Method originalMethod = class_getInstanceMethod(stillClass, originalSelector);
        if (originalMethod) {
            IMP originalIMP = method_getImplementation(originalMethod);
            IMP newIMP = imp_implementationWithBlock(^(id self, AVCaptureConnection *connection, void (^handler)(CMSampleBufferRef, NSError*)) {
                BOOL match = NO;
                if (YHManager.shared.spoofCameraPosition != 0) {
                    for (AVCaptureInputPort *port in connection.inputPorts) {
                        AVCaptureInput *input = port.input;
                        if ([input isKindOfClass:[AVCaptureDeviceInput class]]) {
                            AVCaptureDeviceInput *devInput = (AVCaptureDeviceInput *)input;
                            if (devInput.device.position == YHManager.shared.spoofCameraPosition) { match = YES; break; }
                        }
                    }
                }
                
                if (match && YHManager.shared.spoofImage) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                        NSData *imgData = UIImageJPEGRepresentation(YHManager.shared.spoofImage, 1.0);
                        CMSampleBufferRef sampleBuffer = NULL;
                        CMBlockBufferRef blockBuffer = NULL;
                        CMSampleTimingInfo timingInfo = {CMTimeMake(0, 1), kCMTimeInvalid, kCMTimeInvalid};
                        OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, (void*)imgData.bytes, imgData.length, kCFAllocatorNull, NULL, 0, imgData.length, 0, &blockBuffer);
                        if (status == kCMBlockBufferNoErr) {
                            CMFormatDescriptionRef format = NULL;
                            CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCMVideoCodecType_JPEG, 0, 0, NULL, &format);
                            CMSampleBufferCreate(kCFAllocatorDefault, blockBuffer, true, NULL, NULL, format, 1, 1, &timingInfo, 0, NULL, &sampleBuffer);
                            if (format) CFRelease(format);
                        }
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (handler) handler(sampleBuffer, nil);
                            if (sampleBuffer) CFRelease(sampleBuffer);
                            if (blockBuffer) CFRelease(blockBuffer);
                        });
                    });
                } else {
                    ((void (*)(id, SEL, AVCaptureConnection*, void (^)(CMSampleBufferRef, NSError*)))originalIMP)(self, originalSelector, connection, handler);
                }
            });
            method_setImplementation(originalMethod, newIMP);
            kCameraSpoofSupported = YES;
        }
    }
}
@end

static NSUUID *(*orig_identifierForVendor)(id, SEL);
static NSUUID *my_identifierForVendor(id self, SEL _cmd) {
    if (YHManager.shared.isUDIDSpoofEnabled) {
        NSString *custom = [NSUserDefaults.standardUserDefaults stringForKey:kSaveKeyUDID];
        if (custom.length > 0) {
            NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:custom];
            if (uuid) return uuid;
        }
    }
    return orig_identifierForVendor(self, _cmd);
}

static CFTypeRef (*orig_MGCopyAnswer)(CFStringRef prop);
static CFTypeRef my_MGCopyAnswer(CFStringRef prop) {
    NSString *property = (__bridge NSString *)prop;
    if ([property isEqualToString:@"UniqueDeviceID"] && YHManager.shared.isUDIDSpoofEnabled) {
        NSString *custom = [NSUserDefaults.standardUserDefaults stringForKey:kSaveKeyUDID];
        if (custom.length > 0) { return CFRetain((__bridge CFTypeRef)custom); }
    }
    return orig_MGCopyAnswer(prop);
}

static id (*orig_NSUserDefaults_objectForKey)(id, SEL, id);
static id my_NSUserDefaults_objectForKey(id self, SEL _cmd, NSString *key) {
    if ([key caseInsensitiveCompare:@"deviceid"] == NSOrderedSame || [key caseInsensitiveCompare:@"device_id"] == NSOrderedSame || [key caseInsensitiveCompare:@"uuid"] == NSOrderedSame) {
        CFPropertyListRef enabledRef = CFPreferencesCopyAppValue((__bridge CFStringRef)kSaveKeyDeviceIDEnabled, kCFPreferencesCurrentApplication);
        if (enabledRef) {
            BOOL enabled = [(__bridge NSNumber *)enabledRef boolValue];
            CFRelease(enabledRef);
            if (enabled) {
                CFPropertyListRef customRef = CFPreferencesCopyAppValue((__bridge CFStringRef)kSaveKeyDeviceID, kCFPreferencesCurrentApplication);
                if (customRef) {
                    NSString *custom = (__bridge_transfer NSString *)customRef;
                    if (custom.length > 0) return custom;
                }
            }
        }
    }
    return orig_NSUserDefaults_objectForKey(self, _cmd, key);
}

static IMP orig_CLLocationManager_setDelegate_imp;
static IMP orig_CLLocationManager_location_imp;
static void (*orig_MKCoreLocationProvider_setDelegate)(id, SEL, id);
static CLLocation *(*orig_MKCoreLocationProvider_lastLocation)(id, SEL);
static void (*orig_GMSMyLocationProvider_setDelegate)(id, SEL, id);
static CLLocation *(*orig_GMSMyLocationProvider_lastLocation)(id, SEL);
static IMP orig_UIImagePickerController_setDelegate_imp;

static void override_CLLocationManager_setDelegate(CLLocationManager *self, SEL _cmd, id delegate) {
    YHProxy *delegateProxy = [[YHProxy alloc] initWithDelegate:delegate locationManager:self];
    [retainer addObject:delegateProxy];
    ((void (*)(id, SEL, id))orig_CLLocationManager_setDelegate_imp)(self, _cmd, delegateProxy);
}
static CLLocation *override_CLLocationManager_location(CLLocationManager *self, SEL _cmd) {
    if (kGPSEnabled) { return [[CLLocation alloc] initWithCoordinate:kLocation altitude:15.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]]; }
    return ((CLLocation* (*)(id, SEL))orig_CLLocationManager_location_imp)(self, _cmd);
}
static void override_MKCoreLocationProvider_setDelegate(id self, SEL _cmd, id delegate) {
    if (delegate && kGPSEnabled) {
        YHProxy *proxy = [[YHProxy alloc] initWithDelegate:delegate locationManager:nil];
        @synchronized (retainer) { [retainer addObject:proxy]; }
        orig_MKCoreLocationProvider_setDelegate(self, _cmd, proxy);
    } else {
        orig_MKCoreLocationProvider_setDelegate(self, _cmd, delegate);
    }
}
static CLLocation *override_MKCoreLocationProvider_lastLocation(id self, SEL _cmd) {
    if (kGPSEnabled) { return [[CLLocation alloc] initWithCoordinate:kLocation altitude:15.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]]; }
    return orig_MKCoreLocationProvider_lastLocation(self, _cmd);
}
static void override_GMSMyLocationProvider_setDelegate(id self, SEL _cmd, id delegate) {
    if (delegate && kGPSEnabled) {
        YHProxy *proxy = [[YHProxy alloc] initWithDelegate:delegate locationManager:nil];
        @synchronized (retainer) { [retainer addObject:proxy]; }
        orig_GMSMyLocationProvider_setDelegate(self, _cmd, proxy);
    } else {
        orig_GMSMyLocationProvider_setDelegate(self, _cmd, delegate);
    }
}
static CLLocation *override_GMSMyLocationProvider_lastLocation(id self, SEL _cmd) {
    if (kGPSEnabled) { return [[CLLocation alloc] initWithCoordinate:kLocation altitude:15.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]]; }
    return orig_GMSMyLocationProvider_lastLocation(self, _cmd);
}
static void override_UIImagePickerController_setDelegate(UIImagePickerController *self, SEL _cmd, id delegate) {
    if (delegate) {
        YHProxy *delegateProxy = [[YHProxy alloc] initWithDelegate:delegate locationManager:nil];
        @synchronized (retainer) { [retainer addObject:delegateProxy]; }
        ((void (*)(id, SEL, id))orig_UIImagePickerController_setDelegate_imp)(self, _cmd, delegateProxy);
    } else {
        ((void (*)(id, SEL, id))orig_UIImagePickerController_setDelegate_imp)(self, _cmd, delegate);
    }
}

@interface YHToggle : UIControl
@property (nonatomic, assign) BOOL isOn;
@property (nonatomic, strong) UIView *thumb;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end

@implementation YHToggle
- (instancetype)init {
    self = [super initWithFrame:CGRectMake(0, 0, 56, 30)];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        self.layer.cornerRadius = 15;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
        
        self.thumb = [[UIView alloc] initWithFrame:CGRectMake(2, 2, 26, 26)];
        self.thumb.backgroundColor = [UIColor whiteColor];
        self.thumb.layer.cornerRadius = 13;
        self.thumb.layer.shadowColor = COL_ACCENT.CGColor;
        self.thumb.layer.shadowOffset = CGSizeZero;
        self.thumb.layer.shadowOpacity = 0.0;
        self.thumb.layer.shadowRadius = 8;
        self.thumb.userInteractionEnabled = NO;
        [self addSubview:self.thumb];
        [self addTarget:self action:@selector(toggleTapped) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}
- (void)toggleTapped {
    [self setOn:!self.isOn animated:YES];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}
- (void)setOn:(BOOL)on animated:(BOOL)animated {
    _isOn = on;
    CGFloat targetX = on ? self.bounds.size.width - 28 : 2;
    UIColor *targetColor = on ? COL_ACCENT : [UIColor colorWithWhite:1.0 alpha:0.15];
    CGFloat shadowOpacity = on ? 0.8 : 0.0;
    
    if (animated) {
        [UIView animateWithDuration:0.4 delay:0.0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.thumb.frame = CGRectMake(targetX, 2, 26, 26);
            self.backgroundColor = targetColor;
            self.thumb.layer.shadowOpacity = shadowOpacity;
        } completion:nil];
    } else {
        self.thumb.frame = CGRectMake(targetX, 2, 26, 26);
        self.backgroundColor = targetColor;
        self.thumb.layer.shadowOpacity = shadowOpacity;
    }
}
- (void)setOn:(BOOL)on { [self setOn:on animated:NO]; }
@end

@interface YHMenuVC : UIViewController <MKMapViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate, UIScrollViewDelegate, UITableViewDelegate, UITableViewDataSource, UIPickerViewDelegate, UIPickerViewDataSource>
@property (nonatomic, strong) UIView *mainContainerView;
@property (nonatomic, strong) UIView *animatedOrb1;
@property (nonatomic, strong) UIView *animatedOrb2;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *mapContainer;
@property (nonatomic, strong) UIButton *fullscreenBtn;
@property (nonatomic, assign) CGRect originalMapFrame;
@property (nonatomic, assign) BOOL isMapFullscreen;
@property (nonatomic, strong) MKMapView *map;
@property (nonatomic, strong) MKPointAnnotation *locationAnnotation;
@property (nonatomic, strong) UILabel *distanceLabel;
@property (nonatomic, strong) UILabel *liveCoordLabel;
@property (nonatomic, strong) YHToggle *gpsSwitch;
@property (nonatomic, strong) YHToggle *jitterSwitch;
@property (nonatomic, strong) UIView *scrollIndicator;
@property (nonatomic, strong) UILabel *foxIconLabel; 
@property (nonatomic, assign) BOOL isPickingForSpoof;
@property (nonatomic, strong) UIView *foxContainer;
@property (nonatomic, strong) NSArray<UIButton*> *actionButtons;
@property (nonatomic, strong) UIButton *btnTimerAlert;
@property (nonatomic, strong) NSTimer *attendanceTimer;
@property (nonatomic, strong) NSTimer *warningTimer;
@property (nonatomic, strong) UIView *editScheduleView;
@property (nonatomic, strong) UITableView *scheduleTable;
@property (nonatomic, strong) UIDatePicker *datePicker;
@property (nonatomic, strong) UIPickerView *locationPicker;
@property (nonatomic, strong) UITextField *scheduleTitleField;
@property (nonatomic, strong) UISwitch *repeatSwitch;
@property (nonatomic, strong) UITableView *resultsTable;
@property (nonatomic, strong) UITableView *savedLocationsTable;
@property (nonatomic, strong) NSArray *searchResults;
@property (nonatomic, assign) BOOL isEditingSchedule;
@property (nonatomic, assign) NSInteger editingIndex;
@property (nonatomic, assign) BOOL isWarningActive;
@end

@implementation YHMenuVC
- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [UIColor clearColor];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(overrideMap) name:@"YHOverrideDidChange" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshMapLive) name:@"YHMapShouldRefresh" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resumeFoxAnimation) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    self.attendanceTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateAttendanceCountdown) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.attendanceTimer forMode:NSRunLoopCommonModes];
    [self updateAttendanceCountdown];
    
    self.warningTimer = [NSTimer scheduledTimerWithTimeInterval:120.0 target:self selector:@selector(toggleWarningIcon) userInfo:nil repeats:YES];
}

- (void)setupCyberBackground {
    self.animatedOrb1 = [[UIView alloc] initWithFrame:CGRectMake(-50, -50, 200, 200)];
    self.animatedOrb1.backgroundColor = [COL_ACCENT colorWithAlphaComponent:0.4];
    self.animatedOrb1.layer.cornerRadius = 100;
    self.animatedOrb1.layer.masksToBounds = YES;
    
    self.animatedOrb2 = [[UIView alloc] initWithFrame:CGRectMake(MENU_WIDTH - 100, MENU_HEIGHT - 200, 250, 250)];
    self.animatedOrb2.backgroundColor = [COL_PURPLE colorWithAlphaComponent:0.6];
    self.animatedOrb2.layer.cornerRadius = 125;
    self.animatedOrb2.layer.masksToBounds = YES;
    
    [self.mainContainerView addSubview:self.animatedOrb1];
    [self.mainContainerView addSubview:self.animatedOrb2];
    
    [self animateOrbs];
}

- (void)animateOrbs {
    [UIView animateWithDuration:8.0 delay:0 options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionCurveEaseInOut animations:^{
        self.animatedOrb1.transform = CGAffineTransformMakeTranslation(150, 200);
        self.animatedOrb1.transform = CGAffineTransformScale(self.animatedOrb1.transform, 1.2, 1.2);
        self.animatedOrb1.alpha = 0.2;
        self.animatedOrb2.transform = CGAffineTransformMakeTranslation(-150, -250);
        self.animatedOrb2.transform = CGAffineTransformScale(self.animatedOrb2.transform, 0.8, 0.8);
        self.animatedOrb2.alpha = 0.9;
    } completion:nil];
}

- (void)resumeFoxAnimation {
    if (YHManager.shared.isEnabled) { [self startFoxAnimation]; }
}
- (void)refreshMapLive {
    if (self.locationAnnotation) {
        [UIView animateWithDuration:0.5 animations:^{ self.locationAnnotation.coordinate = kLocation; }];
    }
    self.distanceLabel.text = [NSString stringWithFormat:@"المسافة: %.1f متر", YHManager.shared.currentJitterDistance];
    self.liveCoordLabel.text = [NSString stringWithFormat:@"%.5f, %.5f", kLocation.latitude, kLocation.longitude];
}
- (void)overrideMap {
    [self.map removeAnnotations:self.map.annotations];
    self.locationAnnotation = [MKPointAnnotation new];
    self.locationAnnotation.coordinate = kBaseLocation;
    [self.map addAnnotation:self.locationAnnotation];
    [self.map setCenterCoordinate:kBaseLocation animated:YES];
    self.distanceLabel.text = @"المسافة: 0.0 متر";
    self.liveCoordLabel.text = [NSString stringWithFormat:@"%.5f, %.5f", kBaseLocation.latitude, kBaseLocation.longitude];
}
- (void)updateButtonAnimations {
    if (YHManager.shared.isEnabled) {
        NSArray *anims = @[@"pulse", @"sparkle", @"wiggle", @"none", @"photoFlash", @"shake", @"flip", @"bounce"];
        for (int i=0; i<self.actionButtons.count; i++) {
            UIButton *btn = self.actionButtons[i];
            [btn.layer removeAllAnimations];
            [btn.imageView.layer removeAllAnimations];
            NSString *animType = anims[i % anims.count];
            
            if (i == 3) {
                CABasicAnimation *move = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
                move.duration = 0.5;
                move.fromValue = @(-6);
                move.toValue = @(6);
                move.autoreverses = YES;
                move.repeatCount = HUGE_VALF;
                [btn.layer addAnimation:move forKey:@"warningMove"];
                continue;
            }
            
            if ([animType isEqualToString:@"pulse"]) {
                CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
                a.duration = 0.8; a.fromValue = @0.9; a.toValue = @1.1; a.autoreverses = YES; a.repeatCount = HUGE_VALF;
                [btn.imageView.layer addAnimation:a forKey:animType];
            } else if ([animType isEqualToString:@"sparkle"]) {
                CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"opacity"];
                a.duration = 0.6; a.fromValue = @0.3; a.toValue = @1.0; a.autoreverses = YES; a.repeatCount = HUGE_VALF;
                [btn.imageView.layer addAnimation:a forKey:animType];
            } else if ([animType isEqualToString:@"wiggle"]) {
                CAKeyframeAnimation *a = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
                a.values = @[@0.0, @-0.15, @0.0, @0.15, @0.0]; a.keyTimes = @[@0.0, @0.25, @0.5, @0.75, @1.0];
                a.duration = 1.5; a.repeatCount = HUGE_VALF;
                [btn.imageView.layer addAnimation:a forKey:animType];
            } else if ([animType isEqualToString:@"bounce"]) {
                CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
                a.duration = 0.8; a.fromValue = @-3.0; a.toValue = @3.0; a.autoreverses = YES; a.repeatCount = HUGE_VALF;
                [btn.imageView.layer addAnimation:a forKey:animType];
            } else if ([animType isEqualToString:@"shake"]) {
                CAKeyframeAnimation *a = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
                a.values = @[@0, @-2, @2, @-2, @2, @0]; a.duration = 1.5; a.repeatCount = HUGE_VALF;
                [btn.imageView.layer addAnimation:a forKey:animType];
            } else if ([animType isEqualToString:@"flip"]) {
                CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"transform.rotation.y"];
                a.duration = 2.0; a.toValue = @(M_PI * 2); a.repeatCount = HUGE_VALF;
                [btn.imageView.layer addAnimation:a forKey:animType];
            } else if ([animType isEqualToString:@"photoFlash"]) {
                CAKeyframeAnimation *flash = [CAKeyframeAnimation animationWithKeyPath:@"backgroundColor"];
                flash.values = @[(id)[UIColor clearColor].CGColor, (id)[UIColor whiteColor].CGColor, (id)[UIColor clearColor].CGColor];
                flash.keyTimes = @[@0.0, @0.05, @1.0];
                flash.duration = 2.5; flash.repeatCount = HUGE_VALF;
                [btn.layer addAnimation:flash forKey:@"flashAnim"];
            }
        }
    } else {
        for (int i=0; i<self.actionButtons.count; i++) {
            UIButton *btn = self.actionButtons[i];
            [btn.layer removeAllAnimations];
            [btn.imageView.layer removeAllAnimations];
            if (i == 3) {
                CABasicAnimation *move = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
                move.duration = 0.5; move.fromValue = @(-6); move.toValue = @(6);
                move.autoreverses = YES; move.repeatCount = HUGE_VALF;
                [btn.layer addAnimation:move forKey:@"warningMove"];
            }
        }
    }
}

- (void)toggleWarningIcon {
    if (self.actionButtons.count > 3) {
        UIButton *btn = self.actionButtons[3];
        self.isWarningActive = !self.isWarningActive;
        NSString *sysName = self.isWarningActive ? @"exclamationmark.triangle.fill" : @"info.square.fill";
        UIColor *tint = self.isWarningActive ? COL_RED : COL_ACCENT;
        [btn setImage:[UIImage systemImageNamed:sysName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
        btn.tintColor = tint;
    }
}

- (void)startFoxAnimation {
    self.foxIconLabel.alpha = 1.0;
    self.foxContainer.layer.shadowColor = COL_ACCENT.CGColor;
    self.foxContainer.layer.shadowRadius = 15.0;
    self.foxContainer.layer.shadowOpacity = 1.0;
    [self.foxContainer.layer removeAllAnimations];
    
    CABasicAnimation *hover = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    hover.duration = 1.5; hover.fromValue = @(-4.0); hover.toValue = @(4.0);
    hover.autoreverses = YES; hover.repeatCount = HUGE_VALF;
    hover.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.foxContainer.layer addAnimation:hover forKey:@"hoverAnimation"];

    CAKeyframeAnimation *rock = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
    rock.values = @[@(-0.15), @(0.0), @(0.15), @(0.0), @(-0.15)];
    rock.keyTimes = @[@0.0, @0.25, @0.5, @0.75, @1.0];
    rock.duration = 3.0; rock.repeatCount = HUGE_VALF;
    rock.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.foxContainer.layer addAnimation:rock forKey:@"rockAnimation"];
    
    [self updateButtonAnimations];
}

- (void)stopFoxAnimation {
    self.foxIconLabel.alpha = 0.4;
    self.foxContainer.layer.shadowColor = [UIColor clearColor].CGColor;
    self.foxContainer.layer.shadowRadius = 0.0;
    self.foxContainer.layer.shadowOpacity = 0.0;
    [self.foxContainer.layer removeAllAnimations];
    [self updateButtonAnimations];
}

- (void)openTelegram {
    NSURL *url = [NSURL URLWithString:@"https://t.me/BynoGPS"];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    } else {
        [self showToast:@"تعذر فتح تليجرام"];
    }
}

- (void)setupUI {
    CGFloat xPos = (self.view.bounds.size.width - MENU_WIDTH) / 2.0;
    CGFloat yPos = (self.view.bounds.size.height - MENU_HEIGHT) / 2.0;
    
    self.mainContainerView = [[UIView alloc] initWithFrame:CGRectMake(xPos, yPos, MENU_WIDTH, MENU_HEIGHT)];
    self.mainContainerView.backgroundColor = COL_BG;
    self.mainContainerView.layer.cornerRadius = 40;
    self.mainContainerView.clipsToBounds = YES;
    self.mainContainerView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.mainContainerView.layer.shadowOffset = CGSizeMake(0, 15);
    self.mainContainerView.layer.shadowOpacity = 0.5;
    self.mainContainerView.layer.shadowRadius = 30;
    self.mainContainerView.layer.borderWidth = 1.5;
    self.mainContainerView.layer.borderColor = [COL_ACCENT colorWithAlphaComponent:0.3].CGColor;
    [self.view addSubview:self.mainContainerView];

    [self setupCyberBackground];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = self.mainContainerView.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.mainContainerView addSubview:blurView];
    
    UIView *tintView = [[UIView alloc] initWithFrame:self.mainContainerView.bounds];
    tintView.backgroundColor = COL_GLASS;
    [self.mainContainerView addSubview:tintView];

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, MENU_WIDTH, 80)];
    header.backgroundColor = COL_HEADER;
    [self.mainContainerView addSubview:header];

    UIButton *closeBtn = [[UIButton alloc] initWithFrame:CGRectMake(15, 25, 35, 35)];
    [closeBtn setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.6] forState:UIControlStateNormal];
    closeBtn.tintColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    closeBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    closeBtn.layer.cornerRadius = 17.5;
    [closeBtn addTarget:self action:@selector(closeView) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];

    self.foxContainer = [[UIView alloc] initWithFrame:CGRectMake(20, 20, 44, 44)];
    self.foxContainer.backgroundColor = [UIColor clearColor];
    [header addSubview:self.foxContainer];

    self.foxIconLabel = [[UILabel alloc] initWithFrame:self.foxContainer.bounds];
    self.foxIconLabel.text = @"🦊";
    self.foxIconLabel.font = [UIFont systemFontOfSize:28];
    self.foxIconLabel.textAlignment = NSTextAlignmentCenter;
    self.foxIconLabel.textColor = COL_ACCENT;
    [self.foxContainer addSubview:self.foxIconLabel];

    UIButton *headerTitleBtn = [[UIButton alloc] initWithFrame:CGRectMake(70, 20, 200, 44)];
    [headerTitleBtn setTitle:@"Byno GPS Pro" forState:UIControlStateNormal];
    [headerTitleBtn setTitleColor:COL_TEXT forState:UIControlStateNormal];
    headerTitleBtn.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBlack];
    headerTitleBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [headerTitleBtn addTarget:self action:@selector(openTelegram) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:headerTitleBtn];

    if (YHManager.shared.isEnabled) { [self startFoxAnimation]; } else { [self stopFoxAnimation]; }

    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 80, MENU_WIDTH, MENU_HEIGHT - 80)];
    self.scrollView.delegate = self;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.mainContainerView addSubview:self.scrollView];

    self.originalMapFrame = CGRectMake(20, 10, MENU_WIDTH - 40, 220);
    self.mapContainer = [[UIView alloc] initWithFrame:self.originalMapFrame];
    self.mapContainer.layer.cornerRadius = 30;
    self.mapContainer.clipsToBounds = YES;
    self.mapContainer.layer.borderWidth = 1.0;
    self.mapContainer.layer.borderColor = [COL_ACCENT colorWithAlphaComponent:0.4].CGColor;
    [self.scrollView addSubview:self.mapContainer];

    self.map = [[MKMapView alloc] initWithFrame:self.mapContainer.bounds];
    self.map.delegate = self;
    self.map.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.map.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.mapContainer addSubview:self.map];
    
    UILongPressGestureRecognizer *lpMap = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleMapLongPress:)];
    lpMap.minimumPressDuration = 0.5;
    [self.map addGestureRecognizer:lpMap];

    UIButton *mapTypeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    mapTypeBtn.frame = CGRectMake(10, 10, 40, 40);
    mapTypeBtn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
    mapTypeBtn.layer.cornerRadius = 20;
    mapTypeBtn.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    [mapTypeBtn setImage:[UIImage systemImageNamed:@"map.fill"] forState:UIControlStateNormal];
    mapTypeBtn.tintColor = COL_ACTIVE;
    [mapTypeBtn addTarget:self action:@selector(showMapTypes) forControlEvents:UIControlEventTouchUpInside];
    [self.mapContainer addSubview:mapTypeBtn];
    
    self.fullscreenBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.fullscreenBtn.frame = CGRectMake(self.mapContainer.bounds.size.width - 50, 10, 40, 40);
    self.fullscreenBtn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
    self.fullscreenBtn.layer.cornerRadius = 20;
    self.fullscreenBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.fullscreenBtn setImage:[UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right"] forState:UIControlStateNormal];
    self.fullscreenBtn.tintColor = COL_ACTIVE;
    [self.fullscreenBtn addTarget:self action:@selector(toggleMapFullscreen) forControlEvents:UIControlEventTouchUpInside];
    [self.mapContainer addSubview:self.fullscreenBtn];

    UIBlurEffect *infoBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *infoBox = [[UIVisualEffectView alloc] initWithEffect:infoBlur];
    infoBox.frame = CGRectMake((self.mapContainer.bounds.size.width - 220)/2, self.mapContainer.bounds.size.height - 60, 220, 50);
    infoBox.layer.cornerRadius = 16;
    infoBox.clipsToBounds = YES;
    infoBox.layer.borderWidth = 1.0;
    infoBox.layer.borderColor = [COL_ACCENT colorWithAlphaComponent:0.3].CGColor;
    infoBox.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.mapContainer addSubview:infoBox];

    self.distanceLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 200, 20)];
    self.distanceLabel.textColor = COL_ACCENT;
    self.distanceLabel.font = [UIFont boldSystemFontOfSize:13];
    self.distanceLabel.textAlignment = NSTextAlignmentCenter;
    [infoBox.contentView addSubview:self.distanceLabel];

    self.liveCoordLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 25, 200, 20)];
    self.liveCoordLabel.textColor = [UIColor whiteColor];
    self.liveCoordLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightBold];
    self.liveCoordLabel.textAlignment = NSTextAlignmentCenter;
    [infoBox.contentView addSubview:self.liveCoordLabel];

    self.resultsTable = [[UITableView alloc] initWithFrame:CGRectMake(20, 10, MENU_WIDTH - 40, 220)];
    self.resultsTable.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    self.resultsTable.hidden = YES;
    self.resultsTable.layer.cornerRadius = 24;
    self.resultsTable.delegate = self;
    self.resultsTable.dataSource = self;
    [self.scrollView addSubview:self.resultsTable];
    
    self.savedLocationsTable = [[UITableView alloc] initWithFrame:CGRectMake(20, 10, MENU_WIDTH - 40, 220)];
    self.savedLocationsTable.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    self.savedLocationsTable.hidden = YES;
    self.savedLocationsTable.layer.cornerRadius = 24;
    self.savedLocationsTable.delegate = self;
    self.savedLocationsTable.dataSource = self;
    [self.scrollView addSubview:self.savedLocationsTable];

    [self overrideMap];

    CGFloat contentY = 250;

    NSArray *titles = @[@"حفظ", @"بحث", @"المحفوظ", @"معلومات", @"الكاميرا", @"البيانات", @"الجدولة", @"الاتصال"];
    NSArray *symbolNames = @[@"folder.badge.plus", @"magnifyingglass.circle.fill", @"star.fill", @"info.square.fill", @"camera.aperture", @"lock.shield.fill", @"timer", @"wifi.router.fill"];
    
    NSMutableArray *tempBtns = [NSMutableArray new];
    CGFloat btnWidth = 60;
    CGFloat btnSpacing = (MENU_WIDTH - (4 * btnWidth)) / 5;
    
    for (int i=0; i<8; i++) {
        int row = i / 4;
        int col = i % 4;
        CGFloat y = contentY + (row * 105);
        
        UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(btnSpacing + col*(btnWidth+btnSpacing), y, btnWidth, btnWidth)];
        btn.layer.cornerRadius = btnWidth / 2.0;
        btn.layer.borderWidth = 1.0;
        btn.layer.borderColor = [COL_ACCENT colorWithAlphaComponent:0.3].CGColor;
        btn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.05];
        
        btn.layer.shadowColor = COL_ACCENT.CGColor;
        btn.layer.shadowOpacity = 0.15;
        btn.layer.shadowRadius = 8;
        btn.layer.shadowOffset = CGSizeMake(0, 4);
        btn.tag = i;
        
        UIImage *sym = [UIImage systemImageNamed:symbolNames[i] withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightRegular]];
        [btn setImage:sym forState:UIControlStateNormal];
        btn.tintColor = COL_ACCENT;
        [btn setTitle:@"" forState:UIControlStateNormal];
        
        [btn addTarget:self action:@selector(gridButtons:) forControlEvents:UIControlEventTouchUpInside];
        [self.scrollView addSubview:btn];
        [tempBtns addObject:btn];

        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(btnSpacing + col*(btnWidth+btnSpacing), y+65, btnWidth, 20)];
        lbl.text = titles[i];
        lbl.textColor = COL_SUBTEXT;
        lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        lbl.textAlignment = NSTextAlignmentCenter;
        [self.scrollView addSubview:lbl];
        
        if (i == 3) {
            CABasicAnimation *move = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
            move.duration = 0.5; move.fromValue = @(-6); move.toValue = @(6);
            move.autoreverses = YES; move.repeatCount = HUGE_VALF;
            [btn.layer addAnimation:move forKey:@"warningMove"];
        }
    }
    
    contentY += 210;
    
    self.btnTimerAlert = [[UIButton alloc] initWithFrame:CGRectMake(btnSpacing + 3*(btnWidth+btnSpacing), contentY, btnWidth, btnWidth)];
    self.btnTimerAlert.layer.cornerRadius = btnWidth / 2.0;
    self.btnTimerAlert.layer.borderWidth = 1.0;
    self.btnTimerAlert.layer.borderColor = COL_RED.CGColor;
    self.btnTimerAlert.backgroundColor = [COL_RED colorWithAlphaComponent:0.15];
    self.btnTimerAlert.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.btnTimerAlert.titleLabel.minimumScaleFactor = 0.4;
    self.btnTimerAlert.titleLabel.numberOfLines = 2;
    self.btnTimerAlert.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.btnTimerAlert.titleEdgeInsets = UIEdgeInsetsMake(0, 2, 0, 2);
    [self.btnTimerAlert setTitle:@"00:00" forState:UIControlStateNormal];
    [self.btnTimerAlert setTitleColor:COL_TEXT forState:UIControlStateNormal];
    self.btnTimerAlert.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    self.btnTimerAlert.tag = 8;
    [self.btnTimerAlert addTarget:self action:@selector(showScheduleEditor) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.btnTimerAlert];

    UILabel *lblTimer = [[UILabel alloc] initWithFrame:CGRectMake(btnSpacing + 3*(btnWidth+btnSpacing), contentY+65, btnWidth, 20)];
    lblTimer.text = @"التنبيه";
    lblTimer.textColor = COL_SUBTEXT;
    lblTimer.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    lblTimer.textAlignment = NSTextAlignmentCenter;
    [self.scrollView addSubview:lblTimer];
    
    self.actionButtons = [tempBtns copy];
    contentY += 105;

    self.gpsSwitch = [[YHToggle alloc] init];
    [self.gpsSwitch setOn:YHManager.shared.isEnabled animated:NO];
    [self.gpsSwitch addTarget:self action:@selector(toggleGPS:) forControlEvents:UIControlEventValueChanged];
    [self.scrollView addSubview:[self createRowWithTitle:@"تفعيل المحرك الوهمي" iconName:@"location.circle.fill" control:self.gpsSwitch yPos:contentY]];
    contentY += 75;

    self.jitterSwitch = [[YHToggle alloc] init];
    [self.jitterSwitch setOn:YHManager.shared.isJitterEnabled animated:NO];
    [self.jitterSwitch addTarget:self action:@selector(toggleJitter:) forControlEvents:UIControlEventValueChanged];
    [self.scrollView addSubview:[self createRowWithTitle:@"تفعيل محاكي الحركة" iconName:@"waveform.path.ecg.rectangle.fill" control:self.jitterSwitch yPos:contentY]];
    contentY += 75;

    UIButton *manualBtn = [[UIButton alloc] initWithFrame:CGRectMake(20, contentY, MENU_WIDTH-40, 55)];
    manualBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.05];
    manualBtn.layer.cornerRadius = 20;
    manualBtn.layer.borderWidth = 1.0;
    manualBtn.layer.borderColor = [COL_ACCENT colorWithAlphaComponent:0.4].CGColor;
    [manualBtn setTitle:@" إدخال بيانات يدوية" forState:UIControlStateNormal];
    [manualBtn setImage:[UIImage systemImageNamed:@"highlighter"] forState:UIControlStateNormal];
    manualBtn.tintColor = COL_TEXT;
    manualBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [manualBtn addTarget:self action:@selector(openManualCoordinates) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:manualBtn];
    contentY += 70;

    UIButton *stopBtn = [[UIButton alloc] initWithFrame:CGRectMake(20, contentY, MENU_WIDTH-40, 55)];
    stopBtn.backgroundColor = [COL_RED colorWithAlphaComponent:0.8];
    stopBtn.layer.cornerRadius = 20;
    [stopBtn setTitle:@" إيقاف جميع العمليات" forState:UIControlStateNormal];
    [stopBtn setImage:[UIImage systemImageNamed:@"stop.circle.fill"] forState:UIControlStateNormal];
    stopBtn.tintColor = COL_TEXT;
    stopBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    stopBtn.layer.shadowColor = COL_RED.CGColor;
    stopBtn.layer.shadowRadius = 10.0;
    stopBtn.layer.shadowOpacity = 0.5;
    stopBtn.layer.shadowOffset = CGSizeMake(0, 5);
    [stopBtn addTarget:self action:@selector(stopAll) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:stopBtn];
    contentY += 80;

    self.scrollView.contentSize = CGSizeMake(MENU_WIDTH, contentY);

    self.scrollIndicator = [[UIView alloc] initWithFrame:CGRectMake((MENU_WIDTH-40)/2, MENU_HEIGHT-40, 40, 30)];
    self.scrollIndicator.backgroundColor = [UIColor clearColor];
    self.scrollIndicator.userInteractionEnabled = NO;
    
    UIImageView *arrow = [[UIImageView alloc] initWithFrame:CGRectMake(10, 5, 20, 20)];
    arrow.image = [UIImage systemImageNamed:@"chevron.compact.down" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightBold]];
    arrow.tintColor = COL_ACCENT;
    arrow.contentMode = UIViewContentModeScaleAspectFit;
    [self.scrollIndicator addSubview:arrow];
    
    [self.mainContainerView addSubview:self.scrollIndicator];
    [self scrollViewDidScroll:self.scrollView];
    
    [self setupScheduleEditor];
}

- (void)toggleMapFullscreen {
    self.isMapFullscreen = !self.isMapFullscreen;
    if (self.isMapFullscreen) {
        CGRect rectInMain = [self.scrollView convertRect:self.originalMapFrame toView:self.mainContainerView];
        [self.mapContainer removeFromSuperview];
        self.mapContainer.frame = rectInMain;
        [self.mainContainerView addSubview:self.mapContainer];
        [self.mainContainerView bringSubviewToFront:self.mapContainer];
        
        [UIView animateWithDuration:0.3 animations:^{
            self.mapContainer.frame = self.mainContainerView.bounds;
            self.mapContainer.layer.cornerRadius = 40;
            [self.fullscreenBtn setImage:[UIImage systemImageNamed:@"arrow.down.right.and.arrow.up.left"] forState:UIControlStateNormal];
        }];
    } else {
        CGRect targetRectInMain = [self.scrollView convertRect:self.originalMapFrame toView:self.mainContainerView];
        [UIView animateWithDuration:0.3 animations:^{
            self.mapContainer.frame = targetRectInMain;
            self.mapContainer.layer.cornerRadius = 30;
            [self.fullscreenBtn setImage:[UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right"] forState:UIControlStateNormal];
        } completion:^(BOOL finished) {
            [self.mapContainer removeFromSuperview];
            self.mapContainer.frame = self.originalMapFrame;
            [self.scrollView addSubview:self.mapContainer];
        }];
    }
}

- (void)handleMapLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint point = [gesture locationInView:self.map];
        CLLocationCoordinate2D coord = [self.map convertPoint:point toCoordinateFromView:self.map];
        [self processCoordinateSelection:coord.latitude lng:coord.longitude];
        [self showToast:@"تم تحديد نقطة الإرسال بنجاح"];
    }
}

- (void)showMapTypes {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"نمط العرض" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [ac addAction:[UIAlertAction actionWithTitle:@"عادي" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        self.map.mapType = MKMapTypeStandard;
        [self showToast:@"تم التعيين"];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"قمر صناعي" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        self.map.mapType = MKMapTypeSatellite;
        [self showToast:@"تم التعيين"];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"مختلط" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        self.map.mapType = MKMapTypeHybrid;
        [self showToast:@"تم التعيين"];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [self presentAlert:ac];
}

- (UIView *)createRowWithTitle:(NSString *)title iconName:(NSString *)iconName control:(UIView *)control yPos:(CGFloat)y {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(20, y, MENU_WIDTH-40, 60)];
    row.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.05];
    row.layer.cornerRadius = 25;
    row.layer.borderWidth = 1.0;
    row.layer.borderColor = [COL_ACCENT colorWithAlphaComponent:0.2].CGColor;
    
    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(MENU_WIDTH-75, 15, 30, 30)];
    iconView.image = [UIImage systemImageNamed:iconName withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightRegular]];
    iconView.tintColor = COL_ACCENT;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [row addSubview:iconView];

    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(90, 19, MENU_WIDTH-180, 22)];
    titleLbl.text = title;
    titleLbl.textColor = COL_TEXT;
    titleLbl.font = [UIFont boldSystemFontOfSize:15];
    titleLbl.textAlignment = NSTextAlignmentRight;
    [row addSubview:titleLbl];
    
    if (control) {
        control.frame = CGRectMake(16, (60 - control.bounds.size.height)/2, control.bounds.size.width, control.bounds.size.height);
        [row addSubview:control];
    }
    return row;
}

- (void)gridButtons:(UIButton *)btn {
    switch (btn.tag) {
        case 0: [self saveCurrentLocation]; break;
        case 1: [self showInMenuSearch]; break;
        case 2: [self showFavorites]; break;
        case 3: [self showWarningInfo]; break;
        case 4: [self uploadImageFromCameraRoll]; break;
        case 5: [self openIdentitySetup]; break;
        case 6: [self showScheduleEditor]; break;
        case 7: [self showBluetoothMenu]; break;
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat bottomEdge = scrollView.contentOffset.y + scrollView.frame.size.height;
    if (bottomEdge >= scrollView.contentSize.height - 5) {
        [UIView animateWithDuration:0.3 animations:^{ self.scrollIndicator.alpha = 0; }];
    } else {
        [UIView animateWithDuration:0.3 animations:^{ self.scrollIndicator.alpha = 1; }];
    }
}

- (void)closeView {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"YHCloseMenuTapped" object:nil];
}

- (void)showWarningInfo {
    NSString *msg = @"أداة Byno GPS Pro المتقدمة للتحكم بالموقع والبيانات\nتصميم ثعلب احترافي\nتابعنا على تليجرام: https://t.me/BynoGPS";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Byno GPS Pro" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
    [self presentAlert:alert];
}

- (void)showInMenuSearch {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"بحث عن نقطة اتصال" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) { textField.placeholder = @"اكتب اسم النقطة"; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"بحث" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *query = alert.textFields.firstObject.text;
        [self performSearch:query];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [self presentAlert:alert];
}

- (void)showFavorites {
    if (YHManager.shared.savedLocations.count == 0) {
        [self showToast:@"السجل فارغ"];
        return;
    }
    self.savedLocationsTable.hidden = !self.savedLocationsTable.hidden;
    self.resultsTable.hidden = YES;
    if (!self.savedLocationsTable.hidden) [self.savedLocationsTable reloadData];
}

- (void)saveCurrentLocation {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"حفظ إعدادات النقطة" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) { textField.placeholder = @"أدخل التسمية"; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"حفظ" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields.firstObject.text;
        if (name.length == 0) name = @"نقطة اتصال";
        [YHManager.shared saveLocation:kBaseLocation withName:name favorite:YES];
        [self showToast:@"تم حفظ الإعدادات بنجاح"];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [self presentAlert:alert];
}

- (void)toggleGPS:(YHToggle *)sw {
    YHManager.shared.isEnabled = sw.isOn;
    if (sw.isOn) { [self startFoxAnimation]; } else { [self stopFoxAnimation]; }
    [self showToast:sw.isOn ? @"تم تفعيل المحرك " : @"تم إيقاف المحرك"];
}

- (void)toggleJitter:(YHToggle *)sw {
    YHManager.shared.isJitterEnabled = sw.isOn;
    [self showToast:sw.isOn ? @"تم تفعيل المحاكي" : @"تم إيقاف المحاكي"];
    [self refreshMapLive];
}

- (void)openIdentitySetup {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تكوين معرفات النظام" message:@"أدخل أرقام التكوين الجديدة للإرسال" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"المعرف الأساسي";
        textField.text = [NSUserDefaults.standardUserDefaults stringForKey:kSaveKeyUDID];
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"المعرف الإضافي";
        textField.text = [NSUserDefaults.standardUserDefaults stringForKey:kSaveKeyDeviceID];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"استخراج بيانات التطبيق الحالية" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [UIPasteboard generalPasteboard].string = [UIDevice currentDevice].identifierForVendor.UUIDString;
        [self showToast:@"تم سحب المعرف بنجاح للحافظة"];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self openIdentitySetup];
        });
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"تنفيذ وحقن" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [NSUserDefaults.standardUserDefaults setObject:alert.textFields[0].text forKey:kSaveKeyUDID];
        [NSUserDefaults.standardUserDefaults setObject:alert.textFields[1].text forKey:kSaveKeyDeviceID];
        YHManager.shared.isUDIDSpoofEnabled = YES;
        YHManager.shared.isDeviceIDSpoofEnabled = YES;
        [self showToast:@"تم حقن المعرفات بنجاح"];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إيقاف الحقن" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        YHManager.shared.isUDIDSpoofEnabled = NO;
        YHManager.shared.isDeviceIDSpoofEnabled = NO;
        [self showToast:@"تم استعادة الوضع الافتراضي"];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [self presentAlert:alert];
}

- (void)showBluetoothMenu {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"إدارة الاتصال (بلوتوث)" message:@"اختر طريقة تكوين نقطة الاتصال الوهمية" preferredStyle:UIAlertControllerStyleActionSheet];
    
    [ac addAction:[UIAlertAction actionWithTitle:@"إدخال بيانات يدوياً" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self openManualBluetoothSetup];
    }]];
    
    [ac addAction:[UIAlertAction actionWithTitle:@"الأجهزة القريبة المكتشفة" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self showNearbyBluetoothDevices];
    }]];
    
    [ac addAction:[UIAlertAction actionWithTitle:@"الأجهزة المحفوظة" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self showToast:@"ميزة قيد التطوير للحفظ الدائم"];
        [self showNearbyBluetoothDevices];
    }]];
    
    if (YHManager.shared.isBluetoothSpoofEnabled) {
        [ac addAction:[UIAlertAction actionWithTitle:@"إيقاف حقن الاتصال" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            YHManager.shared.isBluetoothSpoofEnabled = NO;
            [self showToast:@"تم إيقاف تزييف الاتصال"];
        }]];
    }
    
    [ac addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [self presentAlert:ac];
}

- (void)showNearbyBluetoothDevices {
    NSString *autoUUID = [NSUserDefaults.standardUserDefaults stringForKey:@"YH_AutoCopiedBeaconUUID"];
    if (autoUUID.length == 0) {
        [self showToast:@"لم يتم اكتشاف أي نقطة اتصال قريبة حتى الآن. يرجى الاقتراب منها أولاً ليتم حفظها."];
        return;
    }
    
    NSInteger autoMajor = [NSUserDefaults.standardUserDefaults integerForKey:@"YH_AutoCopiedBeaconMajor"];
    NSInteger autoMinor = [NSUserDefaults.standardUserDefaults integerForKey:@"YH_AutoCopiedBeaconMinor"];
    
    NSString *deviceTitle = [NSString stringWithFormat:@"جهاز مكتشف:\n%@\nرقم 1: %ld | رقم 2: %ld", autoUUID, (long)autoMajor, (long)autoMinor];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"الأجهزة القريبة" message:deviceTitle preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"تفعيل وحقن هذا الجهاز" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        YHManager.shared.spoofBeaconUUID = autoUUID;
        YHManager.shared.spoofBeaconMajor = autoMajor;
        YHManager.shared.spoofBeaconMinor = autoMinor;
        YHManager.shared.isBluetoothSpoofEnabled = YES;
        [self showToast:@"تم تفعيل نقطة الاتصال القريبة بنجاح"];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"تعديل البيانات" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self openManualBluetoothSetup];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [self presentAlert:alert];
}

- (void)openManualBluetoothSetup {
    NSString *autoCopiedUUID = [NSUserDefaults.standardUserDefaults stringForKey:@"YH_AutoCopiedBeaconUUID"];
    NSString *currentUUID = YHManager.shared.spoofBeaconUUID.length > 0 ? YHManager.shared.spoofBeaconUUID : autoCopiedUUID;
    
    NSInteger currentMajor = YHManager.shared.spoofBeaconUUID.length > 0 ? YHManager.shared.spoofBeaconMajor : [NSUserDefaults.standardUserDefaults integerForKey:@"YH_AutoCopiedBeaconMajor"];
    NSInteger currentMinor = YHManager.shared.spoofBeaconUUID.length > 0 ? YHManager.shared.spoofBeaconMinor : [NSUserDefaults.standardUserDefaults integerForKey:@"YH_AutoCopiedBeaconMinor"];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"إضافة أرقام الاتصال" message:@"أدخل البيانات المطلوبة للربط بنقطة الاتصال" preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"أضف الرقم الأساسي الطويل";
        textField.text = currentUUID;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"أضف الرقم الأول";
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = currentMajor > 0 ? [NSString stringWithFormat:@"%ld", (long)currentMajor] : @"";
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"أضف الرقم الثاني";
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = currentMinor > 0 ? [NSString stringWithFormat:@"%ld", (long)currentMinor] : @"";
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"حقن وحفظ" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        YHManager.shared.spoofBeaconUUID = alert.textFields[0].text;
        YHManager.shared.spoofBeaconMajor = [alert.textFields[1].text integerValue];
        YHManager.shared.spoofBeaconMinor = [alert.textFields[2].text integerValue];
        YHManager.shared.isBluetoothSpoofEnabled = YES;
        [self showToast:@"تم حقن بيانات الاتصال بنجاح"];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [self presentAlert:alert];
}

- (void)openManualCoordinates {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"الإدخال اليدوي" message:@"أدخل الإحداثيات مفصولة بفاصلة" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"خط العرض, خط الطول";
        textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"تنفيذ" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSArray *comps = [alert.textFields[0].text componentsSeparatedByString:@","];
        if (comps.count == 2) {
            [self processCoordinateSelection:[comps[0] doubleValue] lng:[comps[1] doubleValue]];
            [self showToast:@"تم توجيه المحرك للإحداثيات المدخلة"];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [self presentAlert:alert];
}

- (void)stopAll {
    [self.gpsSwitch setOn:NO animated:YES];
    [self.jitterSwitch setOn:NO animated:YES];
    [self toggleGPS:self.gpsSwitch];
    [self toggleJitter:self.jitterSwitch];
    YHManager.shared.isEngineEnabled = NO;
    YHManager.shared.isUDIDSpoofEnabled = NO;
    YHManager.shared.isDeviceIDSpoofEnabled = NO;
    YHManager.shared.isBluetoothSpoofEnabled = NO;
    YHManager.shared.spoofImage = nil;
    YHManager.shared.spoofVideoURL = nil;
    [self stopFoxAnimation];
    [self showToast:@"تم تصفير النظام وإيقاف كافة العمليات"];
}

- (void)uploadImageFromCameraRoll {
    if (YHManager.shared.isEngineEnabled) {
        YHManager.shared.isEngineEnabled = NO;
        [self showToast:@"تم إيقاف محرك الكاميرا"];
        return;
    }
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"إعداد عدسة الكاميرا" message:@"سيتم استبدال مخرجات الكاميرا فور التقاط الصورة من التطبيق بالصورة التي تحددها" preferredStyle:UIAlertControllerStyleActionSheet];
    [ac addAction:[UIAlertAction actionWithTitle:@"حقن العدسة الأمامية" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        YHManager.shared.spoofCameraPosition = 2;
        [self openImagePicker];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"حقن العدسة الخلفية" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        YHManager.shared.spoofCameraPosition = 1;
        [self openImagePicker];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [self presentAlert:ac];
}

- (void)openImagePicker {
    self.isPickingForSpoof = YES;
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.mediaTypes = @[(NSString *)kUTTypeImage];
    picker.delegate = self;
    [self presentAlert:picker];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (self.isPickingForSpoof) {
        UIImage *img = info[UIImagePickerControllerOriginalImage];
        if (img) {
            YHManager.shared.spoofImage = img;
            YHManager.shared.isEngineEnabled = YES;
            [self showToast:@"تم تجهيز الصورة للحقن المباشر للعدسة"];
        }
        self.isPickingForSpoof = NO;
    }
}

- (void)performSearch:(NSString *)query {
    MKLocalSearchRequest *req = [MKLocalSearchRequest new];
    req.naturalLanguageQuery = query;
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:req];
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        if (response.mapItems.count > 0) {
            self.searchResults = response.mapItems;
            self.resultsTable.hidden = NO;
            self.savedLocationsTable.hidden = YES;
            [self.resultsTable reloadData];
        } else {
            [self showToast:@"عذراً، لم يتم العثور على النقطة"];
        }
    }];
}

- (void)processCoordinateSelection:(double)lat lng:(double)lng {
    [YHManager.shared overrideWith:lat longitude:lng];
    [self.gpsSwitch setOn:YES animated:YES];
    YHManager.shared.isEnabled = YES;
    self.resultsTable.hidden = YES;
    self.savedLocationsTable.hidden = YES;
    [self startFoxAnimation];
}

- (void)presentAlert:(UIViewController *)vc {
    UIViewController *presenter = self;
    while (presenter.presentedViewController) presenter = presenter.presentedViewController;
    [presenter presentViewController:vc animated:YES completion:nil];
}

- (void)showToast:(NSString*)msg {
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(20, self.view.frame.size.height - 110, self.view.frame.size.width - 40, 50)];
    toast.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    toast.textColor = COL_ACCENT;
    toast.textAlignment = NSTextAlignmentCenter;
    toast.text = msg;
    toast.font = [UIFont boldSystemFontOfSize:15];
    toast.layer.cornerRadius = 25;
    toast.clipsToBounds = YES;
    toast.layer.borderWidth = 1.0;
    toast.layer.borderColor = [COL_ACCENT colorWithAlphaComponent:0.3].CGColor;
    toast.alpha = 0;
    [self.view addSubview:toast];
    [UIView animateWithDuration:0.3 animations:^{ toast.alpha = 1; } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3 delay:2.0 options:0 animations:^{ toast.alpha = 0; } completion:^(BOOL f){ [toast removeFromSuperview]; }];
    }];
}

- (void)setupScheduleEditor {
    CGFloat xPos = (self.view.bounds.size.width - MENU_WIDTH) / 2.0;
    CGFloat yPos = (self.view.bounds.size.height - MENU_HEIGHT) / 2.0;
    
    self.editScheduleView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.editScheduleView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
    self.editScheduleView.hidden = YES;
    [self.view addSubview:self.editScheduleView];
    
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *card = [[UIVisualEffectView alloc] initWithEffect:blur];
    card.frame = CGRectMake(xPos, yPos, MENU_WIDTH, MENU_HEIGHT);
    card.layer.cornerRadius = 40;
    card.clipsToBounds = YES;
    card.layer.borderWidth = 1.5;
    card.layer.borderColor = [COL_ACCENT colorWithAlphaComponent:0.3].CGColor;
    [self.editScheduleView addSubview:card];
    
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, MENU_WIDTH, 70)];
    header.backgroundColor = [UIColor clearColor];
    [card.contentView addSubview:header];
    
    UIButton *closeBtn = [[UIButton alloc] initWithFrame:CGRectMake(15, 20, 30, 30)];
    [closeBtn setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.6] forState:UIControlStateNormal];
    closeBtn.tintColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    [closeBtn addTarget:self action:@selector(hideScheduleEditor) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake((MENU_WIDTH - 200)/2, 13, 200, 44)];
    title.text = @"الجدولة التلقائية";
    title.textColor = COL_TEXT;
    title.font = [UIFont systemFontOfSize:20 weight:UIFontWeightHeavy];
    title.textAlignment = NSTextAlignmentCenter;
    [header addSubview:title];
    
    self.scheduleTable = [[UITableView alloc] initWithFrame:CGRectMake(20, 80, MENU_WIDTH - 40, 180)];
    self.scheduleTable.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.05];
    self.scheduleTable.layer.cornerRadius = 20;
    self.scheduleTable.delegate = self;
    self.scheduleTable.dataSource = self;
    [card.contentView addSubview:self.scheduleTable];
    
    self.datePicker = [[UIDatePicker alloc] initWithFrame:CGRectMake(20, 270, MENU_WIDTH - 40, 140)];
    self.datePicker.datePickerMode = UIDatePickerModeDateAndTime;
    if (@available(iOS 13.4, *)) { self.datePicker.preferredDatePickerStyle = UIDatePickerStyleWheels; }
    [self.datePicker setValue:COL_TEXT forKey:@"textColor"];
    [card.contentView addSubview:self.datePicker];
    
    self.scheduleTitleField = [[UITextField alloc] initWithFrame:CGRectMake(20, 420, MENU_WIDTH - 40, 50)];
    self.scheduleTitleField.placeholder = @"اسم العملية";
    self.scheduleTitleField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.05];
    self.scheduleTitleField.textColor = COL_TEXT;
    self.scheduleTitleField.textAlignment = NSTextAlignmentCenter;
    self.scheduleTitleField.layer.cornerRadius = 15;
    self.scheduleTitleField.delegate = self;
    self.scheduleTitleField.returnKeyType = UIReturnKeyDone;
    self.scheduleTitleField.adjustsFontSizeToFitWidth = YES;
    self.scheduleTitleField.minimumFontSize = 10;
    [card.contentView addSubview:self.scheduleTitleField];
    
    UILabel *repLbl = [[UILabel alloc] initWithFrame:CGRectMake(MENU_WIDTH - 150, 480, 130, 30)];
    repLbl.text = @"تكرار أسبوعي";
    repLbl.textColor = COL_TEXT;
    repLbl.textAlignment = NSTextAlignmentRight;
    repLbl.font = [UIFont boldSystemFontOfSize:16];
    [card.contentView addSubview:repLbl];
    
    self.repeatSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(20, 480, 50, 30)];
    self.repeatSwitch.onTintColor = COL_ACCENT;
    [card.contentView addSubview:self.repeatSwitch];
    
    self.locationPicker = [[UIPickerView alloc] initWithFrame:CGRectMake(20, 520, MENU_WIDTH - 40, 80)];
    self.locationPicker.delegate = self;
    self.locationPicker.dataSource = self;
    [card.contentView addSubview:self.locationPicker];
    
    UIButton *saveBtn = [[UIButton alloc] initWithFrame:CGRectMake(20, MENU_HEIGHT - 70, MENU_WIDTH - 40, 50)];
    saveBtn.backgroundColor = COL_ACCENT;
    saveBtn.layer.cornerRadius = 25;
    [saveBtn setTitle:@"حفظ العملية" forState:UIControlStateNormal];
    [saveBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    saveBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [saveBtn addTarget:self action:@selector(saveScheduleItem) forControlEvents:UIControlEventTouchUpInside];
    [card.contentView addSubview:saveBtn];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

- (void)showScheduleEditor {
    self.isEditingSchedule = NO;
    self.editingIndex = -1;
    self.datePicker.date = [NSDate date];
    self.scheduleTitleField.text = @"";
    self.repeatSwitch.on = NO;
    [self.locationPicker reloadAllComponents];
    [self.scheduleTable reloadData];
    self.editScheduleView.hidden = NO;
    [self.view bringSubviewToFront:self.editScheduleView];
}

- (void)hideScheduleEditor {
    self.editScheduleView.hidden = YES;
    [self.view endEditing:YES];
}

- (void)saveScheduleItem {
    NSInteger locRow = [self.locationPicker selectedRowInComponent:0];
    NSInteger linkedLocIndex = -1;
    if (locRow > 0 && locRow <= YHManager.shared.savedLocations.count) { linkedLocIndex = locRow - 1; }
    YHScheduleItem *item = [YHScheduleItem new];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *comps = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute fromDate:self.datePicker.date];
    comps.second = 0;
    item.targetDate = [calendar dateFromComponents:comps];
    item.title = self.scheduleTitleField.text.length > 0 ? self.scheduleTitleField.text : @"عملية جديدة";
    item.enabled = YES;
    item.repeatWeekly = self.repeatSwitch.isOn;
    item.linkedLocationIndex = linkedLocIndex;
    item.mediaPath = @"";
    if (self.isEditingSchedule && self.editingIndex >= 0 && self.editingIndex < YHManager.shared.schedules.count) {
        YHManager.shared.schedules[self.editingIndex] = item;
    } else {
        [YHManager.shared.schedules addObject:item];
    }
    [YHManager.shared saveSchedules];
    [self.scheduleTable reloadData];
    [self hideScheduleEditor];
    [self updateAttendanceCountdown];
}

- (void)updateAttendanceCountdown {
    NSDate *now = [NSDate date];
    NSDate *closestDate = nil;
    
    for (YHScheduleItem *item in YHManager.shared.schedules) {
        if (!item.enabled) continue;
        NSDate *itemNextDate = item.targetDate;
        if (item.repeatWeekly) {
            while ([itemNextDate timeIntervalSinceDate:now] < -60) {
                itemNextDate = [itemNextDate dateByAddingTimeInterval:604800];
            }
        } else {
            if ([itemNextDate timeIntervalSinceDate:now] < -60) continue;
        }
        if (!closestDate || [itemNextDate timeIntervalSinceDate:closestDate] < 0) {
            closestDate = itemNextDate;
        }
    }
    
    if (closestDate) {
        NSTimeInterval diff = [closestDate timeIntervalSinceDate:now];
        if (diff < 0) diff = 0;
        int d = (int)(diff / 86400);
        int h = (int)((diff - (d * 86400)) / 3600);
        int m = (int)((diff - (d * 86400) - (h * 3600)) / 60);
        int s = (int)diff % 60;
        if (d > 0) {
            [self.btnTimerAlert setTitle:[NSString stringWithFormat:@"%dي\n%02d:%02d:%02d", d, h, m, s] forState:UIControlStateNormal];
        } else {
            [self.btnTimerAlert setTitle:[NSString stringWithFormat:@"%02d:%02d:%02d", h, m, s] forState:UIControlStateNormal];
        }
    } else {
        [self.btnTimerAlert setTitle:@"00:00" forState:UIControlStateNormal];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { 
    if (tableView == self.scheduleTable) return YHManager.shared.schedules.count;
    if (tableView == self.savedLocationsTable) return YHManager.shared.savedLocations.count;
    if (tableView == self.resultsTable) return self.searchResults.count;
    return 0;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Cell"];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = COL_TEXT;
        cell.detailTextLabel.textColor = COL_SUBTEXT;
    }
    
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.lineBreakMode = NSLineBreakByWordWrapping;
    cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
    
    if (tableView == self.scheduleTable) {
        YHScheduleItem *item = YHManager.shared.schedules[indexPath.row];
        NSDateFormatter *fmt = [NSDateFormatter new];
        [fmt setDateFormat:@"yyyy/MM/dd HH:mm"];
        if (item.repeatWeekly) [fmt setDateFormat:@"EEEE HH:mm"];
        cell.textLabel.text = item.title;
        cell.detailTextLabel.text = [fmt stringFromDate:item.targetDate];
        cell.accessoryView = [[UISwitch alloc] initWithFrame:CGRectZero];
        [(UISwitch *)cell.accessoryView setOn:item.enabled];
        [(UISwitch *)cell.accessoryView setOnTintColor:COL_ACCENT];
        [(UISwitch *)cell.accessoryView addTarget:self action:@selector(scheduleSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        [(UISwitch *)cell.accessoryView setTag:indexPath.row];
    } else if (tableView == self.savedLocationsTable) {
        NSDictionary *loc = YHManager.shared.savedLocations[indexPath.row];
        cell.textLabel.text = loc[@"name"];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%.4f, %.4f", [loc[@"lat"] doubleValue], [loc[@"lng"] doubleValue]];
        cell.accessoryView = nil;
    } else if (tableView == self.resultsTable) {
        MKMapItem *item = self.searchResults[indexPath.row];
        cell.textLabel.text = item.name;
        cell.detailTextLabel.text = item.placemark.title;
        cell.accessoryView = nil;
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (tableView == self.scheduleTable) {
        self.isEditingSchedule = YES;
        self.editingIndex = indexPath.row;
        YHScheduleItem *item = YHManager.shared.schedules[indexPath.row];
        self.datePicker.date = item.targetDate;
        self.scheduleTitleField.text = item.title;
        self.repeatSwitch.on = item.repeatWeekly;
        [self.locationPicker reloadAllComponents];
        if (item.linkedLocationIndex >= -1) [self.locationPicker selectRow:(item.linkedLocationIndex + 1) inComponent:0 animated:NO];
    } else if (tableView == self.savedLocationsTable) {
        NSDictionary *loc = YHManager.shared.savedLocations[indexPath.row];
        [self processCoordinateSelection:[loc[@"lat"] doubleValue] lng:[loc[@"lng"] doubleValue]];
    } else if (tableView == self.resultsTable) {
        MKMapItem *item = self.searchResults[indexPath.row];
        [self processCoordinateSelection:item.placemark.coordinate.latitude lng:item.placemark.coordinate.longitude];
    }
}
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.scheduleTable) {
        UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"حذف" handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
            [YHManager.shared.schedules removeObjectAtIndex:indexPath.row];
            [YHManager.shared saveSchedules];
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            [self updateAttendanceCountdown];
            completionHandler(YES);
        }];
        return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
    } else if (tableView == self.savedLocationsTable) {
        UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"حذف" handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
            [YHManager.shared.savedLocations removeObjectAtIndex:indexPath.row];
            [NSUserDefaults.standardUserDefaults setObject:YHManager.shared.savedLocations forKey:kSaveKeyLocations];
            [NSUserDefaults.standardUserDefaults synchronize];
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            completionHandler(YES);
        }];
        return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
    }
    return nil;
}
- (void)scheduleSwitchChanged:(UISwitch *)sender {
    NSInteger index = sender.tag;
    if (index >= 0 && index < YHManager.shared.schedules.count) {
        YHScheduleItem *item = YHManager.shared.schedules[index];
        item.enabled = sender.isOn;
        [YHManager.shared saveSchedules];
        [self updateAttendanceCountdown];
    }
}
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView { return 1; }
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component { return YHManager.shared.savedLocations.count + 1; }
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    if (row == 0) return @"بدون تفعيل المحرك";
    return YHManager.shared.savedLocations[row - 1][@"name"];
}
- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view {
    UILabel* label = (UILabel*)view;
    if (!label) {
        label = [[UILabel alloc] init];
        label.font = [UIFont systemFontOfSize:16];
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = COL_TEXT;
    }
    if (row == 0) label.text = @"بدون تفعيل المحرك";
    else label.text = YHManager.shared.savedLocations[row - 1][@"name"];
    return label;
}

@end

@interface YHOverlayWindow : UIWindow @end
@implementation YHOverlayWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self || hitView == self.rootViewController.view) return nil;
    return hitView;
}
@end

@interface YHOverlayController : UIViewController
@property (nonatomic, strong) UIView *menuContainer;
@property (nonatomic, strong) YHMenuVC *menuVC;
@property (nonatomic, strong) UIView *dimBackground;
- (void)showMenu;
- (void)hideMenu;
- (void)triggerHide:(id)sender;
@end

@implementation YHOverlayController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    
    self.dimBackground = [[UIView alloc] initWithFrame:self.view.bounds];
    self.dimBackground.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
    self.dimBackground.alpha = 0;
    self.dimBackground.hidden = YES;
    UITapGestureRecognizer *dimTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(triggerHide:)];
    [self.dimBackground addGestureRecognizer:dimTap];
    [self.view addSubview:self.dimBackground];
    
    self.menuContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    self.menuContainer.hidden = YES;
    
    self.menuVC = [YHMenuVC new];
    [self addChildViewController:self.menuVC];
    self.menuVC.view.frame = self.menuContainer.bounds;
    [self.menuContainer addSubview:self.menuVC.view];
    [self.menuVC didMoveToParentViewController:self];
    [self.view addSubview:self.menuContainer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(triggerHide:) name:@"YHCloseMenuTapped" object:nil];
}

- (void)globalLongPressTriggered:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"البحث السريع للنقاط" message:@"أدخل الإحداثيات مباشرة أو اسم المعلم" preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) { textField.placeholder = @"بحث سريع..."; }];
        UIAlertAction *execAction = [UIAlertAction actionWithTitle:@"تنفيذ" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *input = alert.textFields.firstObject.text;
            NSArray *comps = [input componentsSeparatedByString:@","];
            if (comps.count == 2 && [comps[0] doubleValue] != 0) {
                [self.menuVC processCoordinateSelection:[comps[0] doubleValue] lng:[comps[1] doubleValue]];
                [self showGlobalToast:@"تم الانتقال السريع"];
            } else {
                [self showGlobalToast:@"جاري البحث..."];
                MKLocalSearchRequest *req = [MKLocalSearchRequest new];
                req.naturalLanguageQuery = input;
                MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:req];
                [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
                    if (response.mapItems.count > 0) {
                        MKMapItem *item = response.mapItems.firstObject;
                        [self.menuVC processCoordinateSelection:item.placemark.coordinate.latitude lng:item.placemark.coordinate.longitude];
                        [self showGlobalToast:[NSString stringWithFormat:@"تم الحقن: %@", item.name]];
                    } else {
                        [self showGlobalToast:@"تعذر الوصول للنقطة المطلوبة"];
                    }
                }];
            }
        }];
        [alert addAction:execAction];
        [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
        UIViewController *presenter = self;
        while (presenter.presentedViewController) { presenter = presenter.presentedViewController; }
        [presenter presentViewController:alert animated:YES completion:nil];
    }
}

- (void)showGlobalToast:(NSString *)msg {
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(20, [UIScreen mainScreen].bounds.size.height - 150, [UIScreen mainScreen].bounds.size.width - 40, 50)];
    toast.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    toast.textColor = COL_ACCENT;
    toast.textAlignment = NSTextAlignmentCenter;
    toast.text = msg;
    toast.font = [UIFont boldSystemFontOfSize:15];
    toast.layer.cornerRadius = 25;
    toast.clipsToBounds = YES;
    toast.layer.borderWidth = 1.0;
    toast.layer.borderColor = [COL_ACCENT colorWithAlphaComponent:0.3].CGColor;
    toast.alpha = 0;
    UIWindow *keyWin = [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
    [keyWin addSubview:toast];
    [UIView animateWithDuration:0.3 animations:^{ toast.alpha = 1; } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3 delay:2.0 options:0 animations:^{ toast.alpha = 0; } completion:^(BOOL f){ [toast removeFromSuperview]; }];
    }];
}

- (void)showMenu {
    if (self.menuContainer.hidden) {
        [self.view.window makeKeyWindow];
        self.dimBackground.hidden = NO;
        self.menuContainer.hidden = NO;
        self.menuVC.mainContainerView.transform = CGAffineTransformMakeScale(0.85, 0.85);
        self.menuVC.mainContainerView.alpha = 0;
        [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.6 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.dimBackground.alpha = 1;
            self.menuVC.mainContainerView.transform = CGAffineTransformIdentity;
            self.menuVC.mainContainerView.alpha = 1;
        } completion:^(BOOL finished) {
            if (YHManager.shared.isEnabled) { [self.menuVC startFoxAnimation]; }
        }];
    }
}

- (void)hideMenu {
    if (!self.menuContainer.hidden) {
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.dimBackground.alpha = 0;
            self.menuVC.mainContainerView.transform = CGAffineTransformMakeScale(0.85, 0.85);
            self.menuVC.mainContainerView.alpha = 0;
        } completion:^(BOOL finished) {
            self.menuContainer.hidden = YES;
            self.dimBackground.hidden = YES;
            self.menuVC.mainContainerView.transform = CGAffineTransformIdentity;
            [self.view.window resignKeyWindow];
        }];
    }
}

- (void)triggerHide:(id)sender {
    [self hideMenu];
}
@end

static YHOverlayWindow *kOverlayWindow = nil;
static YHOverlayController *gOverlayController = nil;

@interface YHVolumeTrigger : NSObject
@property (nonatomic, strong) MPVolumeView *volumeView;
@property (nonatomic, assign) float initialVolume;
+ (instancetype)shared;
- (void)startListening;
@end
@implementation YHVolumeTrigger
+ (instancetype)shared {
    static YHVolumeTrigger *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ inst = [self new]; });
    return inst;
}
- (void)startListening {
    self.volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-1000, -1000, 10, 10)];
    self.volumeView.hidden = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
        [window addSubview:self.volumeView];
    });
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setActive:YES error:nil];
    [session addObserver:self forKeyPath:@"outputVolume" options:NSKeyValueObservingOptionNew context:nil];
    self.initialVolume = session.outputVolume;
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"outputVolume"]) {
        float newVol = [change[NSKeyValueChangeNewKey] floatValue];
        if (newVol < self.initialVolume || newVol == 0.0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (gOverlayController) [gOverlayController showMenu];
            });
        }
        if (newVol == 0.0) {
            UISlider *volSlider = nil;
            for (UIView *view in self.volumeView.subviews) {
                if ([view isKindOfClass:[UISlider class]]) { volSlider = (UISlider *)view; break; }
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [volSlider setValue:0.01 animated:NO]; });
        }
        self.initialVolume = [AVAudioSession sharedInstance].outputVolume;
        if (self.initialVolume == 0.0) self.initialVolume = 0.01;
    }
}
@end

__attribute__((constructor))
static void init_tool() {
    // تفعيل الحقن المضمون
    method_exchangeImplementations(class_getInstanceMethod([UIViewController class], @selector(viewDidAppear:)), class_getInstanceMethod([UIViewController class], @selector(byno_viewDidAppear:)));
    
    // تفعيل حالة الترخيص تلقائياً
    NSDate *expiry = [NSDate dateWithTimeIntervalSinceNow:86400 * 365]; 
    [NSUserDefaults.standardUserDefaults setObject:@"BYNO-PRO-FULL" forKey:@"BYANO_LICENSE_KEY"];
    [NSUserDefaults.standardUserDefaults setObject:expiry forKey:@"BYActivationExpiryKey"];

    retainer = [NSMutableSet new];
    struct rebinding r[] = {
        {"SecTrustEvaluate", (void *)my_SecTrustEvaluate, (void**)&orig_SecTrustEvaluate},
        {"SecTrustEvaluateWithError", (void *)my_SecTrustEvaluateWithError, (void**)&orig_SecTrustEvaluateWithError},
        {"MGCopyAnswer", (void *)my_MGCopyAnswer, (void**)&orig_MGCopyAnswer}
    };
    rebind_symbols(r, 3);
    
    kLocationSpoofSupported = YHSafeHookMethod([CLLocation class], @selector(coordinate), (IMP)my_coordinate, (IMP*)&orig_coordinate);
    kLocationSpoofSupported = YHSafeHookMethod([CLLocationManager class], @selector(setDelegate:), (IMP)override_CLLocationManager_setDelegate, &orig_CLLocationManager_setDelegate_imp) || kLocationSpoofSupported;
    kLocationSpoofSupported = YHSafeHookMethod([CLLocationManager class], @selector(location), (IMP)override_CLLocationManager_location, &orig_CLLocationManager_location_imp) || kLocationSpoofSupported;
    
    Class MKCLProvider = NSClassFromString(@"MKCoreLocationProvider");
    if (MKCLProvider) {
        kLocationSpoofSupported = YHSafeHookMethod(MKCLProvider, @selector(setDelegate:), (IMP)override_MKCoreLocationProvider_setDelegate, (IMP*)&orig_MKCoreLocationProvider_setDelegate) || kLocationSpoofSupported;
        kLocationSpoofSupported = YHSafeHookMethod(MKCLProvider, @selector(lastLocation), (IMP)override_MKCoreLocationProvider_lastLocation, (IMP*)&orig_MKCoreLocationProvider_lastLocation) || kLocationSpoofSupported;
    }
    Class GMSProvider = NSClassFromString(@"GMSMyLocationProvider");
    if (GMSProvider) {
        kLocationSpoofSupported = YHSafeHookMethod(GMSProvider, @selector(setDelegate:), (IMP)override_GMSMyLocationProvider_setDelegate, (IMP*)&orig_GMSMyLocationProvider_setDelegate) || kLocationSpoofSupported;
        kLocationSpoofSupported = YHSafeHookMethod(GMSProvider, @selector(lastLocation), (IMP)override_GMSMyLocationProvider_lastLocation, (IMP*)&orig_GMSMyLocationProvider_lastLocation) || kLocationSpoofSupported;
    }
    
    YHSafeHookMethod([UIImagePickerController class], @selector(setDelegate:), (IMP)override_UIImagePickerController_setDelegate, &orig_UIImagePickerController_setDelegate_imp);
    kUDIDSpoofSupported = YHSafeHookMethod([UIDevice class], @selector(identifierForVendor), (IMP)my_identifierForVendor, (IMP*)&orig_identifierForVendor) || orig_MGCopyAnswer != NULL;
    kDeviceIDSpoofSupported = YHSafeHookMethod([NSUserDefaults class], @selector(objectForKey:), (IMP)my_NSUserDefaults_objectForKey, (IMP*)&orig_NSUserDefaults_objectForKey);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [YHManager shared];
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        kOverlayWindow = [[YHOverlayWindow alloc] initWithFrame:screenBounds];
        kOverlayWindow.windowLevel = 10000000.0;
        kOverlayWindow.backgroundColor = [UIColor clearColor];
        kOverlayWindow.hidden = NO;
        gOverlayController = [YHOverlayController new];
        kOverlayWindow.rootViewController = gOverlayController;
        [[YHVolumeTrigger shared] startListening];
        
        UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;
        if (!mainWindow) mainWindow = [UIApplication sharedApplication].windows.firstObject;
        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:gOverlayController action:@selector(globalLongPressTriggered:)];
        lp.minimumPressDuration = 1.0;
        lp.cancelsTouchesInView = NO;
        [mainWindow addGestureRecognizer:lp];
    });
}
@interface UIViewController (BynoGPS) @end
@implementation UIViewController (BynoGPS)
- (void)byno_viewDidAppear:(BOOL)animated {
    [self byno_viewDidAppear:animated];
    if ([NSStringFromClass([self class]) containsString:@"Input"] || self.view.frame.size.width < 100) return;
    static UIButton *fBtn = nil;
    if (!fBtn) {
        fBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        fBtn.frame = CGRectMake(20, 150, 60, 60);
        fBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.42 blue:0.95 alpha:0.8];
        fBtn.layer.cornerRadius = 30;
        [fBtn setTitle:@"Byno" forState:UIControlStateNormal];
        fBtn.layer.zPosition = 9999;
        [fBtn addTarget:self action:@selector(byno_toggleMenu) forControlEvents:UIControlEventTouchUpInside];
        UIPanGestureRecognizer *p = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(byno_pan:)];
        [fBtn addGestureRecognizer:p];
    }
    if (fBtn.superview != self.view) { [self.view addSubview:fBtn]; [self.view bringSubviewToFront:fBtn]; }
}
- (void)byno_pan:(UIPanGestureRecognizer *)g {
    UIView *v = g.view; CGPoint t = [g translationInView:v.superview];
    v.center = CGPointMake(v.center.x + t.x, v.center.y + t.y);
    [g setTranslation:CGPointZero inView:v.superview];
}
- (void)byno_toggleMenu {
    if (gOverlayController) { [gOverlayController showMenu]; }
}
@end
