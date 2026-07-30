#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import "WFThemeManager.h"
#import "WFLocalization.h"
#import "WFFavoritesStore.h"
#import "WFFavoritesViewController.h"
#import "WFGPXMovementManager.h"

static CFStringRef const WFSharedDomain = CFSTR("fun.p3nd.fakegps");
static NSString *const WFFloatXKey = @"WFModernFloatX";
static NSString *const WFFloatYKey = @"WFModernFloatY";
static NSString *const WFFloatHiddenKey = @"WFModernFloatHidden";

static void WFWriteShared(NSString *key, id value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             value ? (__bridge CFPropertyListRef)value : NULL,
                             WFSharedDomain);
    CFPreferencesAppSynchronize(WFSharedDomain);
}

static BOOL WFLicenseActive(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    return [defaults boolForKey:@"FGLicenseActive"] && [defaults stringForKey:@"FGLicenseCode"].length > 0;
}

static UIImage *WFSymbol(NSString *name) {
    if (@available(iOS 13.0, *)) return [UIImage systemImageNamed:name];
    return nil;
}

static UIViewController *WFTopController(UIWindow *window) {
    UIViewController *controller = window.rootViewController;
    while (controller.presentedViewController) controller = controller.presentedViewController;
    return controller;
}

@interface FGManager : NSObject
+ (instancetype)shared;
- (void)fg_showActivationGate;
@end

@interface WFModernManager : NSObject <UISearchBarDelegate, MKMapViewDelegate, MKLocalSearchCompleterDelegate, UITableViewDataSource, UITableViewDelegate, UIDocumentPickerDelegate>
@property (nonatomic, weak) UIWindow *hostWindow;
@property (nonatomic, strong) UIButton *floatingButton;
@property (nonatomic, strong) UIView *overlayView;
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) UIView *bottomSheet;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *coordinateLabel;
@property (nonatomic, strong) UIButton *gpsButton;
@property (nonatomic, strong) UIButton *movementButton;
@property (nonatomic, strong) UISegmentedControl *speedControl;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *suggestionsTable;
@property (nonatomic, strong) MKLocalSearchCompleter *searchCompleter;
@property (nonatomic, copy) NSArray<MKLocalSearchCompletion *> *suggestions;
@property (nonatomic, strong) MKPointAnnotation *pin;
@property (nonatomic, assign) CLLocationCoordinate2D selectedCoordinate;
@property (nonatomic, assign) CGFloat sheetPanStartY;
@property (nonatomic, assign) NSInteger retryCount;
@property (nonatomic, assign) NSInteger volumeCount;
@property (nonatomic, assign) NSTimeInterval lastVolumeTime;
@property (nonatomic, strong) WFGPXMovementManager *movementManager;
+ (instancetype)shared;
- (void)start;
@end

@implementation WFModernManager

+ (instancetype)shared {
    static WFModernManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [WFModernManager new]; });
    return manager;
}

- (instancetype)init {
    if ((self = [super init])) {
        _selectedCoordinate = CLLocationCoordinate2DMake(24.7136, 46.6753);
        _suggestions = @[];
        _movementManager = [WFGPXMovementManager new];
        _movementManager.loops = YES;
        __weak typeof(self) weakSelf = self;
        _movementManager.coordinateHandler = ^(CLLocationCoordinate2D coordinate) {
            [weakSelf selectCoordinate:coordinate centerMap:YES];
        };
        _movementManager.completionHandler = ^{
            [weakSelf refreshState];
        };
    }
    return self;
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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rebuildOpenPanel) name:WFThemeDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rebuildOpenPanel) name:WFLanguageDidChangeNotification object:nil];
        [self attachWhenReady];
    });
}

- (void)attachWhenReady {
    if (self.floatingButton.superview) return;
    UIWindow *window = [self bestWindow];
    if (!window) {
        if (self.retryCount++ < 50) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self attachWhenReady]; });
        return;
    }
    self.hostWindow = window;
    [self buildFloatingButton];
}

- (void)buildFloatingButton {
    [self.floatingButton removeFromSuperview];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(18, 150, 62, 62);
    button.layer.cornerRadius = 31;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.24].CGColor;
    button.tintColor = UIColor.whiteColor;
    [button setImage:WFSymbol(@"location.fill") forState:UIControlStateNormal];
    [button addTarget:self action:@selector(openPanel) forControlEvents:UIControlEventTouchUpInside];
    [button addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragFloating:)]];
    button.hidden = [NSUserDefaults.standardUserDefaults boolForKey:WFFloatHiddenKey];
    CGFloat savedX = [NSUserDefaults.standardUserDefaults doubleForKey:WFFloatXKey];
    CGFloat savedY = [NSUserDefaults.standardUserDefaults doubleForKey:WFFloatYKey];
    if (savedX > 0 && savedY > 0) button.center = CGPointMake(savedX, savedY);
    self.floatingButton = button;
    [self refreshFloatingButton];
    [self.hostWindow addSubview:button];
    [self.hostWindow bringSubviewToFront:button];
}

- (void)refreshFloatingButton {
    BOOL active = [NSUserDefaults.standardUserDefaults boolForKey:@"FGEnabled"];
    UIColor *color = active ? WFThemeManager.shared.successColor : WFThemeManager.shared.accentColor;
    self.floatingButton.backgroundColor = [color colorWithAlphaComponent:0.94];
    self.floatingButton.layer.shadowColor = color.CGColor;
    self.floatingButton.layer.shadowOpacity = 0.52;
    self.floatingButton.layer.shadowRadius = 14;
    self.floatingButton.layer.shadowOffset = CGSizeMake(0, 7);
}

- (void)dragFloating:(UIPanGestureRecognizer *)gesture {
    if (!self.hostWindow) return;
    CGPoint translation = [gesture translationInView:self.hostWindow];
    CGPoint center = CGPointMake(self.floatingButton.center.x + translation.x, self.floatingButton.center.y + translation.y);
    CGFloat half = CGRectGetWidth(self.floatingButton.bounds) / 2.0;
    UIEdgeInsets safe = self.hostWindow.safeAreaInsets;
    center.x = MAX(half + 8, MIN(CGRectGetWidth(self.hostWindow.bounds) - half - 8, center.x));
    center.y = MAX(safe.top + half + 8, MIN(CGRectGetHeight(self.hostWindow.bounds) - safe.bottom - half - 8, center.y));
    self.floatingButton.center = center;
    [gesture setTranslation:CGPointZero inView:self.hostWindow];
    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        CGFloat targetX = center.x < CGRectGetMidX(self.hostWindow.bounds) ? half + 10 : CGRectGetWidth(self.hostWindow.bounds) - half - 10;
        [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.72 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.floatingButton.center = CGPointMake(targetX, center.y);
        } completion:^(BOOL finished) {
            [NSUserDefaults.standardUserDefaults setDouble:self.floatingButton.center.x forKey:WFFloatXKey];
            [NSUserDefaults.standardUserDefaults setDouble:self.floatingButton.center.y forKey:WFFloatYKey];
            [NSUserDefaults.standardUserDefaults synchronize];
        }];
    }
}

- (UIVisualEffectView *)glassViewWithFrame:(CGRect)frame radius:(CGFloat)radius {
    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:[WFThemeManager.shared glassEffectForTraitCollection:self.hostWindow.traitCollection]];
    glass.frame = frame;
    glass.layer.cornerRadius = radius;
    glass.clipsToBounds = YES;
    glass.layer.borderWidth = 1;
    glass.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.16].CGColor;
    return glass;
}

- (UIButton *)iconButton:(NSString *)symbol action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(0, 0, 44, 44);
    button.layer.cornerRadius = 22;
    button.backgroundColor = [WFThemeManager.shared.cardColorForTraitCollection:self.hostWindow.traitCollection colorWithAlphaComponent:0.78];
    button.tintColor = WFThemeManager.shared.primaryTextColorForTraitCollection:self.hostWindow.traitCollection;
    [button setImage:WFSymbol(symbol) forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIButton *)textButton:(NSString *)title symbol:(NSString *)symbol action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.layer.cornerRadius = 14;
    button.backgroundColor = [WFThemeManager.shared.cardColorForTraitCollection:self.hostWindow.traitCollection colorWithAlphaComponent:0.9];
    button.tintColor = WFThemeManager.shared.primaryTextColorForTraitCollection:self.hostWindow.traitCollection;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:WFThemeManager.shared.primaryTextColorForTraitCollection:self.hostWindow.traitCollection forState:UIControlStateNormal];
    [button setImage:WFSymbol(symbol) forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    button.semanticContentAttribute = [WFLocalization isArabic] ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    button.imageEdgeInsets = UIEdgeInsetsMake(0, 5, 0, 0);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)openPanel {
    if (!WFLicenseActive()) {
        FGManager *legacy = [FGManager shared];
        if ([legacy respondsToSelector:@selector(fg_showActivationGate)]) [legacy fg_showActivationGate];
        return;
    }
    [self.overlayView removeFromSuperview];
    if (!self.hostWindow) self.hostWindow = [self bestWindow];
    if (!self.hostWindow) return;

    UIView *root = [[UIView alloc] initWithFrame:self.hostWindow.bounds];
    root.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    root.backgroundColor = [WFThemeManager.shared backgroundColorForTraitCollection:self.hostWindow.traitCollection];
    if (@available(iOS 13.0, *)) {
        root.overrideUserInterfaceStyle = [WFThemeManager.shared isDarkForTraitCollection:self.hostWindow.traitCollection] ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    }
    self.overlayView = root;
    [self.hostWindow addSubview:root];

    MKMapView *map = [[MKMapView alloc] initWithFrame:root.bounds];
    map.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    map.delegate = self;
    map.showsUserLocation = YES;
    map.mapType = MKMapTypeStandard;
    self.mapView = map;
    [root addSubview:map];

    UIEdgeInsets safe = self.hostWindow.safeAreaInsets;
    UIVisualEffectView *topGlass = [self glassViewWithFrame:CGRectMake(12, safe.top + 8, CGRectGetWidth(root.bounds) - 24, 54) radius:20];
    topGlass.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [root addSubview:topGlass];
    UIView *top = topGlass.contentView;

    UIButton *close = [self iconButton:@"xmark" action:@selector(closePanel)];
    close.frame = CGRectMake(5, 5, 44, 44);
    [top addSubview:close];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(56, 5, CGRectGetWidth(top.bounds) - 168, 44)];
    title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    title.text = [WFLocalization text:@"title"];
    title.textColor = WFThemeManager.shared.primaryTextColorForTraitCollection:self.hostWindow.traitCollection;
    title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;
    [top addSubview:title];

    UIButton *theme = [self iconButton:@"circle.lefthalf.filled" action:@selector(toggleTheme)];
    theme.frame = CGRectMake(CGRectGetWidth(top.bounds) - 100, 5, 44, 44);
    theme.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [top addSubview:theme];

    UIButton *language = [UIButton buttonWithType:UIButtonTypeSystem];
    language.frame = CGRectMake(CGRectGetWidth(top.bounds) - 51, 5, 46, 44);
    language.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    language.layer.cornerRadius = 18;
    language.backgroundColor = [WFThemeManager.shared.cardColorForTraitCollection:self.hostWindow.traitCollection colorWithAlphaComponent:0.8];
    language.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [language setTitle:[WFLocalization isArabic] ? @"EN" : @"ع" forState:UIControlStateNormal];
    [language addTarget:self action:@selector(toggleLanguage) forControlEvents:UIControlEventTouchUpInside];
    [top addSubview:language];

    NSArray *tools = @[@[@"star.fill", @selector(saveFavorite)], @[@"location.fill", @selector(realLocation)], @[@"map.fill", @selector(cycleMapType)]];
    for (NSUInteger i = 0; i < tools.count; i++) {
        UIButton *button = [self iconButton:tools[i][0] action:[tools[i][1] pointerValue]];
        button.frame = CGRectMake(CGRectGetWidth(root.bounds) - 58, safe.top + 78 + i * 52, 46, 46);
        button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [root addSubview:button];
    }

    CGFloat sheetHeight = MIN(390, CGRectGetHeight(root.bounds) - safe.top - 90);
    CGFloat sheetY = CGRectGetHeight(root.bounds) - sheetHeight - MAX(safe.bottom, 8);
    UIVisualEffectView *sheetGlass = [self glassViewWithFrame:CGRectMake(10, sheetY, CGRectGetWidth(root.bounds) - 20, sheetHeight) radius:28];
    sheetGlass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.bottomSheet = sheetGlass;
    [root addSubview:sheetGlass];
    [sheetGlass addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panSheet:)]];
    UIView *content = sheetGlass.contentView;
    [WFLocalization applyDirectionToView:content];

    UIView *grabber = [[UIView alloc] initWithFrame:CGRectMake((CGRectGetWidth(content.bounds)-42)/2, 8, 42, 5)];
    grabber.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    grabber.layer.cornerRadius = 2.5;
    grabber.backgroundColor = [UIColor colorWithWhite:0.6 alpha:0.6];
    [content addSubview:grabber];

    UISearchBar *search = [[UISearchBar alloc] initWithFrame:CGRectMake(8, 22, CGRectGetWidth(content.bounds)-16, 46)];
    search.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    search.searchBarStyle = UISearchBarStyleMinimal;
    search.placeholder = [WFLocalization text:@"search_placeholder"];
    search.delegate = self;
    search.semanticContentAttribute = [WFLocalization isArabic] ? UISemanticContentAttributeForceRightToLeft : UISemanticContentAttributeForceLeftToRight;
    self.searchBar = search;
    [content addSubview:search];

    self.searchCompleter = [MKLocalSearchCompleter new];
    self.searchCompleter.delegate = self;
    self.searchCompleter.resultTypes = MKLocalSearchCompleterResultTypeAddress | MKLocalSearchCompleterResultTypePointOfInterest;

    UITableView *suggestions = [[UITableView alloc] initWithFrame:CGRectMake(12, 68, CGRectGetWidth(content.bounds)-24, 150) style:UITableViewStylePlain];
    suggestions.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    suggestions.layer.cornerRadius = 14;
    suggestions.clipsToBounds = YES;
    suggestions.dataSource = self;
    suggestions.delegate = self;
    suggestions.hidden = YES;
    self.suggestionsTable = suggestions;
    [content addSubview:suggestions];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 76, CGRectGetWidth(content.bounds)-32, 30)];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.statusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [content addSubview:self.statusLabel];

    self.coordinateLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 108, CGRectGetWidth(content.bounds)-32, 34)];
    self.coordinateLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.coordinateLabel.font = [UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightMedium];
    self.coordinateLabel.textAlignment = NSTextAlignmentCenter;
    self.coordinateLabel.layer.cornerRadius = 12;
    self.coordinateLabel.clipsToBounds = YES;
    self.coordinateLabel.backgroundColor = [WFThemeManager.shared.cardColorForTraitCollection:self.hostWindow.traitCollection colorWithAlphaComponent:0.75];
    [content addSubview:self.coordinateLabel];

    UISegmentedControl *mapType = [[UISegmentedControl alloc] initWithItems:@[[WFLocalization text:@"map_standard"], [WFLocalization text:@"map_satellite"], [WFLocalization text:@"map_hybrid"]]];
    mapType.frame = CGRectMake(16, 150, CGRectGetWidth(content.bounds)-32, 32);
    mapType.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    mapType.selectedSegmentIndex = 0;
    [mapType addTarget:self action:@selector(mapTypeChanged:) forControlEvents:UIControlEventValueChanged];
    [content addSubview:mapType];

    CGFloat gap = 8;
    CGFloat width = (CGRectGetWidth(content.bounds)-40-gap)/2.0;
    self.gpsButton = [self textButton:@"" symbol:@"location.fill" action:@selector(toggleGPS)];
    self.gpsButton.frame = CGRectMake(16, 192, width, 48);
    self.gpsButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [content addSubview:self.gpsButton];

    UIButton *favorites = [self textButton:[WFLocalization text:@"favorites"] symbol:@"star.fill" action:@selector(showFavorites)];
    favorites.frame = CGRectMake(24+width, 192, width, 48);
    favorites.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
    [content addSubview:favorites];

    self.speedControl = [[UISegmentedControl alloc] initWithItems:@[@"1x", @"3x", @"8x", @"15x"]];
    self.speedControl.frame = CGRectMake(16, 250, CGRectGetWidth(content.bounds)-32, 32);
    self.speedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.speedControl.selectedSegmentIndex = 1;
    [content addSubview:self.speedControl];

    UIButton *load = [self textButton:[WFLocalization text:@"load_gpx"] symbol:@"folder" action:@selector(loadGPX)];
    load.frame = CGRectMake(16, 292, width, 48);
    load.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [content addSubview:load];

    self.movementButton = [self textButton:[WFLocalization text:@"start_movement"] symbol:@"figure.walk" action:@selector(toggleMovement)];
    self.movementButton.frame = CGRectMake(24+width, 292, width, 48);
    self.movementButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
    [content addSubview:self.movementButton];

    UIButton *hide = [self textButton:[WFLocalization text:@"hide_tool"] symbol:@"eye.slash" action:@selector(hideTool)];
    hide.frame = CGRectMake(16, 348, CGRectGetWidth(content.bounds)-32, 38);
    hide.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [content addSubview:hide];

    CLLocationDegrees savedLat = [NSUserDefaults.standardUserDefaults doubleForKey:@"FGLatitude"];
    CLLocationDegrees savedLon = [NSUserDefaults.standardUserDefaults doubleForKey:@"FGLongitude"];
    CLLocationCoordinate2D initial = CLLocationCoordinate2DMake(savedLat, savedLon);
    if (!CLLocationCoordinate2DIsValid(initial) || (savedLat == 0 && savedLon == 0)) initial = self.selectedCoordinate;
    [self selectCoordinate:initial centerMap:YES];
    [self refreshState];
    [self.hostWindow bringSubviewToFront:root];
}

- (void)rebuildOpenPanel {
    if (!self.overlayView.superview) return;
    [self openPanel];
}

- (void)closePanel {
    [self.searchCompleter cancel];
    self.searchCompleter.delegate = nil;
    [self.overlayView removeFromSuperview];
    self.overlayView = nil;
    if (self.floatingButton.superview) [self.hostWindow bringSubviewToFront:self.floatingButton];
}

- (void)panSheet:(UIPanGestureRecognizer *)gesture {
    if (!self.bottomSheet || !self.overlayView) return;
    CGFloat expandedY = self.hostWindow.safeAreaInsets.top + 74;
    CGFloat collapsedY = CGRectGetHeight(self.overlayView.bounds) - 265 - MAX(self.hostWindow.safeAreaInsets.bottom, 8);
    if (gesture.state == UIGestureRecognizerStateBegan) self.sheetPanStartY = CGRectGetMinY(self.bottomSheet.frame);
    CGFloat y = self.sheetPanStartY + [gesture translationInView:self.overlayView].y;
    y = MAX(expandedY, MIN(collapsedY, y));
    CGRect frame = self.bottomSheet.frame;
    frame.origin.y = y;
    self.bottomSheet.frame = frame;
    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        CGFloat target = y < (expandedY + collapsedY) / 2.0 ? expandedY : collapsedY;
        [UIView animateWithDuration:0.38 delay:0 usingSpringWithDamping:0.82 initialSpringVelocity:0 options:0 animations:^{
            CGRect finalFrame = self.bottomSheet.frame;
            finalFrame.origin.y = target;
            self.bottomSheet.frame = finalFrame;
        } completion:nil];
    }
}

- (void)selectCoordinate:(CLLocationCoordinate2D)coordinate centerMap:(BOOL)center {
    if (!CLLocationCoordinate2DIsValid(coordinate)) return;
    self.selectedCoordinate = coordinate;
    [NSUserDefaults.standardUserDefaults setDouble:coordinate.latitude forKey:@"FGLatitude"];
    [NSUserDefaults.standardUserDefaults setDouble:coordinate.longitude forKey:@"FGLongitude"];
    [NSUserDefaults.standardUserDefaults synchronize];
    WFWriteShared(@"latitude", @(coordinate.latitude));
    WFWriteShared(@"longitude", @(coordinate.longitude));
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
    self.statusLabel.text = [WFLocalization text:enabled ? @"gps_active" : @"gps_ready"];
    self.statusLabel.textColor = enabled ? WFThemeManager.shared.successColor : [UIColor colorWithRed:0.96 green:0.68 blue:0.18 alpha:1];
    [self.gpsButton setTitle:[WFLocalization text:enabled ? @"gps_on" : @"gps_off"] forState:UIControlStateNormal];
    [self.movementButton setTitle:[WFLocalization text:self.movementManager.isRunning ? @"stop_movement" : @"start_movement"] forState:UIControlStateNormal];
    [self refreshFloatingButton];
}

- (void)toggleGPS {
    BOOL enabled = ![NSUserDefaults.standardUserDefaults boolForKey:@"FGEnabled"];
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:@"FGEnabled"];
    [NSUserDefaults.standardUserDefaults synchronize];
    WFWriteShared(@"enabled", @(enabled));
    [self refreshState];
}

- (void)saveFavorite {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[WFLocalization text:@"save_favorite"] message:self.coordinateLabel.text preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = [WFLocalization text:@"name"]; }];
    [alert addAction:[UIAlertAction actionWithTitle:[WFLocalization text:@"cancel"] style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:[WFLocalization text:@"done"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[WFFavoritesStore shared] addCoordinate:self.selectedCoordinate name:alert.textFields.firstObject.text];
        [self showMessage:[WFLocalization text:@"saved"]];
    }]];
    [WFTopController(self.hostWindow) presentViewController:alert animated:YES completion:nil];
}

- (void)showFavorites {
    WFFavoritesViewController *favorites = [WFFavoritesViewController new];
    __weak typeof(self) weakSelf = self;
    favorites.selectionHandler = ^(CLLocationCoordinate2D coordinate) { [weakSelf selectCoordinate:coordinate centerMap:YES]; };
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:favorites];
    if (@available(iOS 13.0, *)) navigation.modalPresentationStyle = UIModalPresentationPageSheet;
    [WFTopController(self.hostWindow) presentViewController:navigation animated:YES completion:nil];
}

- (void)realLocation {
    CLLocation *location = self.mapView.userLocation.location;
    if (location) [self selectCoordinate:location.coordinate centerMap:YES];
}

- (void)cycleMapType {
    self.mapView.mapType = self.mapView.mapType == MKMapTypeStandard ? MKMapTypeSatellite : (self.mapView.mapType == MKMapTypeSatellite ? MKMapTypeHybrid : MKMapTypeStandard);
}

- (void)mapTypeChanged:(UISegmentedControl *)sender {
    self.mapView.mapType = sender.selectedSegmentIndex == 1 ? MKMapTypeSatellite : (sender.selectedSegmentIndex == 2 ? MKMapTypeHybrid : MKMapTypeStandard);
}

- (void)toggleTheme {
    WFThemeMode mode = WFThemeManager.shared.mode;
    WFThemeManager.shared.mode = (mode == WFThemeModeDark) ? WFThemeModeLight : WFThemeModeDark;
}

- (void)toggleLanguage { [WFLocalization toggleLanguage]; }

- (void)hideTool {
    [self closePanel];
    self.floatingButton.hidden = YES;
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:WFFloatHiddenKey];
    [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)loadGPX {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"com.topografix.gpx", @"public.xml", @"public.text"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [WFTopController(self.hostWindow) presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSError *error = nil;
    BOOL loaded = [self.movementManager loadGPXData:data error:&error];
    [self showMessage:[WFLocalization text:loaded ? @"gpx_loaded" : @"gpx_invalid"]];
    [self refreshState];
}

- (void)toggleMovement {
    if (self.movementManager.isRunning) {
        [self.movementManager stop];
        [self refreshState];
        return;
    }
    if (self.movementManager.pointCount < 2) { [self loadGPX]; return; }
    NSArray<NSNumber *> *speeds = @[@1.4, @5.0, @15.0, @30.0];
    NSInteger index = MAX(0, MIN(self.speedControl.selectedSegmentIndex, (NSInteger)speeds.count - 1));
    if (![NSUserDefaults.standardUserDefaults boolForKey:@"FGEnabled"]) [self toggleGPS];
    [self.movementManager startWithSpeedMetersPerSecond:speeds[index].doubleValue];
    [self refreshState];
}

- (void)showMessage:(NSString *)message {
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(32, CGRectGetHeight(self.overlayView.bounds)-150, CGRectGetWidth(self.overlayView.bounds)-64, 46)];
    toast.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    toast.backgroundColor = [UIColor colorWithWhite:0 alpha:0.78];
    toast.textColor = UIColor.whiteColor;
    toast.textAlignment = NSTextAlignmentCenter;
    toast.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    toast.layer.cornerRadius = 14;
    toast.clipsToBounds = YES;
    toast.text = message;
    toast.alpha = 0;
    [self.overlayView addSubview:toast];
    [UIView animateWithDuration:0.2 animations:^{ toast.alpha = 1; } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.25 delay:1.2 options:0 animations:^{ toast.alpha = 0; } completion:^(BOOL done) { [toast removeFromSuperview]; }];
    }];
}

- (void)volumeChanged:(NSNotification *)notification {
    NSNumber *value = notification.userInfo[@"AVSystemController_AudioVolumeNotificationParameter"];
    if (![value isKindOfClass:NSNumber.class]) return;
    static float previous = -1;
    float current = value.floatValue;
    if (previous >= 0 && current > previous && self.floatingButton.hidden) {
        NSTimeInterval now = NSDate.date.timeIntervalSince1970;
        if (now - self.lastVolumeTime > 1.5) self.volumeCount = 0;
        self.lastVolumeTime = now;
        if (++self.volumeCount >= 3) {
            self.volumeCount = 0;
            self.floatingButton.hidden = NO;
            [NSUserDefaults.standardUserDefaults setBool:NO forKey:WFFloatHiddenKey];
            [NSUserDefaults.standardUserDefaults synchronize];
            [self.hostWindow bringSubviewToFront:self.floatingButton];
        }
    }
    previous = current;
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view { }

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.searchCompleter.queryFragment = searchText ?: @"";
    self.suggestionsTable.hidden = searchText.length < 2;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    NSString *query = [searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSArray *parts = [query componentsSeparatedByString:@","];
    if (parts.count == 2) {
        CLLocationCoordinate2D c = CLLocationCoordinate2DMake([parts[0] doubleValue], [parts[1] doubleValue]);
        if (CLLocationCoordinate2DIsValid(c)) { [self selectCoordinate:c centerMap:YES]; self.suggestionsTable.hidden = YES; return; }
    }
    MKLocalSearchRequest *request = [MKLocalSearchRequest new];
    request.naturalLanguageQuery = query;
    [self runSearchRequest:request];
}

- (void)completerDidUpdateResults:(MKLocalSearchCompleter *)completer {
    self.suggestions = completer.results.count > 8 ? [completer.results subarrayWithRange:NSMakeRange(0, 8)] : completer.results;
    [self.suggestionsTable reloadData];
    self.suggestionsTable.hidden = self.suggestions.count == 0;
}

- (void)completer:(MKLocalSearchCompleter *)completer didFailWithError:(NSError *)error {
    self.suggestions = @[];
    self.suggestionsTable.hidden = YES;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.suggestions.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"suggestion"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"suggestion"];
    MKLocalSearchCompletion *item = self.suggestions[indexPath.row];
    cell.textLabel.text = item.title;
    cell.detailTextLabel.text = item.subtitle;
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
        if (!error && item) dispatch_async(dispatch_get_main_queue(), ^{
            [self selectCoordinate:item.placemark.coordinate centerMap:YES];
            self.suggestionsTable.hidden = YES;
            self.searchBar.text = item.name ?: self.searchBar.text;
        });
    }];
}

@end

%hook FGManager
- (void)start {
    [[WFModernManager shared] start];
}
%end
