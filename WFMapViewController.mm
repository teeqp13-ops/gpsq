#import "WFMapViewController.h"
#import <MapKit/MapKit.h>
#import "WFMainMenuPanel.h"
#import "WFActivationView.h"

// أيقونات FontAwesome
static NSString * const kWFIconFontName = @"FontAwesome5Free-Solid";
static NSString * const kWFIconMap      = @"\uf279";
static NSString * const kWFIconSatellite = @"\uf0ac";

@interface WFMapViewController () <MKMapViewDelegate>
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) UIButton *toggleBtn;
@property (nonatomic, strong) UIButton *floatingMenuButton;
@end

@implementation WFMapViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupMap];
    [self setupControls];
    [self setupFloatingMenuButton];
}

- (void)setupMap {
    self.mapView = [[MKMapView alloc] initWithFrame:self.view.bounds];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mapView.delegate = self;
    [self.view addSubview:self.mapView];
}

- (void)setupControls {
    UIButton *btn = [self roundButtonWithGlyph:kWFIconSatellite];
    [btn addTarget:self action:@selector(toggleMapType) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    self.toggleBtn = btn;
    
    [NSLayoutConstraint activateConstraints:@[
        [btn.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [btn.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20]
    ]];
}

- (void)setupFloatingMenuButton {
    UIButton *menuBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    menuBtn.translatesAutoresizingMaskIntoConstraints = NO;
    menuBtn.backgroundColor = [UIColor colorWithRed:0x14/255.0 green:0x7b/255.0 blue:0xc4/255.0 alpha:1.0];
    menuBtn.layer.cornerRadius = 28;
    [menuBtn setTitle:@"\uf0c9" forState:UIControlStateNormal];
    menuBtn.titleLabel.font = [UIFont fontWithName:kWFIconFontName size:24] ?: [UIFont systemFontOfSize:24];
    [menuBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [menuBtn addTarget:self action:@selector(menuButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:menuBtn];
    
    [NSLayoutConstraint activateConstraints:@[
        [menuBtn.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-24],
        [menuBtn.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [menuBtn.widthAnchor constraintEqualToConstant:56],
        [menuBtn.heightAnchor constraintEqualToConstant:56],
    ]];
    self.floatingMenuButton = menuBtn;
}

- (void)menuButtonTapped {
    __weak typeof(self) weakSelf = self;
    if (![WFActivationView isActivated]) {
        [WFActivationView presentOnViewController:self onSubmit:^(NSString *code) {
            if (code.length > 0) {
                // محاكاة التفعيل - هنا يتم الربط مع السيرفر مستقبلاً
                [WFActivationView setActivated:YES];
                [WFActivationView saveLicenseCode:code expiryDate:nil];
                [weakSelf openMainMenu];
            }
        } onLater:^{}];
        return;
    }
    [self openMainMenu];
}

- (void)openMainMenu {
    __weak typeof(self) weakSelf = self;
    self.floatingMenuButton.hidden = YES;
    [WFMainMenuPanel presentOverView:self.view
        onClose:^{ weakSelf.floatingMenuButton.hidden = NO; }
        onSearch:^{ /* البحث */ }
        onToggleRun:^(BOOL isRunning) { /* تشغيل */ }
        onToggleUpload:^(BOOL isUploading) { /* رفع */ }
        onMap:^{ [weakSelf toggleMapType]; }
        onID:^{ /* المعرف */ }];
}

- (void)toggleMapType {
    BOOL toSatellite = (self.mapView.mapType == MKMapTypeStandard);
    self.mapView.mapType = toSatellite ? MKMapTypeSatellite : MKMapTypeStandard;
    [self.toggleBtn setTitle:(toSatellite ? kWFIconMap : kWFIconSatellite) forState:UIControlStateNormal];
}

- (UIButton *)roundButtonWithGlyph:(NSString *)glyph {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    btn.layer.cornerRadius = 25;
    [btn setTitle:glyph forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont fontWithName:kWFIconFontName size:20] ?: [UIFont systemFontOfSize:20];
    [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    return btn;
}

@end
