#import "ok.h"
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <MapKit/MapKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <UserNotifications/UserNotifications.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <WebKit/WebKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <Security/Security.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import "fishhook/fishhook.h"
#import "libs/include/SniperGate/SniperGate.h"

extern "C" bool ___isPlatformVersionAtLeast(unsigned int major, unsigned int minor, unsigned int patch, unsigned int build) { return true; }

int sub_990021 = 1155;
#import "WFCodeEntryView.h"

@interface YHOverlayWindow : UIWindow @end
@class YHMenuVC;
@class YHSpoofView;
@interface YHFloatingButton : UIButton
@property (nonatomic, copy) void (^tapHandler)(void);
- (void)updateIcon:(BOOL)active;
@end

@interface YHOverlayController : UIViewController
@property (nonatomic, strong) UIView *menuContainer;
@property (nonatomic, strong) YHMenuVC *menuVC;
@property (nonatomic, strong) YHSpoofView *spoofView;
@property (nonatomic, strong) YHFloatingButton *floatingBtn;
@property (nonatomic, assign) CGFloat menuScale;
@property (nonatomic, strong) MPVolumeView *volumeView;
@property (nonatomic, assign) NSTimeInterval lastVolumeClick;
@property (nonatomic, assign) NSInteger volClickCount;
- (void)toggleMenu:(id)sender;
- (void)showToast:(NSString*)msg;
@end

static YHOverlayWindow *kOverlayWindow = nil;
static YHOverlayController *gOverlayController = nil;

@implementation sub_00295111
static void verify_activation_live() {
    NSString *code = [[NSUserDefaults standardUserDefaults] stringForKey:@"WF_LastCode"];
    if (!code || code.length == 0) return;

    NSString *deviceId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSDictionary *body = @{ @"code": code };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://could.p3nd.fun/admin/api/redeem_process.php"]];
    req.HTTPMethod = @"POST";
    req.HTTPBody = jsonData;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:deviceId forHTTPHeaderField:@"X-Device-Id"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!error && data) {
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (result && [result isKindOfClass:[NSDictionary class]]) {
                if (![result[@"ok"] boolValue]) {
                    // الكود غير صالح أو تم حذفه من اللوحة
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WF_IsActivated"];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        // إشعار المستخدم أو إغلاق الوظائف
                        if (gOverlayController) {
                            [gOverlayController showToast:@"⚠️ تم إلغاء تفعيل الاشتراك من الخادم"];
                        }
                    });
                }
            }
        }
    }] resume];
}

static void run_tweak_logic() {
    sub_990021 = 1144;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [sub_00295111 sub_00238e14b];
        [YHWKWebViewHook sub_0028881];
        [YHCamHook ret_002771];
        [YHTouchHook var_00035255];
        
        // التحقق الدوري من التفعيل (كل 5 دقائق)
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:300 repeats:YES block:^(NSTimer * _Nonnull timer) {
            verify_activation_live();
        }];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    });
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!kOverlayWindow) {
            [YHTouchHook var_00035255];
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (gOverlayController) {
                gOverlayController.floatingBtn.hidden = NO;
                kOverlayWindow.hidden = NO;
                [gOverlayController.view bringSubviewToFront:gOverlayController.floatingBtn];
            }
        });
    });
}
extern "C" void sub_00238e7b(void) { run_tweak_logic(); }
+ (void)sub_00238e14b {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = object_getClass([NSJSONSerialization class]);
        SEL originalSelector = @selector(JSONObjectWithData:options:error:);
        SEL swizzledSelector = @selector(yh_JSONObjectWithData:options:error:);
        Method originalMethod = class_getClassMethod([NSJSONSerialization class], originalSelector);
        Method swizzledMethod = class_getClassMethod(self, swizzledSelector);
        class_addMethod(cls, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
        class_replaceMethod(cls, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
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

@implementation YHWKWebViewHook
+ (void)sub_0028881 {
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
                    BOOL isUDIDSpoofEnabled = [NSUserDefaults.standardUserDefaults boolForKey:@"YH_UDID_Enabled"];
                    if (isUDIDSpoofEnabled) { spoofedUDID = [NSUserDefaults.standardUserDefaults stringForKey:@"YH_Custom_UDID"] ?: @""; }
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
                    WKUserScript *script = [[WKUserScript alloc] initWithSource:jsCode injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
                    [config.userContentController addUserScript:script];
                    return ((WKWebView* (*)(id, SEL, CGRect, WKWebViewConfiguration*))originalIMP)(self, originalSelector, frame, config);
                });
                method_setImplementation(originalMethod, newIMP);
            }
        }
    });
}
@end

#ifndef kUTTypeImage
#define kUTTypeImage CFSTR("public.image")
#endif
#ifndef kUTTypeMovie
#define kUTTypeMovie CFSTR("public.movie")
#endif

#define COL_BG [UIColor colorWithRed:0x15/255.0 green:0x18/255.0 blue:0x21/255.0 alpha:1.0]
#define COL_PANEL [UIColor colorWithRed:0x1c/255.0 green:0x1f/255.0 blue:0x2b/255.0 alpha:1.0]
#define COL_ACCENT [UIColor colorWithRed:0x14/255.0 green:0x7b/255.0 blue:0xc4/255.0 alpha:1.0]
#define COL_ACTIVE [UIColor colorWithRed:0x2e/255.0 green:0xb5/255.0 blue:0x6a/255.0 alpha:1.0]
#define COL_TEXT [UIColor colorWithRed:1.00 green:1.00 blue:1.00 alpha:1.0]
#define COL_SUBTEXT [UIColor colorWithRed:0.70 green:0.75 blue:0.80 alpha:1.0]
#define COL_RED [UIColor colorWithRed:0xe0/255.0 green:0x50/255.0 blue:0x50/255.0 alpha:1.0]
#define COL_GRAY_BTN [UIColor colorWithRed:0x2c/255.0 green:0x2f/255.0 blue:0x3a/255.0 alpha:1.0]

#define COL_SEARCH COL_GRAY_BTN
#define COL_FAV    COL_GRAY_BTN
#define COL_HIDE   COL_GRAY_BTN
#define COL_ID     COL_GRAY_BTN
#define COL_BT     [UIColor colorWithRed:0x14/255.0 green:0x2e/255.0 blue:0x4a/255.0 alpha:1.0]
#define COL_BLUE   [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0]
#define COL_GOLD   [UIColor colorWithRed:1.0 green:0.84 blue:0.0 alpha:1.0]
#define COL_PURPLE [UIColor colorWithRed:0.69 green:0.33 blue:0.83 alpha:1.0]
#define COL_CYAN   [UIColor colorWithRed:0.2 green:0.8 blue:0.9 alpha:1.0]

static BOOL kIsArabic = YES;
static NSMutableSet<id> *retainer = nil;

void YHSwizzleInstanceMethod(Class cls, SEL originalSelector, SEL swizzledSelector) {
    if (!cls) return;
    Method originalMethod = class_getInstanceMethod(cls, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(cls, swizzledSelector);
    if (class_addMethod(cls, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
        class_replaceMethod(cls, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

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

static NSString * const kEnableDidChange = @"YHEnableDidChange";
static NSString * const kOverrideDidChange = @"YHOverrideDidChange";
static NSString * const kSaveKeyGPSEnabled = @"YH_GPS_State";
static NSString * const kSaveKeyLat = @"YH_Lat";
static NSString * const kSaveKeyLng = @"YH_Lng";
static NSString * const kSaveKeyLocations = @"YH_Saved_Locations";
static NSString * const kSaveKeySchedule = @"YH_Schedule_Items";
static NSString * const kSaveKeyLanguage = @"YH_Lang_Arabic";
static NSString * const kSaveKeyUDID = @"YH_Custom_UDID";
static NSString * const kSaveKeyUDIDEnabled = @"YH_UDID_Enabled";
static NSString * const kSaveKeyEngineEnabled = @"YH_Engine_Enabled";
static NSString * const kDistanceDidChange = @"YHDistanceDidChange";
static NSString * const kLanguageDidChange = @"YHLanguageDidChange";
static NSString * const kSaveBleUUID = @"YH_Ble_UUID";
static NSString * const kSaveBleMajor = @"YH_Ble_Major";
static NSString * const kSaveBleMinor = @"YH_Ble_Minor";
static NSString * const kSaveBleEnabled = @"YH_Ble_Enabled";
static NSString * const kSaveBleProfiles = @"YH_Ble_Profiles";
static NSString * const kSaveBleCapturedProfiles = @"YH_Ble_Captured_Profiles";
static NSString * const kSaveBleActiveProfileID = @"YH_Ble_Active_Profile_ID";

static BOOL kGPSEnabled = NO;
static CLLocationCoordinate2D kBaseLocation = {24.7136, 46.6753};
static CLLocationCoordinate2D kLocation = {24.7136, 46.6753};
static NSMutableArray *kSavedLocations = nil;
static NSMutableArray *kScheduleItems = nil;

static NSString *YHHexFromData(NSData *data) {
    if (![data isKindOfClass:NSData.class] || data.length == 0) return @"";
    const unsigned char *bytes = (const unsigned char *)data.bytes;
    NSMutableString *hex = [NSMutableString stringWithCapacity:data.length * 2];
    for (NSUInteger i = 0; i < data.length; i++) [hex appendFormat:@"%02x", bytes[i]];
    return hex;
}
static NSData *YHDataFromHex(NSString *hex) {
    if (![hex isKindOfClass:NSString.class] || hex.length == 0) return nil;
    NSString *clean = [[[hex stringByReplacingOccurrencesOfString:@" " withString:@""] stringByReplacingOccurrencesOfString:@"<" withString:@""] stringByReplacingOccurrencesOfString:@">" withString:@""];
    NSMutableData *data = [NSMutableData data];
    for (NSUInteger i = 0; i + 1 < clean.length; i += 2) {
        NSString *byteString = [clean substringWithRange:NSMakeRange(i, 2)];
        unsigned int value = 0; [[NSScanner scannerWithString:byteString] scanHexInt:&value];
        unsigned char byte = (unsigned char)value; [data appendBytes:&byte length:1];
    }
    return data;
}
static id YHJSONSafeObject(id value) {
    if (!value || value == (id)kCFNull) return @"";
    if ([value isKindOfClass:NSString.class] || [value isKindOfClass:NSNumber.class]) return value;
    if ([value isKindOfClass:NSData.class]) return YHHexFromData(value);
    if ([value isKindOfClass:CBUUID.class]) return [(CBUUID *)value UUIDString] ?: @"";
    if ([value isKindOfClass:NSUUID.class]) return [(NSUUID *)value UUIDString] ?: @"";
    if ([value isKindOfClass:NSDate.class]) return @([(NSDate *)value timeIntervalSince1970]);
    if ([value isKindOfClass:NSArray.class]) { NSMutableArray *items = [NSMutableArray array]; for (id item in (NSArray *)value) [items addObject:YHJSONSafeObject(item) ?: @""]; return items; }
    if ([value isKindOfClass:NSDictionary.class]) { NSMutableDictionary *dict = [NSMutableDictionary dictionary]; [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) { NSString *safeKey = [key isKindOfClass:CBUUID.class] ? [(CBUUID *)key UUIDString] : [key description]; if (safeKey.length) dict[safeKey] = YHJSONSafeObject(obj) ?: @""; }]; return dict; }
    return [value description] ?: @"";
}

// Interface moved to top
@implementation YHFloatingButton {
    CGPoint _startPoint;
}
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0x1c/255.0 green:0x1f/255.0 blue:0x2b/255.0 alpha:0.9];
        self.layer.cornerRadius = frame.size.width / 2;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.3;
        self.layer.shadowRadius = 5;
        self.layer.shadowOffset = CGSizeMake(0, 2);
        self.layer.borderColor = [UIColor colorWithRed:0xc9/255.0 green:0xa2/255.0 blue:0x27/255.0 alpha:1.0].CGColor;
        self.layer.borderWidth = 2.0;
        [self setTitle:@"⚪" forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont systemFontOfSize:24];
        [self addTarget:self action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
    }
    return self;
}
- (void)updateIcon:(BOOL)active {
    [self setTitle:active ? @"🔵" : @"⚪" forState:UIControlStateNormal];
    self.backgroundColor = active ? [UIColor colorWithRed:0x07/255.0 green:0x0b/255.0 blue:0x18/255.0 alpha:0.9] : [UIColor colorWithRed:0x1c/255.0 green:0x1f/255.0 blue:0x2b/255.0 alpha:0.9];
}
- (void)handleTap { if (self.tapHandler) self.tapHandler(); }
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.superview];
    if (pan.state == UIGestureRecognizerStateBegan) {
        _startPoint = self.center;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        self.center = CGPointMake(_startPoint.x + translation.x, _startPoint.y + translation.y);
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        // البقاء داخل حدود الشاشة
        CGRect screenRect = [UIScreen mainScreen].bounds;
        CGFloat margin = 10;
        CGPoint finalPoint = self.center;
        if (finalPoint.x < margin + self.frame.size.width/2) finalPoint.x = margin + self.frame.size.width/2;
        if (finalPoint.x > screenRect.size.width - margin - self.frame.size.width/2) finalPoint.x = screenRect.size.width - margin - self.frame.size.width/2;
        if (finalPoint.y < margin + 60) finalPoint.y = margin + 60;
        if (finalPoint.y > screenRect.size.height - margin - 80) finalPoint.y = screenRect.size.height - margin - 80;
        
        [UIView animateWithDuration:0.3 animations:^{ self.center = finalPoint; }];
    }
}
@end

@interface YHElectricBorderView : UIView
@property (nonatomic, assign) CGFloat cornerRadiusValue;
- (instancetype)initWithFrame:(CGRect)frame cornerRadius:(CGFloat)radius;
- (void)startAnimation;
- (void)stopAnimation;
@end
@implementation YHElectricBorderView
- (instancetype)initWithFrame:(CGRect)frame cornerRadius:(CGFloat)radius {
    self = [super initWithFrame:frame];
    if (self) {
        self.cornerRadiusValue = radius; self.userInteractionEnabled = NO; self.layer.cornerRadius = radius;
        if (@available(iOS 13.0, *)) { self.layer.cornerCurve = kCACornerCurveContinuous; }
        self.layer.borderWidth = 2.0; self.layer.borderColor = [UIColor clearColor].CGColor; self.hidden = YES;
    }
    return self;
}
- (void)startAnimation {
    self.hidden = NO; self.layer.borderColor = COL_ACCENT.CGColor; self.layer.shadowColor = COL_ACCENT.CGColor; self.layer.shadowRadius = 18.0; self.layer.shadowOpacity = 0.9; self.layer.shadowOffset = CGSizeZero;
    CAKeyframeAnimation *lightning = [CAKeyframeAnimation animationWithKeyPath:@"shadowOpacity"];
    lightning.values = @[@0.9, @0.3, @0.9, @0.4, @0.9, @0.9, @0.3, @0.9];
    lightning.keyTimes = @[@0.0, @0.05, @0.1, @0.15, @0.2, @0.8, @0.9, @1.0];
    lightning.duration = 3.0; lightning.repeatCount = HUGE_VALF;
    [self.layer addAnimation:lightning forKey:@"lightningStrike"];
    CAKeyframeAnimation *borderGlow = [CAKeyframeAnimation animationWithKeyPath:@"borderColor"];
    borderGlow.values = @[(id)COL_ACCENT.CGColor, (id)[UIColor colorWithRed:0.5 green:1.0 blue:0.9 alpha:1.0].CGColor, (id)COL_ACCENT.CGColor];
    borderGlow.keyTimes = @[@0.0, @0.1, @1.0];
    borderGlow.duration = 3.0; borderGlow.repeatCount = HUGE_VALF;
    [self.layer addAnimation:borderGlow forKey:@"borderLightning"];
}
- (void)stopAnimation { self.hidden = YES; self.layer.borderColor = [UIColor clearColor].CGColor; self.layer.shadowOpacity = 0.0; [self.layer removeAllAnimations]; }
@end

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
        self.title = dict[@"title"] ?: @""; self.enabled = [dict[@"enabled"] boolValue]; self.repeatWeekly = [dict[@"repeatWeekly"] boolValue];
        self.targetDate = dict[@"targetDate"] ? [NSDate dateWithTimeIntervalSince1970:[dict[@"targetDate"] doubleValue]] : [NSDate date];
        self.linkedLocationIndex = dict[@"linkedLocationIndex"] ? [dict[@"linkedLocationIndex"] integerValue] : -1;
        self.mediaPath = dict[@"mediaPath"] ?: @"";
    }
    return self;
}
- (NSDictionary *)toDictionary { return @{@"title": self.title ?: @"", @"enabled": @(self.enabled), @"repeatWeekly": @(self.repeatWeekly), @"targetDate": @([self.targetDate timeIntervalSince1970]), @"linkedLocationIndex": @(self.linkedLocationIndex), @"mediaPath": self.mediaPath ?: @""}; }
@end

@interface YHManager : NSObject <CLLocationManagerDelegate>
@property (class, readonly) YHManager *shared;
@property (nonatomic) BOOL isEnabled;
@property (nonatomic) BOOL isJitterEnabled;
@property (nonatomic) BOOL isUDIDSpoofEnabled;
@property (nonatomic) BOOL isEngineEnabled;
@property (nonatomic) BOOL isBluetoothSpoofEnabled;
@property (strong, nonatomic) NSString *spoofBeaconUUID;
@property (nonatomic) NSInteger spoofBeaconMajor;
@property (nonatomic) NSInteger spoofBeaconMinor;
@property (strong, nonatomic) NSMutableArray<NSDictionary*> *savedBleProfiles;
@property (strong, nonatomic) NSMutableArray<NSDictionary*> *capturedBleProfiles;
@property (strong, nonatomic) NSString *activeBleProfileID;
@property (strong, nonatomic) dispatch_queue_t blePersistenceQueue;
@property (strong, nonatomic) dispatch_source_t blePersistenceTimer;
@property (copy, nonatomic) NSArray<NSDictionary *> *pendingSavedBleProfiles;
@property (copy, nonatomic) NSArray<NSDictionary *> *pendingCapturedBleProfiles;
@property (nonatomic) BOOL blePersistenceScheduled;
@property (strong, nonatomic, readonly) CLLocation *override;
@property (strong, nonatomic) NSMutableArray<NSDictionary*> *savedLocations;
@property (strong, nonatomic) NSMutableArray<YHScheduleItem*> *schedules;
@property (strong, nonatomic) NSString *language;
@property (strong, nonatomic) NSTimer *scheduleTimer;
@property (strong, nonatomic) NSTimer *jitterTimer;
@property (strong, nonatomic) AVPlayer *mediaPlayer;
@property (strong, nonatomic) UIImage *spoofImage;
@property (strong, nonatomic) NSURL *spoofVideoURL;
@property (nonatomic, assign) double jitterDistance;
@property (strong, nonatomic) NSDictionary *locStrings;
- (void)overrideWith:(CLLocationDegrees)aLatitude longitude:(CLLocationDegrees)aLongitude;
- (void)saveLocation:(CLLocationCoordinate2D)coord withName:(NSString*)name favorite:(BOOL)fav;
- (void)deleteLocationAtIndex:(NSInteger)index;
- (void)addSchedule:(YHScheduleItem*)scheduleItem;
- (void)deleteScheduleAtIndex:(NSInteger)index;
- (void)setLanguageTo:(NSString*)lang;
- (NSString*)localizedString:(NSString*)key;
- (void)checkSchedules;
- (void)playMediaFromPath:(NSString *)path;
- (void)setupScheduleNotifications;
- (void)saveSchedules;
- (void)setJitterEnabled:(BOOL)enabled;
- (NSString*)generateRandomUDID;
- (void)persistBleProfiles;
- (NSDictionary *)profileFromPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI connected:(BOOL)connected;
- (NSDictionary *)activeBleProfile;
- (void)recordBluetoothPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI connected:(BOOL)connected;
- (void)saveBluetoothProfile:(NSDictionary *)profile activate:(BOOL)activate;
- (void)activateBluetoothProfile:(NSDictionary *)profile;
- (void)disableBluetoothInjection;
@end
@interface YHManager()
@property (strong, nonatomic, readwrite) CLLocation *override;
@end
@implementation YHManager
+ (YHManager *)shared { static YHManager *sharedInstance = nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ sharedInstance = [YHManager new]; }); return sharedInstance; }
- (instancetype)init {
    self = [super init];
    if (self) {
        NSArray *saved = [NSUserDefaults.standardUserDefaults arrayForKey:kSaveKeyLocations];
        self.savedLocations = saved ? [saved mutableCopy] : [NSMutableArray new];
        kSavedLocations = self.savedLocations;
        NSArray *scheds = [NSUserDefaults.standardUserDefaults arrayForKey:kSaveKeySchedule];
        self.schedules = [NSMutableArray new];
        for (NSDictionary *dict in scheds) { [self.schedules addObject:[[YHScheduleItem alloc] initWithDictionary:dict]]; }
        kScheduleItems = self.schedules;
        self.isEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kSaveKeyGPSEnabled];
        self.isUDIDSpoofEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kSaveKeyUDIDEnabled];
        self.isEngineEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kSaveKeyEngineEnabled];
        self.isBluetoothSpoofEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kSaveBleEnabled];
        self.language = [NSUserDefaults.standardUserDefaults boolForKey:kSaveKeyLanguage] ? @"ar" : @"en";
        kIsArabic = [self.language isEqualToString:@"ar"];
        self.jitterDistance = 1.0;
        self.spoofBeaconUUID = [NSUserDefaults.standardUserDefaults stringForKey:kSaveBleUUID] ?: @"";
        self.spoofBeaconMajor = [NSUserDefaults.standardUserDefaults integerForKey:kSaveBleMajor];
        self.spoofBeaconMinor = [NSUserDefaults.standardUserDefaults integerForKey:kSaveBleMinor];
        self.savedBleProfiles = [[NSUserDefaults.standardUserDefaults arrayForKey:kSaveBleProfiles] mutableCopy] ?: [NSMutableArray new];
        self.capturedBleProfiles = [[NSUserDefaults.standardUserDefaults arrayForKey:kSaveBleCapturedProfiles] mutableCopy] ?: [NSMutableArray new];
        self.activeBleProfileID = [NSUserDefaults.standardUserDefaults stringForKey:kSaveBleActiveProfileID] ?: @"";
        self.blePersistenceQueue = dispatch_queue_create("com.yh.bluetooth.persistence", DISPATCH_QUEUE_SERIAL);
        self.blePersistenceTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.blePersistenceQueue);
        dispatch_source_set_timer(self.blePersistenceTimer, DISPATCH_TIME_FOREVER, DISPATCH_TIME_FOREVER, 0);
        __weak YHManager *weakSelf = self;
        dispatch_source_set_event_handler(self.blePersistenceTimer, ^{
            __strong YHManager *strongSelf = weakSelf; if (!strongSelf) return;
            NSArray *savedProfiles = strongSelf.pendingSavedBleProfiles ?: @[];
            NSArray *capturedProfiles = strongSelf.pendingCapturedBleProfiles ?: @[];
            strongSelf.pendingSavedBleProfiles = nil; strongSelf.pendingCapturedBleProfiles = nil; strongSelf.blePersistenceScheduled = NO;
            [NSUserDefaults.standardUserDefaults setObject:savedProfiles forKey:kSaveBleProfiles];
            [NSUserDefaults.standardUserDefaults setObject:capturedProfiles forKey:kSaveBleCapturedProfiles];
            [NSUserDefaults.standardUserDefaults synchronize];
        });
        dispatch_resume(self.blePersistenceTimer);
        self.locStrings = @{
            @"ar": @{@"main_title": @"GPS Plus", @"enable_change": @"تفعيل دائم ∞", @"open_map": @"الخريطة", @"saved_locs": @"المواقع المحفوظة", @"add_sched": @"إضافة خطة جديدة", @"sched_title": @"الجدولة", @"tools_title": @"الأدوات", @"attendance_title": @"الحضور", @"location_title": @"الموقع", @"cancel": @"إلغاء", @"save_btn": @"حفظ", @"search_ph": @"بحث 🔍", @"unnamed_loc": @"بدون اسم", @"toast_saved": @"تم الحفظ بنجاح", @"ok": @"موافق", @"repeat_weekly": @"تكرار اسبوعي", @"link_location": @"ربط بموقع", @"alert_title": @"وقت الحضور", @"select_file": @"اختر ملف", @"no_file": @"لم يتم اختيار ملف", @"test_now": @"تجربة الان", @"paste_link": @"لصق رابط", @"camera_roll": @"الاستديو", @"url_media_input": @"رابط فيديو/صوت", @"enter_direct_link": @"أدخل الرابط المباشر", @"saved_from_url": @"تم الحفظ من الرابط", @"file_selected": @"تم اختيار الملف", @"no_location": @"بدون تغيير", @"weekly": @"اسبوعي", @"once": @"مرة واحدة", @"spoof_image_saved": @"تم تعيين صورة بديلة", @"spoof_video_saved": @"تم تعيين فيديو بديل", @"udid_changer": @"إعدادات المعرف", @"udid_current": @"الحالي:", @"udid_enter": @"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX", @"udid_btn_random": @"عشوائي", @"udid_btn_activate": @"تفعيل المعرّف يدوي", @"udid_btn_restore": @"إعادة تعيين", @"udid_activated": @"تم التفعيل", @"udid_restored": @"تم الاسترجاع", @"distance_txt": @"تفعيل الحركة (10 أمتار)", @"save_loc_btn": @"اختر هذا الموقع", @"next_alert_time": @"أقرب موعد:", @"no_upcoming_alerts": @"لا توجد تنبيهات", @"engine_tool": @"تزييف التصوير 📷", @"back": @"رجوع", @"sched_time": @"وقت التفعيل:", @"new_alert": @"تنبيه جديد", @"sound_optional": @"الصوت (اختياري):", @"copied": @"تم النسخ", @"close": @"إغلاق", @"unfav": @"إلغاء التفضيل", @"fav": @"المفضلة ⭐", @"bluetooth_tool": @"بلوتوث 🛰️", @"bt_saved_list": @"قائمة السماعات المحفوظة", @"bt_nearby": @"بحث عن جهاز قريب", @"bt_stop_inject": @"إيقاف حقن السماعة", @"hide_tool": @"إخفاء الأداة 👁️‍🗨️", @"notify_expiry": @"تنبيه قبل انتهاء الاشتراك 🔔", @"sched_active": @"تفعيل بالجدولة ⏰"},
            @"en": @{@"main_title": @"Wellfox", @"enable_change": @"Spoof Location", @"open_map": @"Map", @"saved_locs": @"Saved", @"add_sched": @"Add Schedule", @"sched_title": @"Schedule", @"tools_title": @"Tools", @"attendance_title": @"Timer", @"location_title": @"Location", @"cancel": @"Cancel", @"save_btn": @"Save", @"search_ph": @"Search...", @"unnamed_loc": @"Unnamed", @"toast_saved": @"Saved Successfully", @"ok": @"OK", @"repeat_weekly": @"Weekly", @"link_location": @"Link Location", @"alert_title": @"Alert", @"select_file": @"Select File", @"no_file": @"No file", @"test_now": @"Test", @"paste_link": @"Paste Link", @"camera_roll": @"Camera Roll", @"url_media_input": @"Media URL", @"enter_direct_link": @"Enter Link", @"saved_from_url": @"Saved", @"file_selected": @"Selected", @"no_location": @"None", @"weekly": @"Weekly", @"once": @"Once", @"spoof_image_saved": @"Image Set", @"spoof_video_saved": @"Video Set", @"udid_changer": @"UDID Spoof", @"udid_current": @"Current:", @"udid_enter": @"Enter UDID", @"udid_btn_random": @"Random", @"udid_btn_activate": @"Activate", @"udid_btn_restore": @"Restore", @"udid_activated": @"Activated", @"udid_restored": @"Restored", @"distance_txt": @"Motion:", @"save_loc_btn": @"Save Location", @"next_alert_time": @"Next Alert:", @"no_upcoming_alerts": @"No Alerts", @"engine_tool": @"Upload photos", @"back": @"Back", @"sched_time": @"Trigger Time:", @"new_alert": @"New Alert", @"sound_optional": @"Sound (Opt):", @"copied": @"Copied", @"close": @"Close", @"unfav": @"Unfavorite", @"fav": @"Favorite ⭐️", @"bluetooth_tool": @"Bluetooth Manager", @"bt_saved_list": @"Saved Devices", @"bt_nearby": @"Scan Nearby", @"bt_stop_inject": @"Stop Injection"}
        };
        self.scheduleTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkSchedules) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.scheduleTimer forMode:NSRunLoopCommonModes];
        [self setupScheduleNotifications];
        kGPSEnabled = self.isEnabled;
        double savedLat = [NSUserDefaults.standardUserDefaults doubleForKey:kSaveKeyLat];
        double savedLng = [NSUserDefaults.standardUserDefaults doubleForKey:kSaveKeyLng];
        if (savedLat != 0 && savedLng != 0) { kBaseLocation = CLLocationCoordinate2DMake(savedLat, savedLng); kLocation = kBaseLocation; self.override = [[CLLocation alloc] initWithCoordinate:kLocation altitude:15.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]]; }
        if (kGPSEnabled) { [self setJitterEnabled:YES]; }
        if (self.savedBleProfiles.count == 0) {
            NSString *autoUUID = [[NSUUID UUID] UUIDString];
            NSDictionary *headsetProfile = @{@"id": autoUUID, @"identifier": autoUUID, @"name": @"Air Pods", @"rssi": @(-30), @"connected": @YES, @"injected": @YES, @"source": @"auto-generated", @"lastSeen": @([NSDate.date timeIntervalSince1970]), @"advertisementData": @{}, @"serviceUUIDs": @[@"180A", @"1108", @"111E"], @"manufacturerData": @"4C000215", @"serviceData": @{}};
            [self saveBluetoothProfile:headsetProfile activate:YES];
        }
    }
    return self;
}
- (void)setIsEnabled:(BOOL)isEnabled { _isEnabled = isEnabled; kGPSEnabled = isEnabled; [[NSNotificationCenter defaultCenter] postNotificationName:kEnableDidChange object:self userInfo:@{kSaveKeyGPSEnabled: @(isEnabled)}]; [NSUserDefaults.standardUserDefaults setBool:isEnabled forKey:kSaveKeyGPSEnabled]; [NSUserDefaults.standardUserDefaults synchronize]; }
- (void)setIsEngineEnabled:(BOOL)isEngineEnabled { _isEngineEnabled = isEngineEnabled; [NSUserDefaults.standardUserDefaults setBool:isEngineEnabled forKey:kSaveKeyEngineEnabled]; [NSUserDefaults.standardUserDefaults synchronize]; [[NSNotificationCenter defaultCenter] postNotificationName:@"YHToggleSpoofUI" object:@(isEngineEnabled)]; }
- (void)setIsUDIDSpoofEnabled:(BOOL)isUDIDSpoofEnabled { _isUDIDSpoofEnabled = isUDIDSpoofEnabled; [NSUserDefaults.standardUserDefaults setBool:isUDIDSpoofEnabled forKey:kSaveKeyUDIDEnabled]; [NSUserDefaults.standardUserDefaults synchronize]; }
- (void)setIsBluetoothSpoofEnabled:(BOOL)val { _isBluetoothSpoofEnabled = val; [NSUserDefaults.standardUserDefaults setBool:val forKey:kSaveBleEnabled]; }
- (void)setActiveBleProfileID:(NSString *)val { _activeBleProfileID = val ?: @""; [NSUserDefaults.standardUserDefaults setObject:_activeBleProfileID forKey:kSaveBleActiveProfileID]; }
- (void)persistBleProfiles {
    NSArray *savedSnapshot = nil; NSArray *capturedSnapshot = nil;
    @synchronized (self) { savedSnapshot = [self.savedBleProfiles copy] ?: @[]; capturedSnapshot = [self.capturedBleProfiles copy] ?: @[]; }
    dispatch_async(self.blePersistenceQueue, ^{
        self.pendingSavedBleProfiles = savedSnapshot; self.pendingCapturedBleProfiles = capturedSnapshot;
        if (self.blePersistenceScheduled) return;
        self.blePersistenceScheduled = YES;
        dispatch_source_set_timer(self.blePersistenceTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), DISPATCH_TIME_FOREVER, (uint64_t)(0.05 * NSEC_PER_SEC));
    });
}
- (void)replaceProfile:(NSDictionary *)profile inArray:(NSMutableArray<NSDictionary *> *)array {
    if (!profile || !array) return;
    NSString *identifier = profile[@"identifier"] ?: profile[@"id"];
    NSIndexSet *dupes = [array indexesOfObjectsPassingTest:^BOOL(NSDictionary *obj, NSUInteger idx, BOOL *stop) { NSString *other = obj[@"identifier"] ?: obj[@"id"]; return identifier.length && [other isEqualToString:identifier]; }];
    [array removeObjectsAtIndexes:dupes]; [array insertObject:profile atIndex:0];
}
- (NSDictionary *)profileFromPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI connected:(BOOL)connected {
    if (!peripheral) return nil; NSDictionary *adv = [advertisementData isKindOfClass:NSDictionary.class] ? advertisementData : @{};
    NSString *identifier = peripheral.identifier.UUIDString ?: @""; if (!identifier.length) identifier = NSUUID.UUID.UUIDString;
    NSMutableArray *services = [NSMutableArray array]; for (CBUUID *uuid in adv[CBAdvertisementDataServiceUUIDsKey] ?: @[]) { if ([uuid respondsToSelector:@selector(UUIDString)] && uuid.UUIDString.length) [services addObject:uuid.UUIDString]; }
    NSMutableDictionary *serviceData = [NSMutableDictionary dictionary]; NSDictionary *rawServiceData = adv[CBAdvertisementDataServiceDataKey];
    if ([rawServiceData isKindOfClass:NSDictionary.class]) { [rawServiceData enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) { NSString *uuid = [key respondsToSelector:@selector(UUIDString)] ? [key UUIDString] : [key description]; NSString *hex = YHHexFromData(obj); if (uuid.length && hex.length) serviceData[uuid] = hex; }]; }
    NSString *name = peripheral.name.length ? peripheral.name : adv[CBAdvertisementDataLocalNameKey]; if (![name isKindOfClass:NSString.class] || !name.length) name = @"Unknown Device";
    return @{@"id": identifier, @"identifier": identifier, @"name": name, @"rssi": RSSI ?: @(-55), @"connected": @(connected), @"injected": @NO, @"source": connected ? @"app-connected" : @"app-discovered", @"lastSeen": @([NSDate.date timeIntervalSince1970]), @"advertisementData": YHJSONSafeObject(adv) ?: @{}, @"serviceUUIDs": services, @"manufacturerData": YHHexFromData(adv[CBAdvertisementDataManufacturerDataKey]) ?: @"", @"serviceData": serviceData};
}
- (void)recordBluetoothPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI connected:(BOOL)connected {
    NSDictionary *incomingProfile = [self profileFromPeripheral:peripheral advertisementData:advertisementData RSSI:RSSI connected:connected]; if (!incomingProfile) return;
    @synchronized (self) { [self replaceProfile:incomingProfile inArray:self.capturedBleProfiles]; } [self persistBleProfiles];
}
- (NSDictionary *)activeBleProfile {
    if (!self.isBluetoothSpoofEnabled || !self.activeBleProfileID.length) return nil;
    for (NSDictionary *profile in self.savedBleProfiles) { NSString *identifier = profile[@"identifier"] ?: profile[@"id"]; if ([identifier isEqualToString:self.activeBleProfileID]) return profile; }
    return nil;
}
- (void)saveBluetoothProfile:(NSDictionary *)profile activate:(BOOL)activate { if (!profile) return; [self replaceProfile:profile inArray:self.savedBleProfiles]; if (activate) [self activateBluetoothProfile:profile]; [self persistBleProfiles]; }
- (void)activateBluetoothProfile:(NSDictionary *)profile {
    if (!profile) return; NSMutableDictionary *active = [profile mutableCopy]; active[@"connected"] = @YES; active[@"injected"] = @YES; active[@"lastSeen"] = @([NSDate.date timeIntervalSince1970]);
    NSString *identifier = active[@"identifier"] ?: active[@"id"]; if (!identifier.length) identifier = NSUUID.UUID.UUIDString; active[@"identifier"] = identifier; active[@"id"] = identifier;
    [self replaceProfile:active inArray:self.savedBleProfiles]; self.activeBleProfileID = identifier; self.isBluetoothSpoofEnabled = YES; [self persistBleProfiles];
}
- (void)disableBluetoothInjection { self.isBluetoothSpoofEnabled = NO; self.activeBleProfileID = @""; [self persistBleProfiles]; }
- (void)overrideWith:(CLLocationDegrees)aLatitude longitude:(CLLocationDegrees)aLongitude { kBaseLocation = CLLocationCoordinate2DMake(aLatitude, aLongitude); kLocation = kBaseLocation; self.override = [[CLLocation alloc] initWithCoordinate:kLocation altitude:15.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]]; [NSUserDefaults.standardUserDefaults setDouble:aLatitude forKey:kSaveKeyLat]; [NSUserDefaults.standardUserDefaults setDouble:aLongitude forKey:kSaveKeyLng]; [NSUserDefaults.standardUserDefaults synchronize]; [[NSNotificationCenter defaultCenter] postNotificationName:kOverrideDidChange object:self userInfo:@{kSaveKeyLat: @(aLatitude), kSaveKeyLng: @(aLongitude)}]; }
- (void)saveLocation:(CLLocationCoordinate2D)coord withName:(NSString*)name favorite:(BOOL)fav { NSDictionary *locDict = @{ @"name": name, @"lat": @(coord.latitude), @"lng": @(coord.longitude), @"favorite": @(fav) }; [self.savedLocations addObject:locDict]; [NSUserDefaults.standardUserDefaults setObject:self.savedLocations forKey:kSaveKeyLocations]; [NSUserDefaults.standardUserDefaults synchronize]; }
- (void)deleteLocationAtIndex:(NSInteger)index { if (index < self.savedLocations.count) { [self.savedLocations removeObjectAtIndex:index]; [NSUserDefaults.standardUserDefaults setObject:self.savedLocations forKey:kSaveKeyLocations]; [NSUserDefaults.standardUserDefaults synchronize]; } }
- (void)addSchedule:(YHScheduleItem*)scheduleItem { [self.schedules addObject:scheduleItem]; [self saveSchedules]; [self setupScheduleNotifications]; }
- (void)deleteScheduleAtIndex:(NSInteger)index { if (index < self.schedules.count) { [self.schedules removeObjectAtIndex:index]; [self saveSchedules]; [self setupScheduleNotifications]; } }
- (void)saveSchedules { NSMutableArray *dicts = [NSMutableArray new]; for (YHScheduleItem *item in self.schedules) { [dicts addObject:[item toDictionary]]; } [NSUserDefaults.standardUserDefaults setObject:dicts forKey:kSaveKeySchedule]; [NSUserDefaults.standardUserDefaults synchronize]; }
- (void)setLanguageTo:(NSString*)lang { self.language = lang; [NSUserDefaults.standardUserDefaults setBool:[lang isEqualToString:@"ar"] forKey:kSaveKeyLanguage]; [NSUserDefaults.standardUserDefaults synchronize]; kIsArabic = [lang isEqualToString:@"ar"]; [[NSNotificationCenter defaultCenter] postNotificationName:kLanguageDidChange object:nil]; }
- (NSString*)localizedString:(NSString*)key { NSString *res = self.locStrings[self.language][key]; return res ? res : key; }
- (void)checkSchedules {
    NSDate *now = [NSDate date]; NSCalendar *calendar = [NSCalendar currentCalendar]; NSDateComponents *nowComps = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitWeekday|NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond fromDate:now];
    static NSInteger lastTriggeredMinute = -1; BOOL anyTriggered = NO;
    for (YHScheduleItem *item in self.schedules) {
        if (!item.enabled) continue;
        NSDateComponents *targetComps = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitWeekday|NSCalendarUnitHour|NSCalendarUnitMinute fromDate:item.targetDate]; BOOL shouldTrigger = NO;
        if (item.repeatWeekly) { if (nowComps.weekday == targetComps.weekday && nowComps.hour == targetComps.hour && nowComps.minute == targetComps.minute) { shouldTrigger = YES; } } else { if (nowComps.year == targetComps.year && nowComps.month == targetComps.month && nowComps.day == targetComps.day && nowComps.hour == targetComps.hour && nowComps.minute == targetComps.minute) { shouldTrigger = YES; } }
        if (shouldTrigger && lastTriggeredMinute != nowComps.minute) {
            if (item.linkedLocationIndex >= 0 && item.linkedLocationIndex < self.savedLocations.count) { NSDictionary *loc = self.savedLocations[item.linkedLocationIndex]; [self overrideWith:[loc[@"lat"] doubleValue] longitude:[loc[@"lng"] doubleValue]]; self.isEnabled = YES; }
            if (item.mediaPath.length > 0) { [self playMediaFromPath:item.mediaPath]; }
            dispatch_async(dispatch_get_main_queue(), ^{ [[NSNotificationCenter defaultCenter] postNotificationName:@"YHScheduleDidTrigger" object:item.title]; });
            anyTriggered = YES;
        }
    }
    if (anyTriggered) { lastTriggeredMinute = nowComps.minute; }
}
- (void)playMediaFromPath:(NSString *)path { NSURL *url = [NSURL fileURLWithPath:path]; if (!url) return; [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil]; [[AVAudioSession sharedInstance] setActive:YES error:nil]; self.mediaPlayer = [AVPlayer playerWithURL:url]; [self.mediaPlayer play]; }
- (void)setupScheduleNotifications {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound) completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (granted) {
            [center removeAllPendingNotificationRequests];
            for (YHScheduleItem *item in self.schedules) {
                if (!item.enabled) continue;
                NSDateComponents *components = [[NSCalendar currentCalendar] components:(NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitWeekday) fromDate:item.targetDate];
                UNMutableNotificationContent *content = [UNMutableNotificationContent new];
                content.title = item.title.length > 0 ? item.title : [self localizedString:@"new_alert"];
                content.body = [self localizedString:@"alert_title"];
                if (item.mediaPath.length > 0) { NSString *fileName = [item.mediaPath lastPathComponent]; content.sound = [UNNotificationSound soundNamed:fileName]; } else { content.sound = [UNNotificationSound defaultSound]; }
                UNCalendarNotificationTrigger *trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components repeats:item.repeatWeekly];
                NSString *identifier = [NSString stringWithFormat:@"schedule_%lu", (unsigned long)[self.schedules indexOfObject:item]];
                UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
                [center addNotificationRequest:request withCompletionHandler:nil];
            }
        }
    }];
}
- (void)setJitterEnabled:(BOOL)enabled {
    _isJitterEnabled = enabled;
    if (enabled) {
        [self.jitterTimer invalidate];
        self.jitterTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
            int randomMeters = (arc4random_uniform(11)); self.jitterDistance = (double)randomMeters; double maxMeters = self.jitterDistance; double angle = ((double)arc4random_uniform(360)) * M_PI / 180.0; double lat = kBaseLocation.latitude; double lon = kBaseLocation.longitude; double metersPerDegreeLat = 111320.0; double metersPerDegreeLon = metersPerDegreeLat * cos(lat * M_PI / 180.0); double deltaLat = (maxMeters * cos(angle)) / metersPerDegreeLat; double deltaLon = (maxMeters * sin(angle)) / metersPerDegreeLon; kLocation = CLLocationCoordinate2DMake(lat + deltaLat, lon + deltaLon); [[NSNotificationCenter defaultCenter] postNotificationName:kDistanceDidChange object:@(randomMeters)];
        }];
        [[NSNotificationCenter defaultCenter] postNotificationName:kDistanceDidChange object:@(0)];
    } else {
        [self.jitterTimer invalidate]; self.jitterTimer = nil; kLocation = kBaseLocation;
    }
}
- (NSString*)generateRandomUDID { uint32_t p1 = arc4random_uniform(0xFFFFFFFF); uint32_t p2 = arc4random_uniform(0xFFFFFFFF); uint32_t p3 = arc4random_uniform(0xFFFFFFFF); return [NSString stringWithFormat:@"0000%04X-%08X%08X", arc4random_uniform(0xFFFF), p2, p3]; }
@end

@interface YHFakePeripheral : NSObject
@property (nonatomic, strong) NSUUID *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, weak) id delegate;
@end
@implementation YHFakePeripheral
- (CBPeripheralState)state { return CBPeripheralStateConnected; }
- (NSArray *)services { return @[]; }
- (void)discoverServices:(NSArray<CBUUID *> *)serviceUUIDs { id delegate = self.delegate; if ([delegate respondsToSelector:@selector(peripheral:didDiscoverServices:)]) { dispatch_async(dispatch_get_main_queue(), ^{ [delegate peripheral:(CBPeripheral *)(id)self didDiscoverServices:nil]; }); } }
- (void)discoverCharacteristics:(NSArray<CBUUID *> *)characteristicUUIDs forService:(CBService *)service { id delegate = self.delegate; if ([delegate respondsToSelector:@selector(peripheral:didDiscoverCharacteristicsForService:error:)]) { dispatch_async(dispatch_get_main_queue(), ^{ [delegate peripheral:(CBPeripheral *)(id)self didDiscoverCharacteristicsForService:service error:nil]; }); } }
- (void)readRSSI { id delegate = self.delegate; NSNumber *rssi = YHManager.shared.activeBleProfile[@"rssi"] ?: @(-45); if ([delegate respondsToSelector:@selector(peripheral:didReadRSSI:error:)]) { dispatch_async(dispatch_get_main_queue(), ^{ [delegate peripheral:(CBPeripheral *)(id)self didReadRSSI:rssi error:nil]; }); } }
@end

static NSDictionary *YHAdvertisementFromProfile(NSDictionary *profile) {
    NSMutableDictionary *adv = [NSMutableDictionary dictionary]; NSString *name = profile[@"name"]; if ([name isKindOfClass:NSString.class] && name.length) adv[CBAdvertisementDataLocalNameKey] = name; adv[CBAdvertisementDataIsConnectable] = @YES; NSMutableArray *uuids = [NSMutableArray array]; for (NSString *uuidString in profile[@"serviceUUIDs"] ?: @[]) { if ([uuidString isKindOfClass:NSString.class] && uuidString.length) [uuids addObject:[CBUUID UUIDWithString:uuidString]]; } if (uuids.count) adv[CBAdvertisementDataServiceUUIDsKey] = uuids; NSData *manufacturer = YHDataFromHex(profile[@"manufacturerData"]); if (manufacturer.length) adv[CBAdvertisementDataManufacturerDataKey] = manufacturer; NSMutableDictionary *serviceData = [NSMutableDictionary dictionary]; NSDictionary *rawServiceData = profile[@"serviceData"]; if ([rawServiceData isKindOfClass:NSDictionary.class]) { [rawServiceData enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *hex, BOOL *stop) { NSData *data = YHDataFromHex(hex); if ([key isKindOfClass:NSString.class] && key.length && data.length) serviceData[[CBUUID UUIDWithString:key]] = data; }]; } if (serviceData.count) adv[CBAdvertisementDataServiceDataKey] = serviceData; return adv;
}

@interface YHCBProxy : NSProxy <CBCentralManagerDelegate>
@property (weak, nonatomic, readonly) id delegate;
@property (weak, nonatomic) CBCentralManager *manager;
@property (strong, nonatomic, readonly) dispatch_queue_t callbackQueue;
- (instancetype)initWithDelegate:(id)delegate manager:(CBCentralManager *)manager queue:(dispatch_queue_t)queue;
@end
@implementation YHCBProxy
- (instancetype)initWithDelegate:(id)delegate manager:(CBCentralManager *)manager queue:(dispatch_queue_t)queue { _delegate = delegate; _manager = manager; _callbackQueue = queue ?: dispatch_get_main_queue(); return self; }
- (BOOL)respondsToSelector:(SEL)aSelector { if (aSelector == @selector(centralManager:didDiscoverPeripheral:advertisementData:RSSI:) || aSelector == @selector(centralManager:didConnectPeripheral:)) return YES; return [self.delegate respondsToSelector:aSelector]; }
- (void)forwardInvocation:(NSInvocation *)invocation { SEL sel = invocation.selector; if ([self.delegate respondsToSelector:sel]) { [invocation invokeWithTarget:self.delegate]; } }
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel { return [self.delegate methodSignatureForSelector:sel] ?: [NSObject instanceMethodSignatureForSelector:@selector(description)]; }
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    if (object_getClass((id)peripheral) != YHFakePeripheral.class) { [YHManager.shared recordBluetoothPeripheral:peripheral advertisementData:advertisementData RSSI:RSSI connected:NO]; }
    if ([self.delegate respondsToSelector:_cmd]) { [self.delegate centralManager:central didDiscoverPeripheral:peripheral advertisementData:advertisementData RSSI:RSSI]; }
}
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    if (object_getClass((id)peripheral) != YHFakePeripheral.class) { [YHManager.shared recordBluetoothPeripheral:peripheral advertisementData:@{} RSSI:@(-45) connected:YES]; }
    if ([self.delegate respondsToSelector:_cmd]) { [self.delegate centralManager:central didConnectPeripheral:peripheral]; }
}
@end

@interface YHCBDynamicScanSession : NSObject
@property (weak, nonatomic) CBCentralManager *manager;
@property (strong, nonatomic) dispatch_queue_t workerQueue;
@property (strong, nonatomic) dispatch_source_t timer;
@property (copy, nonatomic) NSDictionary *profile;
@property (strong, nonatomic) YHFakePeripheral *fakePeripheral;
@property (nonatomic) uint64_t generation;
- (instancetype)initWithManager:(CBCentralManager *)manager;
- (void)startWithProfile:(NSDictionary *)profile;
- (void)stop;
@end
@implementation YHCBDynamicScanSession
- (instancetype)initWithManager:(CBCentralManager *)manager { self = [super init]; if (self) { _manager = manager; _workerQueue = dispatch_queue_create("com.yh.bluetooth.dynamic-scan", DISPATCH_QUEUE_SERIAL); } return self; }
- (void)emitLockedForGeneration:(uint64_t)generation {
    if (generation != self.generation || !self.timer) return;
    CBCentralManager *central = self.manager; NSDictionary *profile = self.profile; YHFakePeripheral *fake = self.fakePeripheral; NSString *profileIdentifier = profile[@"identifier"] ?: profile[@"id"];
    if (!central || !profile || !fake || !YHManager.shared.isBluetoothSpoofEnabled || ![YHManager.shared.activeBleProfileID isEqualToString:profileIdentifier]) { [self stop]; return; }
    NSDictionary *advertisement = YHAdvertisementFromProfile(profile); NSNumber *rssi = [profile[@"rssi"] isKindOfClass:NSNumber.class] ? profile[@"rssi"] : @(-45);
    id delegate = central.delegate; SEL selector = @selector(centralManager:didDiscoverPeripheral:advertisementData:RSSI:);
    dispatch_async(dispatch_get_main_queue(), ^{ if ([delegate respondsToSelector:selector]) { [delegate centralManager:central didDiscoverPeripheral:(CBPeripheral *)(id)fake advertisementData:advertisement RSSI:rssi]; } });
}
- (void)startWithProfile:(NSDictionary *)profile {
    NSDictionary *snapshot = [profile copy]; if (!snapshot) { [self stop]; return; }
    dispatch_async(self.workerQueue, ^{
        self.generation += 1; if (self.timer) { dispatch_source_cancel(self.timer); self.timer = nil; }
        self.profile = snapshot; self.fakePeripheral = [YHFakePeripheral new]; self.fakePeripheral.identifier = [[NSUUID alloc] initWithUUIDString:(snapshot[@"identifier"]?:snapshot[@"id"])] ?: NSUUID.UUID; self.fakePeripheral.name = snapshot[@"name"];
        uint64_t gen = self.generation; dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.workerQueue); self.timer = timer;
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 0), (uint64_t)(1.0 * NSEC_PER_SEC), (uint64_t)(0.1 * NSEC_PER_SEC));
        __weak YHCBDynamicScanSession *weakSelf = self; dispatch_source_set_event_handler(timer, ^{ [weakSelf emitLockedForGeneration:gen]; }); dispatch_resume(timer);
    });
}
- (void)stop { dispatch_async(self.workerQueue, ^{ self.generation += 1; if (self.timer) { dispatch_source_cancel(self.timer); self.timer = nil; } self.profile = nil; self.fakePeripheral = nil; }); }
@end

static char kYHCBProxyAssociationKey;
static char kYHCBDynamicScanAssociationKey;

__attribute__((unused)) static void YHStartDynamicBluetoothScan(CBCentralManager *central) {
    if (!central) return; NSDictionary *profile = YHManager.shared.activeBleProfile; YHCBDynamicScanSession *session = objc_getAssociatedObject(central, &kYHCBDynamicScanAssociationKey);
    if (!profile) { [session stop]; return; }
    if (!session) { session = [[YHCBDynamicScanSession alloc] initWithManager:central]; objc_setAssociatedObject(central, &kYHCBDynamicScanAssociationKey, session, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    [session startWithProfile:profile];
}
__attribute__((unused)) static void YHStopDynamicBluetoothScan(CBCentralManager *central) { YHCBDynamicScanSession *session = objc_getAssociatedObject(central, &kYHCBDynamicScanAssociationKey); [session stop]; }

__attribute__((unused)) static NSUUID * (*orig_CBPeripheral_identifier)(CBPeripheral*, SEL);
__attribute__((unused)) static NSUUID * override_CBPeripheral_identifier(CBPeripheral *self, SEL _cmd) {
    NSUUID *original = orig_CBPeripheral_identifier ? orig_CBPeripheral_identifier(self, _cmd) : nil; NSDictionary *profile = YHManager.shared.activeBleProfile; NSString *identifier = profile[@"identifier"] ?: profile[@"id"];
    if (profile && original.UUIDString.length && [original.UUIDString isEqualToString:identifier]) { return [[NSUUID alloc] initWithUUIDString:identifier] ?: original; }
    return original;
}
__attribute__((unused)) static NSString * (*orig_CBPeripheral_name)(CBPeripheral*, SEL);
__attribute__((unused)) static NSString * override_CBPeripheral_name(CBPeripheral *self, SEL _cmd) {
    NSString *original = orig_CBPeripheral_name ? orig_CBPeripheral_name(self, _cmd) : nil; NSDictionary *profile = YHManager.shared.activeBleProfile; NSString *identifier = profile[@"identifier"] ?: profile[@"id"]; NSUUID *peripheralID = orig_CBPeripheral_identifier ? orig_CBPeripheral_identifier(self, @selector(identifier)) : nil;
    if (profile && identifier.length > 0 && [peripheralID.UUIDString isEqualToString:identifier]) { NSString *name = profile[@"name"]; return name.length ? name : original; }
    return original;
}
__attribute__((unused)) static CBPeripheralState (*orig_CBPeripheral_state)(CBPeripheral*, SEL);
__attribute__((unused)) static CBPeripheralState override_CBPeripheral_state(CBPeripheral *self, SEL _cmd) {
    NSDictionary *profile = YHManager.shared.activeBleProfile; NSString *identifier = profile[@"identifier"] ?: profile[@"id"]; NSUUID *peripheralID = orig_CBPeripheral_identifier ? orig_CBPeripheral_identifier(self, @selector(identifier)) : nil;
    if (profile && [peripheralID.UUIDString isEqualToString:identifier]) { return CBPeripheralStateConnected; }
    return orig_CBPeripheral_state(self, _cmd);
}

__attribute__((unused)) static void (*orig_CBCentralManager_setDelegate)(CBCentralManager*, SEL, id);
__attribute__((unused)) static id (*orig_CBCentralManager_initWithDelegate_queue)(CBCentralManager*, SEL, id, dispatch_queue_t);
__attribute__((unused)) static id override_CBCentralManager_initWithDelegate_queue(CBCentralManager *self, SEL _cmd, id delegate, dispatch_queue_t queue) {
    if (delegate && object_getClass(delegate) != YHCBProxy.class && ![[NSStringFromClass([delegate class]) lowercaseString] containsString:@"yhmenuvc"]) {
        YHCBProxy *proxy = [[YHCBProxy alloc] initWithDelegate:delegate manager:nil queue:queue]; CBCentralManager *central = orig_CBCentralManager_initWithDelegate_queue(self, _cmd, proxy, queue); if (!central) return nil; proxy.manager = central; objc_setAssociatedObject(central, &kYHCBProxyAssociationKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC); return central;
    }
    return orig_CBCentralManager_initWithDelegate_queue(self, _cmd, delegate, queue);
}
__attribute__((unused)) static id (*orig_CBCentralManager_initWithDelegate_queue_options)(CBCentralManager*, SEL, id, dispatch_queue_t, NSDictionary*);
__attribute__((unused)) static id override_CBCentralManager_initWithDelegate_queue_options(CBCentralManager *self, SEL _cmd, id delegate, dispatch_queue_t queue, NSDictionary *options) {
    if (delegate && object_getClass(delegate) != YHCBProxy.class && ![[NSStringFromClass([delegate class]) lowercaseString] containsString:@"yhmenuvc"]) {
        YHCBProxy *proxy = [[YHCBProxy alloc] initWithDelegate:delegate manager:nil queue:queue]; CBCentralManager *central = orig_CBCentralManager_initWithDelegate_queue_options(self, _cmd, proxy, queue, options); if (!central) return nil; proxy.manager = central; objc_setAssociatedObject(central, &kYHCBProxyAssociationKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC); return central;
    }
    return orig_CBCentralManager_initWithDelegate_queue_options(self, _cmd, delegate, queue, options);
}
__attribute__((unused)) static void override_CBCentralManager_setDelegate(CBCentralManager *self, SEL _cmd, id delegate) {
    if (delegate && object_getClass(delegate) != YHCBProxy.class && ![[NSStringFromClass([delegate class]) lowercaseString] containsString:@"yhmenuvc"]) {
        YHCBProxy *oldProxy = objc_getAssociatedObject(self, &kYHCBProxyAssociationKey); dispatch_queue_t queue = oldProxy.callbackQueue ?: dispatch_get_main_queue(); YHCBProxy *proxy = [[YHCBProxy alloc] initWithDelegate:delegate manager:self queue:queue]; objc_setAssociatedObject(self, &kYHCBProxyAssociationKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC); orig_CBCentralManager_setDelegate(self, _cmd, proxy);
    } else {
        if (object_getClass(delegate) == YHCBProxy.class) { objc_setAssociatedObject(self, &kYHCBProxyAssociationKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC); } else { objc_setAssociatedObject(self, &kYHCBProxyAssociationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); if (!delegate) YHStopDynamicBluetoothScan(self); }
        orig_CBCentralManager_setDelegate(self, _cmd, delegate);
    }
}
__attribute__((unused)) static void (*orig_CBCentralManager_scanForPeripherals)(CBCentralManager*, SEL, NSArray*, NSDictionary*);
__attribute__((unused)) static void override_CBCentralManager_scanForPeripherals(CBCentralManager *self, SEL _cmd, NSArray *services, NSDictionary *options) { orig_CBCentralManager_scanForPeripherals(self, _cmd, services, options); YHStartDynamicBluetoothScan(self); }
__attribute__((unused)) static void (*orig_CBCentralManager_stopScan)(CBCentralManager*, SEL);
__attribute__((unused)) static void override_CBCentralManager_stopScan(CBCentralManager *self, SEL _cmd) { YHStopDynamicBluetoothScan(self); orig_CBCentralManager_stopScan(self, _cmd); }
__attribute__((unused)) static void (*orig_CBCentralManager_connectPeripheral)(CBCentralManager*, SEL, CBPeripheral*, NSDictionary*);
__attribute__((unused)) static void override_CBCentralManager_connectPeripheral(CBCentralManager *self, SEL _cmd, CBPeripheral *peripheral, NSDictionary *options) {
    NSDictionary *profile = YHManager.shared.activeBleProfile; NSString *identifier = profile[@"identifier"] ?: profile[@"id"]; BOOL isFake = object_getClass((id)peripheral) == YHFakePeripheral.class; BOOL matchesActive = identifier.length && [peripheral.identifier.UUIDString isEqualToString:identifier];
    if (profile && (isFake || matchesActive)) {
        if ([peripheral respondsToSelector:@selector(setDelegate:)]) { ((void (*)(id, SEL, id))objc_msgSend)((id)peripheral, @selector(setDelegate:), self.delegate); }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ id delegate = self.delegate; if ([delegate respondsToSelector:@selector(centralManager:didConnectPeripheral:)]) { [delegate centralManager:self didConnectPeripheral:peripheral]; } }); return;
    }
    orig_CBCentralManager_connectPeripheral(self, _cmd, peripheral, options);
}

@interface CLLocation (YHHack) @end
@implementation CLLocation (YHHack)
- (CLLocationCoordinate2D)swizzled_coordinate { if (kGPSEnabled) { return kLocation; } return [self swizzled_coordinate]; }
@end

@interface YHProxy : NSProxy <CLLocationManagerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (weak, nonatomic, readonly) id delegate;
- (YHProxy*)initWithDelegate:(id)delegate locationManager:(CLLocationManager*)manager;
@end
@interface YHProxy()
@property (weak, nonatomic, readwrite) id delegate;
@property (weak, nonatomic) CLLocationManager *manager;
@end
@implementation YHProxy
- (YHProxy*)initWithDelegate:(id)delegate locationManager:(CLLocationManager*)manager { self.delegate = delegate; self.manager = manager; return self; }
- (void)forwardInvocation:(NSInvocation *)invocation {
    if ([NSStringFromSelector(invocation.selector) isEqualToString:@"locationManager:didUpdateLocations:"] || [NSStringFromSelector(invocation.selector) isEqualToString:@"locationProvider:didUpdateLocation:"]) { [invocation invokeWithTarget:self]; } else if ([NSStringFromSelector(invocation.selector) isEqualToString:@"imagePickerController:didFinishPickingMediaWithInfo:"]) { [invocation invokeWithTarget:self]; } else if ([self.delegate respondsToSelector:invocation.selector]) { [invocation invokeWithTarget:self.delegate]; }
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel { return [self.delegate methodSignatureForSelector:sel]; }
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations { if (kGPSEnabled) { CLLocation *loc = [[CLLocation alloc] initWithCoordinate:kLocation altitude:15.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]]; locations = @[loc]; } [self.delegate locationManager:manager didUpdateLocations:locations]; }
- (void)locationProvider:(id)provider didUpdateLocation:(CLLocation*)location { if (kGPSEnabled) { location = [[CLLocation alloc] initWithCoordinate:kLocation altitude:15.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]]; } [self.delegate locationProvider:provider didUpdateLocation:location]; }
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    NSMutableDictionary *mutInfo = [info mutableCopy];
    if (picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
        if (YHManager.shared.spoofImage) { mutInfo[UIImagePickerControllerOriginalImage] = YHManager.shared.spoofImage; mutInfo[UIImagePickerControllerEditedImage] = YHManager.shared.spoofImage; mutInfo[UIImagePickerControllerMediaType] = (NSString *)kUTTypeImage; [mutInfo removeObjectForKey:UIImagePickerControllerMediaURL]; [mutInfo removeObjectForKey:UIImagePickerControllerLivePhoto]; } else if (YHManager.shared.spoofVideoURL) { mutInfo[UIImagePickerControllerMediaURL] = YHManager.shared.spoofVideoURL; mutInfo[UIImagePickerControllerMediaType] = (NSString *)kUTTypeMovie; [mutInfo removeObjectForKey:UIImagePickerControllerOriginalImage]; [mutInfo removeObjectForKey:UIImagePickerControllerEditedImage]; [mutInfo removeObjectForKey:UIImagePickerControllerLivePhoto]; }
    }
    if ([self.delegate respondsToSelector:@selector(imagePickerController:didFinishPickingMediaWithInfo:)]) { [self.delegate imagePickerController:picker didFinishPickingMediaWithInfo:[mutInfo copy]]; }
}
@end

@implementation YHCamHook
+ (void)ret_002771 { static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ [self sub_00295112]; }); }
+ (void)sub_00295112 {
    Class stillClass = NSClassFromString(@"AVCaptureStillImageOutput");
    if (stillClass) {
        SEL originalSelector = @selector(captureStillImageAsynchronouslyFromConnection:completionHandler:);
        Method originalMethod = class_getInstanceMethod(stillClass, originalSelector);
        if (originalMethod) {
            IMP originalIMP = method_getImplementation(originalMethod);
            IMP newIMP = imp_implementationWithBlock(^(id self, AVCaptureConnection *connection, void (^handler)(CMSampleBufferRef, NSError*)) {
                if (YHManager.shared.spoofImage) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        NSData *imgData = UIImageJPEGRepresentation(YHManager.shared.spoofImage, 1.0); CMSampleBufferRef sampleBuffer = NULL; CMBlockBufferRef blockBuffer = NULL; CMSampleTimingInfo timingInfo = {CMTimeMake(0, 1), kCMTimeInvalid, kCMTimeInvalid};
                        OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, (void*)imgData.bytes, imgData.length, kCFAllocatorNull, NULL, 0, imgData.length, 0, &blockBuffer);
                        if (status == kCMBlockBufferNoErr) { CMFormatDescriptionRef format = NULL; CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCMVideoCodecType_JPEG, 0, 0, NULL, &format); CMSampleBufferCreate(kCFAllocatorDefault, blockBuffer, true, NULL, NULL, format, 1, 1, &timingInfo, 0, NULL, &sampleBuffer); CFRelease(format); }
                        handler(sampleBuffer, nil); if (sampleBuffer) CFRelease(sampleBuffer); if (blockBuffer) CFRelease(blockBuffer);
                    });
                } else { ((void (*)(id, SEL, AVCaptureConnection*, void (^)(CMSampleBufferRef, NSError*)))originalIMP)(self, originalSelector, connection, handler); }
            });
            method_setImplementation(originalMethod, newIMP);
        }
    }
}
@end

static NSUUID *(*orig_identifierForVendor)(id, SEL);
static NSUUID *my_identifierForVendor(id self, SEL _cmd) {
    if (YHManager.shared.isUDIDSpoofEnabled) {
        NSString *custom = [NSUserDefaults.standardUserDefaults stringForKey:kSaveKeyUDID];
        if (custom.length > 0) {
            NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:custom]; if (uuid) return uuid;
            NSString *clean = [[custom stringByReplacingOccurrencesOfString:@"-" withString:@""] uppercaseString]; clean = [clean stringByPaddingToLength:32 withString:@"0" startingAtIndex:0];
            NSString *formatted = [NSString stringWithFormat:@"%@-%@-%@-%@-%@", [clean substringWithRange:NSMakeRange(0,8)], [clean substringWithRange:NSMakeRange(8,4)], [clean substringWithRange:NSMakeRange(12,4)], [clean substringWithRange:NSMakeRange(16,4)], [clean substringWithRange:NSMakeRange(20,12)]];
            uuid = [[NSUUID alloc] initWithUUIDString:formatted]; if (uuid) return uuid;
        }
    }
    return orig_identifierForVendor(self, _cmd);
}

static CFTypeRef (*orig_MGCopyAnswer)(CFStringRef prop);
static CFTypeRef my_MGCopyAnswer(CFStringRef prop) {
    NSString *property = (__bridge NSString *)prop;
    if ([property isEqualToString:@"UniqueDeviceID"] && YHManager.shared.isUDIDSpoofEnabled) { NSString *custom = [NSUserDefaults.standardUserDefaults stringForKey:kSaveKeyUDID]; if (custom.length > 0) { return CFRetain((__bridge CFTypeRef)custom); } }
    return orig_MGCopyAnswer(prop);
}

static IMP orig_CLLocationManager_setDelegate_imp;
static IMP orig_CLLocationManager_location_imp;
static void (*orig_MKCoreLocationProvider_setDelegate)(id, SEL, id);
static CLLocation *(*orig_MKCoreLocationProvider_lastLocation)(id, SEL);
static void (*orig_GMSMyLocationProvider_setDelegate)(id, SEL, id);
static CLLocation *(*orig_GMSMyLocationProvider_lastLocation)(id, SEL);
static IMP orig_UIImagePickerController_setDelegate_imp;
static void override_CLLocationManager_setDelegate(CLLocationManager *self, SEL _cmd, id delegate) { YHProxy *delegateProxy = [[YHProxy alloc] initWithDelegate:delegate locationManager:self]; [retainer addObject:delegateProxy]; ((void (*)(id, SEL, id))orig_CLLocationManager_setDelegate_imp)(self, _cmd, delegateProxy); }
static CLLocation *override_CLLocationManager_location(CLLocationManager *self, SEL _cmd) { if (kGPSEnabled) { return [[CLLocation alloc] initWithCoordinate:kLocation altitude:15.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]]; } return ((CLLocation* (*)(id, SEL))orig_CLLocationManager_location_imp)(self, _cmd); }
static void override_MKCoreLocationProvider_setDelegate(id self, SEL _cmd, id delegate) { if (delegate && kGPSEnabled) { YHProxy *proxy = [[YHProxy alloc] initWithDelegate:delegate locationManager:nil]; @synchronized (retainer) { [retainer addObject:proxy]; } orig_MKCoreLocationProvider_setDelegate(self, _cmd, proxy); } else { orig_MKCoreLocationProvider_setDelegate(self, _cmd, delegate); } }
static CLLocation *override_MKCoreLocationProvider_lastLocation(id self, SEL _cmd) { if (kGPSEnabled) { return [[CLLocation alloc] initWithCoordinate:kLocation altitude:15.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]]; } return orig_MKCoreLocationProvider_lastLocation(self, _cmd); }
static void override_GMSMyLocationProvider_setDelegate(id self, SEL _cmd, id delegate) { if (delegate && kGPSEnabled) { YHProxy *proxy = [[YHProxy alloc] initWithDelegate:delegate locationManager:nil]; @synchronized (retainer) { [retainer addObject:proxy]; } orig_GMSMyLocationProvider_setDelegate(self, _cmd, proxy); } else { orig_GMSMyLocationProvider_setDelegate(self, _cmd, delegate); } }
static CLLocation *override_GMSMyLocationProvider_lastLocation(id self, SEL _cmd) { if (kGPSEnabled) { return [[CLLocation alloc] initWithCoordinate:kLocation altitude:15.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]]; } return orig_GMSMyLocationProvider_lastLocation(self, _cmd); }
static void override_UIImagePickerController_setDelegate(UIImagePickerController *self, SEL _cmd, id delegate) { if (delegate) { YHProxy *delegateProxy = [[YHProxy alloc] initWithDelegate:delegate locationManager:nil]; @synchronized (retainer) { [retainer addObject:delegateProxy]; } ((void (*)(id, SEL, id))orig_UIImagePickerController_setDelegate_imp)(self, _cmd, delegateProxy); } else { ((void (*)(id, SEL, id))orig_UIImagePickerController_setDelegate_imp)(self, _cmd, delegate); } }

@interface YHSpoofView : UIView <UIGestureRecognizerDelegate>
@property (nonatomic, strong) YHElectricBorderView *electricBorder;
@property (nonatomic, strong) UIButton *btnArrow;
@property (nonatomic, strong) UIButton *btnCheck;
@property (nonatomic, strong) UIButton *btnCross;
@property (nonatomic, strong) UIView *resizeHandle;
@property (nonatomic, assign) BOOL isLocked;
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
- (void)unlockView;
@end
@implementation YHSpoofView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark]; UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur]; blurView.frame = self.bounds; blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; blurView.layer.cornerRadius = 20; blurView.clipsToBounds = YES; if (@available(iOS 13.0, *)) { blurView.layer.cornerCurve = kCACornerCurveContinuous; } [self addSubview:blurView];
        self.layer.cornerRadius = 20; if (@available(iOS 13.0, *)) { self.layer.cornerCurve = kCACornerCurveContinuous; } self.clipsToBounds = NO;
        self.electricBorder = [[YHElectricBorderView alloc] initWithFrame:self.bounds cornerRadius:20]; [self addSubview:self.electricBorder];
        self.btnArrow = [UIButton buttonWithType:UIButtonTypeCustom]; [self.btnArrow addTarget:self action:@selector(arrowTapped) forControlEvents:UIControlEventTouchUpInside]; [self addSubview:self.btnArrow];
        CAShapeLayer *arrow = [CAShapeLayer layer]; UIBezierPath *path = [UIBezierPath bezierPath]; [path moveToPoint:CGPointMake(20, 0)]; [path addLineToPoint:CGPointMake(40, 20)]; [path addLineToPoint:CGPointMake(30, 20)]; [path addLineToPoint:CGPointMake(30, 40)]; [path addLineToPoint:CGPointMake(10, 40)]; [path addLineToPoint:CGPointMake(10, 20)]; [path addLineToPoint:CGPointMake(0, 20)]; [path closePath]; arrow.path = path.CGPath; arrow.fillColor = COL_ACTIVE.CGColor; [self.btnArrow.layer addSublayer:arrow];
        self.btnCheck = [UIButton buttonWithType:UIButtonTypeSystem]; [self.btnCheck setTitle:@"✅" forState:UIControlStateNormal]; self.btnCheck.titleLabel.font = [UIFont systemFontOfSize:18]; [self.btnCheck addTarget:self action:@selector(lockView) forControlEvents:UIControlEventTouchUpInside]; [self addSubview:self.btnCheck];
        self.btnCross = [UIButton buttonWithType:UIButtonTypeSystem]; [self.btnCross setTitle:@"❌" forState:UIControlStateNormal]; self.btnCross.titleLabel.font = [UIFont systemFontOfSize:18]; [self.btnCross addTarget:self action:@selector(closeView) forControlEvents:UIControlEventTouchUpInside]; [self addSubview:self.btnCross];
        self.resizeHandle = [[UIView alloc] init]; self.resizeHandle.backgroundColor = COL_ACTIVE; self.resizeHandle.layer.cornerRadius = 12.5; [self addSubview:self.resizeHandle];
        self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]; self.panGesture.delegate = self; [self addGestureRecognizer:self.panGesture];
        UIPanGestureRecognizer *resizePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleResize:)]; [self.resizeHandle addGestureRecognizer:resizePan];
        NSString *savedFrame = [NSUserDefaults.standardUserDefaults objectForKey:@"YHSpoofFrame"]; if (savedFrame) { self.frame = CGRectFromString(savedFrame); } [self.electricBorder startAnimation];
    }
    return self;
}
- (void)layoutSubviews { [super layoutSubviews]; self.electricBorder.frame = self.bounds; self.btnCheck.frame = CGRectMake(self.bounds.size.width - 35, 8, 28, 28); self.btnCross.frame = CGRectMake(self.bounds.size.width - 65, 8, 28, 28); self.btnArrow.frame = CGRectMake((self.bounds.size.width - 40) / 2, (self.bounds.size.height - 40) / 2, 40, 40); self.resizeHandle.frame = CGRectMake(self.bounds.size.width - 25, self.bounds.size.height - 25, 25, 25); }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch { if (gestureRecognizer == self.panGesture && !self.resizeHandle.isHidden) { CGPoint p = [touch locationInView:self]; CGRect handleRect = CGRectInset(self.resizeHandle.frame, -15, -15); if (CGRectContainsPoint(handleRect, p)) { return NO; } } return YES; }
- (void)handlePan:(UIPanGestureRecognizer *)gesture { if (self.isLocked) return; CGPoint translation = [gesture translationInView:self.superview]; self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y); [gesture setTranslation:CGPointZero inView:self.superview]; if (gesture.state == UIGestureRecognizerStateEnded) { [NSUserDefaults.standardUserDefaults setObject:NSStringFromCGRect(self.frame) forKey:@"YHSpoofFrame"]; } }
- (void)handleResize:(UIPanGestureRecognizer *)gesture { if (self.isLocked) return; CGPoint translation = [gesture translationInView:self.superview]; CGFloat newWidth = MAX(80, self.frame.size.width + translation.x); CGFloat newHeight = MAX(80, self.frame.size.height + translation.y); self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, newWidth, newHeight); [gesture setTranslation:CGPointZero inView:self.superview]; if (gesture.state == UIGestureRecognizerStateEnded) { [NSUserDefaults.standardUserDefaults setObject:NSStringFromCGRect(self.frame) forKey:@"YHSpoofFrame"]; } [self setNeedsLayout]; }
- (void)lockView { self.isLocked = YES; for (UIView *sub in self.subviews) { if ([sub isKindOfClass:[UIVisualEffectView class]]) { sub.hidden = YES; } } self.backgroundColor = [UIColor clearColor]; [self.electricBorder stopAnimation]; self.btnCheck.hidden = YES; self.btnCross.hidden = YES; self.resizeHandle.hidden = YES; }
- (void)closeView { self.hidden = YES; YHManager.shared.isEngineEnabled = NO; }
- (void)arrowTapped { [[NSNotificationCenter defaultCenter] postNotificationName:@"YHSpoofUIArrowTapped" object:nil]; }
- (void)unlockView { self.isLocked = NO; for (UIView *sub in self.subviews) { if ([sub isKindOfClass:[UIVisualEffectView class]]) { sub.hidden = NO; } } self.backgroundColor = [UIColor clearColor]; [self.electricBorder startAnimation]; self.btnCheck.hidden = NO; self.btnCross.hidden = NO; self.resizeHandle.hidden = NO; }
@end

@interface YHMenuVC : UIViewController <MKMapViewDelegate, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource, UIPickerViewDelegate, UIPickerViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate, CBCentralManagerDelegate>
- (void)showToast:(NSString*)msg;
@property (nonatomic, strong) YHElectricBorderView *mainElectricBorder;
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIButton *btnCloseKeyboard;
@property (nonatomic, strong) UITableView *resultsTable;
@property (nonatomic, strong) NSArray *searchResults;
@property (nonatomic, strong) UISwitch *swGPS;
@property (nonatomic, strong) UILabel *movementStatusLabel;
@property (nonatomic, strong) UITableView *savedLocationsTable;
@property (nonatomic, strong) UIView *tabsContainer;
@property (nonatomic, strong) NSMutableArray<UIButton *> *tabButtons;
@property (nonatomic, strong) UIView *locationView;
@property (nonatomic, strong) UIView *toolsView;
@property (nonatomic, strong) UIView *attendanceView;
@property (nonatomic, strong) UIView *scheduleView;
@property (nonatomic, strong) UIView *mapBottomPanel;
@property (nonatomic, strong) NSMutableArray *mapControlButtons;
@property (nonatomic, strong) UIScrollView *mainScroll;
@property (nonatomic, strong) UITableView *scheduleTable;
@property (nonatomic, strong) UIButton *btnAddSchedule;
@property (nonatomic, strong) UIDatePicker *datePicker;
@property (nonatomic, strong) UIPickerView *locationPicker;
@property (nonatomic, strong) UITextField *scheduleTitleField;
@property (nonatomic, strong) UILabel *lblSelectedMedia;
@property (nonatomic, strong) NSString *tempSelectedMediaPath;
@property (nonatomic, strong) UISwitch *repeatSwitch;
@property (nonatomic, strong) UIView *editScheduleView;
@property (nonatomic, assign) BOOL isEditingSchedule;
@property (nonatomic, assign) NSInteger editingIndex;
@property (nonatomic, strong) UIButton *btnLangEn;
@property (nonatomic, strong) UIButton *btnLangAr;
@property (nonatomic, assign) BOOL isPickingForSpoof;
@property (nonatomic, strong) UIButton *btnCloseMenuBottom;
@property (nonatomic, strong) UILabel *udidCurrentLabel;
@property (nonatomic, strong) UITextField *udidInputField;
@property (nonatomic, strong) UILabel *lblNextAlertTime;
@property (nonatomic, strong) UILabel *lblNextAlertTitle;
@property (nonatomic, strong) NSTimer *attendanceTimer;
@property (nonatomic, strong) UISwitch *swEngine;
@property (nonatomic, strong) UIView *btScannerView;
@property (nonatomic, strong) UITableView *btScannerTable;
@property (nonatomic, strong) UILabel *btScannerStatus;

@property (nonatomic, strong) CBCentralManager *activeCBManager;
@property (nonatomic, strong) NSMutableArray *scannedDevices;
@end
@implementation YHMenuVC
- (void)showToast:(NSString*)msg { UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(10, self.view.frame.size.height - 100, self.view.frame.size.width-20, 45)]; toast.backgroundColor = [COL_PANEL colorWithAlphaComponent:0.9]; toast.textColor = COL_ACTIVE; toast.textAlignment = NSTextAlignmentCenter; toast.text = msg; toast.layer.cornerRadius = 15; if (@available(iOS 13.0, *)) { toast.layer.cornerCurve = kCACornerCurveContinuous; } toast.layer.borderColor = COL_ACCENT.CGColor; toast.layer.borderWidth = 1.5; toast.layer.shadowColor = COL_ACCENT.CGColor; toast.layer.shadowOpacity = 0.5; toast.layer.shadowRadius = 10; toast.clipsToBounds = NO; toast.alpha = 0; [self.view addSubview:toast]; [UIView animateWithDuration:0.3 animations:^{ toast.alpha = 1; } completion:^(BOOL finished) { [UIView animateWithDuration:0.3 delay:2.0 options:0 animations:^{ toast.alpha = 0; } completion:^(BOOL f){ [toast removeFromSuperview]; }]; }]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.mapControlButtons = [NSMutableArray new]; self.tabButtons = [NSMutableArray new];
    [self setupUI];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(overrideDidChange) name:kOverrideDidChange object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uploadImageFromCameraRoll) name:@"YHSpoofUIArrowTapped" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(distanceDidChange:) name:kDistanceDidChange object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshUI) name:kLanguageDidChange object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleScheduleTriggered:) name:@"YHScheduleDidTrigger" object:nil];
}
- (void)overrideDidChange { [self.mapView removeAnnotations:self.mapView.annotations]; MKPointAnnotation *annotation = [MKPointAnnotation new]; annotation.coordinate = kBaseLocation; [self.mapView addAnnotation:annotation]; }
- (void)distanceDidChange:(NSNotification *)note { dispatch_async(dispatch_get_main_queue(), ^{ int meters = [note.object intValue]; NSString *status = (meters == 0) ? @"0m" : [NSString stringWithFormat:@"%dm", meters]; self.movementStatusLabel.text = [NSString stringWithFormat:@"%@ %@", [YHManager.shared localizedString:@"distance_txt"], status]; }); }
- (void)updateLanguageButtons { self.btnLangEn.backgroundColor = !kIsArabic ? [COL_ACTIVE colorWithAlphaComponent:0.2] : [UIColor clearColor]; [self.btnLangEn setTitleColor:!kIsArabic ? COL_ACTIVE : COL_SUBTEXT forState:UIControlStateNormal]; self.btnLangAr.backgroundColor = kIsArabic ? [COL_ACTIVE colorWithAlphaComponent:0.2] : [UIColor clearColor]; [self.btnLangAr setTitleColor:kIsArabic ? COL_ACTIVE : COL_SUBTEXT forState:UIControlStateNormal]; }
- (void)switchToEnglish { if (![YHManager.shared.language isEqualToString:@"en"]) [YHManager.shared setLanguageTo:@"en"]; [self updateLanguageButtons]; }
- (void)switchToArabic { if (![YHManager.shared.language isEqualToString:@"ar"]) [YHManager.shared setLanguageTo:@"ar"]; [self updateLanguageButtons]; }
- (void)refreshUI { [self.view.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)]; self.mapControlButtons = [NSMutableArray new]; self.tabButtons = [NSMutableArray new]; [self setupUI]; }
- (void)toggleMenuVisibility {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"YHCloseMenuTapped" object:nil];
}
- (void)setupUI {
    self.view.backgroundColor = COL_BG;
    
    CGFloat screenW = UIScreen.mainScreen.bounds.size.width;
    CGFloat screenH = UIScreen.mainScreen.bounds.size.height;
    CGFloat topPadding = 50;
    
    [self setupBluetoothScanner]; // Initialize scanner view

    self.mainElectricBorder = [[YHElectricBorderView alloc] initWithFrame:self.view.bounds cornerRadius:0];
    [self.view addSubview:self.mainElectricBorder];
    if (kGPSEnabled || YHManager.shared.isEngineEnabled) { [self.mainElectricBorder startAnimation]; }

    // Header - Matched to Image
    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(0, topPadding, screenW, 30)];
    header.text = @"GPS Plus";
    header.textColor = [UIColor whiteColor];
    header.textAlignment = NSTextAlignmentCenter;
    header.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    [self.view addSubview:header];

    UIButton *keyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    keyBtn.frame = CGRectMake(15, topPadding, 30, 30);
    [keyBtn setTitle:@"🔑" forState:UIControlStateNormal];
    [keyBtn addTarget:self action:@selector(showActivationAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:keyBtn];

    UIButton *xClose = [UIButton buttonWithType:UIButtonTypeSystem];
    xClose.frame = CGRectMake(screenW - 45, topPadding, 30, 30);
    [xClose setTitle:@"✕" forState:UIControlStateNormal];
    [xClose setTitleColor:[UIColor colorWithRed:0.4 green:0.5 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    xClose.titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightMedium];
    [xClose addTarget:self action:@selector(closeMenuAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:xClose];

    // Scroll View
    self.mainScroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, topPadding + 40, screenW, screenH - (topPadding + 40))];
    self.mainScroll.contentSize = CGSizeMake(screenW, 1100);
    self.mainScroll.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.mainScroll];

    // Map Section
    UIView *mapContainer = [[UIView alloc] initWithFrame:CGRectMake(15, 10, screenW - 30, 250)];
    mapContainer.backgroundColor = COL_PANEL;
    mapContainer.layer.cornerRadius = 20;
    mapContainer.clipsToBounds = YES;
    [self.mainScroll addSubview:mapContainer];

    self.mapView = [[MKMapView alloc] initWithFrame:mapContainer.bounds];
    self.mapView.delegate = self;
    self.mapView.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    [mapContainer addSubview:self.mapView];
    
    // إضافة دبوس عند النقر الطويل
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(mapLongPress:)];
    [self.mapView addGestureRecognizer:lp];
    
    // زر تحديد الموقع الحالي (سهم)
    UIButton *btnLocate = [UIButton buttonWithType:UIButtonTypeSystem];
    btnLocate.frame = CGRectMake(mapContainer.bounds.size.width - 50, mapContainer.bounds.size.height - 50, 40, 40);
    btnLocate.backgroundColor = [COL_PANEL colorWithAlphaComponent:0.8];
    btnLocate.layer.cornerRadius = 20;
    [btnLocate setTitle:@"🎯" forState:UIControlStateNormal];
    [btnLocate addTarget:self action:@selector(centerOnLocation) forControlEvents:UIControlEventTouchUpInside];
    [mapContainer addSubview:btnLocate];

    UISegmentedControl *mapType = [[UISegmentedControl alloc] initWithItems:@[@"خريطة", @"قمر صناعي"]];
    mapType.frame = CGRectMake(10, 10, screenW - 50, 35);
    mapType.selectedSegmentIndex = 0;
    mapType.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    [mapType addTarget:self action:@selector(mapTypeChanged:) forControlEvents:UIControlEventValueChanged];
    [mapContainer addSubview:mapType];

    // Tool Buttons Grid - Matched to Image
    CGFloat margin = 15;
    CGFloat btnH = 55;
    
    UILabel *toolsHeader = [[UILabel alloc] initWithFrame:CGRectMake(margin, 270, screenW - 30, 30)];
    toolsHeader.text = @"الأدوات والمميزات 🛠️";
    toolsHeader.textColor = [UIColor whiteColor];
    toolsHeader.font = [UIFont boldSystemFontOfSize:18];
    toolsHeader.textAlignment = kIsArabic ? NSTextAlignmentRight : NSTextAlignmentLeft;
    [self.mainScroll addSubview:toolsHeader];
    
    // Row 1: 2 buttons (Search, Favorites)
    CGFloat btnW1 = (screenW - (margin * 3)) / 2;
    CGFloat gridY = 310;
    NSArray *toolsRow1 = @[
        @{@"t": @"بحث 🔍", @"a": @"showSearch"},
        @{@"t": @"المفضلة ⭐", @"a": @"showSavedLocationsList"}
    ];
    for (int i = 0; i < toolsRow1.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(margin + i * (btnW1 + margin), gridY, btnW1, btnH);
        btn.backgroundColor = COL_PANEL;
        btn.layer.cornerRadius = 12;
        btn.layer.borderWidth = 1.0;
        btn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
        [btn setTitle:toolsRow1[i][@"t"] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
        [btn addTarget:self action:NSSelectorFromString(toolsRow1[i][@"a"]) forControlEvents:UIControlEventTouchUpInside];
        [self.mainScroll addSubview:btn];
        [self.tabButtons addObject:btn];
    }
    
    // Row 2: 3 buttons (Hide Tool, UDID, Bluetooth)
    CGFloat btnW2 = (screenW - (margin * 4)) / 3;
    NSArray *toolsRow2 = @[
        @{@"t": @"إخفاء الأداة 👁️‍🗨️", @"a": @"hideToolAction"},
        @{@"t": @"المعرف", @"a": @"showUDIDAction"},
        @{@"t": @"بلوتوث 🛰️", @"a": @"showBluetoothMenu"}
    ];
    for (int i = 0; i < toolsRow2.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(margin + i * (btnW2 + margin), gridY + btnH + margin, btnW2, btnH);
        btn.backgroundColor = COL_PANEL;
        btn.layer.cornerRadius = 12;
        btn.layer.borderWidth = 1.0;
        
        BOOL isActive = NO;
        if (i == 1) isActive = YHManager.shared.isUDIDSpoofEnabled;
        if (i == 2) isActive = YHManager.shared.isBluetoothSpoofEnabled;
        
        btn.layer.borderColor = (isActive ? [UIColor greenColor] : [UIColor colorWithWhite:1.0 alpha:0.2]).CGColor;
        [btn setTitle:toolsRow2[i][@"t"] forState:UIControlStateNormal];
        [btn setTitleColor:(isActive ? [UIColor greenColor] : [UIColor whiteColor]) forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        [btn addTarget:self action:NSSelectorFromString(toolsRow2[i][@"a"]) forControlEvents:UIControlEventTouchUpInside];
        [self.mainScroll addSubview:btn];
        [self.tabButtons addObject:btn];
    }

    // Switches Section
    UILabel *settingsHeader = [[UILabel alloc] initWithFrame:CGRectMake(margin, gridY + (btnH + margin) * 2 + 10, screenW - 30, 30)];
    settingsHeader.text = @"إعدادات التحكم ⚙️";
    settingsHeader.textColor = [UIColor whiteColor];
    settingsHeader.font = [UIFont boldSystemFontOfSize:18];
    settingsHeader.textAlignment = kIsArabic ? NSTextAlignmentRight : NSTextAlignmentLeft;
    [self.mainScroll addSubview:settingsHeader];

    UIView *switchesPanel = [[UIView alloc] initWithFrame:CGRectMake(margin, settingsHeader.frame.origin.y + 40, screenW - (margin * 2), 400)];
    switchesPanel.backgroundColor = [UIColor clearColor];
    [self.mainScroll addSubview:switchesPanel];

    NSArray *swLabels = @[
        @"تفعيل دائم ∞",
        @"تنبيه قبل انتهاء الاشتراك 🔔",
        @"تفعيل الحركة (10 أمتار)",
        @"تزييف التصوير 📷",
        @"تفعيل بالجدولة ⏰"
    ];

    for (int i = 0; i < swLabels.count; i++) {
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(kIsArabic ? 10 : 70, i * 60, 260, 30)];
        lbl.text = swLabels[i];
        lbl.textColor = [UIColor whiteColor];
        lbl.textAlignment = kIsArabic ? NSTextAlignmentRight : NSTextAlignmentLeft;
        lbl.font = [UIFont systemFontOfSize:17];
        [switchesPanel addSubview:lbl];

        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(kIsArabic ? 280 : 10, i * 60, 50, 30)];
        sw.onTintColor = [UIColor greenColor];
        [switchesPanel addSubview:sw];
        if (i == 0) { [sw setOn:kGPSEnabled]; [sw addTarget:self action:@selector(toggleGPS:) forControlEvents:UIControlEventValueChanged]; self.swGPS = sw; }
        if (i == 2) { [sw setOn:YHManager.shared.isJitterEnabled]; [sw addTarget:self action:@selector(toggleJitter:) forControlEvents:UIControlEventValueChanged]; }
        if (i == 3) { [sw setOn:YHManager.shared.isEngineEnabled]; [sw addTarget:self action:@selector(toggleEngine:) forControlEvents:UIControlEventValueChanged]; }
        if (i == 4) { [sw setOn:YES]; [sw addTarget:self action:@selector(toggleSchedule:) forControlEvents:UIControlEventValueChanged]; }
    }

    // Bottom Action Button (Centered)
    UIButton *selectLocBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    selectLocBtn.frame = CGRectMake((screenW - 340)/2, 800, 340, 55);
    selectLocBtn.backgroundColor = COL_ACTIVE;
    selectLocBtn.layer.cornerRadius = 15;
    [selectLocBtn setTitle:@"اختر هذا الموقع" forState:UIControlStateNormal];
    [selectLocBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    selectLocBtn.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    [selectLocBtn addTarget:self action:@selector(saveCurrentLocation) forControlEvents:UIControlEventTouchUpInside];
    [self.mainScroll addSubview:selectLocBtn];
    
    // Subscription Info Section
    UIView *subPanel = [[UIView alloc] initWithFrame:CGRectMake(margin, 870, screenW - (margin * 2), 100)];
    subPanel.backgroundColor = [COL_PANEL colorWithAlphaComponent:0.5];
    subPanel.layer.cornerRadius = 20;
    subPanel.layer.borderWidth = 1;
    subPanel.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.1].CGColor;
    [self.mainScroll addSubview:subPanel];
    
    UILabel *subTitle = [[UILabel alloc] initWithFrame:CGRectMake(10, 15, subPanel.frame.size.width - 20, 20)];
    subTitle.text = @"معلومات الاشتراك 🛡️";
    subTitle.textColor = COL_TEXT;
    subTitle.font = [UIFont boldSystemFontOfSize:16];
    subTitle.textAlignment = kIsArabic ? NSTextAlignmentRight : NSTextAlignmentLeft;
    [subPanel addSubview:subTitle];
    
    NSString *expiry = [[NSUserDefaults standardUserDefaults] stringForKey:@"WF_ExpiryDate"] ?: @"غير متوفر";
    UILabel *subExpiry = [[UILabel alloc] initWithFrame:CGRectMake(10, 45, subPanel.frame.size.width - 20, 20)];
    subExpiry.text = [NSString stringWithFormat:@"ينتهي في: %@", expiry];
    subExpiry.textColor = COL_SUBTEXT;
    subExpiry.font = [UIFont systemFontOfSize:14];
    subExpiry.textAlignment = kIsArabic ? NSTextAlignmentRight : NSTextAlignmentLeft;
    [subPanel addSubview:subExpiry];
    
}
- (void)mapTypeChanged:(UISegmentedControl *)sender {
    self.mapView.mapType = (sender.selectedSegmentIndex == 0) ? MKMapTypeStandard : MKMapTypeSatellite;
}
- (void)showSearch {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"البحث عن موقع" message:@"أدخل اسم المكان أو الإحداثيات من Google/Apple Maps" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) { 
        textField.placeholder = @"مثال: 25.1972, 55.2744"; 
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"توجيه / بحث" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *query = alert.textFields[0].text;
        if (query.length > 0) {
            // تنظيف النص من المسافات والأقواس
            NSString *cleanQuery = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            cleanQuery = [cleanQuery stringByReplacingOccurrencesOfString:@"(" withString:@""];
            cleanQuery = [cleanQuery stringByReplacingOccurrencesOfString:@")" withString:@""];
            
            // التحقق إذا كانت إحداثيات (دعم الفاصلة والمسافة)
            NSArray *parts = [cleanQuery componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@", "]];
            NSMutableArray *validParts = [NSMutableArray new];
            for (NSString *p in parts) { if (p.length > 0) [validParts addObject:p]; }
            
            if (validParts.count >= 2) {
                double lat = [validParts[0] doubleValue];
                double lng = [validParts[1] doubleValue];
                if (fabs(lat) > 0.1 && fabs(lng) > 0.1) {
                    [self processCoordinateSelection:lat lng:lng];
                    return;
                }
            }
            [self performSearch:query];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)performSearch:(NSString *)query {
    MKLocalSearchRequest *request = [[MKLocalSearchRequest alloc] init];
    request.naturalLanguageQuery = query;
    request.region = self.mapView.region;
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request];
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        if (response.mapItems.count > 0) {
            MKMapItem *item = response.mapItems.firstObject;
            [self processCoordinateSelection:item.placemark.coordinate.latitude lng:item.placemark.coordinate.longitude];
        }
    }];
}
- (void)hideToolAction {
    UIView *hideView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];
    hideView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.95];
    hideView.layer.cornerRadius = 20;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, 300, 30)];
    titleLabel.text = @"إظهار زر الأداة";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [hideView addSubview:titleLabel];
    
    UILabel *msgLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, 260, 60)];
    msgLabel.text = @"يرجى اختيار عدد النقرات اللازمة لإظهار زر الأداة مرة أخرى";
    msgLabel.textColor = [UIColor whiteColor];
    msgLabel.textAlignment = NSTextAlignmentCenter;
    msgLabel.numberOfLines = 0;
    msgLabel.font = [UIFont systemFontOfSize:14];
    [hideView addSubview:msgLabel];
    
    UIPickerView *picker = [[UIPickerView alloc] initWithFrame:CGRectMake(20, 120, 260, 80)];
    // إعدادات البيكر لعدد النقرات
    [hideView addSubview:picker];
    
    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelBtn.frame = CGRectMake(20, 220, 125, 50);
    cancelBtn.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    cancelBtn.layer.cornerRadius = 10;
    [cancelBtn setTitle:@"إلغاء" forState:UIControlStateNormal];
    [cancelBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [cancelBtn addTarget:self action:@selector(dismissPopUp:) forControlEvents:UIControlEventTouchUpInside];
    [hideView addSubview:cancelBtn];
    
    UIButton *confirmBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    confirmBtn.frame = CGRectMake(155, 220, 125, 50);
    confirmBtn.backgroundColor = [UIColor systemGreenColor];
    confirmBtn.layer.cornerRadius = 10;
    [confirmBtn setTitle:@"تأكيد" forState:UIControlStateNormal];
    [confirmBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [confirmBtn addTarget:self action:@selector(confirmHideAction) forControlEvents:UIControlEventTouchUpInside];
    [hideView addSubview:confirmBtn];
    
    [self showCustomPopUp:hideView];
}

- (void)confirmHideAction {
    self.view.hidden = YES;
    [self showToast:@"تم إخفاء الأداة"];
    [self dismissPopUp:nil];
}

- (void)showBluetoothMenu {
    UIView *btView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 450)];
    btView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.95];
    btView.layer.cornerRadius = 20;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, 300, 60)];
    titleLabel.text = @"📡 نظام نسخ وتزييف\nالبلوتوث GPSPlus";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 0;
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [btView addSubview:titleLabel];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(260, 15, 30, 30);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(dismissPopUp:) forControlEvents:UIControlEventTouchUpInside];
    [btView addSubview:closeBtn];
    
    UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 90, 260, 60)];
    NSString *status = YHManager.shared.isBluetoothSpoofEnabled ? @"متصل 🟢" : @"متوقف 🔴 (لا يوجد تزييف)";
    statusLabel.text = [NSString stringWithFormat:@"الحالة: %@\nالوضع: 🛰️ أولوية المنطقة (وضع عادي)", status];
    statusLabel.textColor = [UIColor whiteColor];
    statusLabel.textAlignment = NSTextAlignmentRight;
    statusLabel.numberOfLines = 0;
    statusLabel.font = [UIFont systemFontOfSize:14];
    [btView addSubview:statusLabel];
    
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(20, 155, 260, 1)];
    sep.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    [btView addSubview:sep];
    
    UILabel *msgLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 165, 260, 60)];
    msgLabel.text = @"⚠️ لا يوجد جهاز محفوظ حالياً.\n\n👈 اضغط 'استجلاب البلوتوث المتصل حالياً'";
    msgLabel.textColor = [UIColor systemYellowColor];
    msgLabel.textAlignment = NSTextAlignmentCenter;
    msgLabel.numberOfLines = 0;
    msgLabel.font = [UIFont systemFontOfSize:13];
    [btView addSubview:msgLabel];
    
    NSArray *btns = @[@"⚙️ تحويل إلى: الوضع اليدوي", @"📥 استجلاب البلوتوث المتصل حالياً", @"🌐 استيراد شبكة محفوظة", @"إغلاق"];
    for (int i=0; i<4; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(0, 230 + (i*50), 300, 50);
        [btn setTitle:btns[i] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
        if (i == 3) [btn addTarget:self action:@selector(dismissPopUp:) forControlEvents:UIControlEventTouchUpInside];
        if (i == 1) [btn addTarget:self action:@selector(showBluetoothScanner) forControlEvents:UIControlEventTouchUpInside];
        [btView addSubview:btn];
        
        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 0.5)];
        line.backgroundColor = [UIColor colorWithWhite:0.3 alpha:0.5];
        [btn addSubview:line];
    }
    
    [self showCustomPopUp:btView];
}
- (void)showUDIDAction {
    UIView *udidView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 410)];
    udidView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.95];
    udidView.layer.cornerRadius = 20;
    udidView.layer.borderWidth = 1;
    udidView.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1.0].CGColor;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, 300, 30)];
    titleLabel.text = @"إعدادات المعرف";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [udidView addSubview:titleLabel];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(260, 15, 30, 30);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(dismissPopUp:) forControlEvents:UIControlEventTouchUpInside];
    [udidView addSubview:closeBtn];
    
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(20, 60, 260, 1)];
    sep.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    [udidView addSubview:sep];
    
    UILabel *manualLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, 260, 30)];
    manualLabel.text = @"تفعيل المعرّف يدوي";
    manualLabel.textColor = [UIColor whiteColor];
    manualLabel.textAlignment = NSTextAlignmentRight;
    [udidView addSubview:manualLabel];
    
    UISwitch *udidSw = [[UISwitch alloc] initWithFrame:CGRectMake(20, 80, 50, 30)];
    [udidSw setOn:YHManager.shared.isUDIDSpoofEnabled];
    [udidSw setOnTintColor:[UIColor systemGreenColor]];
    [udidSw addTarget:self action:@selector(toggleUDIDSw:) forControlEvents:UIControlEventValueChanged];
    [udidView addSubview:udidSw];
    
    UITextField *input = [[UITextField alloc] initWithFrame:CGRectMake(20, 120, 260, 45)];
    input.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1.0];
    input.layer.cornerRadius = 10;
    input.textColor = [UIColor whiteColor];
    input.textAlignment = NSTextAlignmentCenter;
    input.placeholder = @"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";
    NSString *saved = [NSUserDefaults.standardUserDefaults stringForKey:@"YH_Custom_UDID"];
    input.text = saved;
    [udidView addSubview:input];
    
    UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    saveBtn.frame = CGRectMake(20, 180, 260, 50);
    saveBtn.backgroundColor = [UIColor systemGreenColor];
    saveBtn.layer.cornerRadius = 10;
    [saveBtn setTitle:@"حفظ" forState:UIControlStateNormal];
    [saveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    saveBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [saveBtn addTarget:self action:@selector(saveUDIDAction:) forControlEvents:UIControlEventTouchUpInside];
    [udidView addSubview:saveBtn];
    
    UIButton *importBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    importBtn.frame = CGRectMake(20, 245, 125, 45);
    importBtn.backgroundColor = [UIColor systemBlueColor];
    importBtn.layer.cornerRadius = 10;
    [importBtn setTitle:@"استيراد" forState:UIControlStateNormal];
    [importBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [udidView addSubview:importBtn];
    
    UIButton *exportBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    exportBtn.frame = CGRectMake(155, 245, 125, 45);
    exportBtn.backgroundColor = [UIColor systemBlueColor];
    exportBtn.layer.cornerRadius = 10;
    [exportBtn setTitle:@"تصدير" forState:UIControlStateNormal];
    [exportBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [udidView addSubview:exportBtn];
    
    UIButton *autoBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    autoBtn.frame = CGRectMake(20, 305, 260, 40);
    autoBtn.backgroundColor = [UIColor systemRedColor];
    autoBtn.layer.cornerRadius = 10;
    [autoBtn setTitle:@"معطّل التزييف التلقائي من الاستيراد" forState:UIControlStateNormal];
    [autoBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [udidView addSubview:autoBtn];
    
    UIButton *resetBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    resetBtn.frame = CGRectMake(20, 355, 260, 40);
    resetBtn.backgroundColor = [UIColor systemRedColor];
    resetBtn.layer.cornerRadius = 10;
    [resetBtn setTitle:@"إعادة تعيين" forState:UIControlStateNormal];
    [resetBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [resetBtn addTarget:self action:@selector(resetUDIDConfirm) forControlEvents:UIControlEventTouchUpInside];
    [udidView addSubview:resetBtn];
    
    [self showCustomPopUp:udidView];
}

- (void)toggleUDIDSw:(UISwitch *)sw {
    YHManager.shared.isUDIDSpoofEnabled = sw.isOn;
    [self showToast:sw.isOn ? @"تم تفعيل المعرف" : @"تم تعطيل المعرف"];
    [self updateButtonsUI];
}

- (void)saveUDIDAction:(UIButton *)btn {
    UIView *pop = btn.superview;
    UITextField *tf = nil;
    for (UIView *v in pop.subviews) { if ([v isKindOfClass:[UITextField class]]) tf = (UITextField *)v; }
    if (tf && tf.text.length > 0) {
        [NSUserDefaults.standardUserDefaults setObject:tf.text forKey:@"YH_Custom_UDID"];
        YHManager.shared.isUDIDSpoofEnabled = YES;
        [self showToast:@"تم حفظ المعرف بنجاح"];
        [self updateButtonsUI];
    }
}

- (void)resetUDIDConfirm {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"إعادة تعيين" message:@"إذا لم تكن متأكداً من وظيفة هذا الخيار، يُرجى عدم استخدامه.\n\nسيتم حذف جميع المعرّفات المخزّنة وسيقوم التطبيق بتوليد معرّف جديد." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"أدرك ذلك، متابعة" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [NSUserDefaults.standardUserDefaults setBool:NO forKey:@"YH_UDID_Enabled"];
        [NSUserDefaults.standardUserDefaults setObject:@"" forKey:@"YH_Custom_UDID"];
        YHManager.shared.isUDIDSpoofEnabled = NO;
        [self showToast:@"تمت استعادة المعرف الأصلي"];
        [self updateButtonsUI];
        [self dismissPopUp:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showCustomPopUp:(UIView *)view {
    UIView *bg = [[UIView alloc] initWithFrame:self.view.bounds];
    bg.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    bg.tag = 9988;
    
    view.center = bg.center;
    [bg addSubview:view];
    
    [self.view addSubview:bg];
    bg.alpha = 0;
    [UIView animateWithDuration:0.3 animations:^{ bg.alpha = 1; }];
}

- (void)dismissPopUp:(UIButton *)btn {
    UIView *bg = [self.view viewWithTag:9988];
    if (bg) {
        [UIView animateWithDuration:0.3 animations:^{ bg.alpha = 0; } completion:^(BOOL finished) { [bg removeFromSuperview]; }];
    }
}
- (void)toggleJitter:(UISwitch *)sender {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"WF_IsActivated"]) { [sender setOn:NO animated:YES]; [WFCodeEntryViewController showActivationWithCompletion:nil]; return; }
    YHManager.shared.isJitterEnabled = sender.isOn;
    [self showToast:sender.isOn ? @"تم تفعيل الحركة" : @"تم تعطيل الحركة"];
}
- (void)toggleSchedule:(UISwitch *)sender {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"WF_IsActivated"]) { [sender setOn:NO animated:YES]; [WFCodeEntryViewController showActivationWithCompletion:nil]; return; }
    [self showToast:sender.isOn ? @"تم تفعيل الجدولة" : @"تم تعطيل الجدولة"];
}
- (void)updateAttendanceCountdown {
    NSDate *now = [NSDate date]; NSDate *closestDate = nil; NSString *closestTitle = @"";
    for (YHScheduleItem *item in kScheduleItems) {
        if (!item.enabled) continue; NSDate *itemNextDate = item.targetDate;
        if (item.repeatWeekly) { while ([itemNextDate timeIntervalSinceDate:now] < -60) { itemNextDate = [itemNextDate dateByAddingTimeInterval:604800]; } } else { if ([itemNextDate timeIntervalSinceDate:now] < -60) continue; }
        if (!closestDate || [itemNextDate timeIntervalSinceDate:closestDate] < 0) { closestDate = itemNextDate; closestTitle = item.title.length > 0 ? item.title : [YHManager.shared localizedString:@"new_alert"]; }
    }
    if (closestDate) {
        NSTimeInterval diff = [closestDate timeIntervalSinceDate:now]; if (diff < 0) diff = 0;
        int d = (int)(diff / 86400); int h = (int)((diff - (d * 86400)) / 3600); int m = (int)((diff - (d * 86400) - (h * 3600)) / 60); int s = (int)diff % 60;
        if (d > 0) { NSString *dayStr = kIsArabic ? @"يوم و" : @"d"; self.lblNextAlertTime.text = [NSString stringWithFormat:@"%d %@ %02d:%02d:%02d", d, dayStr, h, m, s]; } else { self.lblNextAlertTime.text = [NSString stringWithFormat:@"%02d:%02d:%02d", h, m, s]; }
        self.lblNextAlertTitle.text = closestTitle;
    } else { self.lblNextAlertTime.text = @"00:00:00"; self.lblNextAlertTitle.text = [YHManager.shared localizedString:@"no_upcoming_alerts"]; }
}
- (void)handleScheduleTriggered:(NSNotification *)note {
    NSString *scheduleName = note.object;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:scheduleName message:[YHManager.shared localizedString:@"alert_title"] preferredStyle:UIAlertControllerStyleAlert]; [alert addAction:[UIAlertAction actionWithTitle:[YHManager.shared localizedString:@"ok"] style:UIAlertActionStyleDefault handler:nil]]; [self presentViewController:alert animated:YES completion:nil];
}
- (void)setupToolsTab { }
- (void)toggleEngine:(UISwitch *)sw { 
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"WF_IsActivated"]) { [sw setOn:NO animated:YES]; [WFCodeEntryViewController showActivationWithCompletion:nil]; return; }
    YHManager.shared.isEngineEnabled = sw.isOn; 
    [self updateElectricBorderState]; 
    if (sw.isOn) {
        [self uploadImageFromCameraRoll];
    }
}
- (void)actionRandomUDID { self.udidInputField.text = [YHManager.shared generateRandomUDID]; }
- (void)actionActivateUDID { if (self.udidInputField.text.length > 0) { [NSUserDefaults.standardUserDefaults setObject:self.udidInputField.text forKey:kSaveKeyUDID]; YHManager.shared.isUDIDSpoofEnabled = YES; self.udidCurrentLabel.text = self.udidInputField.text; [self showToast:[YHManager.shared localizedString:@"udid_activated"]]; [self updateButtonsUI]; } }
- (void)actionRestoreUDID { YHManager.shared.isUDIDSpoofEnabled = NO; [NSUserDefaults.standardUserDefaults setObject:@"" forKey:kSaveKeyUDID]; self.udidInputField.text = @""; CFTypeRef rawUDID = NULL; void *handle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_GLOBAL | RTLD_LAZY); if (handle) { CFTypeRef (*mgCopyAnswer)(CFStringRef) = (CFTypeRef (*)(CFStringRef))dlsym(handle, "MGCopyAnswer"); if (mgCopyAnswer) { rawUDID = mgCopyAnswer((__bridge CFStringRef)@"UniqueDeviceID"); } } if (rawUDID) { self.udidCurrentLabel.text = (__bridge NSString *)rawUDID; CFRelease(rawUDID); } else { self.udidCurrentLabel.text = [[[UIDevice currentDevice] identifierForVendor] UUIDString]; } [self showToast:[YHManager.shared localizedString:@"udid_restored"]]; [self updateButtonsUI]; }
- (void)setupScheduleTab { }
- (void)setupScheduleEditor {
    self.editScheduleView = [[UIView alloc] initWithFrame:CGRectMake(10, 50, 340, 580)]; self.editScheduleView.backgroundColor = [UIColor clearColor]; UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]; UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur]; blurView.frame = self.editScheduleView.bounds; blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; blurView.layer.cornerRadius = 25; blurView.clipsToBounds = YES; if (@available(iOS 13.0, *)) { blurView.layer.cornerCurve = kCACornerCurveContinuous; } [self.editScheduleView addSubview:blurView]; self.editScheduleView.layer.cornerRadius = 25; if (@available(iOS 13.0, *)) { self.editScheduleView.layer.cornerCurve = kCACornerCurveContinuous; } self.editScheduleView.layer.borderColor = COL_ACCENT.CGColor; self.editScheduleView.layer.borderWidth = 1.5; self.editScheduleView.hidden = YES; [self.view bringSubviewToFront:self.editScheduleView]; [self.view addSubview:self.editScheduleView];
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.editScheduleView.bounds]; scrollView.contentSize = CGSizeMake(340, 700); [self.editScheduleView addSubview:scrollView];
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeSystem]; backBtn.frame = CGRectMake(kIsArabic ? 270 : 10, 15, 60, 30); [backBtn setTitle:[YHManager.shared localizedString:@"back"] forState:UIControlStateNormal]; [backBtn setTitleColor:COL_RED forState:UIControlStateNormal]; backBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14]; [backBtn addTarget:self action:@selector(hideScheduleEditor) forControlEvents:UIControlEventTouchUpInside]; [scrollView addSubview:backBtn];
    UILabel *lblT = [[UILabel alloc] initWithFrame:CGRectMake(15, 50, 310, 20)]; lblT.text = [YHManager.shared localizedString:@"sched_time"]; lblT.textColor = COL_ACCENT; lblT.font = [UIFont boldSystemFontOfSize:14]; lblT.textAlignment = kIsArabic ? NSTextAlignmentRight : NSTextAlignmentLeft; [scrollView addSubview:lblT];
    self.datePicker = [[UIDatePicker alloc] initWithFrame:CGRectMake(15, 80, 310, 140)]; self.datePicker.datePickerMode = UIDatePickerModeDateAndTime; self.datePicker.locale = [[NSLocale alloc] initWithLocaleIdentifier:kIsArabic ? @"ar" : @"en"]; if (@available(iOS 13.4, *)) { self.datePicker.preferredDatePickerStyle = UIDatePickerStyleWheels; } self.datePicker.backgroundColor = COL_PANEL; self.datePicker.layer.cornerRadius = 15; self.datePicker.clipsToBounds = YES; self.datePicker.tintColor = COL_ACCENT; [self.datePicker setValue:COL_TEXT forKey:@"textColor"]; [scrollView addSubview:self.datePicker];
    UIView *repeatPanel = [[UIView alloc] initWithFrame:CGRectMake(15, 230, 310, 50)]; repeatPanel.backgroundColor = COL_PANEL; repeatPanel.layer.cornerRadius = 12; [scrollView addSubview:repeatPanel]; UILabel *repeatLabel = [[UILabel alloc] initWithFrame:CGRectMake(kIsArabic ? 115 : 15, 5, 180, 40)]; repeatLabel.text = [YHManager.shared localizedString:@"repeat_weekly"]; repeatLabel.textColor = COL_TEXT; repeatLabel.textAlignment = kIsArabic ? NSTextAlignmentRight : NSTextAlignmentLeft; [repeatPanel addSubview:repeatLabel]; self.repeatSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(kIsArabic ? 15 : 245, 10, 50, 30)]; [self.repeatSwitch setOnTintColor:COL_ACTIVE]; [repeatPanel addSubview:self.repeatSwitch];
    UILabel *lblL = [[UILabel alloc] initWithFrame:CGRectMake(15, 290, 310, 20)]; lblL.text = [YHManager.shared localizedString:@"link_location"]; lblL.textColor = COL_ACCENT; lblL.font = [UIFont boldSystemFontOfSize:14]; lblL.textAlignment = kIsArabic ? NSTextAlignmentRight : NSTextAlignmentLeft; [scrollView addSubview:lblL];
    self.locationPicker = [[UIPickerView alloc] initWithFrame:CGRectMake(15, 315, 310, 80)]; self.locationPicker.delegate = self; self.locationPicker.dataSource = self; self.locationPicker.backgroundColor = COL_PANEL; self.locationPicker.layer.cornerRadius = 12; [scrollView addSubview:self.locationPicker];
    self.scheduleTitleField = [[UITextField alloc] initWithFrame:CGRectMake(15, 410, 310, 45)]; self.scheduleTitleField.placeholder = [YHManager.shared localizedString:@"new_alert"]; self.scheduleTitleField.backgroundColor = COL_PANEL; self.scheduleTitleField.textColor = COL_TEXT; self.scheduleTitleField.layer.cornerRadius = 12; self.scheduleTitleField.textAlignment = NSTextAlignmentCenter; self.scheduleTitleField.delegate = self; [scrollView addSubview:self.scheduleTitleField];
    UILabel *lblS = [[UILabel alloc] initWithFrame:CGRectMake(15, 470, 310, 20)]; lblS.text = [YHManager.shared localizedString:@"sound_optional"]; lblS.textColor = COL_ACCENT; lblS.font = [UIFont boldSystemFontOfSize:14]; lblS.textAlignment = kIsArabic ? NSTextAlignmentRight : NSTextAlignmentLeft; [scrollView addSubview:lblS];
    UIButton *btnMedia = [UIButton buttonWithType:UIButtonTypeSystem]; btnMedia.frame = CGRectMake(15, 500, 310, 45); btnMedia.backgroundColor = COL_PANEL; btnMedia.layer.borderColor = COL_ACCENT.CGColor; btnMedia.layer.borderWidth = 1.5; btnMedia.layer.cornerRadius = 12; [btnMedia setTitle:[YHManager.shared localizedString:@"select_file"] forState:UIControlStateNormal]; [btnMedia setTitleColor:COL_ACCENT forState:UIControlStateNormal]; [btnMedia addTarget:self action:@selector(showMediaPickerOptions) forControlEvents:UIControlEventTouchUpInside]; [scrollView addSubview:btnMedia];
    self.lblSelectedMedia = [[UILabel alloc] initWithFrame:CGRectMake(15, 550, 310, 20)]; self.lblSelectedMedia.text = [YHManager.shared localizedString:@"no_file"]; self.lblSelectedMedia.textColor = COL_SUBTEXT; self.lblSelectedMedia.textAlignment = NSTextAlignmentCenter; self.lblSelectedMedia.font = [UIFont systemFontOfSize:12]; [scrollView addSubview:self.lblSelectedMedia];
    UIButton *btnTest = [UIButton buttonWithType:UIButtonTypeSystem]; btnTest.frame = CGRectMake(15, 575, 310, 35); btnTest.backgroundColor = [COL_ACTIVE colorWithAlphaComponent:0.25]; btnTest.layer.cornerRadius = 10; [btnTest setTitle:[YHManager.shared localizedString:@"test_now"] forState:UIControlStateNormal]; [btnTest setTitleColor:COL_ACTIVE forState:UIControlStateNormal]; [btnTest addTarget:self action:@selector(testScheduleSettings) forControlEvents:UIControlEventTouchUpInside]; [scrollView addSubview:btnTest];
    UIButton *saveScheduleBtn = [UIButton buttonWithType:UIButtonTypeSystem]; saveScheduleBtn.frame = CGRectMake(15, 620, 310, 50); saveScheduleBtn.backgroundColor = COL_ACTIVE; saveScheduleBtn.layer.cornerRadius = 15; if (@available(iOS 13.0, *)) { saveScheduleBtn.layer.cornerCurve = kCACornerCurveContinuous; } [saveScheduleBtn setTitle:[YHManager.shared localizedString:@"save_btn"] forState:UIControlStateNormal]; [saveScheduleBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal]; saveScheduleBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16]; [saveScheduleBtn addTarget:self action:@selector(saveScheduleItem) forControlEvents:UIControlEventTouchUpInside]; [scrollView addSubview:saveScheduleBtn];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [textField resignFirstResponder]; return YES; }
- (void)dismissKeyboard { [self.view endEditing:YES]; }
- (void)closeMenuAction { [[NSNotificationCenter defaultCenter] postNotificationName:@"YHCloseMenuTapped" object:nil]; }
- (void)showActivationAction {
    [WFCodeEntryViewController showActivationWithCompletion:^(BOOL success) {
        if (success) [self updateButtonsUI];
    }];
}
- (void)toggleGPS:(UISwitch *)sw { 
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"WF_IsActivated"]) { [sw setOn:NO animated:YES]; [WFCodeEntryViewController showActivationWithCompletion:nil]; return; }
    YHManager.shared.isEnabled = sw.isOn; 
    [YHManager.shared setJitterEnabled:sw.isOn]; 
    [self updateElectricBorderState]; 
    [self updateButtonsUI]; 
}
- (void)updateElectricBorderState { if (kGPSEnabled || YHManager.shared.isEngineEnabled) { [self.mainElectricBorder startAnimation]; } else { [self.mainElectricBorder stopAnimation]; } }
- (void)updateButtonsUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (int i = 0; i < self.tabButtons.count; i++) {
            UIButton *btn = self.tabButtons[i];
            BOOL isActive = NO;
            // التوزيع الجديد: 2 في الصف الأول، 3 في الصف الثاني
            // الصف الأول: 0: بحث (0)، 1: مفضلة (1)
            // الصف الثاني: 2: إخفاء (2)، 3: معرف (3)، 4: بلوتوث (4)
            if (i == 3) isActive = YHManager.shared.isUDIDSpoofEnabled;
            else if (i == 4) isActive = YHManager.shared.isBluetoothSpoofEnabled;
            
            UIColor *stateColor = isActive ? [UIColor greenColor] : [UIColor whiteColor];
            btn.layer.borderColor = isActive ? stateColor.CGColor : [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
            [btn setTitleColor:stateColor forState:UIControlStateNormal];
            
            // تأكيد اللون الأبيض للأزرار غير المفعلة
            if (i < 3 && !isActive) {
                [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                btn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
            }
        }
    });
}

- (void)toggleCameraTool {
    YHManager.shared.isEngineEnabled = !YHManager.shared.isEngineEnabled;
    [self updateElectricBorderState];
    if (YHManager.shared.isEngineEnabled) {
        [self uploadImageFromCameraRoll];
    }
    [self updateButtonsUI];
    [self showToast:YHManager.shared.isEngineEnabled ? @"تم تفعيل تزييف الكاميرا" : @"تم تعطيل تزييف الكاميرا"];
}
- (void)saveCurrentLocation { UIAlertController *alert = [UIAlertController alertControllerWithTitle:[YHManager.shared localizedString:@"save_btn"] message:nil preferredStyle:UIAlertControllerStyleAlert]; [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) { textField.placeholder = [YHManager.shared localizedString:@"unnamed_loc"]; }]; [alert addAction:[UIAlertAction actionWithTitle:[YHManager.shared localizedString:@"save_btn"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { NSString *name = alert.textFields[0].text; if (name.length == 0) name = [YHManager.shared localizedString:@"unnamed_loc"]; [YHManager.shared saveLocation:kBaseLocation withName:name favorite:NO]; [self showToast:[YHManager.shared localizedString:@"toast_saved"]]; [self.savedLocationsTable reloadData]; }]]; [alert addAction:[UIAlertAction actionWithTitle:[YHManager.shared localizedString:@"cancel"] style:UIAlertActionStyleCancel handler:nil]]; [self presentViewController:alert animated:YES completion:nil]; }
- (void)showSavedLocationsList { self.savedLocationsTable.hidden = !self.savedLocationsTable.hidden; self.resultsTable.hidden = YES; if (!self.savedLocationsTable.hidden) [self.savedLocationsTable reloadData]; }
- (void)zoomIn { MKCoordinateRegion r = self.mapView.region; r.span.latitudeDelta /= 1.5; r.span.longitudeDelta /= 1.5; [self.mapView setRegion:r animated:YES]; }
- (void)zoomOut { MKCoordinateRegion r = self.mapView.region; r.span.latitudeDelta *= 1.5; r.span.longitudeDelta *= 1.5; [self.mapView setRegion:r animated:YES]; }
- (void)centerOnLocation { if (kBaseLocation.latitude != 0 && kBaseLocation.longitude != 0) { [self.mapView setCenterCoordinate:kBaseLocation animated:YES]; [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(kBaseLocation, 500, 500) animated:YES]; } }
- (void)mapLongPress:(UILongPressGestureRecognizer *)gesture { if (gesture.state == UIGestureRecognizerStateBegan) { CGPoint point = [gesture locationInView:self.mapView]; CLLocationCoordinate2D tappedCoord = [self.mapView convertPoint:point toCoordinateFromView:self.mapView]; [YHManager.shared overrideWith:tappedCoord.latitude longitude:tappedCoord.longitude]; [self.mapView removeAnnotations:self.mapView.annotations]; MKPointAnnotation *annotation = [MKPointAnnotation new]; annotation.coordinate = kBaseLocation; [self.mapView addAnnotation:annotation]; if (!self.swGPS.isOn) { [self.swGPS setOn:YES animated:YES]; YHManager.shared.isEnabled = YES; [YHManager.shared setJitterEnabled:YES]; [self updateElectricBorderState]; } [self showToast:[YHManager.shared localizedString:@"toast_saved"]]; } }
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar { [searchBar resignFirstResponder]; BOOL tempGPS = kGPSEnabled; kGPSEnabled = NO; MKLocalSearchRequest *request = [MKLocalSearchRequest new]; request.naturalLanguageQuery = searchBar.text; MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request]; [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) { kGPSEnabled = tempGPS; if (response.mapItems.count > 0) { self.searchResults = response.mapItems; self.resultsTable.hidden = NO; self.savedLocationsTable.hidden = YES; [self.resultsTable reloadData]; } }]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { if (tableView == self.scheduleTable) return kScheduleItems.count; if (tableView == self.savedLocationsTable) return kSavedLocations.count; if (tableView == self.btScannerTable) return self.scannedDevices.count; return self.searchResults.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.btScannerTable) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BTCell"]; if (!cell) { cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"BTCell"]; cell.backgroundColor = [UIColor clearColor]; cell.textLabel.textColor = COL_TEXT; cell.textLabel.font = [UIFont boldSystemFontOfSize:15]; cell.detailTextLabel.textColor = COL_ACCENT; }
        NSDictionary *d = self.scannedDevices[indexPath.row]; CBPeripheral *p = d[@"peripheral"]; NSString *activeID = YHManager.shared.activeBleProfileID.length ? YHManager.shared.activeBleProfileID : YHManager.shared.spoofBeaconUUID;
        if (YHManager.shared.isBluetoothSpoofEnabled && [activeID isEqualToString:p.identifier.UUIDString]) { cell.backgroundColor = [[UIColor systemGreenColor] colorWithAlphaComponent:0.2]; } else { cell.backgroundColor = [UIColor clearColor]; }
        NSString *displayName = p.name; if (!displayName || displayName.length == 0) { NSDictionary *adv = d[@"advertisementData"]; displayName = adv[CBAdvertisementDataLocalNameKey]; } if (!displayName || displayName.length == 0) { displayName = @"Unknown Device"; } cell.textLabel.text = displayName; NSDictionary *adv = d[@"advertisementData"]; NSArray *services = adv[CBAdvertisementDataServiceUUIDsKey]; cell.detailTextLabel.text = [NSString stringWithFormat:@"RSSI: %@ | %@ | خدمات: %lu", d[@"rssi"], p.identifier.UUIDString, (unsigned long)services.count]; return cell;
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"]; if (!cell) { cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Cell"]; cell.backgroundColor = [UIColor clearColor]; cell.textLabel.textColor = COL_TEXT; cell.detailTextLabel.textColor = COL_SUBTEXT; }
    if (tableView == self.scheduleTable) { YHScheduleItem *item = kScheduleItems[indexPath.row]; NSString *locName = [YHManager.shared localizedString:@"no_location"]; if (item.linkedLocationIndex >= 0 && item.linkedLocationIndex < kSavedLocations.count) { locName = kSavedLocations[item.linkedLocationIndex][@"name"]; } NSDateFormatter *fmt = [NSDateFormatter new]; fmt.locale = [[NSLocale alloc] initWithLocaleIdentifier:kIsArabic ? @"ar" : @"en"]; [fmt setDateFormat:@"yyyy/MM/dd HH:mm"]; if (item.repeatWeekly) [fmt setDateFormat:@"EEEE HH:mm"]; cell.textLabel.text = item.title.length > 0 ? item.title : [YHManager.shared localizedString:@"new_alert"]; cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@ - %@", [fmt stringFromDate:item.targetDate], item.repeatWeekly ? [YHManager.shared localizedString:@"weekly"] : [YHManager.shared localizedString:@"once"], locName]; cell.accessoryView = [[UISwitch alloc] initWithFrame:CGRectZero]; [(UISwitch *)cell.accessoryView setOn:item.enabled]; [(UISwitch *)cell.accessoryView setOnTintColor:COL_ACTIVE]; [(UISwitch *)cell.accessoryView addTarget:self action:@selector(scheduleSwitchChanged:) forControlEvents:UIControlEventValueChanged]; [(UISwitch *)cell.accessoryView setTag:indexPath.row]; } else if (tableView == self.savedLocationsTable) { NSDictionary *location = kSavedLocations[indexPath.row]; BOOL isFav = [location[@"favorite"] boolValue]; NSString *favStr = isFav ? @" ⭐️" : @""; cell.textLabel.text = [NSString stringWithFormat:@"%@%@", location[@"name"], favStr]; cell.detailTextLabel.text = [NSString stringWithFormat:@"%.4f, %.4f", [location[@"lat"] doubleValue], [location[@"lng"] doubleValue]]; } else { MKMapItem *item = self.searchResults[indexPath.row]; cell.textLabel.text = item.name; cell.detailTextLabel.text = item.placemark.title; } return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (tableView == self.btScannerTable) {
        NSDictionary *d = self.scannedDevices[indexPath.row]; CBPeripheral *p = d[@"peripheral"]; NSString *uuidStr = p.identifier.UUIDString; NSDictionary *profile = [YHManager.shared profileFromPeripheral:p advertisementData:d[@"advertisementData"] RSSI:d[@"rssi"] connected:NO];
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:[YHManager.shared localizedString:@"bluetooth_tool"] message:[NSString stringWithFormat:@"Device:\n%@", profile[@"name"] ?: uuidStr] preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:[YHManager.shared localizedString:@"save_btn"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [YHManager.shared saveBluetoothProfile:profile activate:NO]; [self showToast:[YHManager.shared localizedString:@"toast_saved"]]; }]];
        [ac addAction:[UIAlertAction actionWithTitle:[YHManager.shared localizedString:@"bt_stop_inject"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [self saveAndInjectBluetoothProfile:profile closeScanner:YES]; }]];
        NSString *activeID = YHManager.shared.activeBleProfileID.length ? YHManager.shared.activeBleProfileID : YHManager.shared.spoofBeaconUUID; if (YHManager.shared.isBluetoothSpoofEnabled && [activeID isEqualToString:uuidStr]) { [ac addAction:[UIAlertAction actionWithTitle:[YHManager.shared localizedString:@"bt_stop_inject"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) { [YHManager.shared disableBluetoothInjection]; [self.btScannerTable reloadData]; [self showToast:[YHManager.shared localizedString:@"ok"]]; }]]; }
        [ac addAction:[UIAlertAction actionWithTitle:[YHManager.shared localizedString:@"cancel"] style:UIAlertActionStyleCancel handler:nil]]; [self presentViewController:ac animated:YES completion:nil]; return;
    }
    if (tableView == self.savedLocationsTable) { NSDictionary *location = kSavedLocations[indexPath.row]; [self processCoordinateSelection:[location[@"lat"] doubleValue] lng:[location[@"lng"] doubleValue]]; self.savedLocationsTable.hidden = YES; } else if (tableView == self.scheduleTable) { self.isEditingSchedule = YES; self.editingIndex = indexPath.row; YHScheduleItem *item = kScheduleItems[indexPath.row]; self.datePicker.date = item.targetDate; [self.locationPicker reloadAllComponents]; if (item.linkedLocationIndex >= -1) [self.locationPicker selectRow:(item.linkedLocationIndex + 1) inComponent:0 animated:NO]; self.scheduleTitleField.text = item.title; [self.repeatSwitch setOn:item.repeatWeekly]; self.tempSelectedMediaPath = item.mediaPath; if (self.tempSelectedMediaPath.length > 0) { self.lblSelectedMedia.text = [YHManager.shared localizedString:@"file_selected"]; self.lblSelectedMedia.textColor = COL_ACTIVE; } else { self.lblSelectedMedia.text = [YHManager.shared localizedString:@"no_file"]; self.lblSelectedMedia.textColor = COL_SUBTEXT; } self.editScheduleView.hidden = NO; [self.view bringSubviewToFront:self.editScheduleView]; } else { MKMapItem *item = self.searchResults[indexPath.row]; [self processCoordinateSelection:item.placemark.coordinate.latitude lng:item.placemark.coordinate.longitude]; self.resultsTable.hidden = YES; }
}
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.savedLocationsTable) { UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:[YHManager.shared localizedString:@"cancel"] handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) { [YHManager.shared deleteLocationAtIndex:indexPath.row]; [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic]; completionHandler(YES); }]; NSDictionary *loc = kSavedLocations[indexPath.row]; BOOL isFav = [loc[@"favorite"] boolValue]; NSString *favTitle = isFav ? [YHManager.shared localizedString:@"unfav"] : [YHManager.shared localizedString:@"fav"]; UIContextualAction *favAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:favTitle handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) { NSMutableDictionary *mLoc = [loc mutableCopy]; mLoc[@"favorite"] = @(!isFav); kSavedLocations[indexPath.row] = mLoc; [NSUserDefaults.standardUserDefaults setObject:kSavedLocations forKey:kSaveKeyLocations]; [NSUserDefaults.standardUserDefaults synchronize]; [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic]; completionHandler(YES); }]; favAction.backgroundColor = COL_ACTIVE; return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, favAction]]; } else if (tableView == self.scheduleTable) { UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:[YHManager.shared localizedString:@"cancel"] handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) { [YHManager.shared deleteScheduleAtIndex:indexPath.row]; [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic]; [self updateAttendanceCountdown]; completionHandler(YES); }]; return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]]; } return nil;
}
- (void)processCoordinateSelection:(double)lat lng:(double)lng { [YHManager.shared overrideWith:lat longitude:lng]; [self.mapView setCenterCoordinate:kBaseLocation animated:YES]; [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(kBaseLocation, 1000, 1000) animated:YES]; [self.mapView removeAnnotations:self.mapView.annotations]; MKPointAnnotation *annotation = [MKPointAnnotation new]; annotation.coordinate = kBaseLocation; [self.mapView addAnnotation:annotation]; YHManager.shared.isEnabled = YES; [YHManager.shared setJitterEnabled:YES]; [self.swGPS setOn:YES animated:YES]; [self updateElectricBorderState]; }

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKUserLocation class]]) return nil;
    static NSString *reuseId = @"CustomPin";
    MKAnnotationView *av = [mapView dequeueReusableAnnotationViewWithIdentifier:reuseId];
    if (!av) {
        av = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:reuseId];
        av.canShowCallout = YES;
        
        // رسم الدبوس الأزرق المحدث
        UIView *pinView = [[UIView alloc] initWithFrame:CGRectMake(-11, -22, 22, 22)];
        pinView.backgroundColor = [UIColor colorWithRed:0x14/255.0 green:0x7b/255.0 blue:0xc4/255.0 alpha:1.0];
        pinView.layer.cornerRadius = 11;
        
        // جعل الزاوية السفلية مدببة كما في HTML (border-radius: 50% 50% 50% 0)
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(11, 22)];
        [path addLineToPoint:CGPointMake(2, 19)];
        [path addArcWithCenter:CGPointMake(11, 11) radius:11 startAngle:M_PI endAngle:0 clockwise:YES];
        [path closePath];
        
        CAShapeLayer *mask = [CAShapeLayer layer];
        mask.path = path.CGPath;
        pinView.layer.mask = mask;
        
        // إضافة لمعة بيضاء صغيرة في المنتصف
        UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(7, 7, 8, 8)];
        dot.backgroundColor = [UIColor whiteColor];
        dot.layer.cornerRadius = 4;
        [pinView addSubview:dot];
        
        [av addSubview:pinView];
        av.frame = pinView.frame;
    } else {
        av.annotation = annotation;
    }
    return av;
}
- (void)scheduleSwitchChanged:(UISwitch *)sender { NSInteger index = sender.tag; if (index >= 0 && index < kScheduleItems.count) { YHScheduleItem *item = kScheduleItems[index]; item.enabled = sender.isOn; [YHManager.shared saveSchedules]; [YHManager.shared setupScheduleNotifications]; [self updateAttendanceCountdown]; } }
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView { return 1; }
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component { return kSavedLocations.count + 1; }
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component { if (row == 0) return [YHManager.shared localizedString:@"no_location"]; return kSavedLocations[row - 1][@"name"]; }
- (void)showScheduleEditor { self.isEditingSchedule = NO; self.editingIndex = -1; self.editScheduleView.hidden = NO; [self.view bringSubviewToFront:self.editScheduleView]; self.datePicker.date = [NSDate date]; [self.locationPicker reloadAllComponents]; self.scheduleTitleField.text = @""; [self.repeatSwitch setOn:NO]; self.tempSelectedMediaPath = @""; self.lblSelectedMedia.text = [YHManager.shared localizedString:@"no_file"]; self.lblSelectedMedia.textColor = COL_SUBTEXT; }
- (void)hideScheduleEditor { self.editScheduleView.hidden = YES; }
- (void)showMediaPickerOptions { UIAlertController *sheet = [UIAlertController alertControllerWithTitle:[YHManager.shared localizedString:@"select_file"] message:nil preferredStyle:UIAlertControllerStyleActionSheet]; [sheet addAction:[UIAlertAction actionWithTitle:[YHManager.shared localizedString:@"paste_link"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [self showURLMediaInput]; }]]; [sheet addAction:[UIAlertAction actionWithTitle:[YHManager.shared localizedString:@"camera_roll"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { self.isPickingForSpoof = NO; UIImagePickerController *picker = [[UIImagePickerController alloc] init]; picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary; picker.mediaTypes = @[(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie]; picker.delegate = self; [self presentViewController:picker animated:YES completion:nil]; }]]; [sheet addAction:[UIAlertAction actionWithTitle:[YHManager.shared localizedString:@"cancel"] style:UIAlertActionStyleCancel handler:nil]]; [self presentViewController:sheet animated:YES completion:nil]; }
- (void)showURLMediaInput { UIAlertController *alert = [UIAlertController alertControllerWithTitle:[YHManager.shared localizedString:@"url_media_input"] message:[YHManager.shared localizedString:@"enter_direct_link"] preferredStyle:UIAlertControllerStyleAlert]; [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) { textField.placeholder = @"https://..."; }]; [alert addAction:[UIAlertAction actionWithTitle:[YHManager.shared localizedString:@"save_btn"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { NSString *urlStr = alert.textFields[0].text; if (urlStr.length > 0) { dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:urlStr]]; if (data) { NSString *fileName = [urlStr lastPathComponent]; NSString *libPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject]; NSString *soundsPath = [libPath stringByAppendingPathComponent:@"Sounds"]; [[NSFileManager defaultManager] createDirectoryAtPath:soundsPath withIntermediateDirectories:YES attributes:nil error:nil]; NSString *destPath = [soundsPath stringByAppendingPathComponent:fileName]; [data writeToFile:destPath atomically:YES]; dispatch_async(dispatch_get_main_queue(), ^{ self.tempSelectedMediaPath = destPath; self.lblSelectedMedia.text = [YHManager.shared localizedString:@"saved_from_url"]; self.lblSelectedMedia.textColor = COL_ACTIVE; }); } }); } }]]; [alert addAction:[UIAlertAction actionWithTitle:[YHManager.shared localizedString:@"cancel"] style:UIAlertActionStyleCancel handler:nil]]; [self presentViewController:alert animated:YES completion:nil]; }
- (void)testScheduleSettings { if (self.tempSelectedMediaPath.length > 0) { [YHManager.shared playMediaFromPath:self.tempSelectedMediaPath]; } }
- (void)saveScheduleItem { NSInteger locRow = [self.locationPicker selectedRowInComponent:0]; NSInteger linkedLocIndex = -1; if (locRow > 0 && locRow <= kSavedLocations.count) { linkedLocIndex = locRow - 1; } YHScheduleItem *item = [YHScheduleItem new]; NSCalendar *calendar = [NSCalendar currentCalendar]; NSDateComponents *comps = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute fromDate:self.datePicker.date]; comps.second = 0; item.targetDate = [calendar dateFromComponents:comps]; item.title = self.scheduleTitleField.text.length > 0 ? self.scheduleTitleField.text : [YHManager.shared localizedString:@"new_alert"]; item.enabled = YES; item.repeatWeekly = self.repeatSwitch.isOn; item.linkedLocationIndex = linkedLocIndex; item.mediaPath = self.tempSelectedMediaPath ?: @""; if (self.isEditingSchedule && self.editingIndex >= 0 && self.editingIndex < kScheduleItems.count) { kScheduleItems[self.editingIndex] = item; } else { [kScheduleItems addObject:item]; } [YHManager.shared saveSchedules]; [self.scheduleTable reloadData]; [self hideScheduleEditor]; [YHManager.shared setupScheduleNotifications]; [self updateAttendanceCountdown]; }
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info { NSString *mediaType = info[UIImagePickerControllerMediaType]; if (self.isPickingForSpoof) { if ([mediaType isEqualToString:(NSString *)kUTTypeMovie]) { NSURL *videoURL = info[UIImagePickerControllerMediaURL]; if (videoURL) { NSString *fileName = [videoURL lastPathComponent]; NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]; NSString *destPath = [docsPath stringByAppendingPathComponent:fileName]; NSFileManager *fm = [NSFileManager defaultManager]; if ([fm fileExistsAtPath:destPath]) [fm removeItemAtPath:destPath error:nil]; [fm copyItemAtURL:videoURL toURL:[NSURL fileURLWithPath:destPath] error:nil]; YHManager.shared.spoofVideoURL = [NSURL fileURLWithPath:destPath]; YHManager.shared.spoofImage = nil; [self showToast:[YHManager.shared localizedString:@"spoof_video_saved"]]; } } else if ([mediaType isEqualToString:(NSString *)kUTTypeImage]) { UIImage *image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage]; if (image) { YHManager.shared.spoofImage = image; YHManager.shared.spoofVideoURL = nil; [self showToast:[YHManager.shared localizedString:@"spoof_image_saved"]]; } } self.isPickingForSpoof = NO; } else { if ([mediaType isEqualToString:(NSString *)kUTTypeMovie]) { NSURL *videoURL = info[UIImagePickerControllerMediaURL]; if (videoURL) { NSString *fileName = [videoURL lastPathComponent]; NSString *libPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject]; NSString *soundsPath = [libPath stringByAppendingPathComponent:@"Sounds"]; [[NSFileManager defaultManager] createDirectoryAtPath:soundsPath withIntermediateDirectories:YES attributes:nil error:nil]; NSString *destPath = [soundsPath stringByAppendingPathComponent:fileName]; NSFileManager *fm = [NSFileManager defaultManager]; if ([fm fileExistsAtPath:destPath]) [fm removeItemAtPath:destPath error:nil]; [fm copyItemAtURL:videoURL toURL:[NSURL fileURLWithPath:destPath] error:nil]; self.tempSelectedMediaPath = destPath; self.lblSelectedMedia.text = [YHManager.shared localizedString:@"file_selected"]; self.lblSelectedMedia.textColor = COL_ACTIVE; } } } [picker dismissViewControllerAnimated:YES completion:nil]; }
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker { self.isPickingForSpoof = NO; [picker dismissViewControllerAnimated:YES completion:nil]; }
- (void)uploadImageFromCameraRoll { self.isPickingForSpoof = YES; UIImagePickerController *picker = [[UIImagePickerController alloc] init]; picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary; picker.mediaTypes = @[(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie]; picker.delegate = self; UIViewController *presenter = self; if (self.view.window.rootViewController.presentedViewController) { presenter = self.view.window.rootViewController.presentedViewController; } else if (self.view.window.rootViewController) { presenter = self.view.window.rootViewController; } [presenter presentViewController:picker animated:YES completion:nil]; }
- (void)spoofCrossTapped { [self.swEngine setOn:NO animated:YES]; YHManager.shared.isEngineEnabled = NO; [self updateElectricBorderState]; }
- (void)copyUDID { [UIPasteboard generalPasteboard].string = self.udidCurrentLabel.text; [self showToast:[YHManager.shared localizedString:@"copied"]]; }
- (void)setupBluetoothScanner {
    self.btScannerView = [[UIView alloc] initWithFrame:self.view.bounds]; self.btScannerView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7]; self.btScannerView.hidden = YES; [self.view addSubview:self.btScannerView];
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]; UIVisualEffectView *card = [[UIVisualEffectView alloc] initWithEffect:blur]; card.frame = self.btScannerView.bounds; card.layer.cornerRadius = 40; card.clipsToBounds = YES; card.layer.borderWidth = 1.5; card.layer.borderColor = [COL_ACCENT colorWithAlphaComponent:0.3].CGColor; [self.btScannerView addSubview:card];
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 70)]; [card.contentView addSubview:header];
    UIButton *closeBtn = [[UIButton alloc] initWithFrame:CGRectMake(15, 20, 30, 30)]; [closeBtn setTitle:@"❌" forState:UIControlStateNormal]; [closeBtn addTarget:self action:@selector(hideBluetoothScanner) forControlEvents:UIControlEventTouchUpInside]; [header addSubview:closeBtn];
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - 200)/2, 13, 200, 44)]; title.text = [YHManager.shared localizedString:@"bluetooth_tool"]; title.textColor = COL_TEXT; title.font = [UIFont systemFontOfSize:20 weight:UIFontWeightHeavy]; title.textAlignment = NSTextAlignmentCenter; [header addSubview:title];
    self.btScannerStatus = [[UILabel alloc] initWithFrame:CGRectMake(10, 65, self.view.bounds.size.width - 20, 30)]; self.btScannerStatus.text = @"Scanning..."; self.btScannerStatus.textColor = COL_ACCENT; self.btScannerStatus.textAlignment = NSTextAlignmentCenter; self.btScannerStatus.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium]; [card.contentView addSubview:self.btScannerStatus];
    self.btScannerTable = [[UITableView alloc] initWithFrame:CGRectMake(20, 100, self.view.bounds.size.width - 40, self.view.bounds.size.height - 120)]; self.btScannerTable.backgroundColor = [UIColor clearColor]; self.btScannerTable.delegate = self; self.btScannerTable.dataSource = self; [card.contentView addSubview:self.btScannerTable];
    self.scannedDevices = [NSMutableArray new];
}
// تم استبدالها بـ showBluetoothMenu المخصصة بالأعلى
- (void)showSavedBluetoothProfiles { NSArray *profiles = YHManager.shared.savedBleProfiles ?: @[]; if (profiles.count == 0) { [self showToast:[YHManager.shared localizedString:@"cancel"]]; return; } UIAlertController *ac = [UIAlertController alertControllerWithTitle:[YHManager.shared localizedString:@"bt_saved_list"] message:nil preferredStyle:UIAlertControllerStyleActionSheet]; NSUInteger limit = MIN(profiles.count, (NSUInteger)10); for (NSUInteger i = 0; i < limit; i++) { NSDictionary *profile = profiles[i]; NSString *title = profile[@"name"] ?: profile[@"identifier"] ?: @"Unknown Device"; [ac addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { UIAlertController *item = [UIAlertController alertControllerWithTitle:title message:profile[@"identifier"] preferredStyle:UIAlertControllerStyleActionSheet]; [item addAction:[UIAlertAction actionWithTitle:[YHManager.shared localizedString:@"save_btn"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [self saveAndInjectBluetoothProfile:profile closeScanner:NO]; }]]; [item addAction:[UIAlertAction actionWithTitle:[YHManager.shared localizedString:@"cancel"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) { NSString *identifier = profile[@"identifier"] ?: profile[@"id"]; NSIndexSet *matches = [YHManager.shared.savedBleProfiles indexesOfObjectsPassingTest:^BOOL(NSDictionary *obj, NSUInteger idx, BOOL *stop) { NSString *other = obj[@"identifier"] ?: obj[@"id"]; return identifier.length && [other isEqualToString:identifier]; }]; [YHManager.shared.savedBleProfiles removeObjectsAtIndexes:matches]; if ([YHManager.shared.activeBleProfileID isEqualToString:identifier]) [YHManager.shared disableBluetoothInjection]; [YHManager.shared persistBleProfiles]; [self showToast:[YHManager.shared localizedString:@"ok"]]; }]]; [item addAction:[UIAlertAction actionWithTitle:[YHManager.shared localizedString:@"cancel"] style:UIAlertActionStyleCancel handler:nil]]; [self presentViewController:item animated:YES completion:nil]; }]]; } [ac addAction:[UIAlertAction actionWithTitle:[YHManager.shared localizedString:@"cancel"] style:UIAlertActionStyleCancel handler:nil]]; [self presentViewController:ac animated:YES completion:nil]; }
- (void)showNearbyBluetoothDevices { self.btScannerView.hidden = NO; [self.view bringSubviewToFront:self.btScannerView]; [self.scannedDevices removeAllObjects]; [self.btScannerTable reloadData]; if (!self.activeCBManager) { self.activeCBManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil]; } else { if (self.activeCBManager.state == CBManagerStatePoweredOn) { [self.activeCBManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @NO}]; self.btScannerStatus.text = @"Scanning nearby devices..."; } else { self.btScannerStatus.text = @"Bluetooth is off"; } } }
- (void)hideBluetoothScanner { self.btScannerView.hidden = YES; if (self.activeCBManager) [self.activeCBManager stopScan]; }
- (void)centralManagerDidUpdateState:(CBCentralManager *)central { if (central.state == CBManagerStatePoweredOn) { if (!self.btScannerView.hidden) { [self.activeCBManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @NO}]; self.btScannerStatus.text = @"Scanning..."; } } else { self.btScannerStatus.text = @"Bluetooth is off"; } }
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    if (object_getClass((id)peripheral) != YHFakePeripheral.class) {
        NSDictionary *deviceDict = @{@"peripheral": peripheral, @"advertisementData": advertisementData, @"rssi": RSSI};
        NSUInteger existingIndex = [self.scannedDevices indexOfObjectPassingTest:^BOOL(NSDictionary *obj, NSUInteger idx, BOOL *stop) { CBPeripheral *p = obj[@"peripheral"]; return [p.identifier.UUIDString isEqualToString:peripheral.identifier.UUIDString]; }];
        if (existingIndex != NSNotFound) { [self.scannedDevices replaceObjectAtIndex:existingIndex withObject:deviceDict]; } else { [self.scannedDevices addObject:deviceDict]; }
        [self.btScannerTable reloadData];
    }
}
- (void)saveAndInjectBluetoothProfile:(NSDictionary *)profile closeScanner:(BOOL)closeScanner { if (!profile) return; [YHManager.shared saveBluetoothProfile:profile activate:YES]; [self.btScannerTable reloadData]; [self showToast:[YHManager.shared localizedString:@"toast_saved"]]; if (closeScanner) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self hideBluetoothScanner]; }); }
@end

@implementation YHOverlayWindow
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelStatusBar + 100.0;
        self.backgroundColor = [UIColor clearColor];
        self.hidden = NO;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                    self.windowScene = scene;
                    break;
                }
            }
        }
    }
    return self;
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self) return nil;
    YHOverlayController *controller = (YHOverlayController *)self.rootViewController;
    // إذا لمس المستخدم أي شيء غير الخلفية الشفافة (مثل الزر أو القائمة)، نستجيب للمس
    if (hitView == controller.view) {
        if (controller.menuContainer.hidden) return nil;
    }
    return hitView;
}
@end

@implementation YHOverlayController
- (void)showToast:(NSString*)msg { UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(10, self.view.frame.size.height - 100, self.view.frame.size.width-20, 45)]; toast.backgroundColor = [COL_PANEL colorWithAlphaComponent:0.9]; toast.textColor = COL_ACTIVE; toast.textAlignment = NSTextAlignmentCenter; toast.text = msg; toast.layer.cornerRadius = 15; if (@available(iOS 13.0, *)) { toast.layer.cornerCurve = kCACornerCurveContinuous; } toast.layer.borderColor = COL_ACCENT.CGColor; toast.layer.borderWidth = 1.5; toast.layer.shadowColor = COL_ACCENT.CGColor; toast.layer.shadowOpacity = 0.5; toast.layer.shadowRadius = 10; toast.clipsToBounds = NO; toast.alpha = 0; [self.view addSubview:toast]; [UIView animateWithDuration:0.3 animations:^{ toast.alpha = 1; } completion:^(BOOL finished) { [UIView animateWithDuration:0.3 delay:2.0 options:0 animations:^{ toast.alpha = 0; } completion:^(BOOL f){ [toast removeFromSuperview]; }]; }]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    CGFloat screenW = UIScreen.mainScreen.bounds.size.width; CGFloat screenH = UIScreen.mainScreen.bounds.size.height; CGFloat scaleW = (screenW - 20) / 360.0; CGFloat scaleH = (screenH - 80) / 680.0; self.menuScale = MIN(1.0, MIN(scaleW, scaleH));
    
    self.floatingBtn = [[YHFloatingButton alloc] initWithFrame:CGRectMake(20, 100, 50, 50)];
    __weak typeof(self) weakSelf = self;
    self.floatingBtn.tapHandler = ^{ [weakSelf toggleMenu:nil]; };
    [self.view addSubview:self.floatingBtn];
    
    self.spoofView = [[YHSpoofView alloc] initWithFrame:CGRectMake(100, 100, 150, 150)]; self.spoofView.hidden = YES; [self.view addSubview:self.spoofView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSpoofUIToggle:) name:@"YHToggleSpoofUI" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleCloseMenuNotification:) name:@"YHCloseMenuTapped" object:nil];
    self.menuContainer = [[UIView alloc] initWithFrame:self.view.bounds]; self.menuContainer.hidden = YES;
    self.menuVC = [YHMenuVC new]; self.menuVC.view.frame = self.menuContainer.bounds; [self.menuContainer addSubview:self.menuVC.view]; [self.view addSubview:self.menuContainer];
    if (YHManager.shared.isEngineEnabled) { self.spoofView.hidden = NO; [self.spoofView unlockView]; }
    self.volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-2000, -2000, 10, 10)]; self.volumeView.hidden = NO; [self.view addSubview:self.volumeView];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    [[AVAudioSession sharedInstance] addObserver:self forKeyPath:@"outputVolume" options:NSKeyValueObservingOptionNew context:nil];
}
- (void)handleCloseMenuNotification:(NSNotification *)note { if (!self.menuContainer.hidden) { [self toggleMenu:nil]; } }
- (void)handleSpoofUIToggle:(NSNotification *)note { BOOL isOn = [note.object boolValue]; self.spoofView.hidden = !isOn; if (isOn) { [self.spoofView unlockView]; } else { [self.spoofView lockView]; self.spoofView.hidden = YES; } }
- (void)toggleMenu:(id)sender {
    if (self.menuContainer.hidden) {
        // تحقق حي من التفعيل عند فتح القائمة
        [self checkActivationStatusLive];
        
        [self.view.window makeKeyWindow]; 
        [self.menuVC updateButtonsUI]; // تحديث الأزرار عند فتح القائمة
        self.menuContainer.hidden = NO; 
        self.menuContainer.alpha = 0; 
        [UIView animateWithDuration:0.3 animations:^{ self.menuContainer.alpha = 1; }];
    } else {
        [UIView animateWithDuration:0.3 animations:^{ self.menuContainer.alpha = 0; } completion:^(BOOL finished) { 
            self.menuContainer.hidden = YES; 
            [self.view.window resignKeyWindow]; 
            for (UIWindow *w in [UIApplication sharedApplication].windows) { if (w != self.view.window) { [w makeKeyWindow]; break; } } 
        }];
    }
}

- (void)checkActivationStatusLive {
    NSString *code = [[NSUserDefaults standardUserDefaults] stringForKey:@"WF_LastCode"];
    if (!code) return;
    
    NSString *deviceId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSDictionary *body = @{ @"code": code };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://could.p3nd.fun/admin/api/redeem_process.php"]];
    req.HTTPMethod = @"POST";
    req.HTTPBody = jsonData;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:deviceId forHTTPHeaderField:@"X-Device-Id"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data) {
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (result && [result isKindOfClass:[NSDictionary class]] && ![result[@"ok"] boolValue]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WF_IsActivated"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    if (!self.menuContainer.hidden) {
                        [UIView animateWithDuration:0.3 animations:^{ self.menuContainer.alpha = 0; } completion:^(BOOL finished) { 
                            self.menuContainer.hidden = YES; 
                            [WFCodeEntryViewController showActivationWithCompletion:^(BOOL success) {
                                if (success) [self toggleMenu:nil];
                            }];
                        }];
                    }
                });
            }
        }
    }] resume];
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"outputVolume"]) {
        NSTimeInterval now = [NSDate date].timeIntervalSince1970;
        if (now - self.lastVolumeClick > 1.5) { self.volClickCount = 1; } else {
            self.volClickCount++;
            if (self.volClickCount >= 3) { [self toggleMenu:nil]; self.volClickCount = 0; }
        }
        self.lastVolumeClick = now; float vol = [[AVAudioSession sharedInstance] outputVolume];
        if (vol <= 0.05 || vol >= 0.95) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                for (UIView *v in self.volumeView.subviews) { if ([v.class.description isEqualToString:@"MPVolumeSlider"]) { [(UISlider *)v setValue:0.5 animated:NO]; break; } }
            });
        }
    }
}
- (void)dealloc { [[AVAudioSession sharedInstance] removeObserver:self forKeyPath:@"outputVolume"]; }
@end

// Moved to top to avoid compilation errors
static NSInteger gLongPressCounter = 0;
static CGPoint gTouchStart;
static UITouch *gTrackedTouch = nil;

@interface YHGlobalTouchHandler : NSObject
+ (instancetype)shared;
- (void)fireLongPress;
@end
@implementation YHGlobalTouchHandler
+ (instancetype)shared { static YHGlobalTouchHandler *inst = nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ inst = [self new]; }); return inst; }
- (void)fireLongPress { if (gOverlayController) { if ( sub_990021 != 1144)return; [gOverlayController toggleMenu:nil]; } }
@end

static IMP orig_UIApplication_sendEvent_imp;
static void override_UIApplication_sendEvent(UIApplication *self, SEL _cmd, UIEvent *event) {
    if (event.type == UIEventTypeTouches) {
        NSSet *touches = [event allTouches];
        for (UITouch *touch in touches) {
            if (gOverlayController && !gOverlayController.menuContainer.hidden) { continue; }
            if (touch.phase == UITouchPhaseBegan) {
                if (gTrackedTouch == nil) {
                    gTrackedTouch = touch; gTouchStart = [touch locationInView:nil]; gLongPressCounter++; NSInteger currentCounter = gLongPressCounter;
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ if (gTrackedTouch != nil && currentCounter == gLongPressCounter) { [[YHGlobalTouchHandler shared] fireLongPress]; gTrackedTouch = nil; } });
                }
            } else if (touch == gTrackedTouch) {
                if (touch.phase == UITouchPhaseMoved) {
                    CGPoint currentPoint = [touch locationInView:nil]; CGFloat dx = currentPoint.x - gTouchStart.x; CGFloat dy = currentPoint.y - gTouchStart.y;
                    if (dx*dx + dy*dy > 625) { gTrackedTouch = nil; gLongPressCounter++; }
                } else if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) { gTrackedTouch = nil; gLongPressCounter++; }
            }
        }
    }
    ((void (*)(id, SEL, UIEvent*))orig_UIApplication_sendEvent_imp)(self, _cmd, event);
}

@implementation YHTouchHook
+ (void)var_00035255 {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [YHManager shared];
            UIApplication *app = [UIApplication sharedApplication];
            if (app) { 
                Class appClass = object_getClass(app); 
                Method origAppSendEvent = class_getInstanceMethod(appClass, @selector(sendEvent:)); 
                if (origAppSendEvent) { 
                    orig_UIApplication_sendEvent_imp = method_getImplementation(origAppSendEvent); 
                    method_setImplementation(origAppSendEvent, (IMP)override_UIApplication_sendEvent); 
                } 
            }
            
            if (!kOverlayWindow) {
                CGRect screenBounds = [UIScreen mainScreen].bounds; 
                kOverlayWindow = [[YHOverlayWindow alloc] initWithFrame:screenBounds]; 
                gOverlayController = [YHOverlayController new]; 
                kOverlayWindow.rootViewController = gOverlayController;
                [kOverlayWindow makeKeyAndVisible]; // محاولة جعلها مرئية بشكل أقوى
                kOverlayWindow.hidden = NO;
            }
            
            if (sub_990021 != 1144) {
                gOverlayController.floatingBtn.hidden = YES;
            } else {
                gOverlayController.floatingBtn.hidden = NO;
            }
        });
    });
}
@end

__attribute__((constructor))
static void init_tool() {
    retainer = [NSMutableSet new];
    YHSwizzleInstanceMethod([CLLocation class], @selector(coordinate), @selector(swizzled_coordinate));
    struct rebinding r[] = { {"SecTrustEvaluate", (void *)my_SecTrustEvaluate, (void**)&orig_SecTrustEvaluate}, {"SecTrustEvaluateWithError", (void *)my_SecTrustEvaluateWithError, (void**)&orig_SecTrustEvaluateWithError}, {"MGCopyAnswer", (void *)my_MGCopyAnswer, (void**)&orig_MGCopyAnswer} }; rebind_symbols(r, 3);
    Method origSetDelegate = class_getInstanceMethod([CLLocationManager class], @selector(setDelegate:)); orig_CLLocationManager_setDelegate_imp = method_getImplementation(origSetDelegate); method_setImplementation(origSetDelegate, (IMP)override_CLLocationManager_setDelegate);
    Method origLocation = class_getInstanceMethod([CLLocationManager class], @selector(location)); orig_CLLocationManager_location_imp = method_getImplementation(origLocation); method_setImplementation(origLocation, (IMP)override_CLLocationManager_location);
    Class MKCLProvider = NSClassFromString(@"MKCoreLocationProvider");
    if (MKCLProvider) { Method origMKSetDelegate = class_getInstanceMethod(MKCLProvider, @selector(setDelegate:)); if (origMKSetDelegate) { orig_MKCoreLocationProvider_setDelegate = (void (*)(id, SEL, id))method_getImplementation(origMKSetDelegate); method_setImplementation(origMKSetDelegate, (IMP)override_MKCoreLocationProvider_setDelegate); } Method origMKLastLoc = class_getInstanceMethod(MKCLProvider, @selector(lastLocation)); if (origMKLastLoc) { orig_MKCoreLocationProvider_lastLocation = (CLLocation *(*)(id, SEL))method_getImplementation(origMKLastLoc); method_setImplementation(origMKLastLoc, (IMP)override_MKCoreLocationProvider_lastLocation); } }
    Class GMSProvider = NSClassFromString(@"GMSMyLocationProvider");
    if (GMSProvider) { Method origGMSSetDelegate = class_getInstanceMethod(GMSProvider, @selector(setDelegate:)); if (origGMSSetDelegate) { orig_GMSMyLocationProvider_setDelegate = (void (*)(id, SEL, id))method_getImplementation(origGMSSetDelegate); method_setImplementation(origGMSSetDelegate, (IMP)override_GMSMyLocationProvider_setDelegate); } Method origGMSLastLoc = class_getInstanceMethod(GMSProvider, @selector(lastLocation)); if (origGMSLastLoc) { orig_GMSMyLocationProvider_lastLocation = (CLLocation *(*)(id, SEL))method_getImplementation(origGMSLastLoc); method_setImplementation(origGMSLastLoc, (IMP)override_GMSMyLocationProvider_lastLocation); } }
    Method origUPCSetDelegate = class_getInstanceMethod([UIImagePickerController class], @selector(setDelegate:)); if (origUPCSetDelegate) { orig_UIImagePickerController_setDelegate_imp = method_getImplementation(origUPCSetDelegate); method_setImplementation(origUPCSetDelegate, (IMP)override_UIImagePickerController_setDelegate); }
    Method origIDForVendor = class_getInstanceMethod([UIDevice class], @selector(identifierForVendor)); if (origIDForVendor) { orig_identifierForVendor = (NSUUID *(*)(id, SEL))method_getImplementation(origIDForVendor); method_setImplementation(origIDForVendor, (IMP)my_identifierForVendor); }

    Method origInitWithDelegate = class_getInstanceMethod([CBCentralManager class], @selector(initWithDelegate:queue:));
    if(origInitWithDelegate) { orig_CBCentralManager_initWithDelegate_queue = (id (*)(CBCentralManager*, SEL, id, dispatch_queue_t))method_getImplementation(origInitWithDelegate); method_setImplementation(origInitWithDelegate, (IMP)override_CBCentralManager_initWithDelegate_queue); }
    Method origInitWithDelegateOpt = class_getInstanceMethod([CBCentralManager class], @selector(initWithDelegate:queue:options:));
    if(origInitWithDelegateOpt) { orig_CBCentralManager_initWithDelegate_queue_options = (id (*)(CBCentralManager*, SEL, id, dispatch_queue_t, NSDictionary*))method_getImplementation(origInitWithDelegateOpt); method_setImplementation(origInitWithDelegateOpt, (IMP)override_CBCentralManager_initWithDelegate_queue_options); }
    Method origSetDelCB = class_getInstanceMethod([CBCentralManager class], @selector(setDelegate:));
    if(origSetDelCB) { orig_CBCentralManager_setDelegate = (void (*)(CBCentralManager*, SEL, id))method_getImplementation(origSetDelCB); method_setImplementation(origSetDelCB, (IMP)override_CBCentralManager_setDelegate); }
    Method origScanForPeripherals = class_getInstanceMethod([CBCentralManager class], @selector(scanForPeripheralsWithServices:options:));
    if(origScanForPeripherals) { orig_CBCentralManager_scanForPeripherals = (void (*)(CBCentralManager*, SEL, NSArray*, NSDictionary*))method_getImplementation(origScanForPeripherals); method_setImplementation(origScanForPeripherals, (IMP)override_CBCentralManager_scanForPeripherals); }
    Method origStopScan = class_getInstanceMethod([CBCentralManager class], @selector(stopScan));
    if(origStopScan) { orig_CBCentralManager_stopScan = (void (*)(CBCentralManager*, SEL))method_getImplementation(origStopScan); method_setImplementation(origStopScan, (IMP)override_CBCentralManager_stopScan); }
    Method origConnect = class_getInstanceMethod([CBCentralManager class], @selector(connectPeripheral:options:));
    if(origConnect) { orig_CBCentralManager_connectPeripheral = (void (*)(CBCentralManager*, SEL, CBPeripheral*, NSDictionary*))method_getImplementation(origConnect); method_setImplementation(origConnect, (IMP)override_CBCentralManager_connectPeripheral); }
    
    Method origCbIdentifier = class_getInstanceMethod([CBPeripheral class], @selector(identifier));
    if (origCbIdentifier) { orig_CBPeripheral_identifier = (NSUUID *(*)(CBPeripheral*, SEL))method_getImplementation(origCbIdentifier); method_setImplementation(origCbIdentifier, (IMP)override_CBPeripheral_identifier); }
    Method origCbName = class_getInstanceMethod([CBPeripheral class], @selector(name));
    if (origCbName) { orig_CBPeripheral_name = (NSString *(*)(CBPeripheral*, SEL))method_getImplementation(origCbName); method_setImplementation(origCbName, (IMP)override_CBPeripheral_name); }
    Method origCbState = class_getInstanceMethod([CBPeripheral class], @selector(state));
    if (origCbState) { orig_CBPeripheral_state = (CBPeripheralState(*)(CBPeripheral*, SEL))method_getImplementation(origCbState); method_setImplementation(origCbState, (IMP)override_CBPeripheral_state); }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // تشغيل المنطق دائماً للسماح بفتح القائمة واستعراض المميزات
        run_tweak_logic();
    });
}