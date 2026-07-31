#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreBluetooth/CoreBluetooth.h>

static NSString *const FGEnabled = @"FGEnabled";
static NSString *const FGHidden = @"FGHidden";
static NSString *const FGX = @"FGX";
static NSString *const FGY = @"FGY";
static NSString *const FGFavorites = @"FGFavorites";
static NSString *const FGUploadEnabled = @"FGUploadEnabled";
static NSString *const FGBluetoothEnabled = @"FGBluetoothEnabled";
static NSString *const FGDeviceIdentifierKey = @"GPSQDeviceIdentifier";
static CFStringRef const FGSharedDomain = CFSTR("fun.p3nd.fakegps");

static BOOL FGSimulationEnabled(void) {
    id sharedValue = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("enabled"), FGSharedDomain));
    if ([sharedValue respondsToSelector:@selector(boolValue)]) return [sharedValue boolValue];
    return [NSUserDefaults.standardUserDefaults boolForKey:FGEnabled];
}

static void FGSetSimulationEnabled(BOOL enabled) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setBool:enabled forKey:FGEnabled];
    [defaults setBool:enabled forKey:@"gps_simulation_enabled"];
    [defaults synchronize];

    CFPreferencesSetAppValue(CFSTR("enabled"), enabled ? kCFBooleanTrue : kCFBooleanFalse, FGSharedDomain);
    CFPreferencesAppSynchronize(FGSharedDomain);
}

static BOOL FGExtractCoordinatesFromText(NSString *text, CLLocationCoordinate2D *coordinate) {
    if (text.length == 0 || !coordinate) return NO;

    NSString *decoded = [text stringByRemovingPercentEncoding] ?: text;
    decoded = [decoded stringByReplacingOccurrencesOfString:@"،" withString:@","];

    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(-?[0-9]{1,2}(?:\\.[0-9]+)?)[,\\s]+(-?[0-9]{1,3}(?:\\.[0-9]+)?)"
                                                                           options:0
                                                                             error:&error];
    if (error) return NO;

    NSTextCheckingResult *match = [regex firstMatchInString:decoded options:0 range:NSMakeRange(0, decoded.length)];
    if (!match || match.numberOfRanges < 3) return NO;

    double latitude = [[decoded substringWithRange:[match rangeAtIndex:1]] doubleValue];
    double longitude = [[decoded substringWithRange:[match rangeAtIndex:2]] doubleValue];
    if (!CLLocationCoordinate2DIsValid(CLLocationCoordinate2DMake(latitude, longitude))) return NO;

    *coordinate = CLLocationCoordinate2DMake(latitude, longitude);
    return YES;
}

static BOOL FGLooksLikeSharedMapLink(NSString *text) {
    NSString *lower = text.lowercaseString;
    return [lower hasPrefix:@"http://"] || [lower hasPrefix:@"https://"] ||
           [lower containsString:@"maps.app.goo.gl"] ||
           [lower containsString:@"maps.apple.com"] ||
           [lower containsString:@"google.com/maps"];
}

static NSString *FGCurrentDeviceIdentifier(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *saved = [defaults stringForKey:FGDeviceIdentifierKey];
    if (saved.length) return saved;
    NSString *identifier = UIDevice.currentDevice.identifierForVendor.UUIDString ?: NSUUID.UUID.UUIDString;
    [defaults setObject:identifier forKey:FGDeviceIdentifierKey];
    [defaults synchronize];
    return identifier;
}

static NSUserDefaults *FGDefaults(void) { return NSUserDefaults.standardUserDefaults; }
static UIColor *FGColor(CGFloat r, CGFloat g, CGFloat b) {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1.0];
}
static UIImage *FGSymbol(NSString *name) {
    if (@available(iOS 13.0, *)) return [UIImage systemImageNamed:name];
    return nil;
}

@interface FGManager : NSObject <UISearchBarDelegate, MKMapViewDelegate, CBCentralManagerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property(nonatomic,strong) UIButton *floatingButton;
@property(nonatomic,strong) UIWindow *uploadIconWindow;
@property(nonatomic,strong) UIButton *uploadIconButton;
@property(nonatomic,strong) UIView *menuView;
@property(nonatomic,strong) MKMapView *mapView;
@property(nonatomic,strong) UILabel *coordinateLabel;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UIButton *gpsToggleButton;
@property(nonatomic,strong) UITextField *manualIDField;
@property(nonatomic,strong) UISegmentedControl *mapProviderControl;
@property(nonatomic,copy) NSString *lastMapQuery;
@property(nonatomic,weak) UIWindow *hostWindow;
@property(nonatomic,assign) NSInteger retryCount;
@property(nonatomic,assign) NSInteger volumeCount;
@property(nonatomic,assign) NSTimeInterval lastVolumeTime;
@property(nonatomic,assign) CLLocationCoordinate2D selectedCoordinate;
@property(nonatomic,strong) CBCentralManager *btManager;
@property(nonatomic,strong) NSMutableArray<CBPeripheral *> *foundDevices;
@property(nonatomic,strong) NSUUID *savedRadarUUID;
@property(nonatomic,copy) NSString *savedRadarName;
@property(nonatomic,strong) CBPeripheral *savedRadarDevice;
@property(nonatomic,assign) BOOL autoRadarEnabled;
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
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(showFloatingIconFromNotification:)
                                                     name:@"GPSQShowFloatingIcon"
                                                   object:nil];
        [self loadRadarPlan];
        [self attachWhenReady];
        [self refreshUploadFloatingIcon];
    });
}

- (void)showFloatingIconFromNotification:(__unused NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.floatingButton.superview) [self attachWhenReady];
        self.floatingButton.hidden = NO;
        [FGDefaults() setBool:NO forKey:FGHidden];
        [FGDefaults() synchronize];
        [self refreshFloatingColor];
        if (self.floatingButton.superview) [self.hostWindow bringSubviewToFront:self.floatingButton];
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
    UILongPressGestureRecognizer *togglePress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleFakeGPSTogglePress:)];
    togglePress.minimumPressDuration = 0.55;
    [button addGestureRecognizer:togglePress];

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
    BOOL enabled = FGSimulationEnabled();
    self.floatingButton.backgroundColor = enabled ? FGColor(42, 203, 112) : FGColor(77, 87, 101);
    self.floatingButton.layer.shadowColor = (enabled ? FGColor(42, 203, 112) : UIColor.blackColor).CGColor;
    self.floatingButton.layer.shadowOpacity = 0.45;
    self.floatingButton.layer.shadowRadius = 14;
    self.floatingButton.layer.shadowOffset = CGSizeMake(0, 6);
}

- (void)toggleFakeGPS {
    BOOL enabled = FGSimulationEnabled();
    FGSetSimulationEnabled(!enabled);
    [self refreshFloatingColor];
    [self refreshMenuState];

    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];
}

- (void)handleFakeGPSTogglePress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) [self toggleFakeGPS];
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
    title.text = @"Wolf GPS V17 — المنيو";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;
    [panel addSubview:title];

    UIButton *mapPin = [self iconButton:@"map.fill"
                                  frame:CGRectMake(panel.bounds.size.width - 60, top, 44, 44)
                                 action:@selector(openSelectedLocationInAppleMaps)];
    [panel addSubview:mapPin];

    UISegmentedControl *mapType = [[UISegmentedControl alloc] initWithItems:@[@"Apple Maps", @"Google Maps", @"قمر صناعي"]];
    mapType.frame = CGRectMake(14, 98, panel.bounds.size.width - 28, 40);
    mapType.selectedSegmentIndex = 0;
    [mapType addTarget:self action:@selector(changeMapProvider:) forControlEvents:UIControlEventValueChanged];
    self.mapProviderControl = mapType;
    [panel addSubview:mapType];

    CGFloat mapHeight = MIN(250, MAX(180, panel.bounds.size.height * 0.24));
    MKMapView *map = [[MKMapView alloc] initWithFrame:CGRectMake(14, 146, panel.bounds.size.width - 28, mapHeight)];
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

    UIButton *locateButton = [self iconButton:@"location.fill"
                                        frame:CGRectMake(12, map.bounds.size.height - 56, 44, 44)
                                       action:@selector(locateUserOnMap)];
    locateButton.backgroundColor = UIColor.whiteColor;
    locateButton.tintColor = FGColor(30, 105, 232);
    locateButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
    [map addSubview:locateButton];

    UIButton *pinButton = [self iconButton:@"mappin"
                                     frame:CGRectMake(64, map.bounds.size.height - 56, 44, 44)
                                    action:@selector(placePinAtMapCenter)];
    pinButton.backgroundColor = UIColor.whiteColor;
    pinButton.tintColor = FGColor(232, 56, 62);
    pinButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
    [map addSubview:pinButton];

    CGFloat controlsY = CGRectGetMaxY(map.frame) + 8;
    CGFloat availableHeight = CGRectGetHeight(panel.bounds) - controlsY - MAX(self.hostWindow.safeAreaInsets.bottom, 8);
    UIScrollView *controls = [[UIScrollView alloc] initWithFrame:CGRectMake(0, controlsY, CGRectGetWidth(panel.bounds), availableHeight)];
    controls.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    controls.alwaysBounceVertical = YES;
    controls.showsVerticalScrollIndicator = NO;
    [panel addSubview:controls];

    CGFloat width = (CGRectGetWidth(panel.bounds) - 36) / 2.0;
    CGFloat y = 0;

    UIButton *searchButton = [self cardButton:@"بحث بإحداثية أو رابط أو عنوان"
                                       symbol:@"magnifyingglass"
                                        frame:CGRectMake(14, y, CGRectGetWidth(panel.bounds) - 28, 44)
                                       action:@selector(showMapSearch)];
    searchButton.backgroundColor = FGColor(37, 39, 45);
    searchButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [controls addSubview:searchButton];
    y += 50;

    UIButton *toggle = [self cardButton:@"تفعيل GPS" symbol:@"location.fill" frame:CGRectMake(14, y, width, 44) action:@selector(toggleGPS:)];
    toggle.backgroundColor = FGColor(33, 166, 92);
    self.gpsToggleButton = toggle;

    UIButton *favorites = [self cardButton:@"المفضلة" symbol:@"star.fill" frame:CGRectMake(22 + width, y, width, 44) action:@selector(favoritesMenuTapped)];
    favorites.backgroundColor = FGColor(148, 76, 220);
    [controls addSubview:toggle];
    [controls addSubview:favorites];
    y += 50;

    UIButton *settingsAndFunctions = [self cardButton:@"الإعدادات والوظائف"
                                               symbol:@"slider.horizontal.3"
                                                frame:CGRectMake(14, y, CGRectGetWidth(panel.bounds) - 28, 44)
                                               action:@selector(openSettingsAndFunctions)];
    settingsAndFunctions.backgroundColor = FGColor(25, 103, 210);
    settingsAndFunctions.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [controls addSubview:settingsAndFunctions];
    y += 50;

    UILabel *coord = [[UILabel alloc] initWithFrame:CGRectMake(14, y, CGRectGetWidth(panel.bounds) - 28, 40)];
    coord.text = @"24.713600, 46.675300";
    coord.textColor = UIColor.whiteColor;
    coord.textAlignment = NSTextAlignmentCenter;
    coord.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightMedium];
    coord.backgroundColor = FGColor(17, 21, 26);
    coord.layer.cornerRadius = 13;
    coord.clipsToBounds = YES;
    self.coordinateLabel = coord;
    [controls addSubview:coord];
    y += 48;

    UIButton *choose = [self cardButton:@"اختر هذا الموقع" symbol:@"mappin.and.ellipse" frame:CGRectMake(14, y, CGRectGetWidth(panel.bounds) - 28, 44) action:@selector(chooseCurrentLocation)];
    choose.backgroundColor = FGColor(30, 105, 232);
    choose.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [controls addSubview:choose];
    y += 52;

    controls.contentSize = CGSizeMake(CGRectGetWidth(panel.bounds), y);

    [self refreshMenuState];
    [self.hostWindow bringSubviewToFront:panel];
}

- (void)refreshMenuState {
    BOOL enabled = FGSimulationEnabled();
    self.statusLabel.text = enabled ? @"● GPS متصل — تغيير الموقع نشط" : @"● GPS جاهز — تغيير الموقع متوقف";
    self.statusLabel.textColor = enabled ? FGColor(52, 211, 117) : FGColor(248, 184, 61);
    [self.gpsToggleButton setTitle:(enabled ? @"إيقاف GPS" : @"تفعيل GPS") forState:UIControlStateNormal];
}

- (void)changeMapProvider:(UISegmentedControl *)sender {
    if (sender.selectedSegmentIndex == 2) {
        self.mapView.mapType = MKMapTypeSatellite;
        return;
    }

    self.mapView.mapType = MKMapTypeStandard;
    if (sender.selectedSegmentIndex == 1) {
        NSString *query = self.lastMapQuery.length ? self.lastMapQuery :
            [NSString stringWithFormat:@"%.6f,%.6f", self.selectedCoordinate.latitude, self.selectedCoordinate.longitude];
        [self openGoogleMapsForQuery:query];
    }
}

- (void)openGoogleMapsForQuery:(NSString *)query {
    NSString *value = query.length ? query :
        [NSString stringWithFormat:@"%.6f,%.6f", self.selectedCoordinate.latitude, self.selectedCoordinate.longitude];
    NSString *encoded = [value stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/maps/search/?api=1&query=%@", encoded ?: @""]];
    if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

- (void)openSelectedLocationInAppleMaps {
    NSString *urlString = [NSString stringWithFormat:@"http://maps.apple.com/?ll=%.6f,%.6f&q=Wolf%%20GPS",
                           self.selectedCoordinate.latitude, self.selectedCoordinate.longitude];
    NSURL *url = [NSURL URLWithString:urlString];
    if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

- (void)chooseCurrentLocation {
    [self selectCoordinate:self.mapView.centerCoordinate];
    [self showMessage:@"تم اختيار الموقع الحالي على الخريطة."];
}

- (void)locateUserOnMap {
    CLLocation *location = self.mapView.userLocation.location;
    if (!location) {
        [self showMessage:@"لم يتم تحديد موقعك الحالي بعد."];
        return;
    }
    [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(location.coordinate, 900, 900) animated:YES];
}

- (void)placePinAtMapCenter {
    [self selectCoordinate:self.mapView.centerCoordinate];
}

- (void)showMapSearch {
    UIViewController *controller = self.hostWindow.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"البحث عن موقع"
                                                                   message:@"إحداثية، رابط Apple/Google Maps، رمز مختصر، أو عنوان"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"24.7136, 46.6753";
        field.textAlignment = NSTextAlignmentCenter;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"رجوع" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"بحث" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UISearchBar *temporarySearch = [UISearchBar new];
        temporarySearch.text = alert.textFields.firstObject.text;
        [self searchBarSearchButtonClicked:temporarySearch];
    }]];
    [controller presentViewController:alert animated:YES completion:nil];
}

- (void)favoritesMenuTapped {
    UIViewController *controller = self.hostWindow.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;

    NSArray *favorites = [FGDefaults() arrayForKey:FGFavorites] ?: @[];
    NSString *message = [NSString stringWithFormat:@"المواقع المحفوظة: %lu", (unsigned long)favorites.count];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"المفضلة"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"حفظ الموقع الحالي" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self saveCurrentLocation];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"عرض المواقع المحفوظة" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self showFavorites];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"حذف جميع المفضلة" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [FGDefaults() removeObjectForKey:FGFavorites];
        [FGDefaults() synchronize];
        [self showMessage:@"تم حذف جميع المواقع المحفوظة."];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"رجوع" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = self.menuView;
    alert.popoverPresentationController.sourceRect = self.menuView.bounds;
    [controller presentViewController:alert animated:YES completion:nil];
}

- (void)openSettingsAndFunctions {
    UIViewController *controller = self.hostWindow.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"الإعدادات والوظائف"
                                                                   message:@"اختر القسم"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"قسم المعرّف" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self idSettingsTapped]; });
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"قسم البلوتوث" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self bluetoothSettingsTapped]; });
    }]];

    BOOL uploadEnabled = [FGDefaults() boolForKey:FGUploadEnabled];
    NSString *uploadTitle = uploadEnabled ? @"إيقاف رفع الصور" : @"تفعيل رفع الصور من الأستوديو";
    UIAlertActionStyle uploadStyle = uploadEnabled ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault;
    [alert addAction:[UIAlertAction actionWithTitle:uploadTitle style:uploadStyle handler:^(__unused UIAlertAction *action) {
        [self setUploadEnabled:!uploadEnabled];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"رجوع" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = self.menuView;
    alert.popoverPresentationController.sourceRect = self.menuView.bounds;
    [controller presentViewController:alert animated:YES completion:nil];
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

- (void)toggleGPS:(__unused UIButton *)sender {
    [self toggleFakeGPS];
}

- (void)toggleUpload:(__unused UIButton *)sender {
    [self setUploadEnabled:![FGDefaults() boolForKey:FGUploadEnabled]];
}

- (void)setUploadEnabled:(BOOL)enabled {
    [FGDefaults() setBool:enabled forKey:FGUploadEnabled];
    [FGDefaults() synchronize];
    [self refreshUploadFloatingIcon];
    [self showMessage:(enabled ? @"تم تفعيل أيقونة اختيار الصور." : @"تم إيقاف أيقونة اختيار الصور.")];
}

- (void)refreshUploadFloatingIcon {
    BOOL enabled = [FGDefaults() boolForKey:FGUploadEnabled];
    if (!enabled) {
        self.uploadIconWindow.hidden = YES;
        return;
    }

    if (!self.uploadIconWindow) {
        CGRect screenBounds = UIScreen.mainScreen.bounds;
        CGRect iconFrame = CGRectMake(CGRectGetWidth(screenBounds) - 66, CGRectGetMidY(screenBounds) - 27, 54, 54);
        UIWindow *window = nil;

        if (@available(iOS 13.0, *)) {
            UIWindowScene *activeScene = nil;
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if ([scene isKindOfClass:UIWindowScene.class] && scene.activationState == UISceneActivationStateForegroundActive) {
                    activeScene = (UIWindowScene *)scene;
                    break;
                }
            }
            if (activeScene) window = [[UIWindow alloc] initWithWindowScene:activeScene];
        }
        if (!window) window = [[UIWindow alloc] initWithFrame:iconFrame];
        window.frame = iconFrame;
        window.windowLevel = UIWindowLevelStatusBar + 350;
        window.backgroundColor = UIColor.clearColor;
        window.rootViewController = [UIViewController new];

        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = window.bounds;
        button.layer.cornerRadius = 27;
        button.backgroundColor = FGColor(126, 77, 214);
        button.tintColor = UIColor.whiteColor;
        [button setImage:FGSymbol(@"photo.on.rectangle.angled") forState:UIControlStateNormal];
        button.layer.shadowColor = UIColor.blackColor.CGColor;
        button.layer.shadowOpacity = 0.4;
        button.layer.shadowRadius = 8;
        [button addTarget:self action:@selector(openPhotoLibrary) forControlEvents:UIControlEventTouchUpInside];
        [window.rootViewController.view addSubview:button];

        self.uploadIconWindow = window;
        self.uploadIconButton = button;
    }

    self.uploadIconWindow.hidden = NO;
}

- (void)openPhotoLibrary {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        [self showMessage:@"الأستوديو غير متاح."];
        return;
    }

    UIImagePickerController *picker = [UIImagePickerController new];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = YES;
    [self.uploadIconWindow.rootViewController presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    NSData *data = image ? UIImageJPEGRepresentation(image, 0.94) : nil;
    NSString *path = @"/var/mobile/Library/Preferences/WolfGPS_SelectedImage.jpg";
    BOOL saved = data.length > 0 && [data writeToFile:path atomically:YES];

    if (saved) {
        [FGDefaults() setObject:path forKey:@"FGSelectedUploadImagePath"];
        [FGDefaults() synchronize];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFSTR("fun.p3nd.fakegps/selected-image-changed"),
                                             NULL, NULL, true);
    }

    [picker dismissViewControllerAnimated:YES completion:^{
        [self showMessage:(saved ? @"تم اختيار الصورة من الأستوديو." : @"تعذر حفظ الصورة.")];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)enableBluetooth {
    if (!self.foundDevices) self.foundDevices = [NSMutableArray array];
    self.btManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
    [FGDefaults() setBool:YES forKey:FGBluetoothEnabled];
    [FGDefaults() synchronize];

}

- (void)scanForBLEDevices {
    if (!self.btManager) {
        [self enableBluetooth];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.btManager.state == CBManagerStatePoweredOn) {
                [self.btManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@NO}];
            }
        });
        return;
    }
    if (self.btManager.state != CBManagerStatePoweredOn) {
        [self showMessage:@"البلوتوث غير متاح أو غير مشغل."];
        return;
    }
    [self.foundDevices removeAllObjects];
    [self.btManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@NO}];
    [self showMessage:@"جاري البحث عن أجهزة BLE..."];
}

- (void)showBLEDevicesList {
    if (self.foundDevices.count == 0) {
        [self showMessage:@"لا توجد أجهزة مكتشفة."];
        return;
    }

    UIViewController *controller = self.hostWindow.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"أجهزة الرادار"
                                                                   message:@"اختر جهازًا لحفظه والاتصال به تلقائيًا"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    for (CBPeripheral *peripheral in self.foundDevices) {
        NSString *title = peripheral.name.length ? peripheral.name : @"جهاز غير معروف";
        if ([peripheral.identifier isEqual:self.savedRadarUUID]) {
            title = [title stringByAppendingString:@"  ✓"];
        }
        [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [self saveRadarPlan:peripheral];
            [self.btManager stopScan];
            [self.btManager connectPeripheral:peripheral options:nil];
            [self showMessage:[NSString stringWithFormat:@"تم حفظ خطة الرادار:\n%@", self.savedRadarName]];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"رجوع" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = self.menuView;
    alert.popoverPresentationController.sourceRect = self.menuView.bounds;
    [controller presentViewController:alert animated:YES completion:nil];
}

- (void)bluetoothSettingsTapped {
    UIViewController *controller = self.hostWindow.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"إعدادات البلوتوث" message:@"خيارات التحكم بالبلوتوث والرادار" preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"تشغيل والبحث عن أجهزة" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self enableBluetooth];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self scanForBLEDevices];
        });
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"عرض الأجهزة المكتشفة" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self showBLEDevicesList];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إيقاف البحث" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self.btManager stopScan];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"مسح قائمة الأجهزة" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [self.foundDevices removeAllObjects];
    }]];
    if (self.savedRadarUUID) {
        NSString *savedTitle = [NSString stringWithFormat:@"حذف خطة الرادار (%@)", self.savedRadarName ?: @"جهاز محفوظ"];
        [alert addAction:[UIAlertAction actionWithTitle:savedTitle style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
            [self clearRadarPlan];
            [self showMessage:@"تم حذف خطة الرادار المحفوظة."];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"فتح إعدادات النظام" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSURL *url = [NSURL URLWithString:@"App-Prefs:root=Bluetooth"];
        if (url && [UIApplication.sharedApplication canOpenURL:url]) {
            [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"رجوع" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = self.menuView;
    alert.popoverPresentationController.sourceRect = self.menuView.bounds;
    [controller presentViewController:alert animated:YES completion:nil];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    BOOL poweredOn = central.state == CBManagerStatePoweredOn;
    [FGDefaults() setBool:poweredOn forKey:FGBluetoothEnabled];
    [FGDefaults() synchronize];

    if (poweredOn && self.autoRadarEnabled && self.savedRadarUUID) {
        [self.foundDevices removeAllObjects];
        [central scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@NO}];
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if (!self.foundDevices) self.foundDevices = [NSMutableArray array];
    if (![self.foundDevices containsObject:peripheral]) [self.foundDevices addObject:peripheral];

    if (self.autoRadarEnabled &&
        self.savedRadarUUID &&
        [peripheral.identifier isEqual:self.savedRadarUUID] &&
        self.savedRadarDevice != peripheral) {
        self.savedRadarDevice = peripheral;
        [central stopScan];
        [central connectPeripheral:peripheral options:nil];
    }
}

- (void)saveRadarPlan:(CBPeripheral *)device {
    if (!device.identifier) return;

    self.savedRadarUUID = device.identifier;
    self.savedRadarName = device.name.length ? device.name : @"جهاز غير معروف";
    self.savedRadarDevice = device;
    self.autoRadarEnabled = YES;

    NSUserDefaults *defaults = FGDefaults();
    [defaults setObject:device.identifier.UUIDString forKey:@"radar_uuid"];
    [defaults setObject:self.savedRadarName forKey:@"radar_name"];
    [defaults setBool:YES forKey:@"radar_auto_enabled"];
    [defaults synchronize];
}

- (void)loadRadarPlan {
    NSUserDefaults *defaults = FGDefaults();
    NSString *uuidString = [defaults stringForKey:@"radar_uuid"];
    NSString *name = [defaults stringForKey:@"radar_name"];

    NSUUID *uuid = uuidString.length ? [[NSUUID alloc] initWithUUIDString:uuidString] : nil;
    if (uuid) {
        self.savedRadarUUID = uuid;
        self.savedRadarName = name.length ? name : @"جهاز محفوظ";
        self.autoRadarEnabled = [defaults objectForKey:@"radar_auto_enabled"] ?
                                [defaults boolForKey:@"radar_auto_enabled"] : YES;
    }
}

- (void)clearRadarPlan {
    self.autoRadarEnabled = NO;
    self.savedRadarUUID = nil;
    self.savedRadarName = nil;
    self.savedRadarDevice = nil;

    NSUserDefaults *defaults = FGDefaults();
    [defaults removeObjectForKey:@"radar_uuid"];
    [defaults removeObjectForKey:@"radar_name"];
    [defaults removeObjectForKey:@"radar_auto_enabled"];
    [defaults synchronize];
}

- (void)addFavorite {
    NSString *item = [NSString stringWithFormat:@"%.6f, %.6f", self.selectedCoordinate.latitude, self.selectedCoordinate.longitude];
    NSMutableArray *favorites = [[FGDefaults() arrayForKey:FGFavorites] mutableCopy] ?: [NSMutableArray array];
    if (![favorites containsObject:item]) [favorites addObject:item];
    [FGDefaults() setObject:favorites forKey:FGFavorites];
    [FGDefaults() synchronize];
    [self showMessage:@"تم حفظ الموقع في المفضلة"];
}

- (void)saveCurrentLocation {
    [self addFavorite];
}

- (void)favoritesSettingsTapped {
    UIViewController *controller = self.hostWindow.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"إعدادات المفضلة" message:@"خيارات التحكم بالمفضلة" preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"حذف جميع المفضلة" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [FGDefaults() removeObjectForKey:FGFavorites];
        [FGDefaults() synchronize];
        [self showMessage:@"تم حذف جميع المواقع المحفوظة."];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"رجوع" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = self.menuView;
    alert.popoverPresentationController.sourceRect = self.menuView.bounds;
    [controller presentViewController:alert animated:YES completion:nil];
}

- (void)showFavorites {
    NSArray *favorites = [FGDefaults() arrayForKey:FGFavorites] ?: @[];
    NSString *message = favorites.count ? [favorites componentsJoinedByString:@"\n"] : @"لا توجد مواقع محفوظة";
    [self showMessage:message];
}

- (void)showDeviceID {
    [self showMessage:[NSString stringWithFormat:@"المعرف الحالي:\n%@", FGCurrentDeviceIdentifier()]];
}

- (void)extractAutomaticDeviceIdentifier {
    NSString *automaticID = UIDevice.currentDevice.identifierForVendor.UUIDString;
    if (automaticID.length == 0) automaticID = NSUUID.UUID.UUIDString;
    self.manualIDField.text = automaticID;
}

- (void)saveDeviceIdentifier {
    NSString *enteredID = [self.manualIDField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (enteredID.length == 0) {
        enteredID = UIDevice.currentDevice.identifierForVendor.UUIDString;
        if (enteredID.length == 0) enteredID = NSUUID.UUID.UUIDString;
    }

    if (enteredID.length < 8 || enteredID.length > 128) {
        [self showMessage:@"يجب أن يكون المعرف بين 8 و128 خانة."];
        return;
    }

    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_:."] invertedSet];
    if ([enteredID rangeOfCharacterFromSet:invalid].location != NSNotFound) {
        [self showMessage:@"المعرف يقبل الحروف الإنجليزية والأرقام والرموز - _ : . فقط."];
        return;
    }

    NSString *previousID = FGCurrentDeviceIdentifier();
    BOOL changed = ![previousID isEqualToString:enteredID];
    NSUserDefaults *defaults = FGDefaults();
    [defaults setObject:enteredID forKey:FGDeviceIdentifierKey];
    [defaults setObject:enteredID forKey:@"saved_device_id"];
    [defaults setObject:enteredID forKey:@"FGDeviceUUID"];
    if (changed) {
        [defaults setBool:NO forKey:@"FGLicenseActive"];
        [defaults removeObjectForKey:@"FGLicenseToken"];
    }
    [defaults synchronize];
    self.manualIDField.text = enteredID;

    UIViewController *controller = self.hostWindow.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تم حفظ المعرف"
                                                                   message:enteredID
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        if (changed) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"GPSQResetActivation" object:nil];
            [self closeMenu];
        }
    }]];
    [controller presentViewController:alert animated:YES completion:nil];
}

- (void)generateNewID {
    NSString *newIdentifier = NSUUID.UUID.UUIDString;
    NSUserDefaults *defaults = FGDefaults();
    [defaults setObject:newIdentifier forKey:FGDeviceIdentifierKey];
    [defaults setObject:newIdentifier forKey:@"saved_device_id"];
    [defaults setObject:newIdentifier forKey:@"FGDeviceUUID"];
    [defaults setBool:NO forKey:@"FGLicenseActive"];
    [defaults removeObjectForKey:@"FGLicenseToken"];
    [defaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GPSQResetActivation" object:nil];
    [self showMessage:[NSString stringWithFormat:@"تم إنشاء معرف جديد:\n%@", newIdentifier]];
}

- (void)copyDeviceID {
    UIPasteboard.generalPasteboard.string = FGCurrentDeviceIdentifier();
    [self showMessage:@"تم نسخ المعرف إلى الحافظة."];
}

- (void)presentDeviceIdentifierEditorWithValue:(NSString *)value title:(NSString *)title {
    UIViewController *controller = self.hostWindow.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;

    UIAlertController *editor = [UIAlertController alertControllerWithTitle:title
                                                                    message:@"راجع المعرف ثم اضغط حفظ"
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [editor addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = value;
        field.placeholder = @"أدخل معرف الجهاز";
        field.textAlignment = NSTextAlignmentCenter;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        self.manualIDField = field;
    }];
    [editor addAction:[UIAlertAction actionWithTitle:@"رجوع" style:UIAlertActionStyleCancel handler:nil]];
    [editor addAction:[UIAlertAction actionWithTitle:@"حفظ المعرف" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self saveDeviceIdentifier];
    }]];
    [controller presentViewController:editor animated:YES completion:nil];
}

- (void)idSettingsTapped {
    UIViewController *controller = self.hostWindow.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"إعدادات المعرف"
                                                                   message:FGCurrentDeviceIdentifier()
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:[UIAlertAction actionWithTitle:@"إضافة المعرف يدويًا" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentDeviceIdentifierEditorWithValue:FGCurrentDeviceIdentifier() title:@"إضافة المعرف يدويًا"];
        });
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"استخراج المعرف تلقائيًا" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *automaticID = UIDevice.currentDevice.identifierForVendor.UUIDString ?: NSUUID.UUID.UUIDString;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentDeviceIdentifierEditorWithValue:automaticID title:@"المعرف التلقائي"];
        });
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"نسخ المعرف" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self copyDeviceID];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إعادة التفعيل" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"GPSQShowActivation" object:nil];
        [self closeMenu];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"رجوع" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = self.menuView;
    alert.popoverPresentationController.sourceRect = self.menuView.bounds;
    [controller presentViewController:alert animated:YES completion:nil];
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

- (void)resolveSharedMapLink:(NSString *)linkText {
    NSString *trimmed = [linkText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSURL *url = [NSURL URLWithString:trimmed];
    if (!url) {
        [self showMessage:@"رابط الخريطة غير صالح."];
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:15.0];
    request.HTTPMethod = @"GET";

    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(__unused NSData *data, NSURLResponse *response, NSError *error) {
        NSString *resolved = response.URL.absoluteString ?: trimmed;
        CLLocationCoordinate2D coordinate;
        BOOL found = !error && FGExtractCoordinatesFromText(resolved, &coordinate);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (found) {
                [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(coordinate, 900, 900) animated:YES];
                [self selectCoordinate:coordinate];
                return;
            }

            NSString *lower = trimmed.lowercaseString;
            if ([lower containsString:@"google"] || [lower containsString:@"goo.gl"]) {
                [self openGoogleMapsForQuery:trimmed];
            } else {
                [self showMessage:@"تعذر استخراج الإحداثيات من الرابط. افتح الرابط ثم انسخ الإحداثية الظاهرة."];
            }
        });
    }] resume];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    NSString *query = [searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (query.length == 0) return;
    self.lastMapQuery = query;

    CLLocationCoordinate2D pastedCoordinate;
    if (FGExtractCoordinatesFromText(query, &pastedCoordinate)) {
        [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(pastedCoordinate, 900, 900) animated:YES];
        [self selectCoordinate:pastedCoordinate];
        return;
    }

    if (FGLooksLikeSharedMapLink(query)) {
        [self resolveSharedMapLink:query];
        return;
    }

    if (self.mapProviderControl.selectedSegmentIndex == 1 || [query containsString:@"+"]) {
        [self openGoogleMapsForQuery:query];
        return;
    }

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
    request.region = self.mapView.region;
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request];
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        if (error || response.mapItems.count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showMessage:@"لم يتم العثور على الموقع. جرّب Google Maps للرموز المختصرة."];
            });
            return;
        }
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
