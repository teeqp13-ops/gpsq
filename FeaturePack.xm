#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

static CFStringRef const FGFeatureDomain = CFSTR("fun.p3nd.fakegps");
static NSString *const FGFavoritesKey = @"FGFavorites";
static NSString *const FGHistoryKey = @"FGHistory";
static NSString *const FGLicenseCodeKey = @"FGLicenseCode";
static NSString *const FGLicenseTokenKey = @"FGLicenseToken";
static NSString *const FGDeviceUUIDKey = @"FGDeviceUUID";

static id FGFeatureRead(NSString *key) {
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, FGFeatureDomain));
}

static void FGFeatureWrite(NSString *key, id value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             value ? (__bridge CFPropertyListRef)value : NULL,
                             FGFeatureDomain);
    CFPreferencesAppSynchronize(FGFeatureDomain);
}

static NSString *FGDeviceUUID(void) {
    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:FGDeviceUUIDKey];
    if (saved.length > 0) return saved;
    NSString *uuid = UIDevice.currentDevice.identifierForVendor.UUIDString ?: NSUUID.UUID.UUIDString;
    [[NSUserDefaults standardUserDefaults] setObject:uuid forKey:FGDeviceUUIDKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return uuid;
}

static UIButton *FGCircleButton(NSString *symbol, UIColor *color) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(0, 0, 46, 46);
    button.layer.cornerRadius = 23;
    button.backgroundColor = color;
    button.tintColor = UIColor.whiteColor;
    if (@available(iOS 13.0, *)) [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = 0.35;
    button.layer.shadowRadius = 7;
    button.layer.shadowOffset = CGSizeMake(0, 4);
    return button;
}

@interface FGManager : NSObject
@property(nonatomic,strong) UIView *menuView;
@property(nonatomic,strong) MKMapView *mapView;
@property(nonatomic,strong) UILabel *coordinateLabel;
- (void)openMenu;
@end

static __weak FGManager *FGActiveManager;
static MKPointAnnotation *FGSelectedPin;

static CLLocationCoordinate2D FGCurrentCoordinate(FGManager *manager) {
    NSString *text = manager.coordinateLabel.text ?: @"24.713600, 46.675300";
    NSArray<NSString *> *parts = [text componentsSeparatedByString:@","];
    if (parts.count == 2) {
        double lat = [parts[0] doubleValue];
        double lon = [parts[1] doubleValue];
        if (lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) return CLLocationCoordinate2DMake(lat, lon);
    }
    return CLLocationCoordinate2DMake(24.7136, 46.6753);
}

static void FGStoreSelectedCoordinate(FGManager *manager) {
    CLLocationCoordinate2D c = FGCurrentCoordinate(manager);
    FGFeatureWrite(@"latitude", @(c.latitude));
    FGFeatureWrite(@"longitude", @(c.longitude));
}

static void FGAppendRecord(NSString *key, NSDictionary *record, NSUInteger maxCount) {
    NSArray *old = [[NSUserDefaults standardUserDefaults] arrayForKey:key] ?: @[];
    NSMutableArray *items = [old mutableCopy];
    [items insertObject:record atIndex:0];
    if (items.count > maxCount) [items removeObjectsInRange:NSMakeRange(maxCount, items.count-maxCount)];
    [[NSUserDefaults standardUserDefaults] setObject:items forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static void FGShowAlert(NSString *title, NSString *message) {
    UIViewController *controller = UIApplication.sharedApplication.keyWindow.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    if (!controller) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleDefault handler:nil]];
    [controller presentViewController:alert animated:YES completion:nil];
}

%hook FGManager

- (void)openMenu {
    %orig;
    FGActiveManager = self;
    if (!self.menuView || !self.mapView) return;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fg_pickMap:)];
    tap.cancelsTouchesInView = NO;
    [self.mapView addGestureRecognizer:tap];

    CGFloat right = self.mapView.bounds.size.width - 58;
    NSArray *buttons = @[
        @[@"star.fill", [UIColor colorWithRed:0.95 green:0.67 blue:0.15 alpha:1.0], @"fg_saveFavorite"],
        @[@"clock.arrow.circlepath", [UIColor colorWithRed:0.34 green:0.45 blue:0.58 alpha:1.0], @"fg_showHistory"],
        @[@"map.fill", [UIColor colorWithRed:0.36 green:0.55 blue:0.95 alpha:1.0], @"fg_changeMapType"],
        @[@"scope", [UIColor colorWithRed:0.22 green:0.75 blue:0.46 alpha:1.0], @"fg_realLocation"],
        @[@"person.text.rectangle", [UIColor colorWithRed:0.58 green:0.50 blue:0.95 alpha:1.0], @"fg_deviceInfo"],
        @[@"key.fill", [UIColor colorWithRed:0.85 green:0.34 blue:0.38 alpha:1.0], @"fg_activateLicense"]
    ];

    for (NSUInteger i=0; i<buttons.count; i++) {
        NSArray *item = buttons[i];
        UIButton *button = FGCircleButton(item[0], item[1]);
        button.frame = CGRectMake(right, 12 + i*54, 46, 46);
        [button addTarget:self action:NSSelectorFromString(item[2]) forControlEvents:UIControlEventTouchUpInside];
        [self.mapView addSubview:button];
    }
}

%new
- (void)fg_pickMap:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded) return;
    CGPoint point = [gesture locationInView:self.mapView];
    CLLocationCoordinate2D c = [self.mapView convertPoint:point toCoordinateFromView:self.mapView];
    if (FGSelectedPin) [self.mapView removeAnnotation:FGSelectedPin];
    FGSelectedPin = [MKPointAnnotation new];
    FGSelectedPin.coordinate = c;
    FGSelectedPin.title = @"الموقع المحدد";
    [self.mapView addAnnotation:FGSelectedPin];
    self.coordinateLabel.text = [NSString stringWithFormat:@"%.6f, %.6f", c.latitude, c.longitude];
    FGStoreSelectedCoordinate(self);
    FGAppendRecord(FGHistoryKey, @{ @"lat":@(c.latitude), @"lon":@(c.longitude), @"date":@([[NSDate date] timeIntervalSince1970]) }, 50);
}

%new
- (void)fg_saveFavorite {
    CLLocationCoordinate2D c = FGCurrentCoordinate(self);
    NSDictionary *record = @{ @"name":[NSString stringWithFormat:@"موقع %.4f, %.4f",c.latitude,c.longitude], @"lat":@(c.latitude), @"lon":@(c.longitude), @"date":@([[NSDate date] timeIntervalSince1970]) };
    FGAppendRecord(FGFavoritesKey, record, 100);
    FGShowAlert(@"المفضلة", @"تم حفظ الموقع الحالي.");
}

%new
- (void)fg_showHistory {
    NSArray *items = [[NSUserDefaults standardUserDefaults] arrayForKey:FGHistoryKey] ?: @[];
    if (items.count == 0) { FGShowAlert(@"السجل", @"لا توجد مواقع سابقة."); return; }
    NSMutableString *text = [NSMutableString string];
    NSUInteger count = MIN((NSUInteger)8, items.count);
    for (NSUInteger i=0; i<count; i++) {
        NSDictionary *r = items[i];
        [text appendFormat:@"%lu) %.6f, %.6f\n",(unsigned long)(i+1),[r[@"lat"] doubleValue],[r[@"lon"] doubleValue]];
    }
    FGShowAlert(@"آخر المواقع", text);
}

%new
- (void)fg_changeMapType {
    if (self.mapView.mapType == MKMapTypeStandard) self.mapView.mapType = MKMapTypeSatellite;
    else if (self.mapView.mapType == MKMapTypeSatellite) self.mapView.mapType = MKMapTypeHybrid;
    else self.mapView.mapType = MKMapTypeStandard;
}

%new
- (void)fg_realLocation {
    CLLocation *location = self.mapView.userLocation.location;
    if (!location) { FGShowAlert(@"الموقع الحقيقي", @"لم يتم الحصول على الموقع الحالي بعد."); return; }
    CLLocationCoordinate2D c = location.coordinate;
    [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(c, 800, 800) animated:YES];
    self.coordinateLabel.text = [NSString stringWithFormat:@"%.6f, %.6f",c.latitude,c.longitude];
    FGStoreSelectedCoordinate(self);
}

%new
- (void)fg_deviceInfo {
    NSString *uuid = FGDeviceUUID();
    UIPasteboard.generalPasteboard.string = uuid;
    FGShowAlert(@"معرف الجهاز", [NSString stringWithFormat:@"%@\n\nتم نسخه إلى الحافظة.", uuid]);
}

%new
- (void)fg_activateLicense {
    UIViewController *controller = UIApplication.sharedApplication.keyWindow.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    if (!controller) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تفعيل FAKE GPS" message:@"أدخل كود الترخيص" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){ field.placeholder=@"XXXX-XXXX-XXXX"; field.textAlignment=NSTextAlignmentCenter; field.autocapitalizationType=UITextAutocapitalizationTypeAllCharacters; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"تفعيل" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        NSString *code = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (code.length == 0) return;
        NSURL *url = [NSURL URLWithString:@"https://key.p3nd.fun/api/activate.php"];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = @"POST";
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSDictionary *body = @{ @"code":code, @"license_code":code, @"device_uuid":FGDeviceUUID(), @"project":@"FAKE GPS", @"platform":@"ios" };
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
            NSString *message = @"تعذر الاتصال بخادم التفعيل.";
            BOOL success = NO;
            if (!error && data.length > 0) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([json isKindOfClass:NSDictionary.class]) {
                    NSString *status = [[json[@"status"] description] lowercaseString];
                    success = [json[@"success"] boolValue] || [@[@"success",@"valid",@"active",@"ok"] containsObject:status];
                    message = json[@"message"] ?: (success ? @"تم تفعيل الترخيص بنجاح." : @"الكود غير صالح أو منتهي.");
                    if (success) {
                        [[NSUserDefaults standardUserDefaults] setObject:code forKey:FGLicenseCodeKey];
                        NSString *token = json[@"token"] ?: json[@"auth_token"];
                        if (token.length) [[NSUserDefaults standardUserDefaults] setObject:token forKey:FGLicenseTokenKey];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                    }
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{ FGShowAlert(success ? @"تم التفعيل" : @"فشل التفعيل", message); });
        }];
        [task resume];
    }]];
    [controller presentViewController:alert animated:YES completion:nil];
}

%end
