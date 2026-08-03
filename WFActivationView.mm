//
//  WFActivationView.mm
//  WolFox GPS - Activation Code Panel
//
//  Custom popup (مو UIAlertController) عشان نتحكم بالتصميم بالكامل:
//  - رأس فيه العنوان + زر إغلاق (✕) بالزاوية
//  - رسالة توضيحية
//  - حقل الكود مع زر لصق (Paste) داخل الحقل
//  - Toolbar فوق الكيبورد: رجوع (يسار) + تم (يمين)
//  - زر "تفعيل" واحد بالمنتصف بلون أزرق بحري سماوي أنيق
//

#import <UIKit/UIKit.h>
#import "WFActivationView.h"

// ألوان البراند
static inline UIColor *WFNavy(void)   { return [UIColor colorWithRed:0x07/255.0 green:0x0b/255.0 blue:0x18/255.0 alpha:1.0]; }
static inline UIColor *WFGold(void)   { return [UIColor colorWithRed:0x14/255.0 green:0x7b/255.0 blue:0xc4/255.0 alpha:1.0]; } // أزرق سماوي بحري
static inline UIColor *WFGoldDim(void){ return [UIColor colorWithRed:0x14/255.0 green:0x7b/255.0 blue:0xc4/255.0 alpha:0.55]; }

static NSString * const kWFActivatedKey = @"WFGPSActivated";
static NSString * const kWFActivationCodeKey = @"WFGPSActivationCode";
static NSString * const kWFActivationExpiryKey = @"WFGPSActivationExpiry";

@interface WFActivationView ()

@property (nonatomic, copy) void (^onSubmit)(NSString *code);
@property (nonatomic, copy) void (^onLater)(void);
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UITextField *codeField;
@property (nonatomic, strong) UIButton *activateButton;
@property (nonatomic, weak) UIView *dimBackground;
@end

@implementation WFActivationView

#pragma mark - حالة التفعيل

+ (BOOL)isActivated {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kWFActivatedKey];
}

+ (void)setActivated:(BOOL)activated {
    [[NSUserDefaults standardUserDefaults] setBool:activated forKey:kWFActivatedKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)saveLicenseCode:(NSString *)code expiryDate:(NSDate *)expiryDate {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (code) [defaults setObject:code forKey:kWFActivationCodeKey];
    if (expiryDate) [defaults setObject:expiryDate forKey:kWFActivationExpiryKey];
    [defaults synchronize];
}

+ (NSString *)licenseCode {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kWFActivationCodeKey];
}

+ (NSDate *)licenseExpiryDate {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kWFActivationExpiryKey];
}

#pragma mark - العرض

+ (void)presentOnViewController:(UIViewController *)vc
                       onSubmit:(void (^)(NSString *code))onSubmit
                        onLater:(void (^)(void))onLater {

    UIView *host = vc.view;

    UIView *dim = [[UIView alloc] initWithFrame:host.bounds];
    dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    dim.alpha = 0;
    [host addSubview:dim];

    WFActivationView *panel = [[WFActivationView alloc] initWithFrame:host.bounds];
    panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    panel.dimBackground = dim;
    panel.onSubmit = onSubmit;
    panel.onLater = onLater;
    [host addSubview:panel];

    panel.card.transform = CGAffineTransformMakeScale(0.9, 0.9);
    panel.card.alpha = 0;

    [UIView animateWithDuration:0.25 animations:^{
        dim.alpha = 1;
        panel.card.alpha = 1;
        panel.card.transform = CGAffineTransformIdentity;
    }];
}

#pragma mark - البناء

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        self.backgroundColor = [UIColor clearColor];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackgroundTap:)];
        [self addGestureRecognizer:tap];

        [self buildCard];
    }
    return self;
}

- (void)buildCard {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor colorWithWhite:0.16 alpha:0.97];
    card.layer.cornerRadius = 18;
    card.layer.masksToBounds = YES;
    card.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [self addSubview:card];
    self.card = card;

    [NSLayoutConstraint activateConstraints:@[
        [card.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [card.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [card.widthAnchor constraintEqualToConstant:300],
    ]];

    // رأس الأداة: خلفية داكنة منفصلة + عنوان محاذي لليمين + زر إغلاق واضح
    UIView *header = [[UIView alloc] init];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.backgroundColor = WFNavy();
    header.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [card addSubview:header];

    // تدوير الزوايا العلوية فقط لتطابق زوايا البطاقة
    header.layer.cornerRadius = 18;
    header.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    header.layer.masksToBounds = YES;

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    UIImage *closeIcon = [UIImage systemImageNamed:@"xmark.circle.fill"];
    [closeBtn setImage:closeIcon forState:UIControlStateNormal];
    closeBtn.tintColor = [UIColor colorWithWhite:1 alpha:0.85]; // أوضح من قبل
    [closeBtn addTarget:self action:@selector(laterTapped) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];

    // العنوان (بدون كلمة "تفعيل")
    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"FAKE GPS";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:19];
    title.textAlignment = NSTextAlignmentRight; // يبدأ من اليمين
    [header addSubview:title];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:card.topAnchor],
        [header.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [header.heightAnchor constraintEqualToConstant:52],

        [closeBtn.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:14],
        [closeBtn.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [closeBtn.widthAnchor constraintEqualToConstant:26],
        [closeBtn.heightAnchor constraintEqualToConstant:26],

        [title.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
        [title.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [title.leadingAnchor constraintGreaterThanOrEqualToAnchor:closeBtn.trailingAnchor constant:8],
    ]];

    // الرسالة
    UILabel *message = [[UILabel alloc] init];
    message.translatesAutoresizingMaskIntoConstraints = NO;
    message.text = @"أدخل كود الترخيص لفتح المنيو والمميزات";
    message.textColor = [UIColor colorWithWhite:1 alpha:0.65];
    message.font = [UIFont systemFontOfSize:13];
    message.textAlignment = NSTextAlignmentCenter;
    message.numberOfLines = 0;
    [card addSubview:message];

    // حاوية الحقل (فيها الحقل + زر اللصق)
    UIView *fieldWrap = [[UIView alloc] init];
    fieldWrap.translatesAutoresizingMaskIntoConstraints = NO;
    fieldWrap.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    fieldWrap.layer.cornerRadius = 10;
    fieldWrap.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [card addSubview:fieldWrap];

    UITextField *field = [[UITextField alloc] init];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.placeholder = @"XXXX-XXXX-XXXX";
    field.textColor = [UIColor whiteColor];
    field.tintColor = WFGold();
    field.font = [UIFont monospacedSystemFontOfSize:16 weight:UIFontWeightMedium];
    field.textAlignment = NSTextAlignmentCenter;
    field.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.keyboardType = UIKeyboardTypeASCIICapable;
    field.delegate = self;
    field.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight; // الكود دايمًا LTR
    [field addTarget:self action:@selector(formatCodeField:) forControlEvents:UIControlEventEditingChanged];
    [fieldWrap addSubview:field];
    self.codeField = field;

    // زر اللصق (📋) داخل الحقل
    UIButton *pasteBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    pasteBtn.translatesAutoresizingMaskIntoConstraints = NO;
    UIImage *pasteIcon = [UIImage systemImageNamed:@"doc.on.clipboard"];
    [pasteBtn setImage:pasteIcon forState:UIControlStateNormal];
    pasteBtn.tintColor = WFGold();
    [pasteBtn addTarget:self action:@selector(pasteTapped) forControlEvents:UIControlEventTouchUpInside];
    [fieldWrap addSubview:pasteBtn];

    [NSLayoutConstraint activateConstraints:@[
        [message.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:14],
        [message.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [message.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],

        [fieldWrap.topAnchor constraintEqualToAnchor:message.bottomAnchor constant:16],
        [fieldWrap.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [fieldWrap.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [fieldWrap.heightAnchor constraintEqualToConstant:46],

        [pasteBtn.trailingAnchor constraintEqualToAnchor:fieldWrap.trailingAnchor constant:-8],
        [pasteBtn.centerYAnchor constraintEqualToAnchor:fieldWrap.centerYAnchor],
        [pasteBtn.widthAnchor constraintEqualToConstant:26],
        [pasteBtn.heightAnchor constraintEqualToConstant:26],

        [field.leadingAnchor constraintEqualToAnchor:fieldWrap.leadingAnchor constant:10],
        [field.trailingAnchor constraintEqualToAnchor:pasteBtn.leadingAnchor constant:-6],
        [field.centerYAnchor constraintEqualToAnchor:fieldWrap.centerYAnchor],
    ]];

    // زر تفعيل - مركزي، أنيق، أزرق بحري سماوي
    UIButton *activate = [UIButton buttonWithType:UIButtonTypeSystem];
    activate.translatesAutoresizingMaskIntoConstraints = NO;
    [activate setTitle:@"تفعيل" forState:UIControlStateNormal];
    [activate setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    activate.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    activate.backgroundColor = WFGold();
    activate.layer.cornerRadius = 12;
    [activate addTarget:self action:@selector(activateTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:activate];
    self.activateButton = activate;

    [NSLayoutConstraint activateConstraints:@[
        [activate.topAnchor constraintEqualToAnchor:fieldWrap.bottomAnchor constant:18],
        [activate.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [activate.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [activate.heightAnchor constraintEqualToConstant:46],
        [activate.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18],
    ]];

    field.inputAccessoryView = [self buildToolbarForField:field];
}

#pragma mark - Toolbar فوق الكيبورد (رجوع / تم)

- (UIToolbar *)buildToolbarForField:(UITextField *)field {
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, 44)];
    toolbar.barStyle = UIBarStyleBlack;
    toolbar.translucent = YES;

    UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithTitle:@"⟵ رجوع"
                                                               style:UIBarButtonItemStylePlain
                                                              target:self
                                                              action:@selector(dismissKeyboardOnly)];
    [back setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateNormal];

    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:@"✓ تم"
                                                              style:UIBarButtonItemStyleDone
                                                             target:self
                                                             action:@selector(doneTapped)];
    [done setTitleTextAttributes:@{NSForegroundColorAttributeName: WFGold()} forState:UIControlStateNormal];

    toolbar.items = @[back, flex, done];
    return toolbar;
}

- (void)dismissKeyboardOnly {
    [self.codeField resignFirstResponder];
}

- (void)doneTapped {
    // تم = يطوي الكيبورد بس، ما يفعّل تلقائيًا (التفعيل الفعلي عبر زر "تفعيل" بالمنتصف)
    [self.codeField resignFirstResponder];
}

#pragma mark - أزرار

- (void)pasteTapped {
    NSString *clip = [UIPasteboard generalPasteboard].string;
    if (clip.length > 0) {
        self.codeField.text = clip;
        [self formatCodeField:self.codeField];
    }
}

- (void)activateTapped {
    NSString *code = self.codeField.text ?: @"";
    [self dismissAnimatedWithCompletion:^{
        if (self.onSubmit) self.onSubmit(code);
    }];
}

- (void)laterTapped {
    [self dismissAnimatedWithCompletion:^{
        if (self.onLater) self.onLater();
    }];
}

- (void)handleBackgroundTap:(UITapGestureRecognizer *)gr {
    CGPoint point = [gr locationInView:self];
    if (![self.card pointInside:[self convertPoint:point toView:self.card] withEvent:nil]) {
        [self.codeField resignFirstResponder];
    }
}

- (void)dismissAnimatedWithCompletion:(void (^)(void))completion {
    [self.codeField resignFirstResponder];
    [UIView animateWithDuration:0.2 animations:^{
        self.dimBackground.alpha = 0;
        self.card.alpha = 0;
        self.card.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished) {
        [self.dimBackground removeFromSuperview];
        [self removeFromSuperview];
        if (completion) completion();
    }];
}

#pragma mark - فورمات + تحقق الحقل

- (void)formatCodeField:(UITextField *)textField {
    NSString *raw = [[textField.text componentsSeparatedByCharactersInSet:
                       [[NSCharacterSet alphanumericCharacterSet] invertedSet]]
                      componentsJoinedByString:@""];
    raw = [raw uppercaseString];
    if (raw.length > 12) raw = [raw substringToIndex:12];

    NSMutableString *formatted = [NSMutableString string];
    for (NSInteger i = 0; i < raw.length; i++) {
        if (i > 0 && i % 4 == 0) [formatted appendString:@"-"];
        [formatted appendFormat:@"%C", [raw characterAtIndex:i]];
    }
    textField.text = formatted;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (string.length == 0) return YES;
    NSCharacterSet *allowed = [NSCharacterSet alphanumericCharacterSet];
    for (NSInteger i = 0; i < string.length; i++) {
        if (![allowed characterIsMember:[string characterAtIndex:i]]) return NO;
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end

/*
 طريقة الاستخدام (وضع غير إجباري):

 [WFActivationView presentOnViewController:self
    onSubmit:^(NSString *code) {
        // استدعِ API التفعيل عندك (HMAC-SHA256 على mm.p3nd.fun)
        // عند نجاح السيرفر:
        [WFActivationView setActivated:YES];
        [WFActivationView saveLicenseCode:code expiryDate:/* تاريخ الانتهاء اللي يرجعه السيرفر */ nil];
    }
    onLater:^{
        // ما يصير شيء، المستخدم يكمل عادي بالميزات المجانية
    }];

 // للتحقق قبل فتح ميزة مدفوعة:
 if (![WFActivationView isActivated]) {
     [WFActivationView presentOnViewController:self onSubmit:^(NSString *code){ ... } onLater:^{ }];
     return;
 }
*/
