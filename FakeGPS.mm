#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

static NSString *const FGEnabled = @"FGEnabled";
static NSString *const FGHidden = @"FGHidden";
static NSString *const FGX = @"FGX";
static NSString *const FGY = @"FGY";
static NSString *const FGFavorites = @"FGFavorites";
static NSString *const FGUploadEnabled = @"FGUploadEnabled";
static NSString *const FGBluetoothEnabled = @"FGBluetoothEnabled";

static NSUserDefaults *FGDefaults(void) { return NSUserDefaults.standardUserDefaults; }
static UIColor *FGColor(CGFloat r, CGFloat g, CGFloat b) {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1.0];
}
static UIImage *FGSymbol(NSString *name) {
    if (@available(iOS 13.0, *)) return [UIImage systemImageNamed:name];
    return nil;
}

@interface FGManager : NSObject <UISearchBarDelegate, MKMapViewDelegate>
@property(nonatomic,strong) UIButton *floatingButton;
@property(nonatomic,strong) UIView *menuView;
@property(nonatomic,strong) MKMapView *mapView;
@property(nonatomic,strong) UILabel *coordinateLabel;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UIButton *gpsToggleButton;
@property(nonatomic,weak) UIWindow *hostWindow;
@property(nonatomic,assign) NSInteger retryCount;
@property(nonatomic,assign) NSInteger volumeCount;
@property(nonatomic,assign) NSTimeInterval lastVolumeTime;
@property(nonatomic,assign) CLLocationCoordinate2D selectedCoordinate;
+ (instancetype)shared;
- (void)start;
@end

@implementation FGManager

+ (instancetype)shared {
    static FGManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [FGManager new]; });
    return manager;
}

- (UIWindow *)bestWindow {
    UIApplication *app = UIApplication.sharedApplication;
    for (UIWindow *window in app.windows.reverseObjectEnumerator) {
        if (!window.hidden && window.alpha > 0.0 && window.windowLevel == UIWindowLevelNormal) return window;
    }
    return app.keyWindow ?: app.windows.firstObject;
}

- (void)start {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(volumeChanged:)
                                                     name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                                   object:nil];
        [self attachWhenReady];
    });
}

- (void)attachWhenReady {
    if (self.floatingButton.superview) return;
    UIWindow *window = [self bestWindow];
    if (!window) {
        if (self.retryCount++ < 40) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self attachWhenReady];
            });
        }
        return;
    }
    self.hostWindow = window;
    [self buildFloatingButton];
}

- (void)buildFloatingButton {
    [self.floatingButton removeFromSuperview];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(20, 150, 64, 64);
    button.layer.cornerRadius = 32;
    button.tintColor = UIColor.whiteColor;
    [button setImage:FGSymbol(@"location.fill") forState:UIControlStateNormal];
    [button addTarget:self action:@selector(openMenu) forControlEvents:UIControlEventTouchUpInside];
    [button addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragFloating:)]];

    double x = [FGDefaults() doubleForKey:FGX];
    double y = [FGDefaults() doubleForKey:FGY];
    if (x > 0 && y > 0) button.center = CGPointMake(x, y);

    button.hidden = [FGDefaults() boolForKey:FGHidden];
    self.floatingButton = button;
    [self refreshFloatingColor];
    [self.hostWindow addSubview:button];
    [self.hostWindow bringSubviewToFront:button];
}

- (void)refreshFloatingColor {
    BOOL enabled = [FGDefaults() boolForKey:FGEnabled];
    self.floatingButton.backgroundColor = enabled ? FGColor(42, 203, 112) : FGColor(77, 87, 101);
    self.floatingButton.layer.shadowColor = (enabled ? FGColor(42, 203, 112) : UIColor.blackColor).CGColor;
    self.floatingButton.layer.shadowOpacity = 0.45;
    self.floatingButton.layer.shadowRadius = 14;
    self.floatingButton.layer.shadowOffset = CGSizeMake(0, 6);
}

- (void)dragFloating:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.hostWindow];
    CGPoint center = CGPointMake(self.floatingButton.center.x + translation.x,
                                 self.floatingButton.center.y + translation.y);
    CGFloat half = self.floatingButton.bounds.size.width / 2.0;
    center.x = MAX(half, MIN(self.hostWindow.bounds.size.width - half, center.x));
    center.y = MAX(half + 24, MIN(self.hostWindow.bounds.size.height - half - 24, center.y));
    self.floatingButton.center = center;
    [gesture setTranslation:CGPointZero inView:self.hostWindow];
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [FGDefaults() setDouble:center.x forKey:FGX];
        [FGDefaults() setDouble:center.y forKey:FGY];
        [FGDefaults() synchronize];
    }
}

- (UIButton *)iconButton:(NSString *)symbol frame:(CGRect)frame action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = frame;
    button.layer.cornerRadius = frame.size.height / 2.0;
    button.backgroundColor = FGColor(26, 28, 33);
    button.tintColor = UIColor.whiteColor;
    [button setImage:FGSymbol(symbol) forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIButton *)cardButton:(NSString *)title symbol:(NSString *)symbol frame:(CGRect)frame action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = frame;
    button.backgroundColor = FGColor(17, 19, 23);
    button.layer.cornerRadius = 18;
    button.layer.borderWidth = 1;
    button.layer.borderColor = FGColor(42, 46, 55).CGColor;
    button.tintColor = UIColor.whiteColor;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [button setImage:FGSymbol(symbol) forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    button.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    button.imageEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 0);
    button.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 14);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)openMenu {
    if (!self.hostWindow) self.hostWindow = [self bestWindow];
    if (!self.hostWindow) return;
    [self.menuView removeFromSuperview];

    UIView *panel = [[UIView alloc] initWithFrame:self.hostWindow.bounds];
    panel.backgroundColor = FGColor(5, 6, 8);
    self.menuView = panel;
    [self.hostWindow addSubview:panel];

    CGFloat top = 44;
    UIButton *close = [self iconButton:@"xmark" frame:CGRectMake(16, top, 44, 44) action:@selector(closeMenu)];
    [panel addSubview:close];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(70, top, panel.bounds.size.width - 140, 44)];
    title.text = @"GPS Pro";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;
    [panel addSubview:title];

    UIButton *favorite = [self iconButton:@"star.fill"
                                    frame:CGRectMake(panel.bounds.size.width - 60, top, 44, 44)
                                   action:@selector(addFavorite)];
    [panel addSubview:favorite];

    UISearchBar *search = [[UISearchBar alloc] initWithFrame:CGRectMake(14, 98, panel.bounds.size.width - 28, 48)];
    search.placeholder = @"بحث بكود GPS أو موقع أو إحداثيات";
    search.searchBarStyle = UISearchBarStyleMinimal;
    search.delegate = self;
    search.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [panel addSubview:search];

    UISegmentedControl *mapType = [[UISegmentedControl alloc] initWithItems:@[@"خريطة", @"قمر صناعي"]];
    mapType.frame = CGRectMake(14, 150, panel.bounds.size.width - 28, 40);
    mapType.selectedSegmentIndex = 0;
    [mapType addTarget:self action:@selector(changeMapType:) forControlEvents:UIControlEventValueChanged];
    [panel addSubview:mapType];

    CGFloat mapHeight = MIN(310, MAX(230, panel.bounds.size.height * 0.34));
    MKMapView *map = [[MKMapView alloc] initWithFrame:CGRectMake(14, 198, panel.bounds.size.width - 28, mapHeight)];
    map.layer.cornerRadius = 22;
    map.layer.masksToBounds = YES;
    map.delegate = self;
    map.showsUserLocation = YES;
    map.mapType = MKMapTypeStandard;
    self.mapView = map;
    [panel addSubview:map];

    self.selectedCoordinate = CLLocationCoordinate2DMake(24.7136, 46.6753);
    [map setRegion:MKCoordinateRegionMakeWithDistance(self.selectedCoordinate, 1100, 1100) animated:NO];

    UILongPressGestureRecognizer *pick = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(pickLocation:)];
    pick.minimumPressDuration = 0.45;
    [map addGestureRecognizer:pick];

    CGFloat statusY = CGRectGetMaxY(map.frame) + 10;
    UIView *statusCard = [[UIView alloc] initWithFrame:CGRectMake(14, statusY, panel.bounds.size.width - 28, 48)];
    statusCard.backgroundColor = FGColor(14, 17, 21);
    statusCard.layer.cornerRadius = 15;
    statusCard.layer.borderWidth = 1;
    statusCard.layer.borderColor = FGColor(36, 41, 49).CGColor;
    [panel addSubview:statusCard];

    UILabel *status = [[UILabel alloc] initWithFrame:CGRectMake(14, 0, statusCard.bounds.size.width - 28, 48)];
    status.textColor = FGColor(52, 211, 117);
    status.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    status.textAlignment = NSTextAlignmentRight;
    self.statusLabel = status;
    [statusCard addSubview:status];

    CGFloat coordY = CGRectGetMaxY(statusCard.frame) + 8;
    UILabel *coord = [[UILabel alloc] initWithFrame:CGRectMake(14, coordY, panel.bounds.size.width - 28, 40)];
    coord.text = @"24.713600, 46.675300";
    coord.textColor = UIColor.whiteColor;
    coord.textAlignment = NSTextAlignmentCenter;
    coord.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightMedium];
    coord.backgroundColor = FGColor(17, 21, 26);
    coord.layer.cornerRadius = 13;
    coord.clipsToBounds = YES;
    self.coordinateLabel = coord;
    [panel addSubview:coord];

    CGFloat rowY = CGRectGetMaxY(coord.frame) + 10;
    CGFloat gap = 8;
    CGFloat width = (panel.bounds.size.width - 36) / 2.0;

    UIButton *toggle = [self cardButton:@"تفعيل تغيير الموقع"
                                 symbol:@"location.fill"
                                  frame:CGRectMake(14, rowY, width, 50)
                                 action:@selector(toggleGPS:)];
    self.gpsToggleButton = toggle;
    [panel addSubview:toggle];

    UIButton *hide = [self cardButton:@"إخفاء زر الأداة"
                               symbol:@"eye.slash.fill"
                                frame:CGRectMake(22 + width, rowY, width, 50)
                               action:@selector(hideFloating)];
    [panel addSubview:hide];

    rowY += 58;
    UIButton *upload = [self cardButton:@"تفعيل رفع الصور"
                                 symbol:@"photo.on.rectangle"
                                  frame:CGRectMake(14, rowY, width, 50)
                                 action:@selector(toggleUpload:)];
    [panel addSubview:upload];

    UIButton *device = [self cardButton:@"تغيير معرف الجهاز"
                                 symbol:@"iphone"
                                  frame:CGRectMake(22 + width, rowY, width, 50)
                                 action:@selector(showDeviceIdentifier)];
    [panel addSubview:device];

    rowY += 58;
    UIButton *bluetooth = [self cardButton:@"Bluetooth و Beacons"
                                    symbol:@"wave.3.right"
                                     frame:CGRectMake(14, rowY, width, 50)
                                    action:@selector(toggleBluetooth:)];
    [panel addSubview:bluetooth];

    UIButton *favorites = [self cardButton:@"المفضلة"
                                    symbol:@"star"
                                     frame:CGRectMake(22 + width, rowY, width, 50)
                                    action:@selector(showFavorites)];
    [panel addSubview:favorites];

    [self refreshMenuState];
    [self.hostWindow bringSubviewToFront:panel];
}

- (void)refreshMenuState {
    BOOL enabled = [FGDefaults() boolForKey:FGEnabled];
    self.statusLabel.text = enabled ? @"● GPS متصل — تغيير الموقع نشط" : @"● GPS جاهز — تغيير الموقع متوقف";
    self.statusLabel.textColor = enabled ? FGColor(52, 211, 117) : FGColor(248, 184, 61);
    [self.gpsToggleButton setTitle:(enabled ? @"إيقاف تغيير الموقع" : @"تفعيل تغيير الموقع") forState:UIControlStateNormal];
}

- (void)changeMapType:(UISegmentedControl *)sender {
    self.mapView.mapType = sender.selectedSegmentIndex == 1 ? MKMapTypeSatellite : MKMapTypeStandard;
}

- (void)pickLocation:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    CGPoint point = [gesture locationInView:self.mapView];
    CLLocationCoordinate2D coordinate = [self.mapView convertPoint:point toCoordinateFromView:self.mapView];
    [self selectCoordinate:coordinate];
}

- (void)selectCoordinate:(CLLocationCoordinate2D)coordinate {
    self.selectedCoordinate = coordinate;
    self.coordinateLabel.text = [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];
    [FGDefaults() setDouble:coordinate.latitude forKey:@"FGLatitude"];
    [FGDefaults() setDouble:coordinate.longitude forKey:@"FGLongitude"];
    [FGDefaults() synchronize];

    [self.mapView removeAnnotations:self.mapView.annotations];
    MKPointAnnotation *pin = [MKPointAnnotation new];
    pin.coordinate = coordinate;
    pin.title = @"الموقع المحدد";
    [self.mapView addAnnotation:pin];
    [self.mapView selectAnnotation:pin animated:YES];
}

- (void)closeMenu {
    [self.menuView removeFromSuperview];
    self.menuView = nil;
    if (self.floatingButton.superview) [self.hostWindow bringSubviewToFront:self.floatingButton];
}

- (void)toggleGPS:(UIButton *)sender {
    BOOL enabled = ![FGDefaults() boolForKey:FGEnabled];
    [FGDefaults() setBool:enabled forKey:FGEnabled];
    [FGDefaults() synchronize];
    [self refreshFloatingColor];
    [self refreshMenuState];
}

- (void)toggleUpload:(UIButton *)sender {
    BOOL enabled = ![FGDefaults() boolForKey:FGUploadEnabled];
    [FGDefaults() setBool:enabled forKey:FGUploadEnabled];
    [FGDefaults() synchronize];
    [sender setTitle:(enabled ? @"إيقاف رفع الصور" : @"تفعيل رفع الصور") forState:UIControlStateNormal];
}

- (void)toggleBluetooth:(UIButton *)sender {
    BOOL enabled = ![FGDefaults() boolForKey:FGBluetoothEnabled];
    [FGDefaults() setBool:enabled forKey:FGBluetoothEnabled];
    [FGDefaults() synchronize];
    [sender setTitle:(enabled ? @"إيقاف Bluetooth" : @"Bluetooth و Beacons") forState:UIControlStateNormal];
}

- (void)addFavorite {
    NSString *item = [NSString stringWithFormat:@"%.6f, %.6f", self.selectedCoordinate.latitude, self.selectedCoordinate.longitude];
    NSMutableArray *favorites = [[FGDefaults() arrayForKey:FGFavorites] mutableCopy] ?: [NSMutableArray array];
    if (![favorites containsObject:item]) [favorites addObject:item];
    [FGDefaults() setObject:favorites forKey:FGFavorites];
    [FGDefaults() synchronize];
    [self showMessage:@"تم حفظ الموقع في المفضلة"];
}

- (void)showFavorites {
    NSArray *favorites = [FGDefaults() arrayForKey:FGFavorites] ?: @[];
    NSString *message = favorites.count ? [favorites componentsJoinedByString:@"\n"] : @"لا توجد مواقع محفوظة";
    [self showMessage:message];
}

- (void)showDeviceIdentifier {
    NSString *identifier = UIDevice.currentDevice.identifierForVendor.UUIDString ?: @"غير متاح";
    [self showMessage:[NSString stringWithFormat:@"معرف الجهاز الحالي:\n%@", identifier]];
}

- (void)showMessage:(NSString *)message {
    UIViewController *controller = self.hostWindow.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"GPS Pro"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
    [controller presentViewController:alert animated:YES completion:nil];
}

- (void)hideFloating {
    [self closeMenu];
    self.floatingButton.hidden = YES;
    [FGDefaults() setBool:YES forKey:FGHidden];
    [FGDefaults() synchronize];
}

- (void)volumeChanged:(NSNotification *)notification {
    NSNumber *value = notification.userInfo[@"AVSystemController_AudioVolumeNotificationParameter"];
    if (![value isKindOfClass:NSNumber.class]) return;
    static float previous = -1.0f;
    float current = value.floatValue;
    if (previous >= 0.0f && current > previous && self.floatingButton.hidden) {
        NSTimeInterval now = NSDate.date.timeIntervalSince1970;
        if (now - self.lastVolumeTime > 1.5) self.volumeCount = 0;
        self.lastVolumeTime = now;
        self.volumeCount += 1;
        if (self.volumeCount >= 3) {
            self.volumeCount = 0;
            self.floatingButton.hidden = NO;
            [FGDefaults() setBool:NO forKey:FGHidden];
            [FGDefaults() synchronize];
            [self.hostWindow bringSubviewToFront:self.floatingButton];
            UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
            [feedback impactOccurred];
        }
    }
    previous = current;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    NSString *query = [searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (query.length == 0) return;

    NSArray<NSString *> *parts = [query componentsSeparatedByString:@","];
    if (parts.count == 2) {
        double lat = [parts[0] doubleValue];
        double lon = [parts[1] doubleValue];
        if (lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) {
            CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(lat, lon);
            [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(coordinate, 900, 900) animated:YES];
            [self selectCoordinate:coordinate];
            return;
        }
    }

    MKLocalSearchRequest *request = [MKLocalSearchRequest new];
    request.naturalLanguageQuery = query;
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request];
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        if (error || response.mapItems.count == 0) return;
        CLLocationCoordinate2D coordinate = response.mapItems.firstObject.placemark.coordinate;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(coordinate, 900, 900) animated:YES];
            [self selectCoordinate:coordinate];
        });
    }];
}

@end

__attribute__((constructor)) static void FGInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[FGManager shared] start];
    });
}
