//
//  WFActivationPanel.mm (Updated)
//  Fake GPS Tweak (WolFox)
//
//  لوحة التفعيل + UIToolbar مع زر رجوع وزر تأكيد داخل الكيبورد
//

#import <UIKit/UIKit.h>
#import "WFActivation.h"

static UIColor *WFNavy(void)   { return [UIColor colorWithRed:0x07/255.0 green:0x0b/255.0 blue:0x18/255.0 alpha:1.0]; }
static UIColor *WFPanelC(void) { return [UIColor colorWithRed:0x0e/255.0 green:0x14/255.0 blue:0x2b/255.0 alpha:1.0]; }
static UIColor *WFGold(void)   { return [UIColor colorWithRed:0xc9/255.0 green:0xa2/255.0 blue:0x27/255.0 alpha:1.0]; }
static UIColor *WFGold2(void)  { return [UIColor colorWithRed:0xe8/255.0 green:0xc4/255.0 blue:0x53/255.0 alpha:1.0]; }
static UIColor *WFMuted(void)  { return [UIColor colorWithRed:0x6b/255.0 green:0x74/255.0 blue:0x88/255.0 alpha:1.0]; }
static UIColor *WFSuccess(void){ return [UIColor colorWithRed:0x3f/255.0 green:0xd6/255.0 blue:0x8a/255.0 alpha:1.0]; }
static UIColor *WFDanger(void) { return [UIColor colorWithRed:0xff/255.0 green:0x5d/255.0 blue:0x6c/255.0 alpha:1.0]; }

NS_ASSUME_NONNULL_BEGIN

@protocol WFActivationPanelDelegate <NSObject>
- (void)wfActivationPanelDidActivate;
- (void)wfActivationPanelDidDismiss;
@end

@interface WFActivationPanel : NSObject
+ (instancetype)shared;
- (void)show;
- (void)dismiss;
@property (nonatomic, weak, nullable) id<WFActivationPanelDelegate> delegate;
@end

NS_ASSUME_NONNULL_END

@interface WFActivationPanel () <UITextFieldDelegate>
@property (nonatomic, strong, nullable) UIWindow *window;
@property (nonatomic, strong, nullable) UITextField *codeField;
@property (nonatomic, strong, nullable) UILabel *statusLabel;
@property (nonatomic, strong, nullable) UIButton *activateButton;
@property (nonatomic, strong, nullable) UIButton *visibilityButton;
@property (nonatomic, strong, nullable) UILabel *featuresLabel;
@property (nonatomic, assign) BOOL codeVisible;
@end

@implementation WFActivationPanel

+ (instancetype)shared {
    static WFActivationPanel *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [WFActivationPanel new]; });
    return inst;
}

- (void)show {
    if (self.window) {
        self.window.hidden = NO;
        return;
    }

    UIWindow *win = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    win.windowLevel = UIWindowLevelAlert + 100;
    win.backgroundColor = WFNavy();

    UIViewController *rootVC = [UIViewController new];
    rootVC.view.backgroundColor = WFNavy();
    win.rootViewController = rootVC;

    UIView *root = rootVC.view;

    UIView *topbar = [[UIView alloc] init];
    topbar.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:topbar];

    UIView *badge = [[UIView alloc] init];
    badge.backgroundColor = WFPanelC();
    badge.layer.cornerRadius = 8;
    badge.layer.borderWidth = 1;
    badge.layer.borderColor = [WFGold() colorWithAlphaComponent:0.25].CGColor;
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    [topbar addSubview:badge];

    UILabel *badgeLabel = [[UILabel alloc] init];
    badgeLabel.text = @"📍 Fake GPS";
    badgeLabel.textColor = WFGold2();
    badgeLabel.font = [UIFont boldSystemFontOfSize:11];
    badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [badge addSubview:badgeLabel];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:WFMuted() forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [closeBtn addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    [topbar addSubview:closeBtn];

    [NSLayoutConstraint activateConstraints:@[
        [topbar.topAnchor constraintEqualToAnchor:root.safeAreaLayoutGuide.topAnchor constant:12],
        [topbar.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:16],
        [topbar.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-16],
        [topbar.heightAnchor constraintEqualToConstant:34],
        [badge.leadingAnchor constraintEqualToAnchor:topbar.leadingAnchor],
        [badge.centerYAnchor constraintEqualToAnchor:topbar.centerYAnchor],
        [badge.heightAnchor constraintEqualToConstant:26],
        [badgeLabel.centerXAnchor constraintEqualToAnchor:badge.centerXAnchor],
        [badgeLabel.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor],
        [badge.widthAnchor constraintEqualToAnchor:badgeLabel.widthAnchor constant:20],
        [closeBtn.trailingAnchor constraintEqualToAnchor:topbar.trailingAnchor],
        [closeBtn.centerYAnchor constraintEqualToAnchor:topbar.centerYAnchor],
        [closeBtn.widthAnchor constraintEqualToConstant:32],
        [closeBtn.heightAnchor constraintEqualToConstant:32],
    ]];

    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:content];

    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:topbar.bottomAnchor constant:6],
        [content.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
    ]];

    UIView *lockIcon = [[UIView alloc] init];
    lockIcon.backgroundColor = [WFGold() colorWithAlphaComponent:0.10];
    lockIcon.layer.cornerRadius = 20;
    lockIcon.layer.borderWidth = 1;
    lockIcon.layer.borderColor = [WFGold() colorWithAlphaComponent:0.3].CGColor;
    lockIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:lockIcon];

    UILabel *lockEmoji = [[UILabel alloc] init];
    lockEmoji.text = @"🔒";
    lockEmoji.font = [UIFont systemFontOfSize:28];
    lockEmoji.translatesAutoresizingMaskIntoConstraints = NO;
    [lockIcon addSubview:lockEmoji];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"التفعيل مطلوب";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:16];
    title.textAlignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.text = @"أدخل كود التفعيل للوصول لكل مميزات Fake GPS";
    subtitle.textColor = WFMuted();
    subtitle.font = [UIFont systemFontOfSize:12];
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 0;
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:subtitle];

    UIView *card = [[UIView alloc] init];
    card.backgroundColor = WFPanelC();
    card.layer.cornerRadius = 16;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.06].CGColor;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:card];

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
    self.codeField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.codeField.secureTextEntry = YES;
    self.codeVisible = NO;
    self.codeField.delegate = self;
    self.codeField.translatesAutoresizingMaskIntoConstraints = NO;

    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth([UIScreen mainScreen].bounds), 44)];
    toolbar.barTintColor = WFPanelC();
    toolbar.translucent = NO;
    toolbar.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    UIBarButtonItem *backBtn = [[UIBarButtonItem alloc] initWithTitle:@"← رجوع" style:UIBarButtonItemStylePlain target:self action:@selector(dismissKeyboard)];
    backBtn.tintColor = WFMuted();
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *confirmBtn = [[UIBarButtonItem alloc] initWithTitle:@"✓ تأكيد" style:UIBarButtonItemStylePlain target:self action:@selector(activateTapped)];
    confirmBtn.tintColor = WFGold();
    toolbar.items = @[backBtn, flexSpace, confirmBtn];
    self.codeField.inputAccessoryView = toolbar;
    [card addSubview:self.codeField];

    self.visibilityButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.visibilityButton setTitle:@"إظهار" forState:UIControlStateNormal];
    [self.visibilityButton setTitleColor:WFGold2() forState:UIControlStateNormal];
    self.visibilityButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    self.visibilityButton.backgroundColor = [WFGold() colorWithAlphaComponent:0.10];
    self.visibilityButton.layer.cornerRadius = 10;
    self.visibilityButton.layer.borderWidth = 1;
    self.visibilityButton.layer.borderColor = [WFGold() colorWithAlphaComponent:0.25].CGColor;
    self.visibilityButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.visibilityButton addTarget:self action:@selector(toggleCodeVisibility) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.visibilityButton];

    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [copyButton setTitle:@"نسخ" forState:UIControlStateNormal];
    [copyButton setTitleColor:WFGold2() forState:UIControlStateNormal];
    copyButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    copyButton.backgroundColor = [WFGold() colorWithAlphaComponent:0.10];
    copyButton.layer.cornerRadius = 10;
    copyButton.layer.borderWidth = 1;
    copyButton.layer.borderColor = [WFGold() colorWithAlphaComponent:0.25].CGColor;
    copyButton.translatesAutoresizingMaskIntoConstraints = NO;
    [copyButton addTarget:self action:@selector(copyActivationCode) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:copyButton];

    self.activateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.activateButton setTitle:@"تفعيل" forState:UIControlStateNormal];
    [self.activateButton setTitleColor:WFNavy() forState:UIControlStateNormal];
    self.activateButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    self.activateButton.backgroundColor = WFGold();
    self.activateButton.layer.cornerRadius = 12;
    self.activateButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.activateButton addTarget:self action:@selector(activateTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.activateButton];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:12];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:self.statusLabel];

    self.featuresLabel = [[UILabel alloc] init];
    self.featuresLabel.text = @"المميزات\n• تغيير الموقع بدقة\n• حفظ المواقع المفضلة\n• واجهة خفيفة ومتوافقة مع التطبيقات\n• حماية التفعيل وربط الجهاز";
    self.featuresLabel.textColor = WFMuted();
    self.featuresLabel.font = [UIFont systemFontOfSize:11];
    self.featuresLabel.numberOfLines = 0;
    self.featuresLabel.textAlignment = NSTextAlignmentRight;
    self.featuresLabel.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.025];
    self.featuresLabel.layer.cornerRadius = 12;
    self.featuresLabel.layer.masksToBounds = YES;
    self.featuresLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:self.featuresLabel];

    [NSLayoutConstraint activateConstraints:@[
        [lockIcon.topAnchor constraintEqualToAnchor:content.topAnchor constant:24],
        [lockIcon.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [lockIcon.widthAnchor constraintEqualToConstant:70],
        [lockIcon.heightAnchor constraintEqualToConstant:70],
        [lockEmoji.centerXAnchor constraintEqualToAnchor:lockIcon.centerXAnchor],
        [lockEmoji.centerYAnchor constraintEqualToAnchor:lockIcon.centerYAnchor],
        [title.topAnchor constraintEqualToAnchor:lockIcon.bottomAnchor constant:16],
        [title.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:24],
        [title.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-24],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:6],
        [subtitle.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:30],
        [subtitle.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-30],
        [card.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:22],
        [card.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [card.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [self.codeField.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [self.codeField.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [self.codeField.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [self.codeField.heightAnchor constraintEqualToConstant:48],
        [self.visibilityButton.topAnchor constraintEqualToAnchor:self.codeField.bottomAnchor constant:10],
        [self.visibilityButton.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [self.visibilityButton.heightAnchor constraintEqualToConstant:38],
        [copyButton.topAnchor constraintEqualToAnchor:self.codeField.bottomAnchor constant:10],
        [copyButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [copyButton.leadingAnchor constraintEqualToAnchor:self.visibilityButton.trailingAnchor constant:10],
        [copyButton.widthAnchor constraintEqualToAnchor:self.visibilityButton.widthAnchor],
        [copyButton.heightAnchor constraintEqualToConstant:38],
        [self.activateButton.topAnchor constraintEqualToAnchor:self.visibilityButton.bottomAnchor constant:14],
        [self.activateButton.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [self.activateButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [self.activateButton.heightAnchor constraintEqualToConstant:46],
        [self.activateButton.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18],
        [self.statusLabel.topAnchor constraintEqualToAnchor:card.bottomAnchor constant:14],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:24],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-24],
        [self.featuresLabel.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:14],
        [self.featuresLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [self.featuresLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
    ]];

    win.hidden = NO;
    self.window = win;
}

- (void)dismiss {
    self.window.hidden = YES;
    if ([self.delegate respondsToSelector:@selector(wfActivationPanelDidDismiss)]) {
        [self.delegate wfActivationPanelDidDismiss];
    }
}

#pragma mark - Code Actions

- (void)toggleCodeVisibility {
    self.codeVisible = !self.codeVisible;
    NSString *currentText = self.codeField.text ?: @"";
    self.codeField.secureTextEntry = !self.codeVisible;
    self.codeField.text = currentText;
    [self.visibilityButton setTitle:(self.codeVisible ? @"إخفاء" : @"إظهار") forState:UIControlStateNormal];
}

- (void)copyActivationCode {
    NSString *code = [self.codeField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (code.length == 0) {
        self.statusLabel.text = @"أدخل الكود أولاً";
        self.statusLabel.textColor = WFDanger();
        return;
    }
    [UIPasteboard generalPasteboard].string = code;
    self.statusLabel.text = @"تم نسخ الكود";
    self.statusLabel.textColor = WFSuccess();
}

#pragma mark - Keyboard Actions

- (void)dismissKeyboard {
    [self.codeField resignFirstResponder];
}

#pragma mark - Activation

- (void)activateTapped {
    NSString *code = [self.codeField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (code.length < 4) {
        self.statusLabel.text = @"أدخل كود صحيح";
        self.statusLabel.textColor = WFDanger();
        return;
    }

    self.statusLabel.text = @"جاري التحقق...";
    self.statusLabel.textColor = WFMuted();
    self.activateButton.enabled = NO;

    [WFActivation activateWithCode:code completion:^(BOOL success, NSString *message) {
        self.statusLabel.text = message;
        self.statusLabel.textColor = success ? WFSuccess() : WFDanger();
        self.activateButton.enabled = YES;
        if (success && [self.delegate respondsToSelector:@selector(wfActivationPanelDidActivate)]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.delegate wfActivationPanelDidActivate];
            });
        }
    }];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self activateTapped];
    return YES;
}

@end
