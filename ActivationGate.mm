#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "ActivationConfig.h"

@interface BYActivationGate : NSObject <UITextFieldDelegate>
@property (nonatomic, strong) UIWindow *gateWindow;
@property (nonatomic, strong) UITextField *codeField;
@property (nonatomic, strong) UIButton *activateButton;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation BYActivationGate
+ (instancetype)shared {
    static BYActivationGate *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [BYActivationGate new]; });
    return instance;
}

- (void)start {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:BYANO_LICENSE_STATE]) return;
    dispatch_async(dispatch_get_main_queue(), ^{ [self presentGate]; });
}

- (void)presentGate {
    if (self.gateWindow) return;
    CGRect bounds = UIScreen.mainScreen.bounds;
    self.gateWindow = [[UIWindow alloc] initWithFrame:bounds];
    self.gateWindow.windowLevel = UIWindowLevelAlert + 100;

    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = [UIColor colorWithRed:0.025 green:0.045 blue:0.075 alpha:1.0];
    self.gateWindow.rootViewController = vc;
    [self.gateWindow makeKeyAndVisible];

    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = bounds;
    gradient.colors = @[(id)[UIColor colorWithRed:0.02 green:0.08 blue:0.14 alpha:1].CGColor,
                        (id)[UIColor colorWithRed:0.08 green:0.03 blue:0.15 alpha:1].CGColor];
    [vc.view.layer insertSublayer:gradient atIndex:0];

    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor colorWithWhite:1 alpha:0.07];
    card.layer.cornerRadius = 24;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    [vc.view addSubview:card];

    UILabel *icon = [UILabel new];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.text = @"🔐";
    icon.font = [UIFont systemFontOfSize:48];
    icon.textAlignment = NSTextAlignmentCenter;

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"تفعيل التطبيق";
    title.textColor = UIColor.whiteColor;
    title.textAlignment = NSTextAlignmentCenter;
    title.font = [UIFont boldSystemFontOfSize:27];

    UILabel *subtitle = [UILabel new];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"أدخل كود التفعيل للمتابعة";
    subtitle.textColor = [UIColor colorWithWhite:0.75 alpha:1];
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.font = [UIFont systemFontOfSize:15];

    self.codeField = [UITextField new];
    self.codeField.translatesAutoresizingMaskIntoConstraints = NO;
    self.codeField.placeholder = @"مثال: WF-7G5B-9X2M";
    self.codeField.textAlignment = NSTextAlignmentCenter;
    self.codeField.textColor = UIColor.whiteColor;
    self.codeField.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    self.codeField.layer.cornerRadius = 14;
    self.codeField.layer.borderWidth = 1;
    self.codeField.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    self.codeField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.codeField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.codeField.returnKeyType = UIReturnKeyDone;
    self.codeField.delegate = self;
    self.codeField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 1)];
    self.codeField.leftViewMode = UITextFieldViewModeAlways;
    self.codeField.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 1)];
    self.codeField.rightViewMode = UITextFieldViewModeAlways;

    self.activateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.activateButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.activateButton setTitle:@"تفعيل الكود" forState:UIControlStateNormal];
    [self.activateButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.activateButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    self.activateButton.backgroundColor = [UIColor colorWithRed:0.15 green:0.42 blue:0.95 alpha:1];
    self.activateButton.layer.cornerRadius = 14;
    [self.activateButton addTarget:self action:@selector(activateTapped) forControlEvents:UIControlEventTouchUpInside];

    self.statusLabel = [UILabel new];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1];
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    self.statusLabel.numberOfLines = 2;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[icon, title, subtitle, self.codeField, self.activateButton, self.statusLabel]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 15;
    stack.alignment = UIStackViewAlignmentFill;
    [card addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [card.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [card.centerYAnchor constraintEqualToAnchor:vc.view.centerYAnchor],
        [card.leadingAnchor constraintGreaterThanOrEqualToAnchor:vc.view.leadingAnchor constant:22],
        [card.trailingAnchor constraintLessThanOrEqualToAnchor:vc.view.trailingAnchor constant:-22],
        [card.widthAnchor constraintEqualToConstant:MIN(370, bounds.size.width - 44)],
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:28],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:22],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-22],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-26],
        [self.codeField.heightAnchor constraintEqualToConstant:52],
        [self.activateButton.heightAnchor constraintEqualToConstant:52]
    ]];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self activateTapped];
    return YES;
}

- (void)setLoading:(BOOL)loading {
    self.activateButton.enabled = !loading;
    [self.activateButton setTitle:(loading ? @"جاري التحقق..." : @"تفعيل الكود") forState:UIControlStateNormal];
    self.activateButton.alpha = loading ? 0.65 : 1.0;
}

- (void)activateTapped {
    NSString *code = [[self.codeField.text ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if (code.length < 4) {
        self.statusLabel.text = @"يرجى إدخال كود صحيح";
        self.statusLabel.textColor = [UIColor colorWithRed:1 green:0.35 blue:0.4 alpha:1];
        return;
    }

    [self.codeField resignFirstResponder];
    [self setLoading:YES];
    self.statusLabel.text = @"يتم الآن التحقق من الكود والجهاز";
    self.statusLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1];

    NSString *device = UIDevice.currentDevice.identifierForVendor.UUIDString ?: @"unknown";
    NSURL *url = [NSURL URLWithString:BYANO_ACTIVATION_API];
    if (!url) { [self finishWithError:@"رابط API غير صحيح"]; return; }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSDictionary *payload = @{ @"code": code, @"device_uuid": device, @"platform": @"ios", @"app": BYANO_PRODUCT_NAME };
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    request.timeoutInterval = 20;

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !data) { [self finishWithError:@"تعذر الاتصال بخادم التفعيل"]; return; }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            BOOL success = [json[@"success"] boolValue] || [json[@"active"] boolValue];
            if (success) {
                NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
                [defaults setObject:code forKey:BYANO_LICENSE_KEY];
                [defaults setBool:YES forKey:BYANO_LICENSE_STATE];
                [defaults synchronize];
                self.statusLabel.text = @"تم التفعيل بنجاح ✓";
                self.statusLabel.textColor = [UIColor colorWithRed:0.25 green:0.9 blue:0.55 alpha:1];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    self.gateWindow.hidden = YES;
                    self.gateWindow = nil;
                });
            } else {
                NSString *message = [json[@"message"] isKindOfClass:NSString.class] ? json[@"message"] : @"الكود غير صالح أو منتهي";
                [self finishWithError:message];
            }
        });
    }] resume];
}

- (void)finishWithError:(NSString *)message {
    [self setLoading:NO];
    self.statusLabel.text = message;
    self.statusLabel.textColor = [UIColor colorWithRed:1 green:0.35 blue:0.4 alpha:1];
}
@end

__attribute__((constructor)) static void BYActivationBootstrap(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[BYActivationGate shared] start];
    });
}
