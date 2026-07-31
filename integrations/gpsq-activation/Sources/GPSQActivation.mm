#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

static NSString *const GPAPIBase = @"https://key.p3nd.fun/activation/api";
static NSString *const GPProjectKey = @"gpsq";
static NSString *const GPClientVersion = @"17.0.0";
static NSString *const GPKeychainService = @"com.wolfox.gpsq.activation";
static NSString *const GPTokenAccount = @"session_token";
static NSString *const GPCodeAccount = @"license_code";
static NSString *const GPDeviceDefaultsKey = @"GPSQDeviceIdentifier";
static NSString *const GPActivationCompletedNotification = @"GPSQActivationCompleted";
static NSString *const GPShowActivationNotification = @"GPSQShowActivation";
static NSString *const GPResetActivationNotification = @"GPSQResetActivation";
static NSString *const GPOpenModernPanelNotification = @"GPSQOpenModernPanel";

static UIColor *GPColor(NSUInteger hex) {
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8) & 0xFF) / 255.0
                            blue:(hex & 0xFF) / 255.0
                           alpha:1.0];
}

static NSString *GPDeviceIdentifier(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *saved = [defaults stringForKey:GPDeviceDefaultsKey];
    if (saved.length > 0) return saved;

    NSString *identifier = UIDevice.currentDevice.identifierForVendor.UUIDString;
    if (identifier.length == 0) identifier = NSUUID.UUID.UUIDString;
    [defaults setObject:identifier forKey:GPDeviceDefaultsKey];
    return identifier;
}

static NSMutableDictionary *GPKeychainQuery(NSString *account) {
    return [@{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: GPKeychainService,
        (__bridge id)kSecAttrAccount: account
    } mutableCopy];
}

static BOOL GPKeychainSave(NSString *account, NSString *value) {
    if (account.length == 0 || value.length == 0) return NO;
    NSMutableDictionary *query = GPKeychainQuery(account);
    SecItemDelete((__bridge CFDictionaryRef)query);
    query[(__bridge id)kSecValueData] = [value dataUsingEncoding:NSUTF8StringEncoding];
    query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
    return SecItemAdd((__bridge CFDictionaryRef)query, NULL) == errSecSuccess;
}

static NSString *GPKeychainRead(NSString *account) {
    NSMutableDictionary *query = GPKeychainQuery(account);
    query[(__bridge id)kSecReturnData] = @YES;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    CFTypeRef result = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) != errSecSuccess || !result) return nil;
    NSData *data = CFBridgingRelease(result);
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

static void GPKeychainDelete(NSString *account) {
    SecItemDelete((__bridge CFDictionaryRef)GPKeychainQuery(account));
}

static UIViewController *GPTopController(UIViewController *controller) {
    if (!controller) return nil;
    if (controller.presentedViewController) return GPTopController(controller.presentedViewController);
    if ([controller isKindOfClass:UINavigationController.class]) {
        return GPTopController(((UINavigationController *)controller).visibleViewController);
    }
    if ([controller isKindOfClass:UITabBarController.class]) {
        return GPTopController(((UITabBarController *)controller).selectedViewController);
    }
    return controller;
}

static UIWindow *GPForegroundWindow(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.isKeyWindow) return window;
            }
        }
    }
    return UIApplication.sharedApplication.keyWindow;
}

@interface GPSQActivationViewController : UIViewController <UITextFieldDelegate>
@property(nonatomic, strong) UIView *activationView;
@property(nonatomic, strong) UITextField *codeField;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UIButton *activateButton;
@property(nonatomic, assign) BOOL initialCheckCompleted;
@end

static __weak GPSQActivationViewController *GPCurrentController;

@implementation GPSQActivationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = GPColor(0x070B18);
    self.modalPresentationStyle = UIModalPresentationFullScreen;
    [self buildActivationInterface];
    [self showActivationAnimated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.initialCheckCompleted) {
        self.initialCheckCompleted = YES;
        [self verifySavedSession];
    }
}

- (UILabel *)labelWithText:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight color:(UIColor *)color {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [UIFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    return label;
}

- (UIButton *)buttonWithTitle:(NSString *)title color:(UIColor *)color action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    button.backgroundColor = color;
    button.layer.cornerRadius = 12;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button.heightAnchor constraintEqualToConstant:46].active = YES;
    return button;
}

- (void)buildActivationInterface {
    UIView *container = [UIView new];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:container];
    [NSLayoutConstraint activateConstraints:@[
        [container.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [container.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [container.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [container.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
    self.activationView = container;

    UIView *lock = [UIView new];
    lock.backgroundColor = [GPColor(0xC9A227) colorWithAlphaComponent:0.12];
    lock.layer.borderColor = [GPColor(0xE8C453) colorWithAlphaComponent:0.35].CGColor;
    lock.layer.borderWidth = 1;
    lock.layer.cornerRadius = 20;
    lock.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *lockIcon = [self labelWithText:@"🔒" size:30 weight:UIFontWeightRegular color:GPColor(0xE8C453)];
    lockIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [lock addSubview:lockIcon];
    [NSLayoutConstraint activateConstraints:@[
        [lock.widthAnchor constraintEqualToConstant:72], [lock.heightAnchor constraintEqualToConstant:72],
        [lockIcon.centerXAnchor constraintEqualToAnchor:lock.centerXAnchor], [lockIcon.centerYAnchor constraintEqualToAnchor:lock.centerYAnchor]
    ]];

    UILabel *title = [self labelWithText:@"التفعيل مطلوب" size:19 weight:UIFontWeightHeavy color:UIColor.whiteColor];
    UILabel *subtitle = [self labelWithText:@"أدخل كود التفعيل للوصول إلى مميزات Wolf GPS V17" size:13 weight:UIFontWeightRegular color:GPColor(0x6B7488)];

    UIView *card = [UIView new];
    card.backgroundColor = GPColor(0x0E142B);
    card.layer.cornerRadius = 17;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [UIColor.whiteColor colorWithAlphaComponent:0.07].CGColor;
    card.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *fieldTitle = [self labelWithText:@"كود التفعيل" size:12 weight:UIFontWeightSemibold color:GPColor(0x8C95A8)];
    fieldTitle.textAlignment = NSTextAlignmentRight;
    fieldTitle.translatesAutoresizingMaskIntoConstraints = NO;

    self.codeField = [UITextField new];
    self.codeField.delegate = self;
    self.codeField.placeholder = @"8 إلى 20 رقمًا";
    self.codeField.textAlignment = NSTextAlignmentCenter;
    self.codeField.textColor = UIColor.whiteColor;
    self.codeField.font = [UIFont monospacedSystemFontOfSize:20 weight:UIFontWeightBold];
    self.codeField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.codeField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.codeField.keyboardType = UIKeyboardTypeNumberPad;
    self.codeField.backgroundColor = GPColor(0x070B18);
    self.codeField.layer.cornerRadius = 12;
    self.codeField.layer.borderWidth = 1;
    self.codeField.layer.borderColor = [UIColor.whiteColor colorWithAlphaComponent:0.09].CGColor;
    self.codeField.translatesAutoresizingMaskIntoConstraints = NO;

    self.activateButton = [self buttonWithTitle:@"تفعيل" color:GPColor(0xC9A227) action:@selector(activateTapped)];
    [self.activateButton setTitleColor:GPColor(0x070B18) forState:UIControlStateNormal];

    UIStackView *cardStack = [[UIStackView alloc] initWithArrangedSubviews:@[fieldTitle, self.codeField, self.activateButton]];
    cardStack.axis = UILayoutConstraintAxisVertical;
    cardStack.spacing = 12;
    cardStack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:cardStack];
    [NSLayoutConstraint activateConstraints:@[
        [cardStack.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [cardStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [cardStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [cardStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18],
        [self.codeField.heightAnchor constraintEqualToConstant:50]
    ]];

    self.statusLabel = [self labelWithText:@"" size:12 weight:UIFontWeightBold color:GPColor(0x6B7488)];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[lock, title, subtitle, card, self.statusLabel]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:container.centerYAnchor constant:-20]
    ]];
    [lock.centerXAnchor constraintEqualToAnchor:stack.centerXAnchor].active = YES;
}

- (void)showActivationAnimated:(BOOL)animated {
    void (^changes)(void) = ^{
        self.activationView.alpha = 1;
        self.activationView.hidden = NO;
    };
    animated ? [UIView animateWithDuration:0.25 animations:changes] : changes();
}

- (void)setBusy:(BOOL)busy text:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.activateButton.enabled = !busy;
        self.codeField.enabled = !busy;
        [self.activateButton setTitle:(busy ? @"جاري التحقق..." : @"تفعيل") forState:UIControlStateNormal];
        self.statusLabel.text = text ?: @"";
        self.statusLabel.textColor = busy ? GPColor(0xE8C453) : GPColor(0x6B7488);
    });
}

- (void)activateTapped {
    NSString *code = [[self.codeField.text ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if (code.length < 8 || code.length > 20) {
        self.statusLabel.text = @"أدخل كودًا من 8 إلى 20 رقمًا";
        self.statusLabel.textColor = GPColor(0xFF5D6C);
        return;
    }
    [self.view endEditing:YES];
    [self setBusy:YES text:@"يتم الاتصال بخادم التفعيل"];

    NSDictionary *payload = @{
        @"project_key": GPProjectKey,
        @"code": code,
        @"license_code": code,
        @"device_id": GPDeviceIdentifier(),
        @"bundle_id": NSBundle.mainBundle.bundleIdentifier ?: @"unknown",
        @"app_version": GPClientVersion,
        @"platform": @"ios"
    };
    [self postEndpoint:@"activate.php" payload:payload completion:^(NSDictionary *json, NSInteger statusCode, NSError *error) {
        NSString *token = [json[@"token"] isKindOfClass:NSString.class] ? json[@"token"] : nil;
        BOOL success = !error && statusCode >= 200 && statusCode < 300 && [json[@"success"] boolValue] && token.length > 0;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setBusy:NO text:@""];
            if (!success) {
                self.statusLabel.text = [self messageForResponse:json error:error];
                self.statusLabel.textColor = GPColor(0xFF5D6C);
                return;
            }
            GPKeychainSave(GPTokenAccount, token);
            GPKeychainSave(GPCodeAccount, code);
            NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
            [defaults setObject:code forKey:@"FGLicenseCode"];
            [defaults setObject:token forKey:@"FGLicenseToken"];
            [defaults setBool:YES forKey:@"FGLicenseActive"];
            [defaults synchronize];

            self.statusLabel.text = @"تم التفعيل";
            self.statusLabel.textColor = GPColor(0x3FD68A);
            [NSNotificationCenter.defaultCenter postNotificationName:GPActivationCompletedNotification object:nil userInfo:json];

            UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"تم التفعيل"
                                                                                  message:@"تم قبول الكود وربط الجهاز بنجاح."
                                                                           preferredStyle:UIAlertControllerStyleAlert];
            [successAlert addAction:[UIAlertAction actionWithTitle:@"دخول" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
                UIViewController *presenter = self.presentingViewController;
                void (^openPanel)(void) = ^{
                    [NSNotificationCenter.defaultCenter postNotificationName:GPOpenModernPanelNotification object:nil];
                };
                if (presenter) [presenter dismissViewControllerAnimated:YES completion:openPanel];
                else [self dismissViewControllerAnimated:YES completion:openPanel];
            }]];
            [self presentViewController:successAlert animated:YES completion:nil];
        });
    }];
}

- (void)verifySavedSession {
    NSString *token = GPKeychainRead(GPTokenAccount);
    if (token.length == 0) {
        [self showActivationAnimated:NO];
        return;
    }
    [self setBusy:YES text:@"جاري التحقق من الجلسة المحفوظة"];
    NSDictionary *payload = @{
        @"project_key": GPProjectKey,
        @"token": token,
        @"device_id": GPDeviceIdentifier()
    };
    [self postEndpoint:@"verify.php" payload:payload completion:^(NSDictionary *json, NSInteger statusCode, NSError *error) {
        BOOL valid = !error && statusCode >= 200 && statusCode < 300 && [json[@"success"] boolValue];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setBusy:NO text:@""];
            if (valid) {
                NSString *savedCode = GPKeychainRead(GPCodeAccount);
                NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
                if (savedCode.length) [defaults setObject:savedCode forKey:@"FGLicenseCode"];
                [defaults setObject:token forKey:@"FGLicenseToken"];
                [defaults setBool:YES forKey:@"FGLicenseActive"];
                [defaults synchronize];
                [self dismissViewControllerAnimated:NO completion:nil];
            } else {
                GPKeychainDelete(GPTokenAccount);
                GPKeychainDelete(GPCodeAccount);
                NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
                [defaults removeObjectForKey:@"FGLicenseCode"];
                [defaults removeObjectForKey:@"FGLicenseToken"];
                [defaults setBool:NO forKey:@"FGLicenseActive"];
                [defaults synchronize];
                [self showActivationAnimated:YES];
                self.statusLabel.text = [self messageForResponse:json error:error];
                self.statusLabel.textColor = GPColor(0xFF5D6C);
            }
        });
    }];
}

- (void)postEndpoint:(NSString *)endpoint payload:(NSDictionary *)payload completion:(void (^)(NSDictionary *, NSInteger, NSError *))completion {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", GPAPIBase, endpoint]];
    if (!url) {
        completion(@{}, 0, [NSError errorWithDomain:@"GPSQActivation" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"رابط الخادم غير صالح"}]);
        return;
    }
    NSError *jsonError = nil;
    NSData *body = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
    if (!body) {
        completion(@{}, 0, jsonError);
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20];
    request.HTTPMethod = @"POST";
    request.HTTPBody = body;
    [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        NSDictionary *json = @{};
        if (data.length > 0) {
            id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([object isKindOfClass:NSDictionary.class]) json = object;
        }
        completion(json, statusCode, error);
    }] resume];
}

- (NSString *)messageForResponse:(NSDictionary *)json error:(NSError *)error {
    if (error) return @"تعذر الاتصال بخادم التفعيل";
    NSString *serverMessage = [json[@"message"] isKindOfClass:NSString.class] ? json[@"message"] : nil;
    if (serverMessage.length) return serverMessage;
    NSString *code = [json[@"error"] isKindOfClass:NSString.class] ? json[@"error"] :
                     ([json[@"status"] isKindOfClass:NSString.class] ? json[@"status"] : @"unknown");
    NSDictionary *messages = @{
        @"invalid_code": @"كود التفعيل غير صحيح",
        @"disabled_code": @"تم إيقاف هذا الكود",
        @"expired_code": @"انتهت صلاحية الكود",
        @"device_limit_reached": @"تم تجاوز عدد الأجهزة المسموح",
        @"invalid_project": @"مفتاح المشروع غير صحيح",
        @"maintenance": @"الخادم تحت الصيانة حاليًا",
        @"invalid_session": @"انتهت جلسة التفعيل",
        @"session_expired": @"انتهت جلسة التفعيل",
        @"not_installed": @"نظام التفعيل غير مثبت على الخادم"
    };
    return messages[code] ?: @"فشل التفعيل، حاول مرة أخرى";
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *next = [textField.text stringByReplacingCharactersInRange:range withString:string];
    NSCharacterSet *invalid = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    return next.length <= 20 && [string rangeOfCharacterFromSet:invalid].location == NSNotFound;
}


@end

static void GPResetActivationState(void) {
    GPKeychainDelete(GPTokenAccount);
    GPKeychainDelete(GPCodeAccount);
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults removeObjectForKey:@"FGLicenseCode"];
    [defaults removeObjectForKey:@"FGLicenseToken"];
    [defaults setBool:NO forKey:@"FGLicenseActive"];
    [defaults synchronize];
}

static void GPPresentInterface(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (GPCurrentController.presentingViewController) return;
        UIWindow *window = GPForegroundWindow();
        UIViewController *top = GPTopController(window.rootViewController);
        if (!top || [top isKindOfClass:GPSQActivationViewController.class]) return;
        GPSQActivationViewController *controller = [GPSQActivationViewController new];
        GPCurrentController = controller;
        [top presentViewController:controller animated:YES completion:nil];
    });
}

__attribute__((constructor)) static void GPSQActivationInitialize(void) {
    @autoreleasepool {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            GPPresentInterface();
        });
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
            if (!GPCurrentController.presentingViewController) GPPresentInterface();
        }];
        [NSNotificationCenter.defaultCenter addObserverForName:GPShowActivationNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
            GPPresentInterface();
        }];
        [NSNotificationCenter.defaultCenter addObserverForName:GPResetActivationNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
            GPResetActivationState();
            GPSQActivationViewController *current = GPCurrentController;
            if (current.presentingViewController) {
                [current dismissViewControllerAnimated:YES completion:^{
                    GPCurrentController = nil;
                    GPPresentInterface();
                }];
            } else {
                GPCurrentController = nil;
                GPPresentInterface();
            }
        }];
    }
}
