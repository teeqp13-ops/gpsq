#import "WolFoxLicenseClient.h"
#import <UIKit/UIKit.h>

static NSString * const WFBaseURL = @"https://8001-idlt4ulkrwfpqs2dxf33d-d1d031a5.sg1.manus.computer/api";
static NSString * const WFProjectKey = @"wf_live_88d53403fb38d1419ba1a2feb95c56e2bf5e5d59444ecdc6";
static NSString * const WFLicenseStorageKey = @"wolfox_license_code";

@implementation WolFoxLicenseClient
+ (instancetype)shared { static id x; static dispatch_once_t once; dispatch_once(&once, ^{ x=[self new]; }); return x; }
- (NSString *)uuid { return UIDevice.currentDevice.identifierForVendor.UUIDString ?: @"unknown"; }

- (void)logout {
    [NSUserDefaults.standardUserDefaults removeObjectForKey:WFLicenseStorageKey];
    [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)request:(NSString *)endpoint code:(NSString *)code completion:(void(^)(NSDictionary *, NSError *))completion {
    NSURL *url=[NSURL URLWithString:[NSString stringWithFormat:@"%@/%@",WFBaseURL,endpoint]];
    NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:url]; r.HTTPMethod=@"POST";
    [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [r setValue:WFProjectKey forHTTPHeaderField:@"X-API-Key"];
    NSDictionary *body=@{
        @"code":code ?: @"", 
        @"device_uuid":[self uuid], 
        @"model":UIDevice.currentDevice.model ?: @"iPhone", 
        @"app_version":@"11.0"
    };
    r.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    [[[NSURLSession sharedSession] dataTaskWithRequest:r completionHandler:^(NSData *d, NSURLResponse *resp, NSError *e){
        NSDictionary *j=nil; if(d) j=[NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(j ?: @{}, e); });
    }] resume];
}

- (void)ensureAuthorizedFrom:(UIViewController *)controller completion:(void (^)(BOOL))completion {
    NSString *saved=[NSUserDefaults.standardUserDefaults stringForKey:WFLicenseStorageKey];
    if(saved.length){ 
        [self request:@"activate.php" code:saved completion:^(NSDictionary *j,NSError *e){ 
            if([j[@"ok"] boolValue]) {
                completion(YES); 
            } else { 
                // إذا كان الكود محظور أو غير صالح، نقوم بفصله فوراً
                [self logout];
                [self prompt:controller completion:completion]; 
            }
        }]; 
    } else {
        [self prompt:controller completion:completion];
    }
}

- (void)prompt:(UIViewController *)controller completion:(void (^)(BOOL))completion {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"تفعيل Wolf GPS Pro" message:@"أدخل كود الاشتراك أو الترخيص" preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *t){ t.placeholder=@"XXXX-XXXX-XXXX"; t.autocapitalizationType=UITextAutocapitalizationTypeAllCharacters; }];
    
    [a addAction:[UIAlertAction actionWithTitle:@"تفعيل" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x){
        NSString *code=[a.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if(!code.length){ [self prompt:controller completion:completion]; return; }
        
        [self request:@"activate.php" code:code completion:^(NSDictionary *j,NSError *e){
            if([j[@"ok"] boolValue]){ 
                [NSUserDefaults.standardUserDefaults setObject:code forKey:WFLicenseStorageKey];
                [NSUserDefaults.standardUserDefaults synchronize];
                
                // رسالة تم تفعيل الاشتراك بنجاح
                UIAlertController *success = [UIAlertController alertControllerWithTitle:@"تم التفعيل" message:@"تم تفعيل الاشتراك بنجاح" preferredStyle:UIAlertControllerStyleAlert];
                [success addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * _Nonnull action) {
                    completion(YES);
                }]];
                [controller presentViewController:success animated:YES completion:nil];
            }
            else { 
                UIAlertController *err=[UIAlertController alertControllerWithTitle:@"فشل التفعيل" message:j[@"message"] ?: @"تعذر الاتصال بالخادم" preferredStyle:UIAlertControllerStyleAlert]; 
                [err addAction:[UIAlertAction actionWithTitle:@"إعادة المحاولة" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *z){ [self prompt:controller completion:completion]; }]]; 
                [controller presentViewController:err animated:YES completion:nil]; 
            }
        }];
    }]];
    [controller presentViewController:a animated:YES completion:nil];
}
@end
