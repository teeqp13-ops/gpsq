#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import "WFThemeManager.h"
#import "WFLocalization.h"
#import "WFFavoritesStore.h"
#import "WFFavoritesViewController.h"
#import "WFGPXMovementManager.h"

static CFStringRef const WFPanelSharedDomain = CFSTR("fun.p3nd.fakegps");
static NSString *const WFPanelFloatXKey = @"WFPanelFloatX";
static NSString *const WFPanelFloatYKey = @"WFPanelFloatY";
static NSString *const WFPanelHiddenKey = @"WFPanelHidden";

static void WFPanelWriteShared(NSString *key, id value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             value ? (__bridge CFPropertyListRef)value : NULL,
                             WFPanelSharedDomain);
    CFPreferencesAppSynchronize(WFPanelSharedDomain);
}

static UIImage *WFPanelSymbol(NSString *name) {
    if (@available(iOS 13.0, *)) return [UIImage systemImageNamed:name];
    return nil;
}

static BOOL WFPanelLicenseActive(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    return [defaults boolForKey:@"FGLicenseActive"] && [defaults stringForKey:@"FGLicenseCode"].length > 0;
}

static UIViewController *WFPanelTopController(UIWindow *window) {
    UIViewController *controller = window.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    return controller;
}

@interface FGManager : NSObject
+ (instancetype)shared;
- (void)fg_showActivationGate;
@end

@interface WFModernPanelManager : NSObject <UISearchBarDelegate, MKMapViewDelegate, MKLocalSearchCompleterDelegate, UITableViewDataSource, UITableViewDelegate, UIDocumentPickerDelegate>
@property (nonatomic, weak) UIWindow *hostWindow;
@property (nonatomic, strong) UIButton *floatingButton;
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) UIVisualEffectView *sheetView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *suggestionsTable;
@property (nonatomic, strong) MKLocalSearchCompleter *searchCompleter;
@property (nonatomic, copy) NSArray<MKLocalSearchCompletion *> *suggestions;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *coordinateLabel;
@property (nonatomic, strong) UIButton *gpsButton;
@property (nonatomic, strong) UIButton *movementButton;
@property (nonatomic, strong) UISegmentedControl *speedControl;
@property (nonatomic, strong) MKPointAnnotation *pin;
@property (nonatomic, assign) CLLocationCoordinate2D selectedCoordinate;
@property (nonatomic, assign) CGFloat sheetStartY;
@property (nonatomic, assign) NSInteger retryCount;
@property (nonatomic, assign) NSInteger volumeCount;
@property (nonatomic, assign) NSTimeInterval lastVolumeTime;
@property (nonatomic, strong) WFGPXMovementManager *movementManager;
+ (instancetype)shared;
- (void)start;
@end

@implementation WFModernPanelManager

+ (instancetype)shared {
    static WFModernPanelManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [WFModernPanelManager new]; });
    return manager;
}

- (instancetype)init {
    if ((self = [super init])) {
        _selectedCoordinate = CLLocationCoordinate2DMake(24.7136, 46.6753);
        _suggestions = @[];
        _movementManager = [WFGPXMovementManager new];
        __weak typeof(self) weakSelf = self;
        _movementManager.coordinateHandler = ^(CLLocationCoordinate2D coordinate) {
            [weakSelf selectCoordinate:coordinate center:YES];
        };
        _movementManager.completionHandler = ^{
            [weakSelf refreshState];
        };
    }
    return self;
}

- (UIColor *)primaryTextColor {
    return [[WFThemeManager shared] primaryTextColorForTraitCollection:self.hostWindow.traitCollection];
}

- (UIColor *)secondaryTextColor {
    return [[WFThemeManager shared] secondaryTextColorForTraitCollection:self.hostWindow.traitCollection];
}

- (UIColor *)glassCardColor {
    return [[[WFThemeManager shared] cardColorForTraitCollection:self.hostWindow.traitCollection] colorWithAlphaComponent:0.82];
}

- (UIWindow *)bestWindow {
    UIApplication *application = UIApplication.sharedApplication;
    for (UIWindow *window in application.windows.reverseObjectEnumerator) {
        if (!window.hidden && window.alpha > 0 && window.windowLevel == UIWindowLevelNormal) return window;
    }
    return application.keyWindow ?: application.windows.firstObject;
}

- (void)start {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeChanged:) name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rebuildPanel) name:WFThemeDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rebuildPanel) name:WFLanguageDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openPanel) name:@"GPSQOpenModernPanel" object:nil];
        [self attachWhenReady];
    });
}

- (void)attachWhenReady {
    if (self.floatingButton.superview) return;
    self.hostWindow = [self bestWindow];
    if (!self.hostWindow) {
        if (self.retryCount++ < 50) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self attachWhenReady]; });
        }
        return;
    }
    [self buildFloatingButton];
}

- (void)buildFloatingButton {
    [self.floatingButton removeFromSuperview];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(18, 150, 62, 62);
    button.layer.cornerRadius = 31;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.28].CGColor;
    button.tintColor = UIColor.whiteColor;
    [button setImage:WFPanelSymbol(@"location.fill") forState:UIControlStateNormal];
    [button addTarget:self action:@selector(openPanel) forControlEvents:UIControlEventTouchUpInside];
    [button addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragFloating:)]];

    CGFloat x = [NSUserDefaults.standardUserDefaults doubleForKey:WFPanelFloatXKey];
    CGFloat y = [NSUserDefaults.standardUserDefaults doubleForKey:WFPanelFloatYKey];
    if (x > 0 && y > 0) button.center = CGPointMake(x, y);
    button.hidden = [NSUserDefaults.standardUserDefaults boolForKey:WFPanelHiddenKey];

    self.floatingButton = button;
    [self refreshFloatingButton];
    [self.hostWindow addSubview:button];
    [self.hostWindow bringSubviewToFront:button];
}

- (void)refreshFloatingButton {
    BOOL enabled = [NSUserDefaults.standardUserDefaults boolForKey:@"FGEnabled"];
    UIColor *color = enabled ? [[WFThemeManager shared] successColor] : [[WFThemeManager shared] accentColor];
    self.floatingButton.backgroundColor = [color colorWithAlphaComponent:0.94];
    self.floatingButton.layer.shadowColor = color.CGColor;
    self.floatingButton.layer.shadowOpacity = 0.5;
    self.floatingButton.layer.shadowRadius = 14;
    self.floatingButton.layer.shadowOffset = CGSizeMake(0, 7);
}

- (void)dragFloating:(UIPanGestureRecognizer *)gesture {
    if (!self.hostWindow) return;
    CGPoint translation = [gesture translationInView:self.hostWindow];
    CGPoint center = CGPointMake(self.floatingButton.center.x + translation.x,
                                 self.floatingButton.center.y + translation.y);
    CGFloat half = CGRectGetWidth(self.floatingButton.bounds) / 2.0;
    UIEdgeInsets safe = self.hostWindow.safeAreaInsets;
    center.x = MAX(half + 8, MIN(CGRectGetWidth(self.hostWindow.bounds) - half - 8, center.x));
    center.y = MAX(safe.top + half + 8, MIN(CGRectGetHeight(self.hostWindow.bounds) - safe.bottom - half - 8, center.y));
    self.floatingButton.center = center;
    [gesture setTranslation:CGPointZero inView:self.hostWindow];

    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        CGFloat targetX = center.x < CGRectGetMidX(self.hostWindow.bounds)
            ? half + 10
            : CGRectGetWidth(self.hostWindow.bounds) - half - 10;
        [UIView animateWithDuration:0.42 delay:0 usingSpringWithDamping:0.74 initialSpringVelocity:0.4 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.floatingButton.center = CGPointMake(targetX, center.y);
        } completion:^(BOOL finished) {
            [NSUserDefaults.standardUserDefaults setDouble:self.floatingButton.center.x forKey:WFPanelFloatXKey];
            [NSUserDefaults.standardUserDefaults setDouble:self.floatingButton.center.y forKey:WFPanelFloatYKey];
            [NSUserDefaults.standardUserDefaults synchronize];
        }];
    }
}

- (UIVisualEffectView *)glassViewWithFrame:(CGRect)frame radius:(CGFloat)radius {
    UIBlurEffect *effect = [[WFThemeManager shared] glassEffectForTraitCollection:self.hostWindow.traitCollection];
    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:effect];
    glass.frame = frame;
    glass.layer.cornerRadius = radius;
    glass.clipsToBounds = YES;
    glass.layer.borderWidth = 1;
    glass.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.17].CGColor;
    return glass;
}

- (UIButton *)iconButton:(NSString *)symbol action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(0, 0, 44, 44);
    button.layer.cornerRadius = 22;
    button.backgroundColor = [self glassCardColor];
    button.tintColor = [self primaryTextColor];
    [button setImage:WFPanelSymbol(symbol) forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIButton *)textButton:(NSString *)title symbol:(NSString *)symbol action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.layer.cornerRadius = 14;
    button.backgroundColor = [self glassCardColor];
    button.tintColor = [self primaryTextColor];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[self primaryTextColor] forState:UIControlStateNormal];
    [button setImage:WFPanelSymbol(symbol) forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    button.semanticContentAttribute = [WFLocalization isArabic] ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    button.imageEdgeInsets = UIEdgeInsetsMake(0, 5, 0, 0);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)openPanel {
    if (!WFPanelLicenseActive()) {
        FGManager *legacy = [FGManager shared];
        if ([legacy respondsToSelector:@selector(fg_showActivationGate)]) [legacy fg_showActivationGate];
        return;
    }

    [self.panelView removeFromSuperview];
    if (!self.hostWindow) self.hostWindow = [self bestWindow];
    if (!self.hostWindow) return;

    UIView *root = [[UIView alloc] initWithFrame:self.hostWindow.bounds];
    root.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    root.backgroundColor = [[WFThemeManager shared] backgroundColorForTraitCollection:self.hostWindow.traitCollection];
    if (@available(iOS 13.0, *)) {
        BOOL dark = [[WFThemeManager shared] isDarkForTraitCollection:self.hostWindow.traitCollection];
        root.overrideUserInterfaceStyle = dark ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    }
    self.panelView = root;
    [self.hostWindow addSubview:root];

    MKMapView *map = [[MKMapView alloc] initWithFrame:root.bounds];
    map.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    map.delegate = self;
    map.showsUserLocation = YES;
    map.mapType = MKMapTypeStandard;
    self.mapView = map;
    [root addSubview:map];

    UILongPressGestureRecognizer *pickGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(pickLocation:)];
    pickGesture.minimumPressDuration = 0.35;
    [map addGestureRecognizer:pickGesture];

    UIEdgeInsets safe = self.hostWindow.safeAreaInsets;
    UIVisualEffectView *topGlass = [self glassViewWithFrame:CGRectMake(12, safe.top + 8, CGRectGetWidth(root.bounds) - 24, 54) radius:20];
    topGlass.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [root addSubview:topGlass];

    UIButton *close = [self iconButton:@"xmark" action:@selector(closePanel)];
    close.frame = CGRectMake(5, 5, 44, 44);
    [topGlass.contentView addSubview:close];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(56, 5, CGRectGetWidth(topGlass.bounds) - 168, 44)];
    title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    title.text = [WFLocalization text:@"title"];
    title.textColor = [self primaryTextColor];
    title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;
    [topGlass.contentView addSubview:title];

    UIButton *theme = [self iconButton:@"circle.lefthalf.filled" action:@selector(toggleTheme)];
    theme.frame = CGRectMake(CGRectGetWidth(topGlass.bounds) - 100, 5, 44, 44);
    theme.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [topGlass.contentView addSubview:theme];

    UIButton *language = [UIButton buttonWithType:UIButtonTypeSystem];
    language.frame = CGRectMake(CGRectGetWidth(topGlass.bounds) - 51, 5, 46, 44);
    language.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    language.layer.cornerRadius = 18;
    language.backgroundColor = [self glassCardColor];
    language.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [language setTitle:[WFLocalization isArabic] ? @"EN" : @"ع" forState:UIControlStateNormal];
    [language addTarget:self action:@selector(toggleLanguage) forControlEvents:UIControlEventTouchUpInside];
    [topGlass.contentView addSubview:language];

    NSArray<NSArray<NSString *> *> *toolSpecs = @[
        @[@"star.fill", @"saveFavorite"],
        @[@"location.fill", @"realLocation"],
        @[@"map.fill", @"cycleMapType"]
    ];
    for (NSUInteger index = 0; index < toolSpecs.count; index++) {
        NSArray<NSString *> *spec = toolSpecs[index];
        UIButton *tool = [self iconButton:spec[0] action:NSSelectorFromString(spec[1])];
        tool.frame = CGRectMake(CGRectGetWidth(root.bounds) - 58, safe.top + 78 + index * 52, 46, 46);
        tool.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [root addSubview:tool];
    }

    CGFloat sheetHeight = MIN(390.0, CGRectGetHeight(root.bounds) - safe.top - 92.0);
    CGFloat sheetY = CGRectGetHeight(root.bounds) - sheetHeight - MAX(safe.bottom, 8.0);
    UIVisualEffectView *sheet = [self glassViewWithFrame:CGRectMake(10, sheetY, CGRectGetWidth(root.bounds) - 20, sheetHeight) radius:28];
    sheet.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.sheetView = sheet;
    [root addSubview:sheet];
    [sheet addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panSheet:)]];

    UIView *content = sheet.contentView;
    [WFLocalization applyDirectionToView:content];

    UIView *grabber = [[UIView alloc] initWithFrame:CGRectMake((CGRectGetWidth(content.bounds) - 42) / 2.0, 8, 42, 5)];
    grabber.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    grabber.layer.cornerRadius = 2.5;
    grabber.backgroundColor = [UIColor colorWithWhite:0.6 alpha:0.65];
    [content addSubview:grabber];

    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(8, 22, CGRectGetWidth(content.bounds) - 16, 46)];
    searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    searchBar.searchBarStyle = UISearchBarStyleMinimal;
    searchBar.placeholder = [WFLocalization text:@"search_placeholder"];
    searchBar.delegate = self;
    searchBar.semanticContentAttribute = [WFLocalization isArabic] ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    self.searchBar = searchBar;
    [content addSubview:searchBar];

    self.searchCompleter = [MKLocalSearchCompleter new];
    self.searchCompleter.delegate = self;
    self.searchCompleter.resultTypes = MKLocalSearchCompleterResultTypeAddress | MKLocalSearchCompleterResultTypePointOfInterest;

    UITableView *suggestions = [[UITableView alloc] initWithFrame:CGRectMake(12, 68, CGRectGetWidth(content.bounds) - 24, 155) style:UITableViewStylePlain];
    suggestions.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    suggestions.layer.cornerRadius = 14;
    suggestions.clipsToBounds = YES;
    suggestions.dataSource = self;
    suggestions.delegate = self;
    suggestions.hidden = YES;
    self.suggestionsTable = suggestions;
    [content addSubview:suggestions];

    UILabel *status = [[UILabel alloc] initWithFrame:CGRectMake(16, 76, CGRectGetWidth(content.bounds) - 32, 28)];
    status.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    status.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    status.textAlignment = NSTextAlignmentCenter;
    self.statusLabel = status;
    [content addSubview:status];

    UILabel *coordinate = [[UILabel alloc] initWithFrame:CGRectMake(16, 108, CGRectGetWidth(content.bounds) - 32, 34)];
    coordinate.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    coordinate.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    coordinate.textAlignment = NSTextAlignmentCenter;
    coordinate.textColor = [self primaryTextColor];
    coordinate.layer.cornerRadius = 12;
    coordinate.clipsToBounds = YES;
    coordinate.backgroundColor = [self glassCardColor];
    self.coordinateLabel = coordinate;
    [content addSubview:coordinate];

    UISegmentedControl *mapType = [[UISegmentedControl alloc] initWithItems:@[
        [WFLocalization text:@"map_standard"],
        [WFLocalization text:@"map_satellite"],
        [WFLocalization text:@"map_hybrid"]
    ]];
    mapType.frame = CGRectMake(16, 150, CGRectGetWidth(content.bounds) - 32, 32);
    mapType.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    mapType.selectedSegmentIndex = 0;
    [mapType addTarget:self action:@selector(mapTypeChanged:) forControlEvents:UIControlEventValueChanged];
    [content addSubview:mapType];

    CGFloat gap = 8;
    CGFloat width = (CGRectGetWidth(content.bounds) - 40 - gap) / 2.0;

    self.gpsButton = [self textButton:@"" symbol:@"location.fill" action:@selector(toggleGPS)];
    self.gpsButton.frame = CGRectMake(16, 192, width, 48);
    self.gpsButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [content addSubview:self.gpsButton];

    UIButton *favoritesButton = [self textButton:[WFLocalization text:@"favorites"] symbol:@"star.fill" action:@selector(showFavorites)];
    favoritesButton.frame = CGRectMake(24 + width, 192, width, 48);
    favoritesButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
    [content addSubview:favoritesButton];

    self.speedControl = [[UISegmentedControl alloc] initWithItems:@[@"1x", @"3x", @"8x", @"15x"]];
    self.speedControl.frame = CGRectMake(16, 250, CGRectGetWidth(content.bounds) - 32, 32);
    self.speedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.speedControl.selectedSegmentIndex = 1;
    [content addSubview:self.speedControl];

    UIButton *loadButton = [self textButton:[WFLocalization text:@"load_gpx"] symbol:@"folder" action:@selector(loadGPX)];
    loadButton.frame = CGRectMake(16, 292, width, 48);
    loadButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [content addSubview:loadButton];

    self.movementButton = [self textButton:[WFLocalization text:@"start_movement"] symbol:@"figure.walk" action:@selector(toggleMovement)];
    self.movementButton.frame = CGRectMake(24 + width, 292, width, 48);
    self.movementButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
    [content addSubview:self.movementButton];

    UIButton *hideButton = [self textButton:[WFLocalization text:@"hide_tool"] symbol:@"eye.slash" action:@selector(hideTool)];
    hideButton.frame = CGRectMake(16, 348, CGRectGetWidth(content.bounds) - 32, 38);
    hideButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [content addSubview:hideButton];

    // Search results must remain above every sheet control and receive touches.
    [content bringSubviewToFront:self.suggestionsTable];

    CLLocationDegrees latitude = [NSUserDefaults.standardUserDefaults doubleForKey:@"FGLatitude"];
    CLLocationDegrees longitude = [NSUserDefaults.standardUserDefaults doubleForKey:@"FGLongitude"];
    CLLocationCoordinate2D initial = CLLocationCoordinate2DMake(latitude, longitude);
    if (!CLLocationCoordinate2DIsValid(initial) || (latitude == 0 && longitude == 0)) initial = self.selectedCoordinate;
    [self selectCoordinate:initial center:YES];
    [self refreshState];
    [self.hostWindow bringSubviewToFront:root];
}

- (void)rebuildPanel {
    if (self.panelView.superview) [self openPanel];
}

- (void)closePanel {
    [self.searchCompleter cancel];
    self.searchCompleter.delegate = nil;
    [self.panelView removeFromSuperview];
    self.panelView = nil;
    if (self.floatingButton.superview) [self.hostWindow bringSubviewToFront:self.floatingButton];
}

- (void)panSheet:(UIPanGestureRecognizer *)gesture {
    if (!self.sheetView || !self.panelView) return;
    CGFloat expandedY = self.hostWindow.safeAreaInsets.top + 74;
    CGFloat collapsedY = CGRectGetHeight(self.panelView.bounds) - 265 - MAX(self.hostWindow.safeAreaInsets.bottom, 8);
    if (gesture.state == UIGestureRecognizerStateBegan) self.sheetStartY = CGRectGetMinY(self.sheetView.frame);
    CGFloat y = self.sheetStartY + [gesture translationInView:self.panelView].y;
    y = MAX(expandedY, MIN(collapsedY, y));
    CGRect frame = self.sheetView.frame;
    frame.origin.y = y;
    self.sheetView.frame = frame;

    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        CGFloat targetY = y < (expandedY + collapsedY) / 2.0 ? expandedY : collapsedY;
        [UIView animateWithDuration:0.36 delay:0 usingSpringWithDamping:0.82 initialSpringVelocity:0 options:0 animations:^{
            CGRect finalFrame = self.sheetView.frame;
            finalFrame.origin.y = targetY;
            self.sheetView.frame = finalFrame;
        } completion:nil];
    }
}

- (void)pickLocation:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    CGPoint point = [gesture locationInView:self.mapView];
    CLLocationCoordinate2D coordinate = [self.mapView convertPoint:point toCoordinateFromView:self.mapView];
    [self selectCoordinate:coordinate center:NO];
}

- (void)selectCoordinate:(CLLocationCoordinate2D)coordinate center:(BOOL)center {
    if (!CLLocationCoordinate2DIsValid(coordinate)) return;
    self.selectedCoordinate = coordinate;
    [NSUserDefaults.standardUserDefaults setDouble:coordinate.latitude forKey:@"FGLatitude"];
    [NSUserDefaults.standardUserDefaults setDouble:coordinate.longitude forKey:@"FGLongitude"];
    [NSUserDefaults.standardUserDefaults synchronize];
    WFPanelWriteShared(@"latitude", @(coordinate.latitude));
    WFPanelWriteShared(@"longitude", @(coordinate.longitude));

    self.coordinateLabel.text = [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];
    if (self.pin) [self.mapView removeAnnotation:self.pin];
    self.pin = [MKPointAnnotation new];
    self.pin.coordinate = coordinate;
    self.pin.title = [WFLocalization isArabic] ? @"الموقع المحدد" : @"Selected location";
    [self.mapView addAnnotation:self.pin];
    if (center) [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(coordinate, 950, 950) animated:YES];
}

- (void)refreshState {
    BOOL enabled = [NSUserDefaults.standardUserDefaults boolForKey:@"FGEnabled"];
    self.statusLabel.text = [WFLocalization text:(enabled ? @"gps_active" : @"gps_ready")];
    self.statusLabel.textColor = enabled ? [[WFThemeManager shared] successColor] : [UIColor colorWithRed:0.96 green:0.68 blue:0.18 alpha:1];
    [self.gpsButton setTitle:[WFLocalization text:(enabled ? @"gps_on" : @"gps_off")] forState:UIControlStateNormal];
    [self.movementButton setTitle:[WFLocalization text:(self.movementManager.isRunning ? @"stop_movement" : @"start_movement")] forState:UIControlStateNormal];
    [self refreshFloatingButton];
}

- (void)toggleGPS {
    BOOL enabled = ![NSUserDefaults.standardUserDefaults boolForKey:@"FGEnabled"];
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:@"FGEnabled"];
    [NSUserDefaults.standardUserDefaults synchronize];
    WFPanelWriteShared(@"enabled", @(enabled));
    [self refreshState];
}

- (void)saveFavorite {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[WFLocalization text:@"save_favorite"] message:self.coordinateLabel.text preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = [WFLocalization text:@"name"]; }];
    [alert addAction:[UIAlertAction actionWithTitle:[WFLocalization text:@"cancel"] style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:[WFLocalization text:@"done"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[WFFavoritesStore shared] addCoordinate:self.selectedCoordinate name:alert.textFields.firstObject.text];
        [self showToast:[WFLocalization text:@"saved"]];
    }]];
    [WFPanelTopController(self.hostWindow) presentViewController:alert animated:YES completion:nil];
}

- (void)showFavorites {
    WFFavoritesViewController *controller = [WFFavoritesViewController new];
    __weak typeof(self) weakSelf = self;
    controller.selectionHandler = ^(CLLocationCoordinate2D coordinate) {
        [weakSelf selectCoordinate:coordinate center:YES];
    };
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:controller];
    if (@available(iOS 13.0, *)) navigation.modalPresentationStyle = UIModalPresentationPageSheet;
    [WFPanelTopController(self.hostWindow) presentViewController:navigation animated:YES completion:nil];
}

- (void)realLocation {
    CLLocation *location = self.mapView.userLocation.location;
    if (location) [self selectCoordinate:location.coordinate center:YES];
}

- (void)cycleMapType {
    if (self.mapView.mapType == MKMapTypeStandard) self.mapView.mapType = MKMapTypeSatellite;
    else if (self.mapView.mapType == MKMapTypeSatellite) self.mapView.mapType = MKMapTypeHybrid;
    else self.mapView.mapType = MKMapTypeStandard;
}

- (void)mapTypeChanged:(UISegmentedControl *)sender {
    if (sender.selectedSegmentIndex == 1) self.mapView.mapType = MKMapTypeSatellite;
    else if (sender.selectedSegmentIndex == 2) self.mapView.mapType = MKMapTypeHybrid;
    else self.mapView.mapType = MKMapTypeStandard;
}

- (void)toggleTheme {
    WFThemeMode mode = [WFThemeManager shared].mode;
    [WFThemeManager shared].mode = (mode == WFThemeModeDark) ? WFThemeModeLight : WFThemeModeDark;
}

- (void)toggleLanguage {
    [WFLocalization toggleLanguage];
}

- (void)hideTool {
    [self closePanel];
    self.floatingButton.hidden = YES;
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:WFPanelHiddenKey];
    [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)loadGPX {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"com.topografix.gpx", @"public.xml", @"public.text"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [WFPanelTopController(self.hostWindow) presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSError *error = nil;
    BOOL loaded = [self.movementManager loadGPXData:data error:&error];
    [self showToast:[WFLocalization text:(loaded ? @"gpx_loaded" : @"gpx_invalid")]];
    [self refreshState];
}

- (void)toggleMovement {
    if (self.movementManager.isRunning) {
        [self.movementManager stop];
        [self refreshState];
        return;
    }
    if (self.movementManager.pointCount < 2) {
        [self loadGPX];
        return;
    }
    NSArray<NSNumber *> *speeds = @[@1.4, @5.0, @15.0, @30.0];
    NSInteger index = MAX(0, MIN(self.speedControl.selectedSegmentIndex, (NSInteger)speeds.count - 1));
    if (![NSUserDefaults.standardUserDefaults boolForKey:@"FGEnabled"]) [self toggleGPS];
    [self.movementManager startWithSpeedMetersPerSecond:speeds[index].doubleValue];
    [self refreshState];
}

- (void)showToast:(NSString *)message {
    if (!self.panelView) return;
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(32, CGRectGetHeight(self.panelView.bounds) - 150, CGRectGetWidth(self.panelView.bounds) - 64, 46)];
    toast.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    toast.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
    toast.textColor = UIColor.whiteColor;
    toast.textAlignment = NSTextAlignmentCenter;
    toast.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    toast.layer.cornerRadius = 14;
    toast.clipsToBounds = YES;
    toast.text = message;
    toast.alpha = 0;
    [self.panelView addSubview:toast];
    [UIView animateWithDuration:0.2 animations:^{ toast.alpha = 1; } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.25 delay:1.2 options:0 animations:^{ toast.alpha = 0; } completion:^(BOOL done) { [toast removeFromSuperview]; }];
    }];
}

- (void)volumeChanged:(NSNotification *)notification {
    NSNumber *value = notification.userInfo[@"AVSystemController_AudioVolumeNotificationParameter"];
    if (![value isKindOfClass:NSNumber.class]) return;
    static float previous = -1.0f;
    float current = value.floatValue;
    if (previous >= 0 && current > previous && self.floatingButton.hidden) {
        NSTimeInterval now = NSDate.date.timeIntervalSince1970;
        if (now - self.lastVolumeTime > 1.5) self.volumeCount = 0;
        self.lastVolumeTime = now;
        self.volumeCount += 1;
        if (self.volumeCount >= 3) {
            self.volumeCount = 0;
            self.floatingButton.hidden = NO;
            [NSUserDefaults.standardUserDefaults setBool:NO forKey:WFPanelHiddenKey];
            [NSUserDefaults.standardUserDefaults synchronize];
            [self.hostWindow bringSubviewToFront:self.floatingButton];
        }
    }
    previous = current;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.searchCompleter.queryFragment = searchText ?: @"";
    self.suggestionsTable.hidden = searchText.length < 2;
    if (!self.suggestionsTable.hidden) {
        [self.suggestionsTable.superview bringSubviewToFront:self.suggestionsTable];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    NSString *query = [searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSArray<NSString *> *parts = [query componentsSeparatedByString:@","];
    if (parts.count == 2) {
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(parts[0].doubleValue, parts[1].doubleValue);
        if (CLLocationCoordinate2DIsValid(coordinate)) {
            [self selectCoordinate:coordinate center:YES];
            self.suggestionsTable.hidden = YES;
            return;
        }
    }
    MKLocalSearchRequest *request = [MKLocalSearchRequest new];
    request.naturalLanguageQuery = query;
    [self runSearchRequest:request];
}

- (void)completerDidUpdateResults:(MKLocalSearchCompleter *)completer {
    if (completer.results.count > 8) self.suggestions = [completer.results subarrayWithRange:NSMakeRange(0, 8)];
    else self.suggestions = completer.results;
    [self.suggestionsTable reloadData];
    self.suggestionsTable.hidden = self.suggestions.count == 0;
    if (!self.suggestionsTable.hidden) {
        [self.suggestionsTable.superview bringSubviewToFront:self.suggestionsTable];
    }
}

- (void)completer:(MKLocalSearchCompleter *)completer didFailWithError:(NSError *)error {
    self.suggestions = @[];
    self.suggestionsTable.hidden = YES;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.suggestions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WFSearchSuggestion"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"WFSearchSuggestion"];
    MKLocalSearchCompletion *completion = self.suggestions[indexPath.row];
    cell.textLabel.text = completion.title;
    cell.detailTextLabel.text = completion.subtitle;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    MKLocalSearchRequest *request = [[MKLocalSearchRequest alloc] initWithCompletion:self.suggestions[indexPath.row]];
    [self runSearchRequest:request];
}

- (void)runSearchRequest:(MKLocalSearchRequest *)request {
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request];
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        MKMapItem *item = response.mapItems.firstObject;
        if (error || !item) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self selectCoordinate:item.placemark.coordinate center:YES];
            self.suggestionsTable.hidden = YES;
            self.searchBar.text = item.name ?: self.searchBar.text;
        });
    }];
}

@end

%hook FGManager
- (void)start {
    [[WFModernPanelManager shared] start];
}
%end
