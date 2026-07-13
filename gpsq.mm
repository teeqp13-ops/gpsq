#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import "UI/GPSAnimatedButton.h"

#ifndef GPSQ_API_BASE
#define GPSQ_API_BASE @"https://ipa.p3nd.fun/server/public/api"
#endif
#ifndef GPSQ_API_KEY
#define GPSQ_API_KEY @""
#endif

#define GPSQ_APP_NAME @"GPS Plus"
#define GPSQ_APP_VERSION @"1.1"

static NSString *GPSQDeviceID(void) {
    NSString *vendorID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    if (vendorID.length > 0) return vendorID;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSString *saved = [d stringForKey:@"GPSQ_FallbackUDID"];
    if (saved.length == 0) {
        saved = [[NSUUID UUID] UUIDString];
        [d setObject:saved forKey:@"GPSQ_FallbackUDID"];
        [d synchronize];
    }
    return saved;
}

static UIColor *GPSQColor(CGFloat r, CGFloat g, CGFloat b) {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1.0];
}

static UIButton *GPSQButton(NSString *title, UIColor *color) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.backgroundColor = color;
    b.layer.cornerRadius = 16.0;
    b.layer.masksToBounds = YES;
    b.titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
    b.titleLabel.adjustsFontSizeToFitWidth = YES;
    b.titleLabel.minimumScaleFactor = 0.72;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    return b;
}

static NSDate *GPSQDateFromServer(id value) {
    if (![value isKindOfClass:NSString.class] || [(NSString *)value length] == 0) return nil;
    NSString *s = (NSString *)value;
    NSDateFormatter *iso = [NSDateFormatter new];
    iso.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    iso.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
    NSDate *d = [iso dateFromString:s];
    if (d) return d;
    NSDateFormatter *sql = [NSDateFormatter new];
    sql.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    sql.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    return [sql dateFromString:s];
}

static NSString *GPSQDateText(NSDate *date) {
    if (!date) return @"غير محدد";
    NSDateFormatter *f = [NSDateFormatter new];
    f.locale = [NSLocale localeWithLocaleIdentifier:@"ar"];
    f.dateFormat = @"yyyy/MM/dd HH:mm";
    return [f stringFromDate:date];
}

@interface GPSQRootController : UIViewController <UITextFieldDelegate, MKMapViewDelegate>
@property(nonatomic,strong) GPSAnimatedButton *floatingButton;
@property(nonatomic,strong) UIView *dialogView;
@property(nonatomic,strong) UITextField *codeField;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UIView *fullOverlay;
@property(nonatomic,strong) MKMapView *mapView;
@property(nonatomic,strong) UISegmentedControl *mapTypeControl;
@property(nonatomic,assign) BOOL activated;
@end

@implementation GPSQRootController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.activated = [self hasValidActivation];
    [self buildFloatingIcon];
}

- (BOOL)hasValidActivation {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (![d boolForKey:@"GPSQ_Activated"]) return NO;
    NSString *token = [d stringForKey:@"GPSQ_Token"] ?: @"";
    if (token.length == 0) return NO;
    NSDate *expires = [d objectForKey:@"GPSQ_ExpiresAt"];
    if ([expires isKindOfClass:NSDate.class] && [expires timeIntervalSinceNow] > 0) return YES;
    [d setBool:NO forKey:@"GPSQ_Activated"];
    [d synchronize];
    return NO;
}

- (NSInteger)daysRemaining {
    NSDate *expires = [[NSUserDefaults standardUserDefaults] objectForKey:@"GPSQ_ExpiresAt"];
    if (![expires isKindOfClass:NSDate.class]) return 0;
    NSTimeInterval seconds = [expires timeIntervalSinceNow];
    if (seconds <= 0) return 0;
    return (NSInteger)ceil(seconds / 86400.0);
}

- (void)buildFloatingIcon {
    self.floatingButton = [[GPSAnimatedButton alloc] initWithActivated:self.activated];
    self.floatingButton.frame = CGRectMake(18, 72, 72, 72);
    [self.floatingButton addTarget:self action:@selector(floatingTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.floatingButton];
}

- (void)floatingTapped {
    self.activated = [self hasValidActivation];
    if (self.activated) [self showFullOverlay];
    else [self showActivationDialog];
}

- (void)showActivationDialog {
    [self.dialogView removeFromSuperview];
    [[self.view viewWithTag:1001] removeFromSuperview];
    UIView *shade = [[UIView alloc] initWithFrame:self.view.bounds];
    shade.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.15];
    shade.tag = 1001;
    [self.view addSubview:shade];
    CGFloat w = MIN(self.view.bounds.size.width - 36, 390);
    self.dialogView = [[UIView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - w) / 2, (self.view.bounds.size.height - 260) / 2, w, 260)];
    self.dialogView.backgroundColor = GPSQColor(20, 24, 33);
    self.dialogView.layer.cornerRadius = 24;
    self.dialogView.layer.borderWidth = 1;
    self.dialogView.layer.borderColor = GPSQColor(50, 60, 80).CGColor;
    [self.view addSubview:self.dialogView];
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 18, w - 40, 38)];
    title.text = GPSQ_APP_NAME;
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont boldSystemFontOfSize:26];
    title.textAlignment = NSTextAlignmentCenter;
    [self.dialogView addSubview:title];
    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, w - 40, 28)];
    sub.text = @"أدخل كود التفعيل";
    sub.textColor = GPSQColor(210, 220, 235);
    sub.font = [UIFont systemFontOfSize:16];
    sub.textAlignment = NSTextAlignmentCenter;
    [self.dialogView addSubview:sub];
    self.codeField = [[UITextField alloc] initWithFrame:CGRectMake(20, 100, w - 40, 54)];
    self.codeField.placeholder = @"كود 8 خانات";
    self.codeField.backgroundColor = UIColor.whiteColor;
    self.codeField.textColor = UIColor.blackColor;
    self.codeField.textAlignment = NSTextAlignmentCenter;
    self.codeField.font = [UIFont boldSystemFontOfSize:22];
    self.codeField.layer.cornerRadius = 16;
    self.codeField.layer.masksToBounds = YES;
    self.codeField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.codeField.delegate = self;
    [self.dialogView addSubview:self.codeField];
    CGFloat bw = (w - 52) / 2.0;
    UIButton *paste = GPSQButton(@"لصق النص", GPSQColor(71, 85, 105));
    paste.frame = CGRectMake(20, 170, bw, 48);
    [paste addTarget:self action:@selector(pasteCode) forControlEvents:UIControlEventTouchUpInside];
    [self.dialogView addSubview:paste];
    UIButton *activate = GPSQButton(@"تفعيل", GPSQColor(22, 163, 74));
    activate.frame = CGRectMake(32 + bw, 170, bw, 48);
    [activate addTarget:self action:@selector(activateCode) forControlEvents:UIControlEventTouchUpInside];
    [self.dialogView addSubview:activate];
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 224, w - 40, 24)];
    self.statusLabel.textColor = UIColor.whiteColor;
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.dialogView addSubview:self.statusLabel];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *source = textField.text ?: @"";
    NSString *n = [[source stringByReplacingCharactersInRange:range withString:string] uppercaseString];
    n = [[n componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@""];
    if (n.length > 8) n = [n substringToIndex:8];
    textField.text = n;
    return NO;
}

- (void)pasteCode {
    NSString *clip = UIPasteboard.generalPasteboard.string ?: @"";
    clip = [[clip uppercaseString] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    clip = [[clip componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@""];
    if (clip.length > 8) clip = [clip substringToIndex:8];
    self.codeField.text = clip;
    [self showCenterNotice:@"تم لصق النص"];
}

- (void)activateCode {
    NSString *code = self.codeField.text.uppercaseString ?: @"";
    if (code.length != 8) {
        self.statusLabel.text = @"الكود يجب أن يكون 8 خانات";
        self.statusLabel.textColor = GPSQColor(248, 113, 113);
        [self showCenterNotice:@"الكود غير صحيح"];
        return;
    }
    self.statusLabel.text = @"جاري التحقق...";
    self.statusLabel.textColor = GPSQColor(229, 231, 235);
    NSString *urlString = [NSString stringWithFormat:@"%@/activate.php", GPSQ_API_BASE];
    NSURL *url = [NSURL URLWithString:urlString];
    NSDictionary *payload = @{@"code": code, @"udid": GPSQDeviceID(), @"device_name": UIDevice.currentDevice.name ?: @"iPhone", @"app_bundle": NSBundle.mainBundle.bundleIdentifier ?: @"unknown", @"app_version": GPSQ_APP_VERSION, @"ios_version": UIDevice.currentDevice.systemVersion ?: @"", @"custom_identifier": @"gpsq"};
    NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    if (!url || !json) { [self showCenterNotice:@"خطأ في الطلب"]; return; }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = 18;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if ([GPSQ_API_KEY length] > 0) [req setValue:GPSQ_API_KEY forHTTPHeaderField:@"X-GPS-API-Key"];
    req.HTTPBody = json;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || data.length == 0) {
                self.statusLabel.text = @"تعذر الاتصال بالسيرفر";
                self.statusLabel.textColor = GPSQColor(248, 113, 113);
                [self showCenterNotice:@"فشل الاتصال"];
                return;
            }
            NSDictionary *r = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            BOOL ok = [r[@"success"] boolValue] || [r[@"status"] isEqual:@"ok"] || [r[@"status"] isEqual:@"success"] || [r[@"status"] isEqual:@"active"];
            if (ok) {
                NSString *token = [r[@"token"] isKindOfClass:NSString.class] ? r[@"token"] : @"";
                NSDate *expires = GPSQDateFromServer(r[@"expires_at"]);
                if (!expires) expires = [NSDate dateWithTimeIntervalSinceNow:30 * 86400.0];
                NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
                [d setBool:YES forKey:@"GPSQ_Activated"];
                [d setObject:token forKey:@"GPSQ_Token"];
                [d setObject:code forKey:@"GPSQ_Code"];
                [d setObject:expires forKey:@"GPSQ_ExpiresAt"];
                [d synchronize];
                self.activated = YES;
                [self.floatingButton setActivatedState:YES animated:YES];
                [self showCenterNotice:@"تم التفعيل بنجاح"];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.85 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [[self.view viewWithTag:1001] removeFromSuperview];
                    [self.dialogView removeFromSuperview];
                    [self showFullOverlay];
                });
                return;
            }
            NSString *msg = [r[@"message"] isKindOfClass:NSString.class] ? r[@"message"] : @"الكود غير مقبول";
            self.statusLabel.text = msg;
            self.statusLabel.textColor = GPSQColor(248, 113, 113);
            [self showCenterNotice:msg];
        });
    }];
    [task resume];
}

- (void)showFullOverlay {
    [self.fullOverlay removeFromSuperview];
    self.fullOverlay = [[UIView alloc] initWithFrame:self.view.bounds];
    self.fullOverlay.backgroundColor = GPSQColor(10, 14, 22);
    [self.view addSubview:self.fullOverlay];
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(110, 44, self.view.bounds.size.width - 220, 44)];
    title.text = GPSQ_APP_NAME;
    title.textColor = UIColor.whiteColor;
    title.textAlignment = NSTextAlignmentCenter;
    title.font = [UIFont boldSystemFontOfSize:24];
    [self.fullOverlay addSubview:title];
    UIButton *close = GPSQButton(@"إغلاق", GPSQColor(37, 99, 235));
    close.frame = CGRectMake(self.view.bounds.size.width - 96, 46, 78, 42);
    [close addTarget:self action:@selector(closeFullOverlay) forControlEvents:UIControlEventTouchUpInside];
    [self.fullOverlay addSubview:close];
    UIButton *info = GPSQButton(@"الاشتراك", GPSQColor(71, 85, 105));
    info.frame = CGRectMake(18, 46, 90, 42);
    [info addTarget:self action:@selector(showSubscriptionInfo) forControlEvents:UIControlEventTouchUpInside];
    [self.fullOverlay addSubview:info];
    self.mapTypeControl = [[UISegmentedControl alloc] initWithItems:@[@"خريطة", @"قمر", @"هجينة"]];
    self.mapTypeControl.frame = CGRectMake(18, 100, self.view.bounds.size.width - 36, 34);
    self.mapTypeControl.selectedSegmentIndex = 0;
    [self.mapTypeControl addTarget:self action:@selector(changeMapType) forControlEvents:UIControlEventValueChanged];
    [self.fullOverlay addSubview:self.mapTypeControl];
    CGFloat mapY = 144;
    self.mapView = [[MKMapView alloc] initWithFrame:CGRectMake(18, mapY, self.view.bounds.size.width - 36, self.view.bounds.size.height - mapY - 178)];
    self.mapView.delegate = self;
    self.mapView.showsUserLocation = YES;
    self.mapView.layer.cornerRadius = 18;
    self.mapView.layer.masksToBounds = YES;
    CLLocationCoordinate2D makkah = CLLocationCoordinate2DMake(21.3891, 39.8579);
    [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(makkah, 1800, 1800) animated:NO];
    [self.fullOverlay addSubview:self.mapView];
    CGFloat y = self.view.bounds.size.height - 160;
    CGFloat w = (self.view.bounds.size.width - 52) / 2.0;
    UIButton *current = GPSQButton(@"📍 موقعي الحالي", GPSQColor(22, 163, 74));
    current.frame = CGRectMake(18, y, w, 46);
    [current addTarget:self action:@selector(goCurrentLocation) forControlEvents:UIControlEventTouchUpInside];
    [self.fullOverlay addSubview:current];
    UIButton *save = GPSQButton(@"حفظ الموقع", GPSQColor(37, 99, 235));
    save.frame = CGRectMake(34 + w, y, w, 46);
    [save addTarget:self action:@selector(saveCurrentMapLocation) forControlEvents:UIControlEventTouchUpInside];
    [self.fullOverlay addSubview:save];
    UIButton *saved = GPSQButton(@"المواقع المحفوظة", GPSQColor(124, 58, 237));
    saved.frame = CGRectMake(18, y + 58, self.view.bounds.size.width - 36, 46);
    [saved addTarget:self action:@selector(showSavedLocations) forControlEvents:UIControlEventTouchUpInside];
    [self.fullOverlay addSubview:saved];
}

- (void)changeMapType {
    NSInteger i = self.mapTypeControl.selectedSegmentIndex;
    self.mapView.mapType = i == 0 ? MKMapTypeStandard : (i == 1 ? MKMapTypeSatellite : MKMapTypeHybrid);
}

- (void)goCurrentLocation {
    CLLocation *loc = self.mapView.userLocation.location;
    if (!loc) { [self showCenterNotice:@"لم يتم تحديد موقعك بعد"]; return; }
    [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(loc.coordinate, 900, 900) animated:YES];
    [self showCenterNotice:@"تم تحديد موقعك الحالي"];
}

- (void)saveCurrentMapLocation {
    CLLocationCoordinate2D c = self.mapView.centerCoordinate;
    NSMutableArray *arr = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"GPSQ_SavedLocations"] mutableCopy] ?: [NSMutableArray array];
    NSDictionary *item = @{@"title": [NSString stringWithFormat:@"موقع %lu", (unsigned long)arr.count + 1], @"lat": @(c.latitude), @"lng": @(c.longitude)};
    [arr addObject:item];
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey:@"GPSQ_SavedLocations"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self showCenterNotice:@"تم حفظ الموقع"];
}

- (void)showSavedLocations {
    NSArray *arr = [[NSUserDefaults standardUserDefaults] arrayForKey:@"GPSQ_SavedLocations"] ?: @[];
    if (arr.count == 0) { [self showCenterNotice:@"لا توجد مواقع محفوظة"]; return; }
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"المواقع المحفوظة" message:@"اختر موقعًا" preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *item in arr) {
        NSString *title = item[@"title"] ?: @"موقع محفوظ";
        double lat = [item[@"lat"] doubleValue];
        double lng = [item[@"lng"] doubleValue];
        [ac addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
            CLLocationCoordinate2D c = CLLocationCoordinate2DMake(lat, lng);
            [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(c, 900, 900) animated:YES];
            [self showCenterNotice:@"تم اختيار الموقع"];
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)closeFullOverlay { [self.fullOverlay removeFromSuperview]; self.fullOverlay = nil; }

- (void)showSubscriptionInfo {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSString *code = [d stringForKey:@"GPSQ_Code"] ?: @"غير محدد";
    NSString *token = [d stringForKey:@"GPSQ_Token"] ?: @"";
    NSString *shortToken = token.length > 12 ? [token substringToIndex:12] : token;
    NSDate *expires = [d objectForKey:@"GPSQ_ExpiresAt"];
    NSString *msg = [NSString stringWithFormat:@"الكود: %@\nينتهي: %@\nالمدة المتبقية: %ld يوم\nUUID: %@\nToken: %@", code, GPSQDateText(expires), (long)[self daysRemaining], GPSQDeviceID(), shortToken.length ? shortToken : @"غير محفوظ"];
    [self showCenterNotice:msg];
}

- (void)showCenterNotice:(NSString *)message {
    UILabel *n = [[UILabel alloc] initWithFrame:CGRectMake(28, (self.view.bounds.size.height - 138) / 2, self.view.bounds.size.width - 56, 138)];
    n.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.86];
    n.textColor = UIColor.whiteColor;
    n.text = message ?: @"";
    n.textAlignment = NSTextAlignmentCenter;
    n.font = [UIFont boldSystemFontOfSize:15];
    n.numberOfLines = 0;
    n.layer.cornerRadius = 18;
    n.layer.masksToBounds = YES;
    [self.view addSubview:n];
    [UIView animateWithDuration:0.25 delay:2.2 options:0 animations:^{ n.alpha = 0; } completion:^(__unused BOOL f){ [n removeFromSuperview]; }];
}
@end

static UIWindow *gpsqWindow = nil;
static void GPSQShowWindow(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gpsqWindow) { gpsqWindow.hidden = NO; return; }
        gpsqWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        gpsqWindow.windowLevel = UIWindowLevelAlert + 35;
        gpsqWindow.backgroundColor = UIColor.clearColor;
        gpsqWindow.rootViewController = [GPSQRootController new];
        gpsqWindow.hidden = NO;
    });
}

__attribute__((constructor)) static void GPSQInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) { GPSQShowWindow(); }];
        GPSQShowWindow();
    });
}
