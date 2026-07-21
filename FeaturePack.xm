#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

static CFStringRef const FGFeatureDomain = CFSTR("fun.p3nd.fakegps");
static NSString *const FGFavoritesKey = @"FGFavorites";
static NSString *const FGHistoryKey = @"FGHistory";
static NSString *const FGLicenseCodeKey = @"FGLicenseCode";
static NSString *const FGLicenseTokenKey = @"FGLicenseToken";
static NSString *const FGLicenseActiveKey = @"FGLicenseActive";
static NSString *const FGDeviceUUIDKey = @"FGDeviceUUID";

static void FGFeatureWrite(NSString *key, id value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             value ? (__bridge CFPropertyListRef)value : NULL,
                             FGFeatureDomain);
    CFPreferencesAppSynchronize(FGFeatureDomain);
}

static NSString *FGDeviceUUID(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *saved = [defaults stringForKey:FGDeviceUUIDKey];
    if (saved.length) return saved;
    NSString *uuid = UIDevice.currentDevice.identifierForVendor.UUIDString ?: NSUUID.UUID.UUIDString;
    [defaults setObject:uuid forKey:FGDeviceUUIDKey];
    [defaults synchronize];
    return uuid;
}

static BOOL FGLicenseIsActive(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    return [defaults boolForKey:FGLicenseActiveKey] && [defaults stringForKey:FGLicenseCodeKey].length > 0;
}

static UIViewController *FGTopController(void) {
    UIWindow *window = UIApplication.sharedApplication.keyWindow ?: UIApplication.sharedApplication.windows.firstObject;
    UIViewController *controller = window.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    return controller;
}

static void FGShowAlert(NSString *title, NSString *message) {
    UIViewController *controller = FGTopController();
    if (!controller) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleDefault handler:nil]];
    [controller presentViewController:alert animated:YES completion:nil];
}

static UIButton *FGCircleButton(NSString *symbol, UIColor *color) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(0, 0, 46, 46);
    button.layer.cornerRadius = 23;
    button.backgroundColor = color;
    button.tintColor = UIColor.whiteColor;
    if (@available(iOS 13.0, *)) [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    return button;
}

@interface FGManager : NSObject
@property(nonatomic,strong) UIView *menuView;
@property(nonatomic,strong) MKMapView *mapView;
@property(nonatomic,strong) UILabel *coordinateLabel;
- (void)openMenu;
- (void)fg_showActivationGate;
@end

static MKPointAnnotation *FGSelectedPin;

static CLLocationCoordinate2D FGCurrentCoordinate(FGManager *manager) {
    NSArray<NSString *> *parts = [(manager.coordinateLabel.text ?: @"24.713600, 46.675300") componentsSeparatedByString:@","];
    if (parts.count == 2) {
        double lat = [parts[0] doubleValue], lon = [parts[1] doubleValue];
        if (lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) return CLLocationCoordinate2DMake(lat, lon);
    }
    return CLLocationCoordinate2DMake(24.7136, 46.6753);
}

static void FGStoreCoordinate(FGManager *manager) {
    CLLocationCoordinate2D c = FGCurrentCoordinate(manager);
    FGFeatureWrite(@"latitude", @(c.latitude));
    FGFeatureWrite(@"longitude", @(c.longitude));
}

static void FGAppendRecord(NSString *key, NSDictionary *record, NSUInteger maxCount) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSMutableArray *items = [[defaults arrayForKey:key] mutableCopy] ?: [NSMutableArray array];
    [items insertObject:record atIndex:0];
    if (items.count > maxCount) [items removeObjectsInRange:NSMakeRange(maxCount, items.count-maxCount)];
    [defaults setObject:items forKey:key];
    [defaults synchronize];
}

%hook FGManager

- (void)openMenu {
    if (!FGLicenseIsActive()) {
        [self fg_showActivationGate];
        return;
    }

    %orig;
    if (!self.menuView || !self.mapView) return;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(fg_pickMap:)];
    tap.cancelsTouchesInView = NO;
    [self.mapView addGestureRecognizer:tap];

    CGFloat x = self.mapView.bounds.size.width - 58;
    NSArray *buttons = @[
        @[@"star.fill", UIColor.systemOrangeColor, @"fg_saveFavorite"],
        @[@"clock.arrow.circlepath", UIColor.systemGrayColor, @"fg_showHistory"],
        @[@"map.fill", UIColor.systemBlueColor, @"fg_changeMapType"],
        @[@"scope", UIColor.systemGreenColor, @"fg_realLocation"],
        @[@"person.text.rectangle", UIColor.systemPurpleColor, @"fg_deviceInfo"]
    ];
    for (NSUInteger i=0; i<buttons.count; i++) {
        NSArray *item = buttons[i];
        UIButton *button = FGCircleButton(item[0], item[1]);
        button.frame = CGRectMake(x, 12+i*54, 46, 46);
        [button addTarget:self action:NSSelectorFromString(item[2]) forControlEvents:UIControlEventTouchUpInside];
        [self.mapView addSubview:button];
    }
}

%new
- (void)fg_showActivationGate {
    UIViewController *controller = FGTopController();
    if (!controller || [controller.presentedViewController isKindOfClass:UIAlertController.class]) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تفعيل FAKE GPS"
                                                                   message:@"أدخل كود الترخيص لفتح المنيو والمميزات"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"XXXX-XXXX-XXXX";
        field.textAlignment = NSTextAlignmentCenter;
        field.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"تفعيل" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        NSString *code = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (code.length == 0) { FGShowAlert(@"تنبيه", @"أدخل كود الترخيص."); return; }

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://key.p3nd.fun/BYANO_Merged/api/activate.php"]];
        request.HTTPMethod = @"POST";
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSDictionary *body = @{ @"code":code, @"license_code":code, @"device_uuid":FGDeviceUUID(), @"project":@"FAKE GPS", @"platform":@"ios" };
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

        NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            (void)response;
            BOOL success = NO;
            NSString *message = @"تعذر الاتصال بخادم التفعيل.";
            if (!error && data.length) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([json isKindOfClass:NSDictionary.class]) {
                    NSString *status = [[json[@"status"] description] lowercaseString];
                    success = [json[@"success"] boolValue] || [@[@"success",@"valid",@"active",@"ok",@"approved"] containsObject:status];
                    message = json[@"message"] ?: (success ? @"تم التفعيل بنجاح." : @"الكود غير صالح أو منتهي.");
                    if (success) {
                        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
                        [defaults setObject:code forKey:FGLicenseCodeKey];
                        [defaults setBool:YES forKey:FGLicenseActiveKey];
                        NSString *token = json[@"token"] ?: json[@"auth_token"] ?: json[@"data"][@"token"];
                        if ([token isKindOfClass:NSString.class] && token.length) [defaults setObject:token forKey:FGLicenseTokenKey];
                        [defaults synchronize];
                    }
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    FGShowAlert(@"تم التفعيل", message);
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self openMenu]; });
                } else {
                    FGShowAlert(@"فشل التفعيل", message);
                }
            });
        }];
        [task resume];
    }]];
    [controller presentViewController:alert animated:YES completion:nil];
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
    self.coordinateLabel.text = [NSString stringWithFormat:@"%.6f, %.6f",c.latitude,c.longitude];
    FGStoreCoordinate(self);
    FGAppendRecord(FGHistoryKey,@{@"lat":@(c.latitude),@"lon":@(c.longitude)},50);
}

%new
- (void)fg_saveFavorite {
    CLLocationCoordinate2D c = FGCurrentCoordinate(self);
    FGAppendRecord(FGFavoritesKey,@{@"name":@"موقع محفوظ",@"lat":@(c.latitude),@"lon":@(c.longitude)},100);
    FGShowAlert(@"المفضلة",@"تم حفظ الموقع الحالي.");
}

%new
- (void)fg_showHistory {
    NSArray *items = [NSUserDefaults.standardUserDefaults arrayForKey:FGHistoryKey] ?: @[];
    if (!items.count) { FGShowAlert(@"السجل",@"لا توجد مواقع سابقة."); return; }
    NSMutableString *text = [NSMutableString string];
    for (NSUInteger i=0; i<MIN((NSUInteger)8,items.count); i++) {
        NSDictionary *r = items[i];
        [text appendFormat:@"%lu) %.6f, %.6f\n",(unsigned long)(i+1),[r[@"lat"] doubleValue],[r[@"lon"] doubleValue]];
    }
    FGShowAlert(@"آخر المواقع",text);
}

%new
- (void)fg_changeMapType {
    self.mapView.mapType = self.mapView.mapType == MKMapTypeStandard ? MKMapTypeSatellite : (self.mapView.mapType == MKMapTypeSatellite ? MKMapTypeHybrid : MKMapTypeStandard);
}

%new
- (void)fg_realLocation {
    CLLocation *location = self.mapView.userLocation.location;
    if (!location) { FGShowAlert(@"الموقع الحقيقي",@"لم يتم الحصول على الموقع الحالي بعد."); return; }
    CLLocationCoordinate2D c = location.coordinate;
    [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(c,800,800) animated:YES];
    self.coordinateLabel.text = [NSString stringWithFormat:@"%.6f, %.6f",c.latitude,c.longitude];
    FGStoreCoordinate(self);
}

%new
- (void)fg_deviceInfo {
    NSString *uuid = FGDeviceUUID();
    UIPasteboard.generalPasteboard.string = uuid;
    FGShowAlert(@"معرف الجهاز",[NSString stringWithFormat:@"%@\n\nتم نسخه.",uuid]);
}

%end
