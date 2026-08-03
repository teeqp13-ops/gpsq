#import "WFCodeEntryView.h"
#import <CommonCrypto/CommonHMAC.h>

// ================= إعدادات =================
static NSString * const kWFActivationEndpoint = @"https://could.p3nd.fun/admin/api/redeem_process.php";
static NSString * const kWFHMACSecret         = @"CHANGE_THIS_SECRET_wolfox_a1b2c3";

// ألوان الهوية الجديدة (بنفسجي / سماوي)
static inline UIColor *WFBgTop(void)    { return [UIColor colorWithRed:0.039 green:0.027 blue:0.078 alpha:1.0]; }
static inline UIColor *WFBgBottom(void) { return [UIColor colorWithRed:0.071 green:0.047 blue:0.141 alpha:1.0]; }
static inline UIColor *WFViolet(void)   { return [UIColor colorWithRed:0.545 green:0.361 blue:0.965 alpha:1.0]; }
static inline UIColor *WFCyan(void)     { return [UIColor colorWithRed:0.133 green:0.827 blue:0.933 alpha:1.0]; }
static inline UIColor *WFDanger(void)   { return [UIColor colorWithRed:0.973 green:0.443 blue:0.443 alpha:1.0]; }
static inline UIColor *WFSuccess(void)  { return [UIColor colorWithRed:0.204 green:0.827 blue:0.600 alpha:1.0]; }
static inline UIColor *WFMuted(void)    { return [UIColor colorWithRed:0.616 green:0.580 blue:0.722 alpha:1.0]; }
static inline UIColor *WFText(void)     { return [UIColor colorWithRed:0.918 green:0.906 blue:0.961 alpha:1.0]; }

static UIWindow *activationWindow = nil;

@implementation WFCodeEntryViewController {
    UIView *_cardView;
    UIView *_iconCircle;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UITextField *_codeField;
    UIButton *_activateButton;
    UILabel *_messageLabel;
    UIActivityIndicatorView *_spinner;
    CAGradientLayer *_bgGradient;
    CAGradientLayer *_btnGradient;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _bgGradient.frame = self.view.bounds;
    _btnGradient.frame = _activateButton.bounds;
}

- (void)setupUI {
    // الخلفية المتدرجة
    _bgGradient = [CAGradientLayer layer];
    _bgGradient.colors = @[(id)WFBgTop().CGColor, (id)WFBgBottom().CGColor];
    _bgGradient.startPoint = CGPointMake(0.15, 0.0);
    _bgGradient.endPoint = CGPointMake(0.85, 1.0);
    [self.view.layer insertSublayer:_bgGradient atIndex:0];
    
    // البطاقة الزجاجية
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blur.frame = CGRectMake(0, 0, 320, 420);
    blur.center = self.view.center;
    blur.layer.cornerRadius = 22;
    blur.clipsToBounds = YES;
    blur.layer.borderWidth = 1;
    blur.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    blur.contentView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.03];
    [self.view addSubview:blur];
    _cardView = blur;
    
    UIView *content = blur.contentView;
    
    // الأيقونة
    _iconCircle = [[UIView alloc] initWithFrame:CGRectMake(128, 30, 64, 64)];
    CAGradientLayer *iconGrad = [CAGradientLayer layer];
    iconGrad.colors = @[(id)WFViolet().CGColor, (id)WFCyan().CGColor];
    iconGrad.frame = _iconCircle.bounds;
    iconGrad.cornerRadius = 18;
    [_iconCircle.layer addSublayer:iconGrad];
    [content addSubview:_iconCircle];
    
    UILabel *iconGlyph = [[UILabel alloc] initWithFrame:_iconCircle.bounds];
    iconGlyph.text = @"🛡";
    iconGlyph.font = [UIFont systemFontOfSize:26];
    iconGlyph.textAlignment = NSTextAlignmentCenter;
    [_iconCircle addSubview:iconGlyph];
    
    // العناوين
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 110, 280, 30)];
    _titleLabel.text = @"تفعيل الاشتراك";
    _titleLabel.textColor = WFText();
    _titleLabel.font = [UIFont boldSystemFontOfSize:20];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    [content addSubview:_titleLabel];
    
    _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 145, 280, 40)];
    _subtitleLabel.text = @"أدخل كود التفعيل الخاص بك للاستمرار";
    _subtitleLabel.textColor = WFMuted();
    _subtitleLabel.font = [UIFont systemFontOfSize:13];
    _subtitleLabel.textAlignment = NSTextAlignmentCenter;
    _subtitleLabel.numberOfLines = 0;
    [content addSubview:_subtitleLabel];
    
    // حقل الإدخال
    _codeField = [[UITextField alloc] initWithFrame:CGRectMake(25, 200, 270, 54)];
    _codeField.placeholder = @"XXXX-XXXX-XXXX-XXXX";
    _codeField.textColor = WFText();
    _codeField.font = [UIFont monospacedSystemFontOfSize:18 weight:UIFontWeightBold];
    _codeField.textAlignment = NSTextAlignmentCenter;
    _codeField.backgroundColor = [UIColor colorWithWhite:1 alpha:0.04];
    _codeField.layer.cornerRadius = 14;
    _codeField.layer.borderWidth = 1;
    _codeField.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    _codeField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    _codeField.returnKeyType = UIReturnKeyGo;
    [_codeField addTarget:self action:@selector(codeFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    // إضافة شريط أدوات فوق الكيبورد
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44)];
    toolbar.barStyle = UIBarStyleBlackTranslucent;
    UIBarButtonItem *closeBtn = [[UIBarButtonItem alloc] initWithTitle:@"إغلاق" style:UIBarButtonItemStylePlain target:self action:@selector(dismissActivation)];
    closeBtn.tintColor = [UIColor systemRedColor];
    UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *doneBtn = [[UIBarButtonItem alloc] initWithTitle:@"طي الكيبورد" style:UIBarButtonItemStyleDone target:self action:@selector(hideKeyboard)];
    doneBtn.tintColor = WFCyan();
    [toolbar setItems:@[closeBtn, spacer, doneBtn]];
    _codeField.inputAccessoryView = toolbar;
    
    [content addSubview:_codeField];
    
    // زر التفعيل
    _activateButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _activateButton.frame = CGRectMake(25, 275, 270, 52);
    [_activateButton setTitle:@"تفعيل الآن" forState:UIControlStateNormal];
    [_activateButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _activateButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    _activateButton.layer.cornerRadius = 14;
    _activateButton.clipsToBounds = YES;
    [_activateButton addTarget:self action:@selector(activateTapped) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:_activateButton];
    
    _btnGradient = [CAGradientLayer layer];
    _btnGradient.colors = @[(id)WFViolet().CGColor, (id)WFCyan().CGColor];
    _btnGradient.startPoint = CGPointMake(0, 0);
    _btnGradient.endPoint = CGPointMake(1, 0);
    _btnGradient.cornerRadius = 14;
    [_activateButton.layer insertSublayer:_btnGradient atIndex:0];
    
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.center = CGPointMake(135, 26);
    _spinner.color = UIColor.whiteColor;
    [_activateButton addSubview:_spinner];
    
    _messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 345, 280, 50)];
    _messageLabel.font = [UIFont systemFontOfSize:13];
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    _messageLabel.numberOfLines = 0;
    _messageLabel.alpha = 0;
    [content addSubview:_messageLabel];
}

+ (void)showActivationWithCompletion:(void (^)(BOOL success))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (activationWindow) return;
        
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        activationWindow = [[UIWindow alloc] initWithFrame:screenBounds];
        activationWindow.windowLevel = UIWindowLevelStatusBar + 10.0;
        activationWindow.backgroundColor = [UIColor clearColor];
        
        WFCodeEntryViewController *vc = [[WFCodeEntryViewController alloc] init];
        vc.completionHandler = ^(BOOL success) {
            activationWindow.hidden = YES;
            activationWindow = nil;
            if (completion) completion(success);
        };
        
        activationWindow.rootViewController = vc;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                    activationWindow.windowScene = scene;
                    break;
                }
            }
        }
        [activationWindow makeKeyAndVisible];
    });
}

- (void)dismissActivation {
    if (activationWindow) {
        [UIView animateWithDuration:0.3 animations:^{
            activationWindow.alpha = 0;
        } completion:^(BOOL finished) {
            activationWindow.hidden = YES;
            activationWindow = nil;
        }];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)hideKeyboard {
    [self.view endEditing:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self activateTapped];
    return YES;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self hideKeyboard];
}

- (void)codeFieldDidChange:(UITextField *)field {
    NSString *raw = [[field.text uppercaseString] stringByReplacingOccurrencesOfString:@"[^A-Z0-9]" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, field.text.length)];
    if (raw.length > 16) raw = [raw substringToIndex:16];
    NSMutableString *formatted = [NSMutableString string];
    for (NSUInteger i = 0; i < raw.length; i++) {
        if (i > 0 && i % 4 == 0) [formatted appendString:@"-"];
        [formatted appendFormat:@"%C", [raw characterAtIndex:i]];
    }
    field.text = formatted;
}

- (void)activateTapped {
    NSString *code = _codeField.text ?: @"";
    if (code.length < 12) {
        [self showMessage:@"الرجاء إدخال كود صحيح" isError:YES];
        return;
    }
    
    [_spinner startAnimating];
    [_activateButton setTitle:@"" forState:UIControlStateNormal];
    _activateButton.enabled = NO;
    
    NSString *deviceId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSDictionary *body = @{ @"code": code };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kWFActivationEndpoint]];
    req.HTTPMethod = @"POST";
    req.HTTPBody = jsonData;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:deviceId forHTTPHeaderField:@"X-Device-Id"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_spinner stopAnimating];
            [self->_activateButton setTitle:@"تفعيل الآن" forState:UIControlStateNormal];
            self->_activateButton.enabled = YES;
            
            if (error || !data) {
                [self showMessage:@"تعذر الاتصال بالخادم" isError:YES];
                return;
            }
            
            NSError *jsonError = nil;
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (![result isKindOfClass:[NSDictionary class]]) {
                NSString *rawStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if (rawStr.length > 0 && [rawStr containsString:@"<html"]) {
                    [self showMessage:@"خطأ 404: الرابط غير صحيح" isError:YES];
                } else {
                    [self showMessage:[NSString stringWithFormat:@"خطأ في البيانات: %@", jsonError.localizedDescription] isError:YES];
                }
                return;
            }
            
            if ([result[@"ok"] boolValue]) {
                NSString *expiresAt = result[@"expires_at"] ?: @"";
                NSString *signature = result[@"signature"] ?: @"";
                NSString *payload = [NSString stringWithFormat:@"%@|%@", code, expiresAt];
                NSString *expected = [self hmacSHA256:payload key:kWFHMACSecret];
                
                if ([expected isEqualToString:signature]) {
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WF_IsActivated"];
                    [[NSUserDefaults standardUserDefaults] setObject:expiresAt forKey:@"WF_ExpiryDate"];
                    [[NSUserDefaults standardUserDefaults] setObject:code forKey:@"WF_LastCode"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    [self showMessage:result[@"message"] isError:NO];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        if (self.completionHandler) self.completionHandler(YES);
                    });
                } else {
                    [self showMessage:@"فشل التحقق من التوقيع" isError:YES];
                }
            } else {
                [self showMessage:result[@"message"] isError:YES];
            }
        });
    }] resume];
}

- (void)showMessage:(NSString *)msg isError:(BOOL)isError {
    _messageLabel.text = msg;
    _messageLabel.textColor = isError ? WFDanger() : WFSuccess();
    [UIView animateWithDuration:0.3 animations:^{ self->_messageLabel.alpha = 1.0; }];
}

- (NSString *)hmacSHA256:(NSString *)message key:(NSString *)key {
    const char *cKey = [key cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cData = [message cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    NSMutableString *hash = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hash appendFormat:@"%02x", cHMAC[i]];
    return hash;
}

@end
