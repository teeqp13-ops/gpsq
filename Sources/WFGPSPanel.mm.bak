//
//  WFGPSPanel.m
//  Fake GPS Tweak (WolFox)
//  الإصدار القادم – واجهة محسّنة بالكامل
//

#import "WFGPSPanel.h"
#import "WFActivation.h"
#import <MapKit/MapKit.h>

#pragma mark - ألوان الهوية

static UIColor *WFNavy(void)   { return [UIColor colorWithRed:0x07/255.0 green:0x0b/255.0 blue:0x18/255.0 alpha:1.0]; }
static UIColor *WFPanelC(void) { return [UIColor colorWithRed:0x0e/255.0 green:0x14/255.0 blue:0x2b/255.0 alpha:1.0]; }
static UIColor *WFGold(void)   { return [UIColor colorWithRed:0xc9/255.0 green:0xa2/255.0 blue:0x27/255.0 alpha:1.0]; }
static UIColor *WFGold2(void)  { return [UIColor colorWithRed:0xe8/255.0 green:0xc4/255.0 blue:0x53/255.0 alpha:1.0]; }
static UIColor *WFMuted(void)  { return [UIColor colorWithRed:0x6b/255.0 green:0x74/255.0 blue:0x88/255.0 alpha:1.0]; }
static UIColor *WFSuccess(void){ return [UIColor colorWithRed:0x3f/255.0 green:0xd6/255.0 blue:0x8a/255.0 alpha:1.0]; }
static UIColor *WFDanger(void) { return [UIColor colorWithRed:0xff/255.0 green:0x5d/255.0 blue:0x6c/255.0 alpha:1.0]; }

#pragma mark - الواجهة

@interface WFGPSPanel () <UITextFieldDelegate, MKMapViewDelegate>

@property (nonatomic, strong) UIWindow *floatingWindow;
@property (nonatomic, strong) UIWindow *panelWindow;

// شاشة التفعيل
@property (nonatomic, strong) UIView *activationView;
@property (nonatomic, strong) UITextField *codeField;
@property (nonatomic, strong) UILabel *actStatusLabel;

// شاشة المميزات
@property (nonatomic, strong) UIView *featuresView;
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) MKPointAnnotation *pin;

@property (nonatomic, strong) UISwitch *moveLocationSwitch;
@property (nonatomic, strong) UISwitch *simulateMovementSwitch;

@end

@implementation WFGPSPanel

+ (instancetype)shared {
    static WFGPSPanel *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [WFGPSPanel new]; });
    return inst;
}

#pragma mark - زر عائم محسّن

- (void)showFloatingButton {
    if (self.floatingWindow) { self.floatingWindow.hidden = NO; return; }

    UIWindow *win = [[UIWindow alloc] initWithFrame:CGRectMake(20, 120, 58, 58)];
    win.windowLevel = UIWindowLevelStatusBar + 200;
    win.backgroundColor = [UIColor clearColor];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = win.bounds;
    btn.layer.cornerRadius = 29;
    btn.backgroundColor = WFGold();
    btn.layer.shadowColor = [UIColor blackColor].CGColor;
    btn.layer.shadowOpacity = 0.4;
    btn.layer.shadowRadius = 10;

    [btn setTitle:@"⚡️" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:22];

    [UIView animateWithDuration:1.2 delay:0 options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse animations:^{
        btn.transform = CGAffineTransformMakeScale(1.08, 1.08);
    } completion:nil];

    [btn addTarget:self action:@selector(presentPanel) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    [btn addGestureRecognizer:pan];

    win.rootViewController = [UIViewController new];
    [win addSubview:btn];
    win.hidden = NO;

    self.floatingWindow = win;
}

- (void)handleDrag:(UIPanGestureRecognizer *)gesture {
    UIWindow *win = self.floatingWindow;
    CGPoint t = [gesture translationInView:win];
    win.center = CGPointMake(win.center.x + t.x, win.center.y + t.y);
    [gesture setTranslation:CGPointZero inView:win];
}

#pragma mark - عرض اللوحة الكاملة

- (void)presentPanel {
    if (self.panelWindow) {
        self.panelWindow.hidden = NO;
        [self refreshStateForActivation];
        return;
    }

    UIWindow *win = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    win.windowLevel = UIWindowLevelAlert + 100;
    win.backgroundColor = WFNavy();

    UIViewController *rootVC = [UIViewController new];
    rootVC.view.backgroundColor = WFNavy();
    win.rootViewController = rootVC;

    UIView *root = rootVC.view;

    UIView *topbar = [self buildTopBar];
    topbar.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:topbar];

    [self buildActivationView];
    [self buildFeaturesView];

    self.activationView.translatesAutoresizingMaskIntoConstraints = NO;
    self.featuresView.translatesAutoresizingMaskIntoConstraints = NO;

    [root addSubview:self.activationView];
    [root addSubview:self.featuresView];

    [NSLayoutConstraint activateConstraints:@[
        [topbar.topAnchor constraintEqualToAnchor:root.safeAreaLayoutGuide.topAnchor constant:12],
        [topbar.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:16],
        [topbar.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-16],
        [topbar.heightAnchor constraintEqualToConstant:34],

        [self.activationView.topAnchor constraintEqualToAnchor:topbar.bottomAnchor constant:6],
        [self.activationView.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [self.activationView.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [self.activationView.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],

        [self.featuresView.topAnchor constraintEqualToAnchor:topbar.bottomAnchor constant:6],
        [self.featuresView.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [self.featuresView.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [self.featuresView.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
    ]];

    win.hidden = NO;
    self.panelWindow = win;

    [self refreshStateForActivation];
}

#pragma mark - شريط علوي

- (UIView *)buildTopBar {
    UIView *topbar = [[UIView alloc] init];
    topbar.backgroundColor = [UIColor clearColor];

    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [backBtn setTitle:@"➜" forState:UIControlStateNormal];
    backBtn.transform = CGAffineTransformMakeRotation(M_PI);
    backBtn.backgroundColor = WFPanelC();
    backBtn.layer.cornerRadius = 9;
    backBtn.layer.borderWidth = 1;
    backBtn.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08].CGColor;
    backBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [backBtn addTarget:self action:@selector(dismissPanel) forControlEvents:UIControlEventTouchUpInside];

    UIView *badge = [[UIView alloc] init];
    badge.backgroundColor = WFPanelC();
    badge.layer.cornerRadius = 8;
    badge.layer.borderWidth = 1;
    badge.layer.borderColor = [WFGold() colorWithAlphaComponent:0.25].CGColor;
    badge.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *badgeLabel = [[UILabel alloc] init];
    badgeLabel.text = @"📍 Fake GPS";
    badgeLabel.textColor = WFGold2();
    badgeLabel.font = [UIFont boldSystemFontOfSize:11];
    badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [badge addSubview:badgeLabel];
    [topbar addSubview:backBtn];
    [topbar addSubview:badge];

    [NSLayoutConstraint activateConstraints:@[
        [backBtn.leadingAnchor constraintEqualToAnchor:topbar.leadingAnchor],
        [backBtn.centerYAnchor constraintEqualToAnchor:topbar.centerYAnchor],
        [backBtn.widthAnchor constraintEqualToConstant:32],
        [backBtn.heightAnchor constraintEqualToConstant:32],

        [badge.trailingAnchor constraintEqualToAnchor:topbar.trailingAnchor],
        [badge.centerYAnchor constraintEqualToAnchor:topbar.centerYAnchor],
        [badge.heightAnchor constraintEqualToConstant:26],

        [badgeLabel.centerXAnchor constraintEqualToAnchor:badge.centerXAnchor],
        [badgeLabel.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor],
        [badge.widthAnchor constraintEqualToAnchor:badgeLabel.widthAnchor constant:20],
    ]];

    return topbar;
}

#pragma mark - تحديث حالة التفعيل

- (void)refreshStateForActivation {
    BOOL activated = [WFActivation isActivated];
    self.activationView.hidden = activated;
    self.featuresView.hidden = !activated;
    if (activated) { [self syncMapWithSavedCoordinate]; }
}

- (void)dismissPanel {
    self.panelWindow.hidden = YES;
}

#pragma mark - شاشة التفعيل

- (void)buildActivationView {
    UIView *v = [UIView new];
    self.activationView = v;

    UILabel *title = [[UILabel alloc] init];
    title.text = @"التفعيل مطلوب";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:18];
    title.textAlignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.text = @"أدخل كود التفعيل للوصول لكل مميزات Fake GPS";
    subtitle.textColor = WFMuted();
    subtitle.font = [UIFont systemFontOfSize:12];
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 0;
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *card = [[UIView alloc] init];
    card.backgroundColor = WFPanelC();
    card.layer.cornerRadius = 16;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06].CGColor;
    card.translatesAutoresizingMaskIntoConstraints = NO;

    self.codeField = [[UITextField alloc] init];
    self.codeField.placeholder = @"XXXXXXXX";
    self.codeField.textColor = [UIColor whiteColor];
    self.codeField.font = [UIFont monospacedSystemFontOfSize:18 weight:UIFontWeightBold];
    self.codeField.textAlignment = NSTextAlignmentCenter;
    self.codeField.backgroundColor = WFNavy();
    self.codeField.layer.cornerRadius = 12;
    self.codeField.layer.borderWidth = 1;
    self.codeField.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08].CGColor;
    self.codeField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.codeField.delegate = self;
    self.codeField.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *activateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [activateBtn setTitle:@"تفعيل" forState:UIControlStateNormal];
    [activateBtn setTitleColor:WFNavy() forState:UIControlStateNormal];
    activateBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    activateBtn.backgroundColor = WFGold();
    activateBtn.layer.cornerRadius = 12;
    activateBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [activateBtn addTarget:self action:@selector(activateTapped) forControlEvents:UIControlEventTouchUpInside];

    self.actStatusLabel = [[UILabel alloc] init];
    self.actStatusLabel.font = [UIFont boldSystemFontOfSize:12];
    self.actStatusLabel.textAlignment = NSTextAlignmentCenter;
    self.actStatusLabel.numberOfLines = 0;
    self.actStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [v addSubview:title];
    [v addSubview:subtitle];
    [v addSubview:card];
    [card addSubview:self.codeField];
    [card addSubview:activateBtn];
    [v addSubview:self.actStatusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:v.topAnchor constant:40],
        [title.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:24],
        [title.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-24],

        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:6],
        [subtitle.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:30],
        [subtitle.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-30],

        [card.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:22],
        [card.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:16],
        [card.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-16],

        [self.codeField.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [self.codeField.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [self.codeField.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [self.codeField.heightAnchor constraintEqualToConstant:48],

        [activateBtn.topAnchor constraintEqualToAnchor:self.codeField.bottomAnchor constant:14],
        [activateBtn.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [activateBtn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [activateBtn.heightAnchor constraintEqualToConstant:46],
        [activateBtn.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18],

        [self.actStatusLabel.topAnchor constraintEqualToAnchor:card.bottomAnchor constant:14],
        [self.actStatusLabel.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:24],
        [self.actStatusLabel.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-24],
    ]];
}

- (void)activateTapped {
    NSString *code = [self.codeField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (code.length < 4) {
        self.actStatusLabel.text = @"أدخل كود صحيح";
        self.actStatusLabel.textColor = WFDanger();
        return;
    }
    self.actStatusLabel.text = @"جاري التحقق...";
    self.actStatusLabel.textColor = WFMuted();

    [WFActivation activateWithCode:code completion:^(BOOL success, NSString *message) {
        self.actStatusLabel.text = message;
        self.actStatusLabel.textColor = success ? WFSuccess() : WFDanger();
        if (success) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self refreshStateForActivation];
            });
        }
    }];
}

#pragma mark - شاشة المميزات الجديدة

- (void)buildFeaturesView {
    UIView *v = [UIView new];
    self.featuresView = v;

    UIView *statusBar = [self buildStatusBar];
    statusBar.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:statusBar];

    self.mapView = [[MKMapView alloc] init];
    self.mapView.mapType = MKMapTypeHybrid;
    self.mapView.layer.cornerRadius = 16;
    self.mapView.clipsToBounds = YES;
    self.mapView.delegate = self;
    self.mapView.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:self.mapView];

    self.pin = [MKPointAnnotation new];
    [self.mapView addAnnotation:self.pin];

    UIStackView *searchSection = [self buildSectionWithTitle:@"🔍 البحث"
                                                       items:@[
        [self makeFeatureButton:@"بحث عن موقع" bg:WFPanelC() textColor:[UIColor whiteColor] action:@selector(searchTapped)],
        [self makeFeatureButton:@"⭐️ المفضلة" bg:[UIColor colorWithRed:0.48 green:0.36 blue:1.0 alpha:1.0] textColor:[UIColor whiteColor] action:@selector(favoritesTapped)]
    ]];

    UIStackView *locationSection = [self buildSectionWithTitle:@"📍 الموقع"
                                                         items:@[
        [self makeToggleRow:@"تفعيل تغيير الموقع" switchOut:&_moveLocationSwitch action:@selector(moveLocationChanged)],
        [self makeToggleRow:@"تفعيل الحركة" switchOut:&_simulateMovementSwitch action:@selector(movementChanged)],
        [self makeFeatureButton:@"📍 اختر هذا الموقع" bg:WFGold() textColor:WFNavy() action:@selector(chooseLocationTapped)]
    ]];

    UIStackView *btSection = [self buildSectionWithTitle:@"📡 البلوتوث"
                                                  items:@[
        [self makeFeatureButton:@"إدارة البلوتوث والـ Beacons" bg:[UIColor colorWithRed:0.09 green:0.71 blue:0.77 alpha:1.0] textColor:[UIColor whiteColor] action:@selector(beaconsTapped)]
    ]];

    UIStackView *toolSection = [self buildSectionWithTitle:@"⚙️ الأداة"
                                                    items:@[
        [self makeFeatureButton:@"🙈 إخفاء زر الأداة" bg:[UIColor colorWithRed:0.88 green:0.30 blue:0.30 alpha:1.0] textColor:[UIColor whiteColor] action:@selector(hideToolTapped)]
    ]];

    UIStackView *mainStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        searchSection, locationSection, btSection, toolSection
    ]];
