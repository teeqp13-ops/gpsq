//
//  WFGPSPanel+Activation.mm
//  مثال ربط WFActivationView بواجهة GPS الرئيسية (الزر العائم / المنيو)
//
//  الفكرة: أي عنصر بالمنيو يعتبر "مميزة مدفوعة" يستدعي checkActivationThen:
//  قبل ما يفتح فعليًا. باقي عناصر المنيو (زر GPS العائم، البحث، إلخ) تفتح
//  عادي بدون أي مرور على التفعيل.
//

#import "WFGPSPanel.h"      // ملفك الأساسي (المسار/الاسم حسب مشروعك)
#import "WFActivationView.h"

@implementation WFGPSPanel (Activation)

// استدعِ هالميثود قبل فتح أي ميزة مقفولة (مسارات محفوظة، بروفايلات، إلخ)
- (void)checkActivationThen:(void (^)(void))unlockedAction {

    if ([WFActivationView isActivated]) {
        // مفعّل مسبقًا -> نفّذ الميزة مباشرة
        if (unlockedAction) unlockedAction();
        return;
    }

    // غير مفعّل -> اعرض لوحة التفعيل. إذا ألغى المستخدم (الإكس / ما فيه كود)
    // ما يصير شيء، والميزة المطلوبة ما تفتح، لكن باقي التطبيق يشتغل عادي
    __weak typeof(self) weakSelf = self;
    [WFActivationView presentOnViewController:self
        onSubmit:^(NSString *code) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || code.length == 0) return;

            [strongSelf sendActivationCodeToServer:code completion:^(BOOL success) {
                if (success) {
                    [WFActivationView setActivated:YES];
                    if (unlockedAction) unlockedAction();
                } else {
                    // اعرض رسالة خطأ بسيطة (كود غير صحيح / منتهي)
                    [strongSelf showActivationErrorAlert];
                }
            }];
        }
        onLater:^{
            // المستخدم ضغط الإكس أو رجع -> ما يصير شيء، الميزة تبقى مقفولة بس التطبيق يكمل
        }];
}

// نداء الـ API الفعلي عندك (mm.p3nd.fun) - HMAC-SHA256
- (void)sendActivationCodeToServer:(NSString *)code completion:(void (^)(BOOL success))completion {
    NSURL *url = [NSURL URLWithString:@"https://mm.p3nd.fun/api.php?action=activate"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSDictionary *body = @{ @"code": code, @"device_id": [self deviceIdentifier] };
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        BOOL ok = NO;
        if (data && !error) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            ok = [json[@"success"] boolValue];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(ok);
        });
    }];
    [task resume];
}

- (NSString *)deviceIdentifier {
    return [[[UIDevice currentDevice] identifierForVendor] UUIDString];
}

- (void)showActivationErrorAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"كود غير صحيح"
                                                                     message:@"تأكد من الكود وحاول مرة ثانية"
                                                              preferredStyle:UIAlertControllerStyleAlert];
    alert.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

/*
 مثال استخدام داخل زر بالمنيو (مثلاً "المسارات المحفوظة"):

 - (void)savedRoutesButtonTapped {
     [self checkActivationThen:^{
         [self openSavedRoutesScreen];   // يفتح فقط بعد التأكد من التفعيل
     }];
 }

 وزر GPS العائم الأساسي يبقى بدون أي ربط بالتفعيل، يشتغل مباشرة:

 - (void)floatingGPSButtonTapped {
     [self toggleGPSPanel];   // بدون فحص تفعيل
 }
*/
