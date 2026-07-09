#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

#ifndef GPSQ_API_BASE
#define GPSQ_API_BASE @"https://ipa.p3nd.fun/server/public/api"
#endif

#ifndef GPSQ_API_KEY
#define GPSQ_API_KEY @""
#endif

#define GPSQ_APP_NAME @"GPS Plus"
#define GPSQ_APP_VERSION @"1.1"

static NSString *GPSQDeviceID(void) {
    NSString *vendorID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    if (vendorID.length > 0) return vendorID;

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSString *saved = [d stringForKey:@"GPSQ_FallbackUDID"];
    if (saved.length == 0) {
        saved = [[NSUUID UUID] UUIDString];
        [d setObject:saved forKey:@"GPSQ_FallbackUDID"];
        [d synchronize];
    }
    return saved;
}

static UIColor *GPSQColor(CGFloat r, CGFloat g, CGFloat b) {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1.0];
}

static UIButton *GPSQButton(NSString *title, UIColor *color) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.backgroundColor = color;
    b.layer.cornerRadius = 16.0;
    b.layer.masksToBounds = YES;
    b.titleLabel.font = [UIFont boldSystemFontOfSize:16.0];
    b.titleLabel.adjustsFontSizeToFitWidth = YES;
    b.titleLabel.minimumScaleFactor = 0.75;
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    return b;
}

@interface GPSQRootController : UIViewController <UITextFieldDelegate>
@property(nonatomic,strong) UIButton *floatingButton;
@property(nonatomic,strong) UIView *dialogView;
@property(nonatomic,strong) UITextField *codeField;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UIView *fullOverlay;
@property(nonatomic,assign) BOOL activated;
@property(nonatomic,assign) CGPoint dragStart;
@end

@implementation GPSQRootController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.activated = [[NSUserDefaults standardUserDefaults] boolForKey:@"GPSQ_Activated"];
    [self buildFloatingIcon];
}

- (void)buildFloatingIcon {
    self.floatingButton = GPSQButton(@"GPS", GPSQColor(22, 163, 74));
    self.floatingButton.frame = CGRectMake(24, 180, 68, 68);
    self.floatingButton.layer.cornerRadius = 34;
    self.floatingButton.layer.shadowColor = UIColor.blackColor.CGColor;
    self.floatingButton.layer.shadowOpacity = 0.35;
    self.floatingButton.layer.shadowRadius = 12;
    self.floatingButton.layer.shadowOffset = CGSizeMake(0, 6);
    [self.floatingButton addTarget:self action:@selector(floatingTapped) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    [self.floatingButton addGestureRecognizer:pan];
    [self.view addSubview:self.floatingButton];
}

- (void)handleDrag:(UIPanGestureRecognizer *)pan {
    CGPoint t = [pan translationInView:self.view];
    if (pan.state == UIGestureRecognizerStateBegan) self.dragStart = self.floatingButton.center;

    CGPoint c = CGPointMake(self.dragStart.x + t.x, self.dragStart.y + t.y);
    CGFloat hw = self.floatingButton.bounds.size.width / 2.0;
    CGFloat hh = self.floatingButton.bounds.size.height / 2.0;
    c.x = MAX(hw, MIN(self.view.bounds.size.width - hw, c.x));
    c.y = MAX(hh, MIN(self.view.bounds.size.height - hh, c.y));
    self.floatingButton.center = c;
}

- (void)floatingTapped {
    if (self.activated) [self showFullOverlay];
    else [self showActivationDialog];
}

- (void)showActivationDialog {
    [self.dialogView removeFromSuperview];
    [[self.view viewWithTag:1001] removeFromSuperview];

    UIView *shade = [[UIView alloc] initWithFrame:self.view.bounds];
    shade.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.15];
    shade.tag = 1001;
    [self.view addSubview:shade];

    CGFloat w = MIN(self.view.bounds.size.width - 36, 390);
    self.dialogView = [[UIView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - w) / 2, (self.view.bounds.size.height - 260) / 2, w, 260)];
    self.dialogView.backgroundColor = GPSQColor(20, 24, 33);
    self.dialogView.layer.cornerRadius = 24;
    self.dialogView.layer.borderWidth = 1;
    self.dialogView.layer.borderColor = GPSQColor(50, 60, 80).CGColor;
    [self.view addSubview:self.dialogView];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 18, w - 40, 38)];
    title.text = GPSQ_APP_NAME;
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont boldSystemFontOfSize:26];
    title.textAlignment = NSTextAlignmentCenter;
    [self.dialogView addSubview:title];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, w - 40, 28)];
    sub.text = @"أدخل كود التفعيل";
    sub.textColor = GPSQColor(210, 220, 235);
    sub.font = [UIFont systemFontOfSize:16];
    sub.textAlignment = NSTextAlignmentCenter;
    [self.dialogView addSubview:sub];

    self.codeField = [[UITextField alloc] initWithFrame:CGRectMake(20, 100, w - 40, 54)];
    self.codeField.placeholder = @"كود 8 خانات";
    self.codeField.backgroundColor = UIColor.whiteColor;
    self.codeField.textColor = UIColor.blackColor;
    self.codeField.textAlignment = NSTextAlignmentCenter;
    self.codeField.font = [UIFont boldSystemFontOfSize:22];
    self.codeField.layer.cornerRadius = 16;
    self.codeField.layer.masksToBounds = YES;
    self.codeField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.codeField.delegate = self;
    [self.dialogView addSubview:self.codeField];

    CGFloat bw = (w - 52) / 2.0;
    UIButton *paste = GPSQButton(@"لصق النص", GPSQColor(71, 85, 105));
    paste.frame = CGRectMake(20, 170, bw, 48);
    [paste addTarget:self action:@selector(pasteCode) forControlEvents:UIControlEventTouchUpInside];
    [self.dialogView addSubview:paste];

    UIButton *activate = GPSQButton(@"تفعيل", GPSQColor(22, 163, 74));
    activate.frame = CGRectMake(32 + bw, 170, bw, 48);
    [activate addTarget:self action:@selector(activateCode) forControlEvents:UIControlEventTouchUpInside];
    [self.dialogView addSubview:activate];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 224, w - 40, 24)];
    self.statusLabel.textColor = UIColor.whiteColor;
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.dialogView addSubview:self.statusLabel];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *source = textField.text ?: @"";
    NSString *n = [[source stringByReplacingCharactersInRange:range withString:string] uppercaseString];
    n = [[n componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@""];
    if (n.length > 8) n = [n substringToIndex:8];
    textField.text = n;
    return NO;
}

- (void)pasteCode {
    NSString *clip = UIPasteboard.generalPasteboard.string ?: @"";
    clip = [[clip uppercaseString] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    clip = [[clip componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@""];
    if (clip.length > 8) clip = [clip substringToIndex:8];
    self.codeField.text = clip;
    [self showCenterNotice:@"تم لصق النص"];
}

- (void)activateCode {
    NSString *code = self.codeField.text.uppercaseString ?: @"";
    if (code.length != 8) {
        self.statusLabel.text = @"الكود يجب أن يكون 8 خانات";
        self.statusLabel.textColor = GPSQColor(248, 113, 113);
        [self showCenterNotice:@"الكود غير صحيح"];
        return;
    }

    self.statusLabel.text = @"جاري التحقق...";
    self.statusLabel.textColor = GPSQColor(229, 231, 235);

    NSString *urlString = [NSString stringWithFormat:@"%@/activate.php", GPSQ_API_BASE];
    NSURL *url = [NSURL URLWithString:urlString];

    NSDictionary *payload = @{
        @"code": code,
        @"udid": GPSQDeviceID(),
        @"device_name": UIDevice.currentDevice.name ?: @"iPhone",
        @"app_bundle": NSBundle.mainBundle.bundleIdentifier ?: @"unknown",
        @"app_version": GPSQ_APP_VERSION,
        @"ios_version": UIDevice.currentDevice.systemVersion ?: @"",
        @"custom_identifier": @"gpsq"
    };

    NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    if (!url || !json) {
        [self showCenterNotice:@"خطأ في الطلب"];
        return;
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    req.timeoutInterval = 18;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if ([GPSQ_API_KEY length] > 0) [req setValue:GPSQ_API_KEY forHTTPHeaderField:@"X-GPS-API-Key"];
    req.HTTPBody = json;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || data.length == 0) {
                self.statusLabel.text = @"تعذر الاتصال بالسيرفر";
                self.statusLabel.textColor = GPSQColor(248, 113, 113);
                [self showCenterNotice:@"فشل الاتصال"];
                return;
            }

            NSDictionary *r = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            BOOL ok = [r[@"success"] boolValue] || [r[@"status"] isEqual:@"ok"] || [r[@"status"] isEqual:@"success"] || [r[@"status"] isEqual:@"active"];
            if (ok) {
                NSString *token = [r[@"token"] isKindOfClass:NSString.class] ? r[@"token"] : @"";
                NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
                [d setBool:YES forKey:@"GPSQ_Activated"];
                [d setObject:token forKey:@"GPSQ_Token"];
                [d synchronize];
                self.activated = YES;
                [self showCenterNotice:@"تم التفعيل بنجاح"];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [[self.view viewWithTag:1001] removeFromSuperview];
                    [self.dialogView removeFromSuperview];
                    [self showFullOverlay];
                });
                return;
            }

            NSString *msg = [r[@"message"] isKindOfClass:NSString.class] ? r[@"message"] : @"الكود غير مقبول";
            self.statusLabel.text = msg;
            self.statusLabel.textColor = GPSQColor(248, 113, 113);
            [self showCenterNotice:msg];
        });
    }];
    [task resume];
}

- (void)showFullOverlay {
    [self.fullOverlay removeFromSuperview];
    self.fullOverlay = [[UIView alloc] initWithFrame:self.view.bounds];
    self.fullOverlay.backgroundColor = GPSQColor(10, 14, 22);
    [self.view addSubview:self.fullOverlay];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(110, 44, self.view.bounds.size.width - 220, 44)];
    title.text = GPSQ_APP_NAME;
    title.textColor = UIColor.whiteColor;
    title.textAlignment = NSTextAlignmentCenter;
    title.font = [UIFont boldSystemFontOfSize:26];
    [self.fullOverlay addSubview:title];

    UIButton *close = GPSQButton(@"إغلاق", GPSQColor(37, 99, 235));
    close.frame = CGRectMake(self.view.bounds.size.width - 96, 46, 78, 42);
    [close addTarget:self action:@selector(closeFullOverlay) forControlEvents:UIControlEventTouchUpInside];
    [self.fullOverlay addSubview:close];

    UIButton *info = GPSQButton(@"الاشتراك", GPSQColor(71, 85, 105));
    info.frame = CGRectMake(18, 46, 90, 42);
    [info addTarget:self action:@selector(showSubscriptionInfo) forControlEvents:UIControlEventTouchUpInside];
    [self.fullOverlay addSubview:info];

    UILabel *body = [[UILabel alloc] initWithFrame:CGRectMake(22, 120, self.view.bounds.size.width - 44, 140)];
    body.text = @"تم تفعيل GPS Plus.\nسنكمل إضافة الخريطة والمفضلة والإعدادات بالتدريج.";
    body.textColor = GPSQColor(220, 226, 235);
    body.numberOfLines = 0;
    body.textAlignment = NSTextAlignmentCenter;
    body.font = [UIFont systemFontOfSize:18];
    [self.fullOverlay addSubview:body];
}

- (void)closeFullOverlay {
    [self.fullOverlay removeFromSuperview];
    self.fullOverlay = nil;
}

- (void)showSubscriptionInfo {
    NSString *token = [[NSUserDefaults standardUserDefaults] stringForKey:@"GPSQ_Token"] ?: @"";
    NSString *shortToken = token.length > 12 ? [token substringToIndex:12] : token;
    [self showCenterNotice:[NSString stringWithFormat:@"اشتراك مفعل %@", shortToken.length ? shortToken : @""]];
}

- (void)showCenterNotice:(NSString *)message {
    UILabel *n = [[UILabel alloc] initWithFrame:CGRectMake(34, (self.view.bounds.size.height - 58) / 2, self.view.bounds.size.width - 68, 58)];
    n.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.82];
    n.textColor = UIColor.whiteColor;
    n.text = message ?: @"";
    n.textAlignment = NSTextAlignmentCenter;
    n.font = [UIFont boldSystemFontOfSize:16];
    n.layer.cornerRadius = 18;
    n.layer.masksToBounds = YES;
    [self.view addSubview:n];
    [UIView animateWithDuration:0.25 delay:1.2 options:0 animations:^{ n.alpha = 0; } completion:^(__unused BOOL f){ [n removeFromSuperview]; }];
}

@end

static UIWindow *gpsqWindow = nil;

static void GPSQShowWindow(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gpsqWindow) { gpsqWindow.hidden = NO; return; }
        gpsqWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        gpsqWindow.windowLevel = UIWindowLevelAlert + 35;
        gpsqWindow.backgroundColor = UIColor.clearColor;
        gpsqWindow.rootViewController = [GPSQRootController new];
        gpsqWindow.hidden = NO;
    });
}

__attribute__((constructor)) static void GPSQInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
            GPSQShowWindow();
        }];
        GPSQShowWindow();
    });
}
