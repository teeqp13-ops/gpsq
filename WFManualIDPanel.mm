//
//  WFManualIDPanel.mm
//  WolFox GPS - لوحة إعدادات المعرّف
//

#import "WFManualIDPanel.h"

static NSString * const kWFManualIDEnabledKey = @"WFManualIDEnabled";
static NSString * const kWFManualIDValueKey   = @"WFManualIDValue";
static inline UIColor *WFNavy(void) { return [UIColor colorWithRed:0x07/255.0 green:0x0b/255.0 blue:0x18/255.0 alpha:1.0]; }
static inline UIColor *WFBlue(void) { return [UIColor colorWithRed:0x14/255.0 green:0x7b/255.0 blue:0xc4/255.0 alpha:1.0]; }

@interface WFManualIDPanel ()
@property (nonatomic, strong) UISwitch *manualSwitch;
@property (nonatomic, strong) UITextField *idField;
@property (nonatomic, weak) UIView *hostView;
@end

@implementation WFManualIDPanel

#pragma mark - المعرّف الحالي

+ (NSString *)currentIdentifier {
    BOOL manual = [[NSUserDefaults standardUserDefaults] boolForKey:kWFManualIDEnabledKey];
    NSString *manualValue = [[NSUserDefaults standardUserDefaults] stringForKey:kWFManualIDValueKey];
    if (manual && manualValue.length > 0) {
        return manualValue;
    }
    return [[[UIDevice currentDevice] identifierForVendor] UUIDString];
}

#pragma mark - العرض

+ (void)presentOverView:(UIView *)hostView {
    WFManualIDPanel *panel = [[WFManualIDPanel alloc] initWithFrame:hostView.bounds];
    panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    panel.hostView = hostView;
    panel.alpha = 0;
    [hostView addSubview:panel];
    [UIView animateWithDuration:0.2 animations:^{ panel.alpha = 1; }];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
        self.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        [self buildCard];
    }
    return self;
}

- (void)buildCard {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = WFNavy();
    card.layer.cornerRadius = 18;
    card.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [self addSubview:card];

    [NSLayoutConstraint activateConstraints:@[
        [card.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [card.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [card.widthAnchor constraintEqualToConstant:300],
    ]];

    // رأس
    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"إعدادات المعرّف";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:18];
    [card addSubview:title];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor colorWithWhite:1 alpha:0.6] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(dismissPanel) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:closeBtn];

    // تفعيل يدوي
    UILabel *switchLabel = [[UILabel alloc] init];
    switchLabel.translatesAutoresizingMaskIntoConstraints = NO;
    switchLabel.text = @"تفعيل المعرّف يدوي";
    switchLabel.textColor = [UIColor whiteColor];
    switchLabel.font = [UIFont systemFontOfSize:15];
    [card addSubview:switchLabel];

    UISwitch *sw = [[UISwitch alloc] init];
    sw.translatesAutoresizingMaskIntoConstraints = NO;
    sw.onTintColor = WFBlue();
    sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:kWFManualIDEnabledKey];
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [card addSubview:sw];
    self.manualSwitch = sw;

    // حقل المعرّف
    UITextField *field = [[UITextField alloc] init];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    field.textColor = [UIColor whiteColor];
    field.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    field.textAlignment = NSTextAlignmentCenter;
    field.placeholder = @"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";
    field.text = [[NSUserDefaults standardUserDefaults] stringForKey:kWFManualIDValueKey];
    field.layer.cornerRadius = 8;
    field.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    [card addSubview:field];
    self.idField = field;
    UIView *pad = [[UIView alloc] initWithFrame:CGRectMake(0,0,10,10)];
    field.leftView = pad; field.leftViewMode = UITextFieldViewModeAlways;
    field.rightView = pad; field.rightViewMode = UITextFieldViewModeAlways;

    // حفظ
    UIButton *saveBtn = [self actionButtonWithTitle:@"حفظ" color:[UIColor systemGreenColor]];
    [saveBtn addTarget:self action:@selector(saveTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:saveBtn];

    // تصدير / استيراد
    UIButton *exportBtn = [self actionButtonWithTitle:@"تصدير" color:WFBlue()];
    [exportBtn addTarget:self action:@selector(exportTapped) forControlEvents:UIControlEventTouchUpInside];
    UIButton *importBtn = [self actionButtonWithTitle:@"استيراد" color:WFBlue()];
    [importBtn addTarget:self action:@selector(importTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[importBtn, exportBtn]];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.axis = UILayoutConstraintAxisHorizontal;
    row.distribution = UIStackViewDistributionFillEqually;
    row.spacing = 10;
    [card addSubview:row];

    // إعادة تعيين (مع تحذير)
    UIButton *resetBtn = [self actionButtonWithTitle:@"إعادة تعيين" color:[UIColor systemRedColor]];
    [resetBtn addTarget:self action:@selector(resetTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:resetBtn];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [title.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],

        [closeBtn.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [closeBtn.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],

        [switchLabel.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:20],
        [switchLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],

        [sw.centerYAnchor constraintEqualToAnchor:switchLabel.centerYAnchor],
        [sw.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],

        [field.topAnchor constraintEqualToAnchor:switchLabel.bottomAnchor constant:14],
        [field.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [field.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [field.heightAnchor constraintEqualToConstant:42],

        [saveBtn.topAnchor constraintEqualToAnchor:field.bottomAnchor constant:12],
        [saveBtn.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [saveBtn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [saveBtn.heightAnchor constraintEqualToConstant:44],

        [row.topAnchor constraintEqualToAnchor:saveBtn.bottomAnchor constant:14],
        [row.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [row.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [row.heightAnchor constraintEqualToConstant:44],

        [resetBtn.topAnchor constraintEqualToAnchor:row.bottomAnchor constant:14],
        [resetBtn.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [resetBtn.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [resetBtn.heightAnchor constraintEqualToConstant:44],
        [resetBtn.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18],
    ]];
}

- (UIButton *)actionButtonWithTitle:(NSString *)title color:(UIColor *)color {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    btn.backgroundColor = color;
    btn.layer.cornerRadius = 10;
    return btn;
}

#pragma mark - أحداث

- (void)switchChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:kWFManualIDEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)saveTapped {
    [[NSUserDefaults standardUserDefaults] setObject:self.idField.text forKey:kWFManualIDValueKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self.idField resignFirstResponder];
}

- (void)exportTapped {
    NSString *value = [WFManualIDPanel currentIdentifier];
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[value] applicationActivities:nil];
    UIViewController *rootVC = self.hostView.window.rootViewController;
    [rootVC presentViewController:share animated:YES completion:nil];
}

- (void)importTapped {
    NSString *clip = [UIPasteboard generalPasteboard].string;
    if (clip.length > 0) {
        self.idField.text = clip;
    }
}

- (void)resetTapped {
    // تحذير قبل الحذف (مثل ما هو متعارف عليه بأي عملية حذف بيانات لا يمكن التراجع عنها)
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"إعادة تعيين"
                                                                     message:@"سيتم حذف المعرّف الحالي وتوليد معرّف جديد. إذا لم تكن متأكدًا من وظيفة هذا الخيار يرجى عدم استخدامه."
                                                              preferredStyle:UIAlertControllerStyleAlert];
    alert.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إعادة تعيين" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kWFManualIDValueKey];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kWFManualIDEnabledKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        self.idField.text = @"";
        self.manualSwitch.on = NO;
    }]];
    UIViewController *rootVC = self.hostView.window.rootViewController;
    [rootVC presentViewController:alert animated:YES completion:nil];
}

- (void)dismissPanel {
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end
