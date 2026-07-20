#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import <sys/stat.h>
#import <unistd.h>

static NSString *const FGEnabled = @"FGEnabled";
static NSString *const FGHidden = @"FGHidden";
static NSString *const FGX = @"FGX";
static NSString *const FGY = @"FGY";

static NSUserDefaults *FGDefaults(void) {
    return NSUserDefaults.standardUserDefaults;
}

static UIColor *FGColor(CGFloat r, CGFloat g, CGFloat b) {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1.0];
}

static UIImage *FGSymbol(NSString *name) {
    if (@available(iOS 13.0, *)) {
        return [UIImage systemImageNamed:name];
    }
    return nil;
}

static BOOL FGPathExists(NSString *path) {
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

static NSArray<NSString *> *FGJailbreakIndicators(void) {
    NSMutableArray<NSString *> *matches = [NSMutableArray array];
    NSArray<NSString *> *paths = @[
        @"/var/jb",
        @"/Applications/Cydia.app",
        @"/Applications/Sileo.app",
        @"/Applications/Zebra.app",
        @"/Library/MobileSubstrate/MobileSubstrate.dylib",
        @"/usr/lib/libsubstitute.dylib",
        @"/usr/lib/libhooker.dylib",
        @"/usr/bin/ssh",
        @"/bin/bash",
        @"/etc/apt",
        @"/private/var/lib/apt"
    ];

    for (NSString *path in paths) {
        if (FGPathExists(path)) {
            [matches addObject:path];
        }
    }

    if (access("/var/jb", F_OK) == 0 && ![matches containsObject:@"/var/jb"]) {
        [matches addObject:@"/var/jb"];
    }

    return matches;
}

static BOOL FGIsJailbroken(void) {
    return FGJailbreakIndicators().count > 0;
}

@interface FGController : UIViewController <MKMapViewDelegate, UISearchBarDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property(nonatomic, strong) UIButton *floating;
@property(nonatomic, strong) UIView *panel;
@property(nonatomic, strong) MKMapView *map;
@property(nonatomic, strong) UILabel *coord;
@property(nonatomic, strong) UILabel *jailbreakLabel;
@property(nonatomic, assign) NSInteger volumeCount;
@property(nonatomic, assign) NSTimeInterval lastVolume;
@end

@implementation FGController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    [self buildFloating];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(volumeChanged:)
                                                 name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)buildFloating {
    self.floating = [UIButton buttonWithType:UIButtonTypeSystem];
    self.floating.frame = CGRectMake(20, 150, 64, 64);
    self.floating.layer.cornerRadius = 32;
    self.floating.tintColor = UIColor.whiteColor;
    [self.floating setImage:FGSymbol(@"location.fill") forState:UIControlStateNormal];
    [self.floating addTarget:self action:@selector(openPanel) forControlEvents:UIControlEventTouchUpInside];
    [self.floating addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)]];

    double x = [FGDefaults() doubleForKey:FGX];
    double y = [FGDefaults() doubleForKey:FGY];
    if (x > 0 && y > 0) {
        self.floating.center = CGPointMake(x, y);
    }

    self.floating.hidden = [FGDefaults() boolForKey:FGHidden];
    [self refreshColor];
    [self.view addSubview:self.floating];
}

- (void)refreshColor {
    BOOL enabled = [FGDefaults() boolForKey:FGEnabled];
    self.floating.backgroundColor = enabled ? FGColor(70, 226, 123) : FGColor(104, 113, 125);
    self.floating.layer.shadowColor = (enabled ? FGColor(70, 226, 123) : UIColor.blackColor).CGColor;
    self.floating.layer.shadowOpacity = 0.45;
    self.floating.layer.shadowRadius = 14;
    self.floating.layer.shadowOffset = CGSizeMake(0, 6);
}

- (void)drag:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.view];
    CGPoint center = CGPointMake(self.floating.center.x + translation.x,
                                 self.floating.center.y + translation.y);
    CGFloat half = self.floating.bounds.size.width / 2.0;
    center.x = MAX(half, MIN(self.view.bounds.size.width - half, center.x));
    center.y = MAX(half, MIN(self.view.bounds.size.height - half, center.y));
    self.floating.center = center;
    [gesture setTranslation:CGPointZero inView:self.view];

    if (gesture.state == UIGestureRecognizerStateEnded) {
        [FGDefaults() setDouble:center.x forKey:FGX];
        [FGDefaults() setDouble:center.y forKey:FGY];
        [FGDefaults() synchronize];
    }
}

- (void)volumeChanged:(NSNotification *)notification {
    NSNumber *value = notification.userInfo[@"AVSystemController_AudioVolumeNotificationParameter"];
    if (![value isKindOfClass:NSNumber.class]) return;

    static float previous = -1.0f;
    float current = value.floatValue;
    if (previous >= 0.0f && current > previous && self.floating.hidden) {
        NSTimeInterval now = NSDate.date.timeIntervalSince1970;
        if (now - self.lastVolume > 1.5) self.volumeCount = 0;
        self.lastVolume = now;
        self.volumeCount += 1;

        if (self.volumeCount >= 3) {
            self.volumeCount = 0;
            self.floating.hidden = NO;
            [FGDefaults() setBool:NO forKey:FGHidden];
            [FGDefaults() synchronize];
            UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
            [feedback impactOccurred];
        }
    }
    previous = current;
}

- (UIButton *)buttonWithTitle:(NSString *)title symbol:(NSString *)symbol color:(UIColor *)color {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.backgroundColor = color;
    button.layer.cornerRadius = 14;
    button.tintColor = UIColor.whiteColor;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [button setImage:FGSymbol(symbol) forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    button.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 8);
    return button;
}

- (void)openPanel {
    [self.panel removeFromSuperview];
    self.panel = [[UIView alloc] initWithFrame:self.view.bounds];
    self.panel.backgroundColor = FGColor(5, 7, 11);
    [self.view addSubview:self.panel];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(82, 42, self.view.bounds.size.width - 164, 44)];
    title.text = @"FAKE GPS";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont boldSystemFontOfSize:24];
    title.textAlignment = NSTextAlignmentCenter;
    [self.panel addSubview:title];

    UIButton *close = [self buttonWithTitle:@"إغلاق" symbol:@"xmark" color:FGColor(44, 54, 68)];
    close.frame = CGRectMake(16, 46, 78, 40);
    [close addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:close];

    BOOL jailbroken = FGIsJailbroken();
    self.jailbreakLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 112, 48, 96, 36)];
    self.jailbreakLabel.text = jailbroken ? @"جيلبريك ✓" : @"بدون جيلبريك";
    self.jailbreakLabel.textColor = jailbroken ? FGColor(70, 226, 123) : FGColor(190, 198, 210);
    self.jailbreakLabel.backgroundColor = jailbroken ? FGColor(18, 53, 34) : FGColor(40, 47, 57);
    self.jailbreakLabel.font = [UIFont boldSystemFontOfSize:11];
    self.jailbreakLabel.textAlignment = NSTextAlignmentCenter;
    self.jailbreakLabel.layer.cornerRadius = 12;
    self.jailbreakLabel.clipsToBounds = YES;
    self.jailbreakLabel.userInteractionEnabled = YES;
    [self.jailbreakLabel addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showJailbreakDetails)]];
    [self.panel addSubview:self.jailbreakLabel];

    UISearchBar *search = [[UISearchBar alloc] initWithFrame:CGRectMake(14, 96, self.view.bounds.size.width - 28, 50)];
    search.placeholder = @"مدينة، عنوان، أو إحداثيات";
    search.delegate = self;
    search.searchBarStyle = UISearchBarStyleMinimal;
    [self.panel addSubview:search];

    self.map = [[MKMapView alloc] initWithFrame:CGRectMake(14, 152, self.view.bounds.size.width - 28, self.view.bounds.size.height - 340)];
    self.map.layer.cornerRadius = 22;
    self.map.layer.masksToBounds = YES;
    self.map.delegate = self;
    self.map.showsUserLocation = YES;
    [self.panel addSubview:self.map];

    self.coord = [[UILabel alloc] initWithFrame:CGRectMake(14, self.view.bounds.size.height - 178, self.view.bounds.size.width - 28, 42)];
    self.coord.text = @"24.713600, 46.675300";
    self.coord.textColor = UIColor.whiteColor;
    self.coord.textAlignment = NSTextAlignmentCenter;
    self.coord.backgroundColor = FGColor(17, 26, 36);
    self.coord.layer.cornerRadius = 13;
    self.coord.clipsToBounds = YES;
    [self.panel addSubview:self.coord];

    CGFloat buttonWidth = (self.view.bounds.size.width - 42) / 2.0;
    UIButton *toggle = [self buttonWithTitle:@"تفعيل الموقع" symbol:@"location.fill" color:FGColor(71, 140, 255)];
    toggle.frame = CGRectMake(14, self.view.bounds.size.height - 126, buttonWidth, 50);
    [toggle addTarget:self action:@selector(toggleGPS) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:toggle];

    UIButton *photos = [self buttonWithTitle:@"الصور" symbol:@"photo.on.rectangle" color:FGColor(154, 140, 255)];
    photos.frame = CGRectMake(28 + buttonWidth, self.view.bounds.size.height - 126, buttonWidth, 50);
    [photos addTarget:self action:@selector(openPhotos) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:photos];
}

- (void)showJailbreakDetails {
    NSArray<NSString *> *indicators = FGJailbreakIndicators();
    NSString *message = indicators.count > 0
        ? [NSString stringWithFormat:@"تم اكتشاف مؤشرات جيلبريك:\n%@", [indicators componentsJoinedByString:@"\n"]]
        : @"لم يتم العثور على مؤشرات جيلبريك معروفة.";

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"حالة الجهاز"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)closePanel {
    [self.panel removeFromSuperview];
    self.panel = nil;
}

- (void)toggleGPS {
    BOOL enabled = ![FGDefaults() boolForKey:FGEnabled];
    [FGDefaults() setBool:enabled forKey:FGEnabled];
    [FGDefaults() synchronize];
    [self refreshColor];
}

- (void)openPhotos {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) return;
    UIImagePickerController *picker = [UIImagePickerController new];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (image) {
        [self.floating setImage:image forState:UIControlStateNormal];
        self.floating.imageView.contentMode = UIViewContentModeScaleAspectFill;
        self.floating.clipsToBounds = YES;
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    NSString *query = [searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (query.length == 0) return;

    MKLocalSearchRequest *request = [MKLocalSearchRequest new];
    request.naturalLanguageQuery = query;
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request];
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        if (error || response.mapItems.count == 0) return;
        CLLocationCoordinate2D coordinate = response.mapItems.firstObject.placemark.coordinate;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.map setRegion:MKCoordinateRegionMakeWithDistance(coordinate, 900, 900) animated:YES];
            self.coord.text = [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];
        });
    }];
}

@end

static UIWindow *FGWindow = nil;

__attribute__((constructor)) static void FGInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        FGWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        FGWindow.windowLevel = UIWindowLevelAlert + 50;
        FGWindow.backgroundColor = UIColor.clearColor;
        FGWindow.rootViewController = [FGController new];
        FGWindow.hidden = NO;
    });
}
