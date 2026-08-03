//
//  WFGPSPanel.mm
//  WolFox GPS - الشاشة الرئيسية (تدمج كل المكونات)
//

#import "WFGPSPanel.h"
#import <MapKit/MapKit.h>
#import "WFFavoritesManager.h"
#import "WFManualIDPanel.h"
#import "WFScheduleSettingsPanel.h"
#import "WFActivationView.h"

static inline UIColor *WFNavy(void) { return [UIColor colorWithRed:0x07/255.0 green:0x0b/255.0 blue:0x18/255.0 alpha:1.0]; }
static inline UIColor *WFBlue(void) { return [UIColor colorWithRed:0x14/255.0 green:0x7b/255.0 blue:0xc4/255.0 alpha:1.0]; }

static NSString * const kWFToggleMovement  = @"WFToggleMovement";
static NSString * const kWFToggleCamera    = @"WFToggleCamera";
static NSString * const kWFToggleSchedule  = @"WFToggleSchedule";
static NSString * const kWFTogglePermanent = @"WFTogglePermanent";
static NSString * const kWFToggleNotify    = @"WFToggleNotify";
static NSString * const kWFHideTapCountKey = @"WFHideTapCount";

@interface WFGPSPanel () <MKMapViewDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) UISegmentedControl *mapTypeControl;
@property (nonatomic, strong) UIView *toolButton;
@property (nonatomic, strong) UIStackView *togglesStack;
@property (nonatomic, assign) NSInteger hiddenTapCount;
@property (nonatomic, assign) BOOL toolHidden;
@end

@implementation WFGPSPanel

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = WFNavy();
    [self setupMap];
    [self setupMapTypeControl];
    [self setupBottomPanel];
    [self setupFloatingToolButton];
}

#pragma mark - الخريطة
- (void)setupMap {
    self.mapView = [[MKMapView alloc] init];
    self.mapView.translatesAutoresizingMaskIntoConstraints = NO;
    self.mapView.delegate = self;
    self.mapView.showsUserLocation = YES;
    [self.view addSubview:self.mapView];
    [NSLayoutConstraint activateConstraints:@[
        [self.mapView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:60],
        [self.mapView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.mapView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.mapView.heightAnchor constraintEqualToConstant:340],
    ]];
    MKPointAnnotation *center = [[MKPointAnnotation alloc] init];
    center.coordinate = self.mapView.centerCoordinate;
    center.title = @"الموقع المحدد";
    [self.mapView addAnnotation:center];
}

- (void)setupMapTypeControl {
    self.mapTypeControl = [[UISegmentedControl alloc] initWithItems:@[@"قمر صناعي", @"خريطة"]];
    self.mapTypeControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.mapTypeControl.selectedSegmentIndex = 0;
    [self.mapTypeControl addTarget:self action:@selector(mapTypeChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.mapTypeControl];
    [NSLayoutConstraint activateConstraints:@[
        [self.mapTypeControl.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [self.mapTypeControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.mapTypeControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
    ]];
}

- (void)mapTypeChanged {
    self.mapView.mapType = (self.mapTypeControl.selectedSegmentIndex == 0) ? MKMapTypeSatellite : MKMapTypeStandard;
}

#pragma mark - اللوحة السفلية
- (void)setupBottomPanel {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [scroll addSubview:stack];

    // صف 1: بحث + مفضلة
    UIStackView *row1 = [self rowStack];
    [row1 addArrangedSubview:[self pillButtonWithTitle:@"بحث" color:WFBlue() action:@selector(searchTapped)]];
    [row1 addArrangedSubview:[self pillButtonWithTitle:@"المفضلة" color:[UIColor colorWithRed:0xe8/255.0 green:0xc0/255.0 blue:0x2e/255.0 alpha:1.0] action:@selector(favoritesTapped)]];
    [stack addArrangedSubview:row1];

    // صف 2: إخفاء الأداة + المعرّف
    UIStackView *row2 = [self rowStack];
    [row2 addArrangedSubview:[self pillButtonWithTitle:@"إخفاء الأداة" color:[UIColor colorWithRed:0xe0/255.0 green:0x7a/255.0 blue:0x2e/255.0 alpha:1.0] action:@selector(hideToolTapped)]];
    [row2 addArrangedSubview:[self pillButtonWithTitle:@"المعرّف" color:[UIColor colorWithRed:0x2e/255.0 green:0xb5/255.0 blue:0x6a/255.0 alpha:1.0] action:@selector(idTapped)]];
    [stack addArrangedSubview:row2];

    // صف 3: إدخال الكود + معلومات الترخيص
    UIStackView *row3 = [self rowStack];
    [row3 addArrangedSubview:[self pillButtonWithTitle:@"إدخال الكود" color:WFBlue() action:@selector(enterCodeTapped)]];
    [row3 addArrangedSubview:[self pillButtonWithTitle:@"معلومات الترخيص" color:[UIColor colorWithRed:0x2e/255.0 green:0x9b/255.0 blue:0xe0/255.0 alpha:1.0] action:@selector(licenseInfoTapped)]];
    [stack addArrangedSubview:row3];

    // التبديلات
    self.togglesStack = [[UIStackView alloc] init];
    self.togglesStack.axis = UILayoutConstraintAxisVertical;
    self.togglesStack.spacing = 8;
    [self addToggleRowWithTitle:@"تفعيل دائم" key:kWFTogglePermanent];
    [self addToggleRowWithTitle:@"تنبيه قبل انتهاء الاشتراك" key:kWFToggleNotify];
    [self addToggleRowWithTitle:@"محاكاة الحركة" key:kWFToggleMovement];
    [self addToggleRowWithTitle:@"تزييف موقع الكاميرا" key:kWFToggleCamera];
    [self addToggleRowWithTitle:@"تفعيل بالجدولة" key:kWFToggleSchedule];
    [stack addArrangedSubview:self.togglesStack];

    // زر اختيار الموقع
    UIButton *chooseBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [chooseBtn setTitle:@"اختر هذا الموقع" forState:UIControlStateNormal];
    [chooseBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    chooseBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    chooseBtn.backgroundColor = WFBlue();
    chooseBtn.layer.cornerRadius = 12;
    [chooseBtn.heightAnchor constraintEqualToConstant:50].active = YES;
    [chooseBtn addTarget:self action:@selector(chooseLocationTapped) forControlEvents:UIControlEventTouchUpInside];
    [chooseBtn addTarget:self action:@selector(buttonPressedDown:) forControlEvents:UIControlEventTouchDown];
    [chooseBtn addTarget:self action:@selector(buttonPressedUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [stack addArrangedSubview:chooseBtn];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.mapView.bottomAnchor constant:16],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [stack.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor constant:-16],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor constant:-20],
        [stack.widthAnchor constraintEqualToAnchor:scroll.widthAnchor constant:-32],
    ]];
}

- (UIStackView *)rowStack {
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 10;
    row.distribution = UIStackViewDistributionFillEqually;
    return row;
}

- (UIButton *)pillButtonWithTitle:(NSString *)title color:(UIColor *)color action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    btn.backgroundColor = color;
    btn.layer.cornerRadius = 10;
    [btn.heightAnchor constraintEqualToConstant:48].active = YES;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [btn addTarget:self action:@selector(buttonPressedDown:) forControlEvents:UIControlEventTouchDown];
    [btn addTarget:self action:@selector(buttonPressedUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    return btn;
}

- (void)buttonPressedDown:(UIButton *)sender {
    [UIView animateWithDuration:0.1 animations:^{
        sender.transform = CGAffineTransformMakeScale(0.95, 0.95);
        sender.alpha = 0.75;
    }];
}

- (void)buttonPressedUp:(UIButton *)sender {
    [UIView animateWithDuration:0.15 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.4 options:0 animations:^{
        sender.transform = CGAffineTransformIdentity;
        sender.alpha = 1.0;
    } completion:nil];
}

- (void)addToggleRowWithTitle:(NSString *)title key:(NSString *)key {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [row.heightAnchor constraintEqualToConstant:36].active = YES;
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:14];
    [row addSubview:label];
    UISwitch *sw = [[UISwitch alloc] init];
    sw.translatesAutoresizingMaskIntoConstraints = NO;
    sw.onTintColor = WFBlue();
    sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:key];
    sw.accessibilityIdentifier = key;
    [sw addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw];
    [NSLayoutConstraint activateConstraints:@[
        [label.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [sw.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [sw.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    [self.togglesStack addArrangedSubview:row];
}

- (void)toggleChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:sender.accessibilityIdentifier];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)searchTapped { /* منطق البحث */ }
- (void)favoritesTapped { /* المفضلة */ }
- (void)hideToolTapped { /* إخفاء الأداة */ }
- (void)idTapped { [WFManualIDPanel presentOverView:self.view]; }
- (void)enterCodeTapped { [WFActivationView presentOnViewController:self onSubmit:^(NSString *code) {} onLater:^{}]; }
- (void)licenseInfoTapped { /* معلومات الترخيص */ }
- (void)chooseLocationTapped { NSLog(@"Location selected: %f, %f", self.mapView.centerCoordinate.latitude, self.mapView.centerCoordinate.longitude); }

- (void)setupFloatingToolButton { /* الزر العائم */ }

@end
