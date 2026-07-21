#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

static NSString *const FGEnabled = @"FGEnabled";
static NSString *const FGHidden  = @"FGHidden";
static NSString *const FGX       = @"FGX";
static NSString *const FGY       = @"FGY";

static NSUserDefaults *FGDefaults(void) { return NSUserDefaults.standardUserDefaults; }
static UIColor *FGColor(CGFloat r, CGFloat g, CGFloat b) {
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1.0];
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
@property(nonatomic,weak) UIWindow *hostWindow;
@property(nonatomic,assign) NSInteger retryCount;
@property(nonatomic,assign) NSInteger volumeCount;
@property(nonatomic,assign) NSTimeInterval lastVolumeTime;
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

    button.hidden = NO;
    [FGDefaults() setBool:NO forKey:FGHidden];
    [FGDefaults() synchronize];

    self.floatingButton = button;
    [self refreshFloatingColor];
    [self.hostWindow addSubview:button];
    [self.hostWindow bringSubviewToFront:button];
}

- (void)refreshFloatingColor {
    BOOL enabled = [FGDefaults() boolForKey:FGEnabled];
    self.floatingButton.backgroundColor = enabled ? FGColor(70,226,123) : FGColor(104,113,125);
    self.floatingButton.layer.shadowColor = (enabled ? FGColor(70,226,123) : UIColor.blackColor).CGColor;
    self.floatingButton.layer.shadowOpacity = 0.45;
    self.floatingButton.layer.shadowRadius = 14;
    self.floatingButton.layer.shadowOffset = CGSizeMake(0,6);
}

- (void)dragFloating:(UIPanGestureRecognizer *)gesture {
    CGPoint t = [gesture translationInView:self.hostWindow];
    CGPoint c = CGPointMake(self.floatingButton.center.x+t.x, self.floatingButton.center.y+t.y);
    CGFloat half = self.floatingButton.bounds.size.width/2.0;
    c.x = MAX(half, MIN(self.hostWindow.bounds.size.width-half, c.x));
    c.y = MAX(half+24, MIN(self.hostWindow.bounds.size.height-half-24, c.y));
    self.floatingButton.center = c;
    [gesture setTranslation:CGPointZero inView:self.hostWindow];
    if (gesture.state == UIGestureRecognizerStateEnded) {
        [FGDefaults() setDouble:c.x forKey:FGX];
        [FGDefaults() setDouble:c.y forKey:FGY];
        [FGDefaults() synchronize];
    }
}

- (UIButton *)menuButton:(NSString *)title symbol:(NSString *)symbol color:(UIColor *)color {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.backgroundColor = color;
    button.layer.cornerRadius = 15;
    button.tintColor = UIColor.whiteColor;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [button setImage:FGSymbol(symbol) forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    return button;
}

- (void)openMenu {
    if (!self.hostWindow) self.hostWindow = [self bestWindow];
    if (!self.hostWindow) return;
    [self.menuView removeFromSuperview];

    UIView *panel = [[UIView alloc] initWithFrame:self.hostWindow.bounds];
    panel.backgroundColor = FGColor(5,7,11);
    self.menuView = panel;
    [self.hostWindow addSubview:panel];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(100, 44, panel.bounds.size.width-200, 44)];
    title.text = @"FAKE GPS";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont boldSystemFontOfSize:24];
    title.textAlignment = NSTextAlignmentCenter;
    [panel addSubview:title];

    UIButton *close = [self menuButton:@"إغلاق" symbol:@"xmark" color:FGColor(44,54,68)];
    close.frame = CGRectMake(16, 46, 82, 42);
    [close addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:close];

    UISearchBar *search = [[UISearchBar alloc] initWithFrame:CGRectMake(14, 100, panel.bounds.size.width-28, 52)];
    search.placeholder = @"مدينة، عنوان، أو إحداثيات";
    search.searchBarStyle = UISearchBarStyleMinimal;
    search.delegate = self;
    [panel addSubview:search];

    CGFloat mapHeight = MAX(250, panel.bounds.size.height-350);
    MKMapView *map = [[MKMapView alloc] initWithFrame:CGRectMake(14, 158, panel.bounds.size.width-28, mapHeight)];
    map.layer.cornerRadius = 22;
    map.layer.masksToBounds = YES;
    map.delegate = self;
    map.showsUserLocation = YES;
    self.mapView = map;
    [panel addSubview:map];

    UILabel *coord = [[UILabel alloc] initWithFrame:CGRectMake(14, CGRectGetMaxY(map.frame)+10, panel.bounds.size.width-28, 44)];
    coord.text = @"24.713600, 46.675300";
    coord.textColor = UIColor.whiteColor;
    coord.textAlignment = NSTextAlignmentCenter;
    coord.backgroundColor = FGColor(17,26,36);
    coord.layer.cornerRadius = 13;
    coord.clipsToBounds = YES;
    self.coordinateLabel = coord;
    [panel addSubview:coord];

    CGFloat y = CGRectGetMaxY(coord.frame)+10;
    CGFloat width = (panel.bounds.size.width-42)/2.0;

    UIButton *toggle = [self menuButton:@"تفعيل الموقع" symbol:@"location.fill" color:FGColor(71,140,255)];
    toggle.frame = CGRectMake(14, y, width, 52);
    [toggle addTarget:self action:@selector(toggleGPS:) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:toggle];

    UIButton *hide = [self menuButton:@"إخفاء الأيقونة" symbol:@"eye.slash.fill" color:FGColor(95,101,112)];
    hide.frame = CGRectMake(28+width, y, width, 52);
    [hide addTarget:self action:@selector(hideFloating) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:hide];

    [self.hostWindow bringSubviewToFront:panel];
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
    [sender setTitle:(enabled ? @"إيقاف الموقع" : @"تفعيل الموقع") forState:UIControlStateNormal];
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
        if (now-self.lastVolumeTime > 1.5) self.volumeCount = 0;
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
            CLLocationCoordinate2D c = CLLocationCoordinate2DMake(lat, lon);
            [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(c, 900, 900) animated:YES];
            self.coordinateLabel.text = [NSString stringWithFormat:@"%.6f, %.6f", lat, lon];
            return;
        }
    }

    MKLocalSearchRequest *request = [MKLocalSearchRequest new];
    request.naturalLanguageQuery = query;
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request];
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        if (error || response.mapItems.count == 0) return;
        CLLocationCoordinate2D c = response.mapItems.firstObject.placemark.coordinate;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(c, 900, 900) animated:YES];
            self.coordinateLabel.text = [NSString stringWithFormat:@"%.6f, %.6f", c.latitude, c.longitude];
        });
    }];
}

@end

__attribute__((constructor)) static void FGInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[FGManager shared] start];
    });
}
