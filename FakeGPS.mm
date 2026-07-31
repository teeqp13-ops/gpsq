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

@interface FGManager : NSObject <UISearchBarDelegate, MKMapViewDelegate, CBCentralManagerDelegate>
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
@property(nonatomic,strong) CBCentralManager *btManager;
@property(nonatomic,strong) NSMutableArray<CBPeripheral *> *foundDevices;
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
        [self attachWhenReady];
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
    title.text = @"Wolf GPS V17";
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

    CGFloat mapHeight = MIN(250, MAX(180, panel.bounds.size.height * 0.24));
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

    CGFloat rowY = CGRectGetMaxY(coord.frame) + 8;
    CGFloat availableHeight = CGRectGetHeight(panel.bounds) - rowY - MAX(self.hostWindow.safeAreaInsets.bottom, 8);
    UIScrollView *features = [[UIScrollView alloc] initWithFrame:CGRectMake(0, rowY, CGRectGetWidth(panel.bounds), availableHeight)];
    features.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    features.alwaysBounceVertical = YES;
    features.showsVerticalScrollIndicator = NO;
    [panel addSubview:features];

    CGFloat gap = 8;
    CGFloat width = (CGRectGetWidth(panel.bounds) - 36) / 2.0;
    CGFloat y = 0;

    NSString *identifier = FGCurrentDeviceIdentifier();
    NSString *suffix = identifier.length > 8 ? [identifier substringFromIndex:identifier.length - 8] : identifier;
    UILabel *identifierCard = [[UILabel alloc] initWithFrame:CGRectMake(14, y, CGRectGetWidth(panel.bounds) - 28, 42)];
    identifierCard.text = [NSString stringWithFormat:@"معرف الجهاز    •••• %@", suffix];
    identifierCard.textColor = UIColor.whiteColor;
    identifierCard.textAlignment = NSTextAlignmentCenter;
    identifierCard.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightSemibold];
    identifierCard.backgroundColor = FGColor(17, 21, 26);
    identifierCard.layer.cornerRadius = 13;
    identifierCard.clipsToBounds = YES;
    [features addSubview:identifierCard];
    y += 50;

    UILabel *(^sectionLabel)(NSString *, CGFloat) = ^UILabel *(NSString *text, CGFloat originY) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(18, originY, CGRectGetWidth(panel.bounds) - 36, 28)];
        label.text = text;
        label.textColor = FGColor(130, 174, 255);
        label.textAlignment = NSTextAlignmentRight;
        label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
        [features addSubview:label];
        return label;
    };

    sectionLabel(@"مجموعة المعرف", y); y += 32;
    UIButton *showID = [self cardButton:@"عرض المعرف الحالي" symbol:@"iphone" frame:CGRectMake(14, y, width, 48) action:@selector(showDeviceID)];
    UIButton *newID = [self cardButton:@"إنشاء معرف جديد" symbol:@"arrow.triangle.2.circlepath" frame:CGRectMake(22 + width, y, width, 48) action:@selector(generateNewID)];
    [features addSubview:showID]; [features addSubview:newID]; y += 56;
    UIButton *copyID = [self cardButton:@"نسخ المعرف" symbol:@"doc.on.doc" frame:CGRectMake(14, y, width, 48) action:@selector(copyDeviceID)];
    UIButton *idSettings = [self cardButton:@"إعدادات المعرف" symbol:@"gearshape" frame:CGRectMake(22 + width, y, width, 48) action:@selector(idSettingsTapped)];
    [features addSubview:copyID]; [features addSubview:idSettings]; y += 62;

    sectionLabel(@"مجموعة البلوتوث", y); y += 32;
    UIButton *enableBT = [self cardButton:@"تشغيل البلوتوث" symbol:@"bolt.horizontal.circle" frame:CGRectMake(14, y, width, 48) action:@selector(enableBluetooth)];
    UIButton *scanBT = [self cardButton:@"بحث عن أجهزة" symbol:@"dot.radiowaves.left.and.right" frame:CGRectMake(22 + width, y, width, 48) action:@selector(scanForBLEDevices)];
    [features addSubview:enableBT]; [features addSubview:scanBT]; y += 56;
    UIButton *showBT = [self cardButton:@"عرض الأجهزة" symbol:@"list.bullet" frame:CGRectMake(14, y, width, 48) action:@selector(showBLEDevicesList)];
    UIButton *settingsBT = [self cardButton:@"إعدادات البلوتوث" symbol:@"gearshape.fill" frame:CGRectMake(22 + width, y, width, 48) action:@selector(bluetoothSettingsTapped)];
    [features addSubview:showBT]; [features addSubview:settingsBT]; y += 62;

    sectionLabel(@"مجموعة المفضلة", y); y += 32;
    UIButton *saveFavorite = [self cardButton:@"حفظ الموقع" symbol:@"star.badge.plus" frame:CGRectMake(14, y, width, 48) action:@selector(saveCurrentLocation)];
    UIButton *showFavorites = [self cardButton:@"عرض المفضلة" symbol:@"star.fill" frame:CGRectMake(22 + width, y, width, 48) action:@selector(showFavorites)];
    [features addSubview:saveFavorite]; [features addSubview:showFavorites]; y += 56;
    UIButton *favoriteSettings = [self cardButton:@"إعدادات المفضلة" symbol:@"slider.horizontal.3" frame:CGRectMake(14, y, CGRectGetWidth(panel.bounds) - 28, 48) action:@selector(favoritesSettingsTapped)];
    [features addSubview:favoriteSettings]; y += 62;

    sectionLabel(@"التحكم", y); y += 32;
    UIButton *toggle = [self cardButton:@"تفعيل تغيير الموقع" symbol:@"location.fill" frame:CGRectMake(14, y, width, 48) action:@selector(toggleGPS:)];
    self.gpsToggleButton = toggle;
    UIButton *upload = [self cardButton:@"تفعيل رفع الصور" symbol:@"photo.on.rectangle" frame:CGRectMake(22 + width, y, width, 48) action:@selector(toggleUpload:)];
    [features addSubview:toggle]; [features addSubview:upload]; y += 56;
    UIButton *hide = [self cardButton:@"إخفاء زر الأداة" symbol:@"eye.slash.fill" frame:CGRectMake(14, y, CGRectGetWidth(panel.bounds) - 28, 48) action:@selector(hideFloating)];
    [features addSubview:hide]; y += 64;

    features.contentSize = CGSizeMake(CGRectGetWidth(panel.bounds), y);

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

- (void)enableBluetooth {
    if (!self.foundDevices) self.foundDevices = [NSMutableArray array];
    self.btManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
    [FGDefaults() setBool:YES forKey:FGBluetoothEnabled];
    [FGDefaults() synchronize];
    [self showMessage:@"تم تشغيل جلسة البلوتوث."];
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
    NSMutableString *list = [NSMutableString string];
    for (CBPeripheral *peripheral in self.foundDevices) {
        [list appendFormat:@"%@\n", peripheral.name.length ? peripheral.name : @"جهاز غير معروف"];
    }
    [self showMessage:list.length ? list : @"لا توجد أجهزة مكتشفة."];
}

- (void)bluetoothSettingsTapped {
    UIViewController *controller = self.hostWindow.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"إعدادات البلوتوث" message:@"خيارات التحكم بالبلوتوث" preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"إيقاف البحث" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [self.btManager stopScan];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"مسح قائمة الأجهزة" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [self.foundDevices removeAllObjects];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"فتح إعدادات النظام" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSURL *url = [NSURL URLWithString:@"App-Prefs:root=Bluetooth"];
        if (url && [UIApplication.sharedApplication canOpenURL:url]) {
            [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = self.menuView;
    alert.popoverPresentationController.sourceRect = self.menuView.bounds;
    [controller presentViewController:alert animated:YES completion:nil];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    BOOL poweredOn = central.state == CBManagerStatePoweredOn;
    [FGDefaults() setBool:poweredOn forKey:FGBluetoothEnabled];
    [FGDefaults() synchronize];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if (!self.foundDevices) self.foundDevices = [NSMutableArray array];
    if (![self.foundDevices containsObject:peripheral]) [self.foundDevices addObject:peripheral];
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
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
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

- (void)generateNewID {
    NSString *newIdentifier = NSUUID.UUID.UUIDString;
    NSUserDefaults *defaults = FGDefaults();
    [defaults setObject:newIdentifier forKey:FGDeviceIdentifierKey];
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

- (void)idSettingsTapped {
    UIViewController *controller = self.hostWindow.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"إعدادات المعرف" message:@"خيارات التحكم بالمعرف" preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"إعادة التعيين" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [self generateNewID];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إعادة التفعيل" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"GPSQShowActivation" object:nil];
        [self closeMenu];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
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
